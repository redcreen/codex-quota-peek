import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { createRequire } from "node:module";
import util from "node:util";
import { resolvePluginConfig } from "./config.js";
import {
  DISABLE_ENV_KEY,
  injectQuotaIntoJson,
  loadQuotaSnapshot,
  mergeQuotaIntoStatusOutput,
  runBaseStatus,
  wantsJsonOutput
} from "./quota.js";

function beginStdoutCapture() {
  const originalWrite = process.stdout.write.bind(process.stdout);
  let buffer = "";

  function patchedWrite(chunk, encoding, callback) {
    if (Buffer.isBuffer(chunk)) {
      buffer += chunk.toString(typeof encoding === "string" ? encoding : undefined);
    } else {
      buffer += String(chunk);
    }

    if (typeof encoding === "function") encoding();
    if (typeof callback === "function") callback();
    return true;
  }

  process.stdout.write = patchedWrite;

  return {
    restore() {
      process.stdout.write = originalWrite;
      return buffer;
    },
    write(text) {
      originalWrite(text);
    }
  };
}

export function getCurrentCliArgs(argv = process.argv) {
  return Array.isArray(argv) ? argv.slice(2) : [];
}

function isCurrentCliStatusInvocation() {
  for (const token of getCurrentCliArgs()) {
    if (!token || token.startsWith("-")) continue;
    return token === "status";
  }
  return false;
}

function currentCliWantsJson() {
  return getCurrentCliArgs().includes("--json");
}

function stripPluginPrelude(output) {
  return String(output ?? "")
    .split("\n")
    .filter((line) => !/^\[plugins\] \[[^\]]+\] plugin loaded /.test(line))
    .join("\n");
}

const CLI_QUOTA_BUDGET_MS = 200;
let defaultRuntimePromise = null;

async function loadOpenClawDefaultRuntime() {
  if (defaultRuntimePromise) return defaultRuntimePromise;

  defaultRuntimePromise = (async () => {
    const cliEntry = fs.realpathSync(process.argv[1]);
    const require = createRequire(cliEntry);
    const openClawEntry = require.resolve("openclaw");
    const distDir = path.dirname(openClawEntry);
    const subsystemFile = fs.readdirSync(distDir).find((entry) => /^subsystem-.*\.js$/.test(entry));
    if (!subsystemFile) return null;
    const module = await import(pathToFileURL(path.join(distDir, subsystemFile)).href);
    return module?.m ?? null;
  })().catch(() => null);

  return defaultRuntimePromise;
}

