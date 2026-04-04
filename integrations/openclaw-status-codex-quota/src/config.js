const DEFAULT_CONFIG = Object.freeze({
  enabled: true,
  openclawCommand: "openclaw",
  quotaCommand: "codexQuotaPeek",
  quotaTimeoutMs: 600,
  statusTimeoutMs: 15000,
  cliInject: true,
  slashOverride: true
});

function asPositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function resolvePluginConfig(value) {
  const input = value && typeof value === "object" ? value : {};
  return {
    enabled: input.enabled !== false,
    openclawCommand: typeof input.openclawCommand === "string" && input.openclawCommand.trim()
      ? input.openclawCommand.trim()
      : DEFAULT_CONFIG.openclawCommand,
    quotaCommand: typeof input.quotaCommand === "string" && input.quotaCommand.trim()
      ? input.quotaCommand.trim()
      : DEFAULT_CONFIG.quotaCommand,
    quotaTimeoutMs: asPositiveInt(input.quotaTimeoutMs, DEFAULT_CONFIG.quotaTimeoutMs),
    statusTimeoutMs: asPositiveInt(input.statusTimeoutMs, DEFAULT_CONFIG.statusTimeoutMs),
    cliInject: input.cliInject !== false,
    slashOverride: input.slashOverride !== false
  };
}

export { DEFAULT_CONFIG };
