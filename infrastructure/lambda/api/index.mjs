/**
 * HTTP API v2 (Lambda proxy) — Cognito JWT + DynamoDB user settings/locations + weather cache + Bedrock chat agent.
 */
import { createHash } from "node:crypto";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
  DeleteCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from "@aws-sdk/client-bedrock-runtime";
import { CognitoJwtVerifier } from "aws-jwt-verify";

const TABLE = process.env.TABLE_NAME;
const USER_POOL_ID = process.env.USER_POOL_ID;
const CLIENT_ID = process.env.COGNITO_CLIENT_ID;
const REGION = process.env.AWS_REGION || "eu-west-1";
const OPEN_METEO_BASE_URL =
  process.env.OPEN_METEO_BASE_URL || "https://archive-api.open-meteo.com/v1/archive";
const OPEN_METEO_API_KEY = (process.env.OPEN_METEO_API_KEY || "").trim();
const BEDROCK_MODEL_ID =
  process.env.BEDROCK_MODEL_ID || "anthropic.claude-3-5-haiku-20241022-v1:0";
const CHAT_DAILY_TOKEN_LIMIT = parseInt(
  process.env.CHAT_DAILY_TOKEN_LIMIT || "200000",
  10,
);

const DAILY_VARS =
  "temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code,wind_speed_10m_max,wind_direction_10m_dominant,uv_index_max";
const HOURLY_VARS =
  "temperature_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,cloud_cover,relative_humidity_2m,uv_index";
/** DynamoDB `ttl` attribute: Unix seconds (historical data — long cache). */
const CACHE_TTL_SEC = 30 * 24 * 3600;

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));
const bedrock = new BedrockRuntimeClient({ region: REGION });

let verifier;
function getVerifier() {
  if (!verifier && USER_POOL_ID && CLIENT_ID) {
    verifier = CognitoJwtVerifier.create({
      userPoolId: USER_POOL_ID,
      tokenUse: "access",
      clientId: CLIENT_ID,
    });
  }
  return verifier;
}

// Origins permitted to receive CORS headers. A mobile/desktop client sends no
// Origin at all, so an absent header is fine; what is not fine is reflecting an
// arbitrary attacker-supplied Origin straight back.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

function resolveOrigin(requestOrigin) {
  if (!requestOrigin) return ALLOWED_ORIGINS[0] || "*";
  if (ALLOWED_ORIGINS.length === 0) return "*"; // unconfigured: preserve old behaviour
  return ALLOWED_ORIGINS.includes(requestOrigin) ? requestOrigin : ALLOWED_ORIGINS[0];
}

function corsHeaders(origin) {
  return {
    "content-type": "application/json",
    "access-control-allow-origin": origin || "*",
    "access-control-allow-headers": "authorization,content-type",
    "access-control-allow-methods": "GET,PUT,POST,DELETE,OPTIONS",
  };
}

function json(statusCode, body, origin, extra = {}) {
  return {
    statusCode,
    headers: { ...corsHeaders(origin), ...extra },
    body: JSON.stringify(body),
  };
}

async function verifyAccessToken(token, origin) {
  const v = getVerifier();
  if (!v) {
    throw new Error("JWT verifier not configured");
  }
  const payload = await v.verify(token);
  return payload.sub;
}

/** Bump when DAILY_VARS/HOURLY_VARS change so old cached payloads aren't reused. */
const WEATHER_CACHE_VERSION = "v2";

function weatherCacheSk({ latitude, longitude, start_date, end_date, timezone, hourly }) {
  const key = JSON.stringify({
    v: WEATHER_CACHE_VERSION,
    lat: latitude,
    lon: longitude,
    start: start_date,
    end: end_date,
    tz: timezone || "auto",
    hourly: !!hourly,
  });
  const hash = createHash("sha256").update(key).digest("hex");
  return `ARCH#${hash}`;
}

