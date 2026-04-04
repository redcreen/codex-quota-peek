export const DISABLE_ENV_KEY = "OPENCLAW_STATUS_QUOTA_DISABLE";

export function tokenizeArgs(input) {
  const source = String(input ?? "").trim();
  if (!source) return [];

  const tokens = [];
  let current = "";
  let quote = null;
  let escape = false;

  for (const char of source) {
    if (escape) {
      current += char;
      escape = false;
      continue;
    }
    if (char === "\\") {
      escape = true;
      continue;
    }
    if (quote) {
      if (char === quote) {
        quote = null;
      } else {
        current += char;
      }
      continue;
    }
    if (char === "'" || char === "\"") {
      quote = char;
      continue;
    }
    if (/\s/.test(char)) {
      if (current) {
        tokens.push(current);
        current = "";
      }
      continue;
    }
    current += char;
  }

  if (current) tokens.push(current);
  return tokens;
}

export function wantsJsonOutput(rawArgs) {
  return tokenizeArgs(rawArgs).includes("--json");
}

export async function runCommand(runtime, command, args, { timeoutMs = 1000, env = process.env } = {}) {
  const result = await runtime.system.runCommandWithTimeout(
    [command, ...args],
    { timeoutMs, env }
  );

  return {
    ok: result.code === 0 && result.termination === "exit",
    timedOut: result.termination === "timeout" || result.termination === "no-output-timeout",
    code: result.code,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
    termination: result.termination
  };
}

export async function loadQuotaSnapshot(runtime, pluginConfig, { timeoutMs } = {}) {
  const result = await runCommand(
    runtime,
    pluginConfig.quotaCommand,
    ["status", "--json"],
    { timeoutMs: timeoutMs ?? pluginConfig.quotaTimeoutMs }
  );

  if (!result.ok || !result.stdout.trim()) return null;

  let parsed;
  try {
    parsed = JSON.parse(result.stdout);
  } catch {
    return null;
  }

  return normalizeQuotaSnapshot(parsed);
}

export function normalizeQuotaSnapshot(parsed) {
  const sessionPercent = parsed?.session?.percent;
  const weeklyPercent = parsed?.weekly?.percent;
  const line1 = parsed?.status?.line1;
  const line2 = parsed?.status?.line2;

  if (!sessionPercent && !weeklyPercent && !line1 && !line2) return null;

  return {
    account: parsed?.account?.display_name || parsed?.account?.email || null,
    plan: parsed?.account?.plan || null,
    source: parsed?.source || null,
    updated: parsed?.status?.updated || null,
    session: {
      label: parsed?.session?.label || "5 hours",
      percent: sessionPercent || null,
      reset: parsed?.session?.reset || null,
      line: line1 || null
    },
    weekly: {
      label: parsed?.weekly?.label || "7 days",
      percent: weeklyPercent || null,
      reset: parsed?.weekly?.reset || null,
      line: line2 || null
    },
    credits: parsed?.credits || null
  };
}

export function formatQuotaBlock(quota) {
  const lines = [];
  const headerMeta = [];
  if (quota.account) headerMeta.push(quota.account);
  if (quota.plan) headerMeta.push(quota.plan);
  lines.push(headerMeta.length > 0 ? `Codex Quota · ${headerMeta.join(" · ")}` : "Codex Quota");

  if (quota.session?.line || quota.session?.percent) {
    const sessionParts = [`${quota.session.label}:`];
    if (quota.session.line) sessionParts.push(quota.session.line);
    else if (quota.session.percent) sessionParts.push(quota.session.percent);
    if (quota.session.reset) sessionParts.push(`reset ${quota.session.reset}`);
    lines.push(`- ${sessionParts.join(" · ")}`);
  }

  if (quota.weekly?.line || quota.weekly?.percent) {
    const weeklyParts = [`${quota.weekly.label}:`];
    if (quota.weekly.line) weeklyParts.push(quota.weekly.line);
    else if (quota.weekly.percent) weeklyParts.push(quota.weekly.percent);
    if (quota.weekly.reset) weeklyParts.push(`reset ${quota.weekly.reset}`);
    lines.push(`- ${weeklyParts.join(" · ")}`);
  }

  const meta = [];
  if (quota.updated) meta.push(`updated ${quota.updated}`);
  if (quota.source) meta.push(`source ${quota.source}`);
  if (meta.length > 0) lines.push(`- ${meta.join(" · ")}`);

  return lines.join("\n");
}

export function injectQuotaIntoJson(baseJson, quota) {
  return {
    ...baseJson,
    codexQuota: {
      account: quota.account,
      plan: quota.plan,
      source: quota.source,
      updated: quota.updated,
      session: quota.session,
      weekly: quota.weekly,
      credits: quota.credits
    }
  };
}

export function parseJsonFromMixedOutput(body) {
  const raw = String(body ?? "").trim();
  if (!raw) return null;

  try {
    return JSON.parse(raw);
  } catch {
    const firstBrace = raw.indexOf("{");
    if (firstBrace === -1) return null;
    try {
      return JSON.parse(raw.slice(firstBrace));
    } catch {
      return null;
    }
  }
}

export function mergeQuotaIntoStatusOutput(baseOutput, quota, { json = false } = {}) {
  const body = String(baseOutput ?? "");
  if (!quota) return body;

  if (json) {
    const parsed = parseJsonFromMixedOutput(body);
    if (!parsed) return body;
    return `${JSON.stringify(injectQuotaIntoJson(parsed, quota), null, 2)}\n`;
  }

  const trimmed = body.replace(/\s+$/, "");
  if (!trimmed) return `${formatQuotaBlock(quota)}\n`;
  return `${trimmed}\n\n${formatQuotaBlock(quota)}\n`;
}

export async function runBaseStatus(runtime, pluginConfig, rawArgs) {
  const args = ["status", ...tokenizeArgs(rawArgs)];
  return await runCommand(
    runtime,
    pluginConfig.openclawCommand,
    args,
    {
      timeoutMs: pluginConfig.statusTimeoutMs,
      env: {
        ...process.env,
        [DISABLE_ENV_KEY]: "1"
      }
    }
  );
}
