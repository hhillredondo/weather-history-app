/**
 * Health-check tests — hit the real external services the chat agent depends on.
 *
 * Run with `npm run test:health` to enable. These are skipped on a normal
 * `npm test` run because they hit the network and (for Bedrock) cost money.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';

const ENABLED = process.env.RUN_HEALTH_CHECKS === '1';

describe('Open-Meteo archive — service health', { skip: !ENABLED }, () => {
  it('returns a parseable daily payload with expected fields', async () => {
    const url = new URL('https://archive-api.open-meteo.org/v1/archive');
    url.searchParams.set('latitude', '40.4168');
    url.searchParams.set('longitude', '-3.7038');
    // Use a fixed historical day so the test is deterministic.
    url.searchParams.set('start_date', '2024-07-01');
    url.searchParams.set('end_date', '2024-07-01');
    url.searchParams.set('timezone', 'auto');
    url.searchParams.set(
      'daily',
      'temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code',
    );

    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    assert.equal(res.ok, true, `Open-Meteo HTTP ${res.status}`);
    const data = await res.json();
    assert.ok(data.daily, 'response must have a `daily` block');
    assert.ok(Array.isArray(data.daily.time), '`daily.time` must be an array');
    assert.equal(data.daily.time.length, 1);
    assert.equal(data.daily.time[0], '2024-07-01');
    assert.equal(typeof data.daily.temperature_2m_max[0], 'number');
  });

  it('rejects future dates with a 400-style error', async () => {
    const url = new URL('https://archive-api.open-meteo.org/v1/archive');
    url.searchParams.set('latitude', '40');
    url.searchParams.set('longitude', '-3');
    url.searchParams.set('start_date', '3000-01-01');
    url.searchParams.set('end_date', '3000-01-02');
    url.searchParams.set('daily', 'temperature_2m_max');
    const res = await fetch(url);
    // Open-Meteo returns 400 with `{error:true, reason:...}` for invalid ranges.
    const body = await res.json();
    assert.ok(!res.ok || body.error === true, 'expected an error response');
  });
});

describe('Bedrock — service health', { skip: !ENABLED }, () => {
  it('can invoke the configured model with a tiny prompt', async () => {
    const region = process.env.AWS_REGION || 'eu-west-1';
    const modelId =
      process.env.BEDROCK_MODEL_ID || 'eu.anthropic.claude-haiku-4-5-20251001-v1:0';
    const client = new BedrockRuntimeClient({ region });

    const cmd = new InvokeModelCommand({
      modelId,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 8,
        messages: [{ role: 'user', content: [{ type: 'text', text: 'ping' }] }],
      }),
    });

    const res = await client.send(cmd);
    const text = new TextDecoder().decode(res.body);
    const payload = JSON.parse(text);
    assert.ok(Array.isArray(payload.content), 'response must have a content array');
    assert.ok(
      payload.content.some((b) => b.type === 'text'),
      'response must contain at least one text block',
    );
  });
});