/** Cache-aware Open-Meteo archive fetch. Returns parsed JSON `data`. */
async function fetchArchive({ latitude, longitude, start_date, end_date, timezone = "auto", hourly = false }) {
  const sk = weatherCacheSk({ latitude, longitude, start_date, end_date, timezone, hourly });
  const cached = await ddb.send(
    new GetCommand({ TableName: TABLE, Key: { pk: "CACHE#weather", sk } }),
  );
  if (cached.Item?.payload) {
    return { data: cached.Item.payload, cached: true };
  }

  const u = new URL(OPEN_METEO_BASE_URL);
  u.searchParams.set("latitude", String(latitude));
  u.searchParams.set("longitude", String(longitude));
  u.searchParams.set("start_date", String(start_date));
  u.searchParams.set("end_date", String(end_date));
  u.searchParams.set("timezone", String(timezone));
  if (hourly) {
    u.searchParams.set("hourly", HOURLY_VARS);
  } else {
    u.searchParams.set("daily", DAILY_VARS);
  }
  if (OPEN_METEO_API_KEY) {
    u.searchParams.set("apikey", OPEN_METEO_API_KEY);
  }

  const res = await fetch(u.toString(), { headers: { Accept: "application/json" } });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error(`Open-Meteo non-JSON response (status ${res.status}): ${text.slice(0, 500)}`);
  }
  if (!res.ok || data.error) {
    throw new Error(`Open-Meteo error: ${data.reason || data.error || res.statusText}`);
  }

  const now = Math.floor(Date.now() / 1000);
  await ddb.send(
    new PutCommand({
      TableName: TABLE,
      Item: {
        pk: "CACHE#weather",
        sk,
        payload: data,
        ttl: now + CACHE_TTL_SEC,
        updatedAt: new Date().toISOString(),
      },
    }),
  );
  return { data, cached: false };
}

async function handleWeatherArchive(origin, qs) {
  const lat = qs.latitude;
  const lon = qs.longitude;
  const start = qs.start_date;
  const end = qs.end_date;
  if (!lat || !lon || !start || !end) {
    return json(
      400,
      { error: "BadRequest", reason: "latitude, longitude, start_date, end_date required" },
      origin,
    );
  }
  const hourly = qs.hourly === "1" || qs.hourly === "true";
  try {
    const { data, cached } = await fetchArchive({
      latitude: lat,
      longitude: lon,
      start_date: start,
      end_date: end,
      timezone: qs.timezone || "auto",
      hourly,
    });
    return json(200, { cached, data }, origin);
  } catch (e) {
    return json(502, { error: "OpenMeteoError", reason: String(e.message || e) }, origin);
  }
}

// ---------------------------------------------------------------------------
// Chat agent
// ---------------------------------------------------------------------------

const METRIC_TO_DAILY_FIELD = {
  temp_max: "temperature_2m_max",
  temp_min: "temperature_2m_min",
  precip_sum: "precipitation_sum",
  wind_max: "wind_speed_10m_max",
  uv_max: "uv_index_max",
};
const METRIC_UNITS = {
  temp_max: "°C",
  temp_min: "°C",
  precip_sum: "mm",
  wind_max: "km/h",
  uv_max: "",
};

function pad2(n) {
  return n < 10 ? `0${n}` : `${n}`;
}
function ymd(date) {
  return `${date.getUTCFullYear()}-${pad2(date.getUTCMonth() + 1)}-${pad2(date.getUTCDate())}`;
}
function yesterdayUtc() {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - 1);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

/** Pull (date, value) rows for one metric from an Open-Meteo daily payload. */
function dailySeries(payload, metric) {
  const field = METRIC_TO_DAILY_FIELD[metric];
  if (!field) throw new Error(`Unknown metric: ${metric}`);
  const dates = payload?.daily?.time || [];
  const values = payload?.daily?.[field] || [];
  const out = [];
  for (let i = 0; i < dates.length; i++) {
    const v = values[i];
    if (v == null || Number.isNaN(v)) continue;
    out.push({ date: dates[i], value: v });
  }
  return out;
}

