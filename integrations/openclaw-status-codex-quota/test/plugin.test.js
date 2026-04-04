import test from "node:test";
import assert from "node:assert/strict";

import {
  formatQuotaBlock,
  injectQuotaIntoJson,
  mergeQuotaIntoStatusOutput,
  normalizeQuotaSnapshot,
  parseJsonFromMixedOutput,
  tokenizeArgs,
  wantsJsonOutput
} from "../src/quota.js";
import { resolvePluginConfig } from "../src/config.js";
import { getCurrentCliArgs } from "../src/plugin.js";

test("resolvePluginConfig applies defaults", () => {
  const config = resolvePluginConfig({});
  assert.equal(config.enabled, true);
  assert.equal(config.quotaCommand, "codexQuotaPeek");
  assert.equal(config.quotaTimeoutMs, 600);
});

test("tokenizeArgs handles quoted values", () => {
  assert.deepEqual(
    tokenizeArgs('--json --timeout 5000 --note "hello world"'),
    ["--json", "--timeout", "5000", "--note", "hello world"]
  );
  assert.equal(wantsJsonOutput("--deep --json"), true);
});

test("normalizeQuotaSnapshot returns null when payload is empty", () => {
  assert.equal(normalizeQuotaSnapshot({}), null);
});

test("formatQuotaBlock renders session and weekly details", () => {
  const quota = normalizeQuotaSnapshot({
    account: { display_name: "67560691@qq.com", plan: "Pro" },
    source: "API",
    status: { updated: "just updated", line1: "H 67%", line2: "W 84%" },
    session: { label: "5 hours", reset: "20:23", percent: "67%" },
    weekly: { label: "7 days", reset: "Apr 11", percent: "84%" }
  });

  assert.ok(quota);
  const text = formatQuotaBlock(quota);
  assert.match(text, /Codex Quota · 67560691@qq.com · Pro/);
  assert.match(text, /5 hours: · H 67% · reset 20:23/);
  assert.match(text, /7 days: · W 84% · reset Apr 11/);
  assert.match(text, /updated just updated · source API/);
});

test("injectQuotaIntoJson appends codexQuota object", () => {
  const merged = injectQuotaIntoJson(
    { ok: true },
    normalizeQuotaSnapshot({
      source: "local logs",
      status: { updated: "20s", line1: "H 70%", line2: "W 82%" },
      session: { label: "5 hours", reset: "20:23", percent: "70%" },
      weekly: { label: "7 days", reset: "Apr 11", percent: "82%" }
    })
  );

  assert.equal(merged.ok, true);
  assert.equal(merged.codexQuota.source, "local logs");
  assert.equal(merged.codexQuota.weekly.percent, "82%");
});

test("mergeQuotaIntoStatusOutput appends plain-text quota block", () => {
  const quota = normalizeQuotaSnapshot({
    source: "API",
    status: { updated: "just updated", line1: "H 67%", line2: "W 84%" },
    session: { label: "5 hours", reset: "20:23", percent: "67%" },
    weekly: { label: "7 days", reset: "Apr 11", percent: "84%" }
  });

  const output = mergeQuotaIntoStatusOutput("Base status\n", quota, { json: false });
  assert.match(output, /Base status/);
  assert.match(output, /Codex Quota/);
  assert.match(output, /source API/);
});

test("mergeQuotaIntoStatusOutput augments JSON when parsable", () => {
  const quota = normalizeQuotaSnapshot({
    source: "API",
    status: { updated: "5s", line1: "H 75%", line2: "W 86%" },
    session: { label: "5 hours", reset: "20:23", percent: "75%" },
    weekly: { label: "7 days", reset: "Apr 11", percent: "86%" }
  });

  const output = mergeQuotaIntoStatusOutput(JSON.stringify({ ok: true }), quota, { json: true });
  const parsed = JSON.parse(output);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.codexQuota.source, "API");
});

test("parseJsonFromMixedOutput tolerates non-json prelude", () => {
  const parsed = parseJsonFromMixedOutput("[warn] prelude\n{\"ok\":true}");
  assert.deepEqual(parsed, { ok: true });
});

test("mergeQuotaIntoStatusOutput augments JSON even with prelude", () => {
  const quota = normalizeQuotaSnapshot({
    source: "API",
    status: { updated: "5s", line1: "H 75%", line2: "W 86%" },
    session: { label: "5 hours", reset: "20:23", percent: "75%" },
    weekly: { label: "7 days", reset: "Apr 11", percent: "86%" }
  });

  const output = mergeQuotaIntoStatusOutput("[warn] prelude\n{\"ok\":true}", quota, { json: true });
  const parsed = JSON.parse(output);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.codexQuota.weekly.percent, "86%");
});

test("getCurrentCliArgs drops node and executable entries", () => {
  assert.deepEqual(
    getCurrentCliArgs(["node", "/usr/local/bin/openclaw", "status", "--json"]),
    ["status", "--json"]
  );
});
