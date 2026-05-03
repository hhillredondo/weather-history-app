import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import esmock from 'esmock';
import { mockClient } from 'aws-sdk-client-mock';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';

// Set env vars before the handler module is imported (it reads them at top-level).
process.env.TABLE_NAME = 'TestTable';
process.env.USER_POOL_ID = 'eu-west-1_test';
process.env.COGNITO_CLIENT_ID = 'test-client';
process.env.AWS_REGION = 'eu-west-1';
process.env.BEDROCK_MODEL_ID = 'test-model';
process.env.OPEN_METEO_BASE_URL = 'https://archive-api.open-meteo.test/v1/archive';
process.env.CHAT_DAILY_TOKEN_LIMIT = '10000';

const ddbMock = mockClient(DynamoDBDocumentClient);
const bedrockMock = mockClient(BedrockRuntimeClient);

let realFetch;
let fetchCalls;
let fetchHandler;

function installFetchStub() {
  realFetch = globalThis.fetch;
  fetchCalls = [];
  fetchHandler = null;
  globalThis.fetch = async (url, init) => {
    fetchCalls.push({ url: String(url), init });
    if (!fetchHandler) {
      throw new Error(`Unexpected fetch in test: ${url}`);
    }
    return fetchHandler(String(url), init);
  };
}

function restoreFetch() {
  globalThis.fetch = realFetch;
}

// Mock the JWT verifier so any "Bearer test-token" resolves to sub=test-user.
const verifierMock = {
  CognitoJwtVerifier: {
    create: () => ({
      verify: async (token) => {
        if (token === 'invalid') {
          throw new Error('jwt invalid');
        }
        return { sub: 'test-user' };
      },
    }),
  },
};

let handler;

before(async () => {
  installFetchStub();
  // esmock loads index.mjs with `aws-jwt-verify` swapped for our stub.
  ({ handler } = await esmock('../index.mjs', {
    'aws-jwt-verify': verifierMock,
  }));
});

after(() => {
  restoreFetch();
});

beforeEach(() => {
  ddbMock.reset();
  bedrockMock.reset();
  fetchCalls.length = 0;
  fetchHandler = null;
});

function buildEvent({ method = 'GET', path = '/', token = 'test-token', body, qs } = {}) {
  return {
    requestContext: { http: { method } },
    rawPath: path,
    headers: token ? { authorization: `Bearer ${token}` } : {},
    queryStringParameters: qs,
    body: body == null ? null : (typeof body === 'string' ? body : JSON.stringify(body)),
  };
}

describe('handler — public endpoints', () => {
  it('GET /health returns 200 without auth', async () => {
    const res = await handler(buildEvent({ path: '/health', token: null }));
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.ok, true);
    assert.equal(body.service, 'weather-history-api');
  });

  it('GET /v1/health returns 200 without auth', async () => {
    const res = await handler(buildEvent({ path: '/v1/health', token: null }));
    assert.equal(res.statusCode, 200);
  });

  it('OPTIONS preflight returns 204', async () => {
    const res = await handler(buildEvent({ method: 'OPTIONS', path: '/v1/chat', token: null }));
    assert.equal(res.statusCode, 204);
  });
});

describe('handler — auth', () => {
  it('rejects missing Bearer token with 401', async () => {
    const res = await handler(buildEvent({ path: '/v1/me', token: null }));
    assert.equal(res.statusCode, 401);
    const body = JSON.parse(res.body);
    assert.equal(body.error, 'Unauthorized');
    assert.match(body.reason, /Missing Bearer token/);
  });

  it('rejects invalid token with 401', async () => {
    const res = await handler(buildEvent({ path: '/v1/me', token: 'invalid' }));
    assert.equal(res.statusCode, 401);
    assert.equal(JSON.parse(res.body).error, 'Unauthorized');
  });

  it('returns sub for /v1/me with a valid token', async () => {
    const res = await handler(buildEvent({ path: '/v1/me' }));
    assert.equal(res.statusCode, 200);
    assert.equal(JSON.parse(res.body).sub, 'test-user');
  });
});