const CHAT_TOOLS = [
  {
    name: "get_daily",
    description:
      "Fetch daily historical weather (temperature max/min, precipitation, wind, UV, weather code) from the Open-Meteo archive for a single contiguous date range. Use for short windows (≤ 60 days). For multi-year stats use `aggregate` instead.",
    input_schema: {
      type: "object",
      properties: {
        latitude: { type: "number", description: "WGS84 latitude" },
        longitude: { type: "number", description: "WGS84 longitude" },
        start_date: { type: "string", description: "ISO date YYYY-MM-DD (inclusive)" },
        end_date: { type: "string", description: "ISO date YYYY-MM-DD (inclusive). Must be ≤ yesterday." },
      },
      required: ["latitude", "longitude", "start_date", "end_date"],
    },
  },
  {
    name: "aggregate",
    description:
      "Run a multi-year aggregation over the Open-Meteo daily archive. Use for: ranking top-N days by a metric, day-of-year stats across years (e.g. '10 Feb across the last 10 years'), or month-of-year stats across years (e.g. 'July across 30 years').",
    input_schema: {
      type: "object",
      properties: {
        latitude: { type: "number" },
        longitude: { type: "number" },
        mode: {
          type: "string",
          enum: ["top_n", "doy_stats", "monthly_stats"],
          description:
            "top_n = single date range, return top N days by metric (highest if order=desc, lowest if asc). " +
            "doy_stats = same calendar day across N years. " +
            "monthly_stats = same calendar month across N years.",
        },
        metric: {
          type: "string",
          enum: ["temp_max", "temp_min", "precip_sum", "wind_max", "uv_max"],
        },
        years_back: {
          type: "integer",
          description: "Number of past years to span (1-50). Required for doy_stats and monthly_stats.",
        },
        start_date: {
          type: "string",
          description: "Required for mode=top_n. ISO date YYYY-MM-DD.",
        },
        end_date: {
          type: "string",
          description: "Required for mode=top_n. ISO date YYYY-MM-DD (≤ yesterday).",
        },
        month: { type: "integer", description: "1-12. Required for doy_stats and monthly_stats." },
        day: { type: "integer", description: "1-31. Required for doy_stats." },
        top_n: {
          type: "integer",
          description: "How many top days to return for mode=top_n (default 10, max 50).",
        },
        order: {
          type: "string",
          enum: ["desc", "asc"],
          description: "For mode=top_n: desc = highest, asc = lowest. Default desc.",
        },
        threshold: {
          type: "number",
          description:
            "Optional. For doy_stats / monthly_stats, also report fraction of days exceeding this metric value.",
        },
      },
      required: ["latitude", "longitude", "mode", "metric"],
    },
  },
  {
    name: "plot",
    description:
      "Render a chart inline in the chat. Returns the spec back to the client which renders it with fl_chart. Use after get_daily / aggregate when a chart helps the user see the answer.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        y_label: { type: "string", description: "e.g. 'Temperature (°C)' or 'Precipitation (mm)'" },
        kind: {
          type: "string",
          enum: ["line", "bar"],
          description: "line = time series, bar = categorical (e.g. one bar per year).",
        },
        series: {
          type: "array",
          description: "1-3 series. Each has a label and a list of (x, y) points.",
          items: {
            type: "object",
            properties: {
              label: { type: "string" },
              points: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    x: {
                      type: "string",
                      description: "x-axis label (date YYYY-MM-DD, year, or month name).",
                    },
                    y: { type: "number" },
                  },
                  required: ["x", "y"],
                },
              },
            },
            required: ["label", "points"],
          },
        },
      },
      required: ["title", "kind", "series"],
    },
  },
];

function clampInt(n, lo, hi) {
  const v = Math.floor(Number(n));
  if (Number.isNaN(v)) return lo;
  return Math.max(lo, Math.min(hi, v));
}

async function toolGetDaily(input) {
  const { latitude, longitude, start_date, end_date } = input;
  const { data, cached } = await fetchArchive({ latitude, longitude, start_date, end_date });
  // Strip to compact rows so we don't blow the model's input window.
  const rows = [];
  const dates = data?.daily?.time || [];
  for (let i = 0; i < dates.length; i++) {
    rows.push({
      date: dates[i],
      tmax_c: data.daily.temperature_2m_max?.[i] ?? null,
      tmin_c: data.daily.temperature_2m_min?.[i] ?? null,
      precip_mm: data.daily.precipitation_sum?.[i] ?? null,
      wind_max_kmh: data.daily.wind_speed_10m_max?.[i] ?? null,
      wind_dir_deg: data.daily.wind_direction_10m_dominant?.[i] ?? null,
      uv_max: data.daily.uv_index_max?.[i] ?? null,
      weather_code: data.daily.weather_code?.[i] ?? null,
    });
  }
  return { cached, count: rows.length, rows };
}

