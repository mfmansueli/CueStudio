#!/usr/bin/env node
// What Ultra AI really spent: Google's own call and token counts in the lab project (Cloud Monitoring: every phone and the web lab together),
// priced at the Cloud Billing catalog's current prices, day by day in this Mac's time zone. Read-only, through the Firebase CLI's login
// (`firebase login`): it enables, writes and changes nothing. Monitoring keeps these counts for six weeks.
//
//   node tools/ultra/spend.js [--days 42] [--project cue-script-ai-lab] [--json]
//
// The app's own price (`UltraPrice.swift`, what the lab's cost per script uses) is compared with the catalog's, so a price change shows here.
// Output tokens include the thinking (Google bills it as output). Monitoring doesn't tell cached input apart: a cached prompt would cost less
// than shown here (the app prices it from each answer's usage).
"use strict";

const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const VERTEX_AI_SERVICE = "C7E2-9256-1C43"; // Cloud Billing catalog id of "Vertex AI" (Agent Platform's Gemini SKUs live there).
const APP_PRICE_FILE = path.join(__dirname, "..", "..", "Cue Studio", "Managers", "ScriptAI", "Ultra", "UltraPrice.swift");

function options(argv) {
  const opts = { days: 42, project: "cue-script-ai-lab", json: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--days") opts.days = Math.min(42, Math.max(1, Number(argv[++i]) || 42));
    else if (argv[i] === "--project") opts.project = argv[++i];
    else if (argv[i] === "--json") opts.json = true;
    else throw new Error(`Unknown option ${argv[i]} (use --days N, --project ID, --json)`);
  }
  return opts;
}

/// The firebase-tools package behind the `firebase` command (Homebrew's libexec or npm's global node_modules).
function firebaseTools() {
  let bin;
  try {
    bin = fs.realpathSync(execFileSync("/bin/sh", ["-c", "command -v firebase"]).toString().trim());
  } catch {
    throw new Error("The Firebase CLI isn't installed (brew install firebase-cli), or `firebase` isn't on the PATH");
  }
  for (let dir = path.dirname(bin); dir !== path.dirname(dir); dir = path.dirname(dir)) {
    for (const candidate of [dir, path.join(dir, "libexec", "lib", "node_modules", "firebase-tools"), path.join(dir, "lib", "node_modules", "firebase-tools")]) {
      try {
        if (JSON.parse(fs.readFileSync(path.join(candidate, "package.json"), "utf8")).name === "firebase-tools") return path.join(candidate, "lib");
      } catch {}
    }
  }
  throw new Error(`firebase-tools not found next to ${bin}`);
}

async function clients() {
  const lib = firebaseTools();
  const account = require(path.join(lib, "auth")).getGlobalDefaultAccount();
  if (!account) throw new Error("Not logged in: run `firebase login` with the account that owns the lab project");
  await require(path.join(lib, "requireAuth")).requireAuth({ user: account.user, tokens: account.tokens });
  const { Client } = require(path.join(lib, "apiv2"));
  return {
    monitoring: new Client({ urlPrefix: "https://monitoring.googleapis.com", apiVersion: "v3" }),
    billing: new Client({ urlPrefix: "https://cloudbilling.googleapis.com", apiVersion: "v1" }),
  };
}

/// Minute sums of one metric, grouped by `groupBy`, every page. A minute, not an hour or a day: Monitoring anchors the buckets to the end
/// time, so a day's bucket doesn't start at midnight, and a 24-hour alignment counted 310 calls where the raw points hold 234 (31/10/2026).
async function series(monitoring, project, metric, groupBy, start, end) {
  const out = [];
  let pageToken = "";
  do {
    const query = new URLSearchParams({
      filter: `metric.type = "${metric}"`,
      "interval.startTime": start.toISOString(),
      "interval.endTime": end.toISOString(),
      "aggregation.alignmentPeriod": "60s",
      "aggregation.perSeriesAligner": "ALIGN_SUM",
      "aggregation.crossSeriesReducer": "REDUCE_SUM",
    });
    for (const field of groupBy) query.append("aggregation.groupByFields", field);
    if (pageToken) query.set("pageToken", pageToken);
    const { body } = await monitoring.get(`/projects/${project}/timeSeries?${query}`, { headers: { "x-goog-user-project": project } });
    out.push(...(body.timeSeries || []));
    pageToken = body.nextPageToken;
  } while (pageToken);
  return out;
}

