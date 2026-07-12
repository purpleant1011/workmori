# Discord-Native 확장 — Gemini Provider 전략 (6단계)

> 기준: `security_model.md` (4단계), `data_flow.md` (3단계)
> 핵심: **모델 ID·Provider를 코드에 하드코딩하지 않는다. Runtime Config에서 변경 가능.**

---

## 1. Provider 인터페이스

```typescript
// workers/gemini-conversation/src/provider.ts
export interface GeminiProvider {
  name: string;
  
  converse(args: {
    context: ConversationContext;
    systemPrompt: string;
    modelCode: string;
    thinking: ThinkingLevel;
    tools?: ToolDefinition[];
  }): Promise<ConverseResult>;
  
  extractChange(args: {
    context: ConversationContext;
    currentRuntime: RuntimeSnapshot;
    systemPrompt: string;
    modelCode: string;
    thinking: ThinkingLevel;
  }): Promise<ChangeExtractionResult>;
  
  generateContent(args: {
    context: ConversationContext;
    contentKind: ContentKind;
    systemPrompt: string;
    modelCode: string;
    thinking: ThinkingLevel;
  }): Promise<ContentDraft>;
  
  classifyInquiry(args: {
    context: ConversationContext;
    systemPrompt: string;
    modelCode: string;
  }): Promise<InquiryClassification>;
  
  summarizeReport(args: {
    runtime: RuntimeSnapshot;
    executions: ExecutionSummary[];
    systemPrompt: string;
    modelCode: string;
  }): Promise<ReportSummary>;
}

export type ThinkingLevel = "minimal" | "low" | "medium" | "high";

export interface ConverseResult {
  text: string;
  usage?: { promptTokens: number; completionTokens: number; totalTokens: number };
  modelUsed: string;
  durationMs: number;
  raw?: unknown;
}

export interface ChangeExtractionResult {
  changeType: string | null;  // null = 변경 없음
  currentValue: unknown;
  proposedValue: unknown;
  reason: string;
  confidence: number;        // 0..1
  riskLevel: "low" | "medium" | "high" | "blocked";
  effectiveFrom?: string;
  expiresAt?: string;
  isOneTime: boolean;
}

export interface ContentDraft {
  title: string;
  body: string;
  caption?: string;
  hashtags?: string[];
  imageBrief?: string;
  estimatedRisk: "low" | "medium" | "high";
}

export interface InquiryClassification {
  category: "product_inquiry" | "reservation" | "refund" | "complaint" | "general" | "escalation";
  needsHuman: boolean;
  reason: string;
  priority: "low" | "medium" | "high" | "urgent";
}
```

---

## 2. 구현체 3종

### 2.1 GeminiApiProvider (프로덕션 기본)

```typescript
// workers/gemini-conversation/src/gemini_api_provider.ts
import { GoogleGenAI } from "@google/genai";

export class GeminiApiProvider implements GeminiProvider {
  name = "gemini_api";
  private client: GoogleGenAI;
  
  constructor(apiKey: string) {
    this.client = new GoogleGenAI({ apiKey });
  }
  
  async converse(args): Promise<ConverseResult> {
    const response = await this.client.interactions.create({
      model: args.modelCode,
      input: [
        { role: "system", content: args.systemPrompt },
        ...args.context.messages.map(m => ({ role: m.role, content: m.content }))
      ],
      thinking: { level: args.thinking },
      tools: args.tools
    });
    
    return {
      text: response.output,
      usage: response.usage,
      modelUsed: args.modelCode,
      durationMs: response.durationMs,
      raw: response
    };
  }
  
  // ... 다른 메소드들도 동일 패턴
}
```

**특징**:
- 공식 Google GenAI SDK (`@google/genai`)
- Interactions API (Function Calling / structured output)
- Auth Key 또는 Service Account 기반 인증
- 모든 호출 AuditEvent 기록
- 모델 카탈로그의 `code`로 모델 선택 (하드코딩 X)

### 2.2 AntigravityAgentProvider (복잡한 장기 작업)

```typescript
// workers/gemini-conversation/src/antigravity_agent_provider.ts
export class AntigravityAgentProvider implements GeminiProvider {
  name = "antigravity_agent";
  
  async converse(args): Promise<ConverseResult> {
    // 기본 대화에는 사용하지 않음
    throw new Error("Use GeminiApiProvider for general conversation");
  }
  
  async research(args: { topic: string; depth: number }): Promise<ResearchResult> {
    // 리서치, 파일 작업, 브라우저 작업 등
    // ...
  }
  
  // ... 다른 복잡한 작업 메소드
}
```