function statsOf(values) {
  if (!values.length) return null;
  let sum = 0;
  let min = Infinity;
  let max = -Infinity;
  for (const v of values) {
    sum += v;
    if (v < min) min = v;
    if (v > max) max = v;
  }
  const mean = sum / values.length;
  const sorted = [...values].sort((a, b) => a - b);
  const median = sorted[Math.floor(sorted.length / 2)];
  return { count: values.length, mean, min, max, median };
}

async function toolAggregate(input) {
  const { latitude, longitude, mode, metric } = input;
  if (!METRIC_TO_DAILY_FIELD[metric]) {
    throw new Error(`Unknown metric: ${metric}`);
  }
  const yest = yesterdayUtc();
  const thisYear = yest.getUTCFullYear();

  if (mode === "top_n") {
    const start = input.start_date;
    const end = input.end_date;
    if (!start || !end) throw new Error("top_n requires start_date and end_date");
    const n = clampInt(input.top_n ?? 10, 1, 50);
    const order = input.order === "asc" ? "asc" : "desc";

    // Year-by-year fetch so individual cache items stay small (each year ≈ tens of KB).
    const startY = parseInt(start.slice(0, 4), 10);
    const endY = parseInt(end.slice(0, 4), 10);
    if (endY - startY > 50) throw new Error("Range too large; max 50 years");

    const all = [];
    for (let y = startY; y <= endY; y++) {
      const ys = `${y}-01-01`;
      const ye = `${y}-12-31`;
      const clipStart = ys < start ? start : ys;
      const clipEnd = ye > end ? end : ye;
      if (clipEnd > ymd(yest)) {
        if (clipStart > ymd(yest)) continue;
      }
      const safeEnd = clipEnd > ymd(yest) ? ymd(yest) : clipEnd;
      const { data } = await fetchArchive({
        latitude,
        longitude,
        start_date: clipStart,
        end_date: safeEnd,
      });
      all.push(...dailySeries(data, metric));
    }
    all.sort((a, b) => (order === "desc" ? b.value - a.value : a.value - b.value));
    const top = all.slice(0, n).map((r) => ({
      date: r.date,
      value: Number(r.value.toFixed(2)),
      unit: METRIC_UNITS[metric],
    }));
    return { mode, metric, range: { start, end }, count_considered: all.length, top };
  }

  if (mode === "doy_stats") {
    const yearsBack = clampInt(input.years_back ?? 10, 1, 50);
    const month = clampInt(input.month, 1, 12);
    const day = clampInt(input.day, 1, 31);
    const values = [];
    const samples = [];
    for (let y = thisYear - yearsBack; y <= thisYear - 1; y++) {
      const date = `${y}-${pad2(month)}-${pad2(day)}`;
      try {
        const { data } = await fetchArchive({
          latitude,
          longitude,
          start_date: date,
          end_date: date,
        });
        const series = dailySeries(data, metric);
        if (series.length) {
          const v = series[0].value;
          values.push(v);
          samples.push({ year: y, value: Number(v.toFixed(2)) });
        }
      } catch (_) {
        // Skip years that error (e.g. data not available).
      }
    }
    const stats = statsOf(values);
    let pctAbove = null;
    if (input.threshold != null && values.length) {
      pctAbove =
        values.filter((v) => v > input.threshold).length / values.length;
    }
    return {
      mode,
      metric,
      unit: METRIC_UNITS[metric],
      day_of_year: `${pad2(month)}-${pad2(day)}`,
      years: { from: thisYear - yearsBack, to: thisYear - 1 },
      stats,
      threshold: input.threshold ?? null,
      fraction_above_threshold: pctAbove,
      samples,
    };
  }

  if (mode === "monthly_stats") {
    const yearsBack = clampInt(input.years_back ?? 10, 1, 50);
    const month = clampInt(input.month, 1, 12);
    const allValues = [];
    const perYearMeans = [];
    for (let y = thisYear - yearsBack; y <= thisYear - 1; y++) {
      const lastDay = new Date(Date.UTC(y, month, 0)).getUTCDate();
      const start = `${y}-${pad2(month)}-01`;
      const end = `${y}-${pad2(month)}-${pad2(lastDay)}`;
      try {
        const { data } = await fetchArchive({
          latitude,
          longitude,
          start_date: start,
          end_date: end,
        });
        const series = dailySeries(data, metric);
        const yearVals = series.map((r) => r.value);
        const yearStats = statsOf(yearVals);
        if (yearStats) {
          perYearMeans.push({
            year: y,
            mean: Number(yearStats.mean.toFixed(2)),
            min: Number(yearStats.min.toFixed(2)),
            max: Number(yearStats.max.toFixed(2)),
          });
          allValues.push(...yearVals);
        }
      } catch (_) {
        // skip
      }
    }
    const overall = statsOf(allValues);
    let pctAbove = null;
    if (input.threshold != null && allValues.length) {
      pctAbove =
        allValues.filter((v) => v > input.threshold).length / allValues.length;
    }
    return {
      mode,
      metric,
      unit: METRIC_UNITS[metric],
      month,
      years: { from: thisYear - yearsBack, to: thisYear - 1 },
      overall,
      per_year: perYearMeans,
      threshold: input.threshold ?? null,
      fraction_above_threshold: pctAbove,
    };
  }

  throw new Error(`Unknown aggregate mode: ${mode}`);
}

