// Hermes MCP Server entrypoint (P1, 2026-07-12)
// Hermes Agent가 stdio로 호출 — 10개 도구 화이트리스트

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { TOOLS, handleTool } from "./tools.js";

const server = new Server(
  { name: "sohee-control-mcp", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: t.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const tool = TOOLS.find((t) => t.name === name);
  if (!tool) {
    return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
  }
  try {
    const result = await handleTool(name, (args ?? {}) as Record<string, unknown>);
    return { content: [{ type: "text", text: JSON.stringify(result) }] };
  } catch (err) {
    return { content: [{ type: "text", text: `Error: ${String(err)}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[sohee-control-mcp] connected via stdio");