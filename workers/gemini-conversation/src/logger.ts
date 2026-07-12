export const logger = {
  info: (msg: string, meta?: Record<string, unknown>) =>
    process.stdout.write(JSON.stringify({ t: new Date().toISOString(), level: "info", service: "gemini-conversation", msg, ...meta }) + "\n"),
  warn: (msg: string, meta?: Record<string, unknown>) =>
    process.stderr.write(JSON.stringify({ t: new Date().toISOString(), level: "warn", service: "gemini-conversation", msg, ...meta }) + "\n"),
  error: (msg: string, meta?: Record<string, unknown>) =>
    process.stderr.write(JSON.stringify({ t: new Date().toISOString(), level: "error", service: "gemini-conversation", msg, ...meta }) + "\n"),
};