**용도**:
- 리서치 (경쟁사 분석, 트렌드 조사)
- 다단계 파일 작업 (대용량 문서 분석)
- 브라우저 작업 (웹 페이지 스크래핑/요약)
- **기본 대화에는 절대 사용하지 않음**

### 2.3 AntigravityCliDevProvider (개발 전용)

```typescript
// workers/gemini-conversation/src/antigravity_cli_dev_provider.ts
export class AntigravityCliDevProvider implements GeminiProvider {
  name = "antigravity_cli_dev";
  
  constructor(private cliPath: string, private workspace: string) {}
  
  // ... Antigravity CLI 호출
}
```

**정책 (절대 위반 금지)**:
- `FeatureFlag["antigravity_cli_enabled"]` 가 `true` 일 때만 로딩
- 프로덕션 환경에서는 `FeatureFlag`가 항상 `false`
- 로딩 자체를 시도하지 않음 (feature flag false면 클래스 생성 안 함)
- AuditEvent(action: antigravity.cli.disabled_in_production) 자동 경고

```typescript
// workers/gemini-conversation/src/index.ts
function selectProvider(env: NodeJS.ProcessEnv, flagService: FlagService): GeminiProvider {
  const provider = env.SOHEE_GEMINI_DEFAULT_PROVIDER || "gemini_api";
  
  if (provider === "antigravity_cli_dev") {
    if (env.RAILS_ENV === "production") {
      throw new Error("Antigravity CLI Dev Provider cannot be used in production");
    }
    const enabled = await flagService.get("antigravity_cli_enabled");
    if (!enabled) {
      throw new Error("Antigravity CLI Dev Provider is disabled by feature flag");
    }
    return new AntigravityCliDevProvider(env.ANTIGRAVITY_CLI_PATH, env.ANTIGRAVITY_WORKSPACE);
  }
  
  if (provider === "antigravity_agent") {
    return new AntigravityAgentProvider(env.ANTIGRAVITY_AGENT_URL);
  }
  
  return new GeminiApiProvider(env.GEMINI_API_KEY);
}
```

---

## 3. 모델 카탈로그 정책

### 절대 원칙

> **모델 ID와 Provider를 코드에 하드코딩하지 않는다.**

모든 모델은 `ModelCatalogEntry` 테이블에서 관리:

```ruby
{
  code: "gemini-3.5-flash",
  provider: "google",
  kind: "text",
  active: true,
  capabilities: {
    thinking_levels: ["minimal", "low", "medium", "high"],
    max_input_tokens: 1000000,
    max_output_tokens: 8192,
    supports_function_calling: true,
    supports_structured_output: true,
    supports_vision: false
  }
}
```

### 기본값 ENV

```
SOHEE_GEMINI_DEFAULT_PROVIDER=gemini_api
SOHEE_GEMINI_DEFAULT_MODEL=gemini-3.5-flash
SOHEE_GEMINI_FALLBACK_MODEL=<관리자 설정값>
SOHEE_GEMINI_DEFAULT_THINKING=low
```

### 사고 수준 (Thinking Level) 정책

| 작업 | 기본 thinking | Runtime Config로 변경 가능 |
|---|---|---|
| 일반 Discord 대화 | `minimal` 또는 `low` | ✅ |
| 변경안 추출 | `low` 또는 `medium` | ✅ |
| 정책 충돌 분석 | `medium` 또는 `high` | ✅ |
| 콘텐츠 작성 | `low` 또는 `medium` | ✅ |
| 리서치 (Antigravity) | `high` | ✅ |

`RuntimeConfig.bundle_json.model_routing.<task>.thinking` 으로 오버라이드.

---

## 4. 작업별 라우팅

```ruby
# app/services/ai/model_router.rb
class ModelRouter
  def select_for(task:, account:)
    runtime = RuntimeConfig.current_for(account)
    routing = runtime&.bundle_json&.dig("model_routing", task.to_s) || {}
    
    provider_code = routing["provider"] || ENV.fetch("SOHEE_GEMINI_DEFAULT_PROVIDER")
    model_code = routing["model"] || default_model_for(task)
    thinking = routing["thinking"] || default_thinking_for(task)
    
    {
      provider: provider_code,
      model: model_code,
      thinking: thinking,
      capabilities: ModelCatalogEntry.find_by(code: model_code)&.capabilities || {}
    }
  end
  
  private
  
  def default_model_for(task)
    case task
    when :converse, :classify_inquiry then ENV.fetch("SOHEE_GEMINI_DEFAULT_MODEL")
    when :extract_change, :generate_content then ENV.fetch("SOHEE_GEMINI_DEFAULT_MODEL")
    when :summarize_report then ENV.fetch("SOHEE_GEMINI_FALLBACK_MODEL")
    end
  end
  
  def default_thinking_for(task)
    case task
    when :converse then "low"
    when :classify_inquiry then "minimal"
    when :extract_change then "medium"
    when :generate_content then "low"
    when :summarize_report then "low"
    end
  end
end
```