describe('handler — /v1/weather/archive', () => {
  it('400 when required params missing', async () => {
    const res = await handler(
      buildEvent({ path: '/v1/weather/archive', qs: { latitude: '51' } }),
    );
    assert.equal(res.statusCode, 400);
  });

  it('returns cached payload from DynamoDB without hitting Open-Meteo', async () => {
    ddbMock.on(GetCommand).resolves({
      Item: {
        payload: { daily: { time: ['2024-01-01'], temperature_2m_max: [5.0] } },
      },
    });

    const res = await handler(
      buildEvent({
        path: '/v1/weather/archive',
        qs: {
          latitude: '51.5',
          longitude: '-0.12',
          start_date: '2024-01-01',
          end_date: '2024-01-01',
        },
      }),
    );
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.cached, true);
    assert.deepEqual(body.data.daily.time, ['2024-01-01']);
    assert.equal(fetchCalls.length, 0, 'should not call Open-Meteo on cache hit');
  });

  it('fetches Open-Meteo and writes cache on miss', async () => {
    ddbMock.on(GetCommand).resolves({});
    ddbMock.on(PutCommand).resolves({});
    fetchHandler = async () => new Response(
      JSON.stringify({ daily: { time: ['2024-06-01'], temperature_2m_max: [22.0] } }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );

    const res = await handler(
      buildEvent({
        path: '/v1/weather/archive',
        qs: {
          latitude: '40.4',
          longitude: '-3.7',
          start_date: '2024-06-01',
          end_date: '2024-06-01',
        },
      }),
    );
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.cached, false);
    assert.equal(body.data.daily.temperature_2m_max[0], 22.0);
    assert.equal(fetchCalls.length, 1);
    assert.match(fetchCalls[0].url, /archive-api\.open-meteo\.test/);
    const puts = ddbMock.commandCalls(PutCommand);
    assert.equal(puts.length, 1);
    assert.equal(puts[0].args[0].input.Item.pk, 'CACHE#weather');
  });

  it('502 when Open-Meteo errors', async () => {
    ddbMock.on(GetCommand).resolves({});
    fetchHandler = async () => new Response(
      JSON.stringify({ error: true, reason: 'No data' }),
      { status: 400, headers: { 'content-type': 'application/json' } },
    );
    const res = await handler(
      buildEvent({
        path: '/v1/weather/archive',
        qs: {
          latitude: '0',
          longitude: '0',
          start_date: '1900-01-01',
          end_date: '1900-01-01',
        },
      }),
    );
    assert.equal(res.statusCode, 502);
    assert.equal(JSON.parse(res.body).error, 'OpenMeteoError');
  });
});