function toolPlot(input, plotsOut) {
  // The plot tool just echoes a validated spec; the client renders it with fl_chart.
  const spec = {
    title: String(input.title || ""),
    y_label: input.y_label ? String(input.y_label) : null,
    kind: input.kind === "bar" ? "bar" : "line",
    series: (input.series || []).slice(0, 3).map((s) => ({
      label: String(s.label || ""),
      points: (s.points || []).slice(0, 400).map((p) => ({
        x: String(p.x),
        y: Number(p.y),
      })),
    })),
  };
  plotsOut.push(spec);
  return { ok: true, plot_index: plotsOut.length - 1, spec };
}

async function runTool(name, input, ctx) {
  if (name === "get_daily") return await toolGetDaily(input);
  if (name === "aggregate") return await toolAggregate(input);
  if (name === "plot") return toolPlot(input, ctx.plots);
  throw new Error(`Unknown tool: ${name}`);
}

const RATE_LIMIT_TTL_SEC = 36 * 3600;

async function checkAndReserveRate(sub) {
  const today = new Date().toISOString().slice(0, 10);
  const sk = `CHATRATE#${today}`;
  const out = await ddb.send(
    new GetCommand({ TableName: TABLE, Key: { pk: `USER#${sub}`, sk } }),
  );
  const used = (out.Item?.outputTokens || 0) + (out.Item?.inputTokens || 0);
  if (used >= CHAT_DAILY_TOKEN_LIMIT) {
    return { allowed: false, used, limit: CHAT_DAILY_TOKEN_LIMIT };
  }
  return { allowed: true, used, limit: CHAT_DAILY_TOKEN_LIMIT, sk };
}

async function recordUsage(sub, sk, inputTokens, outputTokens) {
  const ttl = Math.floor(Date.now() / 1000) + RATE_LIMIT_TTL_SEC;
  await ddb.send(
    new UpdateCommand({
      TableName: TABLE,
      Key: { pk: `USER#${sub}`, sk },
      UpdateExpression:
        "ADD inputTokens :i, outputTokens :o, requests :r SET #ttl = :t, updatedAt = :u",
      ExpressionAttributeNames: { "#ttl": "ttl" },
      ExpressionAttributeValues: {
        ":i": inputTokens,
        ":o": outputTokens,
        ":r": 1,
        ":t": ttl,
        ":u": new Date().toISOString(),
      },
    }),
  );
}

function buildSystemPrompt(location) {
  const yest = ymd(yesterdayUtc());
  const lines = [
    "You are a weather-history assistant for a Flutter app. The user asks questions about historical weather (the Open-Meteo archive ends yesterday).",
    `Today is ${ymd(new Date())}. The latest available archive day is ${yest}.`,
    "When you need data, call the tools. Prefer `aggregate` over many `get_daily` calls for multi-year questions.",
    "After computing an answer, write a short, plain-language reply (≤ 4 sentences). Use the user's metric units unless they specify otherwise.",
    "When a chart would help (trends, distributions, top-N), call `plot` once with a small, focused dataset (≤ 50 points per series).",
    "Cite the year(s) and location you queried in your reply. Do not invent numbers — only state what tools returned.",
  ];
  if (location && location.latitude != null && location.longitude != null) {
    lines.push(
      `Default location for this conversation: ${location.name || "(unnamed)"} at lat=${location.latitude}, lon=${location.longitude}. Use these coordinates when the user does not specify a place.`,
    );
  }
  return lines.join("\n");
}