---

## 5. 컨텍스트 격리

### Provider 호출 시 컨텍스트 분리

```typescript
interface ConversationContext {
  type: "owner_conversation" | "verified_business_knowledge" | 
        "content_generation" | "customer_response" | "internal_operations";
  messages: { role: "user" | "assistant" | "system"; content: string; timestamp?: string }[];
  metadata: {
    accountId: number;
    runtimeConfigId?: number;
    sessionId?: string;
  };
}
```

Rails 측에서 컨텍스트 구성 시 **반드시 type 명시**, Provider는 type별로 캐시 키 분리.

```typescript
class ContextCache {
  private cache = new Map<string, ConversationContext>();
  
  get(type: string, accountId: number): ConversationContext | null {
    return this.cache.get(`${type}:${accountId}`) || null;
  }
  
  set(type: string, accountId: number, ctx: ConversationContext) {
    this.cache.set(`${type}:${accountId}`, ctx);
  }
  
  invalidate(type: string, accountId: number) {
    this.cache.delete(`${type}:${accountId}`);
  }
}
```

**원칙**: 절대 모든 컨텍스트를 한 번에 보내지 않음. 작업별로 필요한 context_type만 로딩.

---

## 6. Function Calling / Structured Output

### 변경 추출

Gemini의 Function Calling 또는 Strict JSON Schema 모드 사용:

```typescript
const tools = [
  {
    name: "propose_change",
    description: "사용자가 사업장 설정 변경을 요청했습니다.",
    parameters: {
      type: "object",
      properties: {
        change_type: { type: "string", enum: ["business_hours", "brand_preference", "operating_rule", "forbidden_phrase", "escalation_rule", "campaign", "one_time_task", "none"] },
        current_value: { type: "object", description: "현재 값 (있는 경우)" },
        proposed_value: { type: "object", description: "새 값" },
        reason: { type: "string" },
        confidence: { type: "number", minimum: 0, maximum: 1 },
        risk_level: { type: "string", enum: ["low", "medium", "high", "blocked"] },
        effective_from: { type: "string", format: "date-time" },
        expires_at: { type: "string", format: "date-time" },
        is_one_time: { type: "boolean" }
      },
      required: ["change_type", "proposed_value", "reason", "confidence", "risk_level", "is_one_time"]
    }
  }
];

const response = await client.interactions.create({
  model: modelCode,
  input: [...],
  tools: [tools],
  tool_choice: "auto"  // 또는 "any" (반드시 호출)
});
```

### 출력 검증

```typescript
function validateChangeOutput(output: any): ChangeExtractionResult {
  const schema = z.object({
    change_type: z.string().nullable(),
    proposed_value: z.unknown(),
    reason: z.string(),
    confidence: z.number().min(0).max(1),
    risk_level: z.enum(["low", "medium", "high", "blocked"]),
    is_one_time: z.boolean()
  });
  
  const parsed = schema.safeParse(output);
  if (!parsed.success) {
    throw new Error(`Invalid Gemini output: ${parsed.error}`);
  }
  
  if (parsed.data.risk_level === "blocked") {
    // 절대 DB에 반영하지 않음
    AuditEvent.create({
      action: "gemini.change.blocked",
      metadata: { output: parsed.data }
    });
    throw new Error("Change blocked due to risk level");
  }
  
  return parsed.data;
}
```

---

## 7. 에러 처리

### 재시도 정책

```typescript
class GeminiApiProvider {
  async callWithRetry<T>(operation: () => Promise<T>, maxRetries = 3): Promise<T> {
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (err) {
        if (err.code === 429 && attempt < maxRetries) {
          const waitMs = (err.retryAfter || 60) * 1000;
          await new Promise(r => setTimeout(r, waitMs));
          continue;
        }
        if (err.code === "INVALID_ARGUMENT" && attempt === 0) {
          // 모델을 fallback으로 전환 시도
          return await this.tryFallbackModel(operation);
        }
        if (attempt === maxRetries) throw err;
        await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000));
      }
    }
    throw new Error("Unreachable");
  }
}
```