function label(series, key) {
  return series.metric?.labels?.[key] ?? series.resource?.labels?.[key] ?? "";
}

/// The local calendar day a point's minute belongs to.
function day(point) {
  return new Date(Date.parse(point.interval.endTime) - 1).toLocaleDateString("sv-SE");
}

/// "gemini-3.5-flash" → "Gemini 3.5 Flash", as the catalog names it.
function catalogName(model) {
  return model.split("-").map((word) => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
}

function unitPrice(sku) {
  const expression = sku?.pricingInfo?.[0]?.pricingExpression;
  const rate = expression?.tieredRates?.[expression.tieredRates.length - 1]?.unitPrice;
  if (!rate) return null;
  return (Number(rate.units || 0) + (rate.nanos || 0) / 1e9) * 1e6; // per million
}

async function catalogPrices(billing, models) {
  const wanted = new Map();
  for (const { model, location } of models) {
    const scope = location === "global" ? "Global" : "Regional";
    wanted.set(`${model}|${location}`, {
      input: `${catalogName(model)} ${scope} Text Input - Predictions`,
      output: `${catalogName(model)} ${scope} Text Output - Predictions`,
    });
  }
  const byDescription = new Map();
  let pageToken = "";
  do {
    const queryParams = { currencyCode: "USD", pageSize: "5000" };
    if (pageToken) queryParams.pageToken = pageToken;
    const { body } = await billing.get(`/services/${VERTEX_AI_SERVICE}/skus`, { queryParams });
    for (const sku of body.skus || []) byDescription.set(sku.description, sku);
    pageToken = body.nextPageToken;
  } while (pageToken);
  const prices = new Map();
  for (const [key, names] of wanted) {
    prices.set(key, { input: unitPrice(byDescription.get(names.input)), output: unitPrice(byDescription.get(names.output)), names });
  }
  return prices;
}

function appPrice() {
  try {
    const text = fs.readFileSync(APP_PRICE_FILE, "utf8");
    const match = text.match(/inputPerMillion:\s*([\d.]+),\s*cachedInputPerMillion:\s*([\d.]+),\s*outputPerMillion:\s*([\d.]+)/);
    return match ? { input: Number(match[1]), cached: Number(match[2]), output: Number(match[3]) } : null;
  } catch {
    return null;
  }
}

const number = (n) => Math.round(n).toLocaleString("en-US");
const dollars = (n, digits = 2) => n.toFixed(digits);

async function main() {
  const opts = options(process.argv.slice(2));
  const { monitoring, billing } = await clients();
  const end = new Date();
  const start = new Date(end.getTime() - opts.days * 864e5);
  const tokenSeries = await series(
    monitoring, opts.project, "aiplatform.googleapis.com/publisher/online_serving/token_count",
    ["resource.label.model_user_id", "resource.label.location", "metric.label.type"], start, end,
  );
  const callSeries = await series(
    monitoring, opts.project, "aiplatform.googleapis.com/publisher/online_serving/model_invocation_count",
    ["resource.label.model_user_id", "resource.label.location", "metric.label.response_code"], start, end,
  );

  // day → model|location → counts
  const days = new Map();
  const models = new Map();
  const cell = (d, key) => {
    if (!days.has(d)) days.set(d, new Map());
    const row = days.get(d);
    if (!row.has(key)) row.set(key, { calls: 0, errors: 0, input: 0, output: 0 });
    return row.get(key);
  };
  for (const s of tokenSeries) {
    const model = label(s, "model_user_id"), location = label(s, "location") || "global", type = label(s, "type");
    models.set(`${model}|${location}`, { model, location });
    for (const point of s.points || []) {
      const value = Number(point.value.int64Value || 0);
      if (!value) continue;
      const counts = cell(day(point), `${model}|${location}`);
      if (type === "input") counts.input += value;
      else if (type === "output") counts.output += value;
    }
  }
  // response code → refused calls (429: Google's capacity or quota at that moment)
  const refused = new Map();
  for (const s of callSeries) {
    const model = label(s, "model_user_id"), location = label(s, "location") || "global", code = label(s, "response_code");
    models.set(`${model}|${location}`, { model, location });
    for (const point of s.points || []) {
      const value = Number(point.value.int64Value || 0);
      if (!value) continue;
      const counts = cell(day(point), `${model}|${location}`);
      if (code === "200") counts.calls += value;
      else {
        counts.errors += value;
        refused.set(code, (refused.get(code) || 0) + value);
      }
    }
  }

  const prices = await catalogPrices(billing, [...models.values()]);
  const rows = [];
  const total = { calls: 0, errors: 0, input: 0, output: 0, usd: 0 };
  for (const d of [...days.keys()].sort()) {
    for (const [key, counts] of days.get(d)) {
      const price = prices.get(key);
      const usd = price?.input != null && price?.output != null ? (counts.input * price.input + counts.output * price.output) / 1e6 : NaN;
      rows.push({ day: d, model: key.split("|")[0], location: key.split("|")[1], ...counts, usd });
      total.calls += counts.calls;
      total.errors += counts.errors;
      total.input += counts.input;
      total.output += counts.output;
      total.usd += usd;
    }
  }
  const app = appPrice();

  if (opts.json) {
    console.log(JSON.stringify({ project: opts.project, days: opts.days, prices: Object.fromEntries(prices), appPrice: app, rows, total, errorsByCode: Object.fromEntries(refused) }, null, 2));
    return;
  }
  console.log(`Ultra AI spend · ${opts.project} · last ${opts.days} days · Google's own counts (Cloud Monitoring)`);
  for (const [key, price] of prices) {
    const [model, location] = key.split("|");
    if (price.input == null || price.output == null) {
      console.log(`  ${model} (${location}): no catalog price for "${price.names.input}" / "${price.names.output}"`);
      continue;
    }
    console.log(`  ${model} (${location}), catalog USD per million tokens: input ${dollars(price.input)}, output ${dollars(price.output)} (thinking included)`);
    if (app && (Math.abs(app.input - price.input) > 1e-9 || Math.abs(app.output - price.output) > 1e-9)) {
      console.log(`  ⚠ The app's UltraPrice is input ${dollars(app.input)}, output ${dollars(app.output)}: update UltraPrice.swift`);
    } else if (app) {
      console.log("  The app's UltraPrice matches the catalog.");
    }
  }
  if (!rows.length) {
    console.log("\nNo Gemini calls in this period.");
    return;
  }
  console.log("");
  const header = ["Day", "Model", "Calls", "Errors", "Input tokens", "Output tokens", "USD"];
  const table = rows.map((r) => [r.day, r.model, number(r.calls), number(r.errors), number(r.input), number(r.output), dollars(r.usd)]);
  table.push(["Total", "", number(total.calls), number(total.errors), number(total.input), number(total.output), dollars(total.usd)]);
  const widths = header.map((h, i) => Math.max(h.length, ...table.map((r) => r[i].length)));
  const line = (r) => r.map((c, i) => (i < 2 ? c.padEnd(widths[i]) : c.padStart(widths[i]))).join("  ");
  console.log(line(header));
  for (const r of table) console.log(line(r));
  if (refused.size) {
    console.log(`\nErrors by response code: ${[...refused].sort((a, b) => b[1] - a[1]).map(([code, n]) => `${code} × ${n}`).join(", ")}`);
  }
  if (total.calls) {
    console.log(`\nPer answered call: USD ${dollars(total.usd / total.calls, 4)} · ${number(total.input / total.calls)} input and ${number(total.output / total.calls)} output tokens`);
  }
  console.log("Today is partial. The bill (credits included): console.cloud.google.com/billing › Reports, project filter, group by SKU.");
}

main().catch((error) => {
  console.error(`spend.js: ${error.message || error}`);
  process.exit(1);
});