function sanitizeMessages(history, userMessage) {
  const safe = [];
  if (Array.isArray(history)) {
    for (const m of history) {
      if (!m || typeof m.content !== "string") continue;
      if (m.role !== "user" && m.role !== "assistant") continue;
      safe.push({ role: m.role, content: [{ type: "text", text: m.content }] });
    }
  }
  safe.push({ role: "user", content: [{ type: "text", text: String(userMessage) }] });
  // Cap the rolling history to prevent runaway prompts.
  return safe.slice(-20);
}

async function invokeBedrock(messages, system) {
  const body = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 1024,
    system,
    tools: CHAT_TOOLS,
    messages,
  };
  const cmd = new InvokeModelCommand({
    modelId: BEDROCK_MODEL_ID,
    contentType: "application/json",
    accept: "application/json",
    body: JSON.stringify(body),
  });
  const res = await bedrock.send(cmd);
  const text = new TextDecoder().decode(res.body);
  return JSON.parse(text);
}

async function handleChat(origin, sub, body) {
  const userMessage = (body?.message || "").toString().trim();
  if (!userMessage) {
    return json(400, { error: "BadRequest", reason: "message required" }, origin);
  }
  const rate = await checkAndReserveRate(sub);
  if (!rate.allowed) {
    return json(
      429,
      {
        error: "RateLimited",
        reason: "Daily chat token budget exceeded. Try again tomorrow.",
        used: rate.used,
        limit: rate.limit,
      },
      origin,
    );
  }

  const system = buildSystemPrompt(body?.location);
  const messages = sanitizeMessages(body?.history, userMessage);
  const ctx = { plots: [] };
  const toolCalls = [];
  let totalInputTokens = 0;
  let totalOutputTokens = 0;
  let finalText = "";
  let exitedNormally = false;

  const MAX_STEPS = 8;
  for (let step = 0; step < MAX_STEPS; step++) {
    const resp = await invokeBedrock(messages, system);
    totalInputTokens += resp.usage?.input_tokens || 0;
    totalOutputTokens += resp.usage?.output_tokens || 0;

    if (resp.stop_reason === "tool_use") {
      // Append the assistant's tool_use content block(s) verbatim.
      messages.push({ role: "assistant", content: resp.content });
      const toolResults = [];
      for (const block of resp.content || []) {
        if (block.type !== "tool_use") continue;
        let result;
        let isError = false;
        try {
          result = await runTool(block.name, block.input || {}, ctx);
        } catch (e) {
          result = { error: String(e.message || e) };
          isError = true;
        }
        toolCalls.push({
          name: block.name,
          input: block.input,
          ok: !isError,
        });
        toolResults.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: JSON.stringify(result),
          is_error: isError,
        });
      }
      messages.push({ role: "user", content: toolResults });
      continue;
    }

    // Final stop: collect any text blocks.
    finalText = (resp.content || [])
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("\n")
      .trim();
    exitedNormally = true;
    break;
  }

  await recordUsage(sub, rate.sk, totalInputTokens, totalOutputTokens);

  let reply = finalText;
  if (!reply) {
    reply = exitedNormally
      ? "Sorry — I couldn't put together an answer for that one. Could you try rephrasing or asking something more specific?"
      : "That question is too complex for me right now. Try breaking it into a smaller question — for example, focus on a single year, a single metric, or a shorter date range.";
  }

  return json(
    200,
    {
      reply,
      plots: ctx.plots,
      tool_calls: toolCalls,
      usage: {
        input_tokens: totalInputTokens,
        output_tokens: totalOutputTokens,
        daily_used: rate.used + totalInputTokens + totalOutputTokens,
        daily_limit: rate.limit,
      },
    },
    origin,
  );
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

