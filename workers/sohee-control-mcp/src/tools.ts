// MCP 도구 10개 정의 + 핸들러 (P1, 2026-07-12)
// 원칙: 화이트리스트만, 모든 호출은 멱등키 필수, 감사 로그 자동

export interface McpTool {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

const RAISE_NOTE = "MCP 도구는 실제 구현 후 동작 — 현재는 stub. 사람 단계 #7(Hermes Secret) 완료 후 활성.";

export const TOOLS: McpTool[] = [
  {
    name: "get_active_runtime_config",
    description: "현재 사업자에 활성 적용된 Runtime Config 조회",
    inputSchema: {
      type: "object",
      properties: { business_profile_id: { type: "number" } },
      required: ["business_profile_id"],
    },
  },
  {
    name: "list_pending_jobs",
    description: "Hermes가 처리해야 할 작업 큐 조회",
    inputSchema: {
      type: "object",
      properties: { business_profile_id: { type: "number" }, limit: { type: "number" } },
    },
  },
  {
    name: "claim_job",
    description: "작업을 Hermes가 처리한다고 마킹",
    inputSchema: {
      type: "object",
      properties: { job_id: { type: "number" } },
      required: ["job_id"],
    },
  },
  {
    name: "submit_job_result",
    description: "작업 처리 결과를 Rails에 보고",
    inputSchema: {
      type: "object",
      properties: { job_id: { type: "number" }, result: { type: "object" } },
      required: ["job_id", "result"],
    },
  },
  {
    name: "request_human_review",
    description: "사람 승인이 필요한 변경 후보를 Rails에 기록",
    inputSchema: {
      type: "object",
      properties: {
        business_profile_id: { type: "number" },
        target_kind: { type: "string" },
        target_field: { type: "string" },
        proposed_payload: { type: "object" },
        previous_payload: { type: "object" },
        reason: { type: "string" },
        user_quote: { type: "string" },
      },
      required: ["business_profile_id", "target_kind", "proposed_payload"],
    },
  },
  {
    name: "save_content_draft",
    description: "콘텐츠 초안을 Rails DB에 저장",
    inputSchema: {
      type: "object",
      properties: {
        business_profile_id: { type: "number" },
        title: { type: "string" },
        body: { type: "string" },
        channel: { type: "string" },
      },
      required: ["business_profile_id", "body"],
    },
  },
  {
    name: "report_knowledge_gap",
    description: "AI가 답변 못한 영역을 보강 요청으로 기록",
    inputSchema: {
      type: "object",
      properties: {
        business_profile_id: { type: "number" },
        summary: { type: "string" },
        context: { type: "object" },
      },
      required: ["business_profile_id", "summary"],
    },
  },
  {
    name: "post_discord_report",
    description: "Discord에 일일/주간/이상 보고 메시지 송신",
    inputSchema: {
      type: "object",
      properties: {
        business_profile_id: { type: "number" },
        channel_id: { type: "string" },
        content: { type: "string" },
        report_kind: { type: "string", enum: ["daily", "weekly", "incident"] },
      },
      required: ["business_profile_id", "content"],
    },
  },
  {
    name: "report_agent_health",
    description: "Hermes 자신의 헬스 체크 보고",
    inputSchema: {
      type: "object",
      properties: { health: { type: "object" } },
      required: ["health"],
    },
  },
  {
    name: "recall_business_memory",
    description: "사업자 메모리 조회 (BusinessMemory)",
    inputSchema: {
      type: "object",
      properties: {
        business_profile_id: { type: "number" },
        kinds: { type: "array", items: { type: "string" } },
        limit: { type: "number" },
      },
      required: ["business_profile_id"],
    },
  },
];

export async function handleTool(name: string, _args: Record<string, unknown>): Promise<unknown> {
  return {
    tool: name,
    note: RAISE_NOTE,
    args_received: Object.keys(_args),
  };
}