function installCliStatusInjection(api, pluginConfig, logger) {
  if (!pluginConfig.cliInject) return;
  if (process.env[DISABLE_ENV_KEY] === "1") return;
  if (!isCurrentCliStatusInvocation()) return;
  if (globalThis.__statusCodexQuotaInstalled) return;

  globalThis.__statusCodexQuotaInstalled = true;

  const json = currentCliWantsJson();

  if (json) {
    loadOpenClawDefaultRuntime().then((defaultRuntime) => {
      if (!defaultRuntime || typeof defaultRuntime.writeJson !== "function") return;
      if (defaultRuntime.__statusCodexQuotaPatched) return;

      const originalWriteJson = defaultRuntime.writeJson.bind(defaultRuntime);
      defaultRuntime.writeJson = (value, space = 2) => {
        loadQuotaSnapshot(api.runtime, pluginConfig, {
          timeoutMs: Math.min(pluginConfig.quotaTimeoutMs, CLI_QUOTA_BUDGET_MS)
        }).then((quota) => {
          originalWriteJson(quota ? injectQuotaIntoJson(value, quota) : value, space);
        }).catch(() => {
          originalWriteJson(value, space);
        });
      };
      defaultRuntime.__statusCodexQuotaPatched = true;
    }).catch(() => {});

    logger.info(`[status-codex-quota] CLI status JSON runtime patch armed (quotaBudgetMs=${Math.min(pluginConfig.quotaTimeoutMs, CLI_QUOTA_BUDGET_MS)})`);
    return;
  }

  loadOpenClawDefaultRuntime().then((defaultRuntime) => {
    if (!defaultRuntime) return;
    if (defaultRuntime.__statusCodexQuotaTextPatched) return;

    const originalLog = typeof defaultRuntime.log === "function" ? defaultRuntime.log.bind(defaultRuntime) : null;
    const originalWriteStdout = typeof defaultRuntime.writeStdout === "function" ? defaultRuntime.writeStdout.bind(defaultRuntime) : null;
    if (!originalLog && !originalWriteStdout) return;

    defaultRuntime.__statusCodexQuotaTextPatched = true;

    const buffer = [];
    let quota = null;
    let quotaSettled = false;
    let flushed = false;

    const quotaPromise = loadQuotaSnapshot(api.runtime, pluginConfig, {
      timeoutMs: Math.min(pluginConfig.quotaTimeoutMs, CLI_QUOTA_BUDGET_MS)
    }).then((value) => {
      quota = value;
      quotaSettled = true;
    }).catch(() => {
      quota = null;
      quotaSettled = true;
    });

    defaultRuntime.log = (...args) => {
      buffer.push(`${util.format(...args)}\n`);
    };
    defaultRuntime.writeStdout = (value) => {
      const text = String(value ?? "");
      buffer.push(text.endsWith("\n") ? text : `${text}\n`);
    };

    const flush = () => {
      if (flushed) return;
      flushed = true;

      const baseOutput = stripPluginPrelude(buffer.join(""));
      const finalOutput = mergeQuotaIntoStatusOutput(baseOutput, quota, { json: false });
      if (originalWriteStdout) originalWriteStdout(finalOutput);
      else if (originalLog) originalLog(finalOutput.trimEnd());
    };

    process.once("beforeExit", () => {
      if (flushed) return;
      if (quotaSettled) {
        flush();
        return;
      }

      const keepAlive = setInterval(() => {}, 25);
      const timeout = setTimeout(() => {
        clearInterval(keepAlive);
        flush();
      }, Math.min(pluginConfig.quotaTimeoutMs, CLI_QUOTA_BUDGET_MS) + 25);

      quotaPromise.finally(() => {
        clearTimeout(timeout);
        clearInterval(keepAlive);
        flush();
      });
    });
    process.once("exit", flush);
  }).catch(() => {});

  logger.info(`[status-codex-quota] CLI status text runtime patch armed (quotaBudgetMs=${Math.min(pluginConfig.quotaTimeoutMs, CLI_QUOTA_BUDGET_MS)})`);
}

async function handleStatusCommand(api, pluginConfig, ctx) {
  const rawArgs = ctx.args?.trim() ?? "";
  const json = wantsJsonOutput(rawArgs);

  const [statusResult, quota] = await Promise.all([
    runBaseStatus(api.runtime, pluginConfig, rawArgs),
    loadQuotaSnapshot(api.runtime, pluginConfig).catch(() => null)
  ]);

  if (!statusResult.ok) {
    const details = statusResult.stderr.trim() || statusResult.stdout.trim() || "status command failed";
    return { text: `Status failed: ${details}` };
  }

  const body = statusResult.stdout.trim();
  if (!body) return { text: "Status returned no output." };

  return {
    text: mergeQuotaIntoStatusOutput(body, quota, { json }).trimEnd()
  };
}

export default {
  id: "status-codex-quota",
  name: "Status Codex Quota",
  description: "Inject Codex quota into OpenClaw status output",

  configSchema: {
    parse(value) {
      return resolvePluginConfig(value);
    }
  },

  register(api) {
    if (process.env[DISABLE_ENV_KEY] === "1") return;

    const pluginConfig = resolvePluginConfig(api.pluginConfig);
    if (!pluginConfig.enabled) {
      api.logger.info("[status-codex-quota] disabled");
      return;
    }

    installCliStatusInjection(api, pluginConfig, api.logger);

    if (pluginConfig.slashOverride) {
      api.registerCommand({
        name: "status",
        description: "Show OpenClaw status and append Codex quota when available.",
        acceptsArgs: true,
        handler: async (ctx) => await handleStatusCommand(api, pluginConfig, ctx)
      });
    }

    api.logger.info(
      `[status-codex-quota] loaded (cliInject=${pluginConfig.cliInject}, slashOverride=${pluginConfig.slashOverride}, quotaTimeoutMs=${pluginConfig.quotaTimeoutMs})`
    );
  }
};