export async function handler(event) {
  const origin = resolveOrigin(event.headers?.origin || event.headers?.Origin);

  const method = event.requestContext?.http?.method || "GET";
  const rawPath = event.rawPath || "/";

  if (method === "OPTIONS") {
    return json(204, {}, origin);
  }

  if (rawPath === "/health" || rawPath === "/v1/health") {
    return json(200, { ok: true, service: "weather-history-api" }, origin);
  }

  const auth =
    event.headers?.authorization || event.headers?.Authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : null;
  if (!token) {
    return json(401, { error: "Unauthorized", reason: "Missing Bearer token" }, origin);
  }

  let sub;
  try {
    sub = await verifyAccessToken(token, origin);
  } catch (e) {
    return json(401, { error: "Unauthorized", reason: String(e.message || e) }, origin);
  }

  const pk = `USER#${sub}`;

  try {
    if (rawPath === "/v1/me" && method === "GET") {
      return json(200, { sub }, origin);
    }

    if (rawPath === "/v1/settings" && method === "GET") {
      const out = await ddb.send(
        new GetCommand({
          TableName: TABLE,
          Key: { pk, sk: "SETTINGS" },
        }),
      );
      return json(200, { settings: out.Item?.payload ?? null }, origin);
    }

    if (rawPath === "/v1/settings" && method === "PUT") {
      const body = JSON.parse(event.body || "{}");
      await ddb.send(
        new PutCommand({
          TableName: TABLE,
          Item: {
            pk,
            sk: "SETTINGS",
            payload: body,
            updatedAt: new Date().toISOString(),
          },
        }),
      );
      return json(200, { ok: true }, origin);
    }

    if (rawPath === "/v1/locations" && method === "GET") {
      const out = await ddb.send(
        new QueryCommand({
          TableName: TABLE,
          KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
          ExpressionAttributeValues: {
            ":pk": pk,
            ":prefix": "LOC#",
          },
        }),
      );
      const locations = (out.Items || []).map((item) => ({
        ...item.payload,
        id: item.payload?.id || item.sk?.replace(/^LOC#/, ""),
      }));
      return json(200, { locations }, origin);
    }

    if (rawPath === "/v1/locations" && method === "POST") {
      const loc = JSON.parse(event.body || "{}");
      const id = loc.id;
      if (!id) {
        return json(400, { error: "id required" }, origin);
      }
      await ddb.send(
        new PutCommand({
          TableName: TABLE,
          Item: {
            pk,
            sk: `LOC#${id}`,
            payload: loc,
            updatedAt: new Date().toISOString(),
          },
        }),
      );
      return json(200, { ok: true, id }, origin);
    }

    const delMatch = rawPath.match(/^\/v1\/locations\/([^/]+)$/);
    if (delMatch && method === "DELETE") {
      const id = decodeURIComponent(delMatch[1]);
      await ddb.send(
        new DeleteCommand({
          TableName: TABLE,
          Key: { pk, sk: `LOC#${id}` },
        }),
      );
      return json(200, { ok: true, deleted: id }, origin);
    }

    if (rawPath === "/v1/locations/favourite" && method === "PUT") {
      const body = JSON.parse(event.body || "{}");
      const favouriteId = body.favouriteId ?? null;
      await ddb.send(
        new PutCommand({
          TableName: TABLE,
          Item: {
            pk,
            sk: "PROFILE",
            favouriteLocationId: favouriteId,
            updatedAt: new Date().toISOString(),
          },
        }),
      );
      return json(200, { ok: true, favouriteId }, origin);
    }

    if (rawPath === "/v1/profile" && method === "GET") {
      const out = await ddb.send(
        new GetCommand({
          TableName: TABLE,
          Key: { pk, sk: "PROFILE" },
        }),
      );
      return json(
        200,
        { favouriteLocationId: out.Item?.favouriteLocationId ?? null },
        origin,
      );
    }

    if (rawPath === "/v1/weather/archive" && method === "GET") {
      const qs = event.queryStringParameters || {};
      return await handleWeatherArchive(origin, qs);
    }

    if (rawPath === "/v1/chat" && method === "POST") {
      const body = JSON.parse(event.body || "{}");
      return await handleChat(origin, sub, body);
    }

    return json(404, { error: "Not found", path: rawPath }, origin);
  } catch (e) {
    console.error(e);
    return json(500, { error: "ServerError", message: String(e.message || e) }, origin);
  }
}