describe('handler — /v1/chat', () => {
  function bedrockResponse(payload) {
    return { body: new TextEncoder().encode(JSON.stringify(payload)) };
  }

  function setupChatBaseline() {
    // First DDB GetCommand = rate-limit lookup; subsequent = weather cache (empty so we fall to Open-Meteo).
    ddbMock.on(GetCommand).resolves({}); // rate row not present → allowed
    ddbMock.on(PutCommand).resolves({});
    ddbMock.on(UpdateCommand).resolves({});
  }

  it('400 when message is missing', async () => {
    const res = await handler(
      buildEvent({ method: 'POST', path: '/v1/chat', body: {} }),
    );
    assert.equal(res.statusCode, 400);
  });

  it('happy path: tool_use → tool_result → final text', async () => {
    setupChatBaseline();
    // Open-Meteo response for the get_daily tool the model will request.
    fetchHandler = async () => new Response(
      JSON.stringify({
        daily: {
          time: ['2024-07-01'],
          temperature_2m_max: [28.5],
          temperature_2m_min: [18.0],
          precipitation_sum: [0.0],
          weather_code: [1],
          wind_speed_10m_max: [10.0],
          wind_direction_10m_dominant: [180.0],
          uv_index_max: [7.0],
        },
      }),
      { status: 200 },
    );

    // Bedrock: call 1 returns a tool_use; call 2 returns final text.
    bedrockMock
      .on(InvokeModelCommand)
      .resolvesOnce(bedrockResponse({
        stop_reason: 'tool_use',
        usage: { input_tokens: 100, output_tokens: 30 },
        content: [
          {
            type: 'tool_use',
            id: 'toolu_1',
            name: 'get_daily',
            input: {
              latitude: 40.4,
              longitude: -3.7,
              start_date: '2024-07-01',
              end_date: '2024-07-01',
            },
          },
        ],
      }))
      .resolvesOnce(bedrockResponse({
        stop_reason: 'end_turn',
        usage: { input_tokens: 200, output_tokens: 50 },
        content: [{ type: 'text', text: 'On 1 July 2024 the max in Madrid was 28.5°C.' }],
      }));

    const res = await handler(
      buildEvent({
        method: 'POST',
        path: '/v1/chat',
        body: { message: 'How hot was 1 July 2024?', history: [] },
      }),
    );
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.match(body.reply, /28\.5/);
    assert.equal(body.tool_calls.length, 1);
    assert.equal(body.tool_calls[0].name, 'get_daily');
    assert.equal(body.tool_calls[0].ok, true);
    assert.equal(body.usage.input_tokens, 300);
    assert.equal(body.usage.output_tokens, 80);
    // recordUsage was called even on success.
    assert.equal(ddbMock.commandCalls(UpdateCommand).length, 1);
  });

  it('cap-hit fallback: never converges within MAX_STEPS', async () => {
    setupChatBaseline();
    fetchHandler = async () => new Response(
      JSON.stringify({ daily: { time: [], temperature_2m_max: [] } }),
      { status: 200 },
    );

    // Always return tool_use so the loop exhausts.
    bedrockMock.on(InvokeModelCommand).resolves(bedrockResponse({
      stop_reason: 'tool_use',
      usage: { input_tokens: 50, output_tokens: 10 },
      content: [
        {
          type: 'tool_use',
          id: 'toolu_loop',
          name: 'get_daily',
          input: {
            latitude: 0,
            longitude: 0,
            start_date: '2024-01-01',
            end_date: '2024-01-01',
          },
        },
      ],
    }));

    const res = await handler(
      buildEvent({
        method: 'POST',
        path: '/v1/chat',
        body: { message: 'Run forever please', history: [] },
      }),
    );
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.match(body.reply, /too complex/i);
    // Tokens still recorded.
    assert.ok(body.usage.input_tokens > 0);
    assert.equal(ddbMock.commandCalls(UpdateCommand).length, 1);
    // Tool calls still surfaced.
    assert.ok(body.tool_calls.length > 0);
  });

  it('empty-text fallback: model returns end_turn with no content', async () => {
    setupChatBaseline();
    bedrockMock.on(InvokeModelCommand).resolves(bedrockResponse({
      stop_reason: 'end_turn',
      usage: { input_tokens: 50, output_tokens: 5 },
      content: [],
    }));
    const res = await handler(
      buildEvent({
        method: 'POST',
        path: '/v1/chat',
        body: { message: 'Hi', history: [] },
      }),
    );
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.match(body.reply, /couldn't put together an answer/i);
  });

  it('429 when daily token budget exceeded', async () => {
    ddbMock.on(GetCommand).resolves({
      Item: { inputTokens: 999_999, outputTokens: 0 },
    });
    const res = await handler(
      buildEvent({
        method: 'POST',
        path: '/v1/chat',
        body: { message: 'Hi', history: [] },
      }),
    );
    assert.equal(res.statusCode, 429);
    assert.equal(JSON.parse(res.body).error, 'RateLimited');
    // Bedrock should NOT have been called.
    assert.equal(bedrockMock.commandCalls(InvokeModelCommand).length, 0);
  });
});