### Fallback 모델

```
SOHEE_GEMINI_FALLBACK_MODEL=<관리자 설정값>
```

429 / 5xx / 모델 사용 불가 시 자동 전환.

### 실패 시 안전한 응답

Gemini 호출 실패 시 Discord 응답:

> "지금은 응답을 생성할 수 없습니다. 잠시 후 다시 시도해 주세요. 문제가 계속되면 운영팀에 알려 주세요."

→ AuditEvent(action: gemini.call.failed, error_code, error_message)

---

## 8. 비용 / 사용량 추적

### UsageRecord 활용

```ruby
UsageRecord.create!(
  account_id: account.id,
  kind: "gemini_call",
  task: "converse",
  provider: "gemini_api",
  model_code: "gemini-3.5-flash",
  prompt_tokens: response.usage.prompt_tokens,
  completion_tokens: response.usage.completion_tokens,
  total_tokens: response.usage.total_tokens,
  duration_ms: response.duration_ms,
  cost_usd: calculate_cost(response.usage),
  occurred_at: Time.current
)
```

### 비용 한도

`Account.plan.gemini_monthly_token_limit` 초과 시:

- 다음 달까지 응답: "이번 달 AI 사용량을 모두 사용했습니다."
- 또는: `runtime_config.bundle_json.guardrails.cost_limit_exceeded_action = "pause_automation"` → 자동화 일시정지

---

## 9. 환경변수 (.env.example 추가)

```
# Gemini Provider
SOHEE_GEMINI_DEFAULT_PROVIDER=gemini_api
SOHEE_GEMINI_DEFAULT_MODEL=gemini-3.5-flash
SOHEE_GEMINI_FALLBACK_MODEL=<관리자 설정값>
SOHEE_GEMINI_DEFAULT_THINKING=low
GEMINI_API_KEY=<Keychain에서 로드 또는 환경변수>
GEMINI_REQUEST_TIMEOUT=30

# Antigravity (선택, dev only)
ANTIGRAVITY_CLI_PATH=
ANTIGRAVITY_AGENT_URL=
ANTIGRAVITY_WORKSPACE=
```

> 운영자는 macOS Keychain 또는 credential manager에 `GEMINI_API_KEY` 저장 후, `.env`에는 `GEMINI_API_KEY=$(security find-generic-password -s sohee-gemini -w)` 형태로 참조.

---

## 10. Feature Flag 통합

```ruby
# db/seeds/feature_flags.rb (신규)
FeatureFlag.find_or_create_by!(key: "antigravity_cli_enabled") do |f|
  f.enabled = false
  f.description = "Antigravity CLI Dev Provider — development only, never in production"
end

FeatureFlag.find_or_create_by!(key: "discord_gateway_enabled") do |f|
  f.enabled = true
  f.description = "Discord Gateway worker can poll Rails"
end

FeatureFlag.find_or_create_by!(key: "sohee_mcp_enabled") do |f|
  f.enabled = false
  f.description = "sohee-control-mcp tools exposed to Hermes Agent"
end
```

---

## 11. 테스트 전략

### 단위

- `gemini_api_provider.test.ts` — 모의 응답으로 parse/validate
- `model_router.test.ts` — Runtime Config 기반 라우팅
- `change_extractor.test.ts` — JSON schema 검증
- `antigravity_cli_provider.test.ts` — feature flag on/off 동작
- **프로덕션에서 antigravity_cli 호출 시도가 있는지 검증** (CI)

### 통합

- Discord 메시지 → Gemini 응답 → Outbound → Discord 메시지 (실제 모의 환경)

### 보안

- 모델 카탈로그에 없는 model_code로 호출 시도 → 거부
- feature flag false 상태에서 Antigravity CLI 호출 시도 → 거부

---

## 12. 사람 단계

1. **Gemini Google Cloud Project 선택**
2. **Auth Key 또는 Service Account 생성**
3. **API 활성화** (Generative AI API)
4. **macOS Keychain 또는 credential manager에 저장**
5. **모델 카탈로그 시드 데이터 입력** (gemini-3.5-flash 등)
6. **테스트 호출** (`scripts/test-gemini-call.ts`)
7. **운영 환경에 Secret 등록**

---

## 다음 단계

→ `hermes_integration.md` — Hermes MCP 도구 + 작업 흐름 + ACK + Rollback