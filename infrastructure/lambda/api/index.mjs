/**
 * HTTP API v2 (Lambda proxy) — Cognito JWT + DynamoDB user settings/locations.
 */
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
  DeleteCommand,
} from "@aws-sdk/lib-dynamodb";
import { CognitoJwtVerifier } from "aws-jwt-verify";

const TABLE = process.env.TABLE_NAME;
const USER_POOL_ID = process.env.USER_POOL_ID;
const CLIENT_ID = process.env.COGNITO_CLIENT_ID;
const REGION = process.env.AWS_REGION || "eu-west-1";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

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

export async function handler(event) {
  const origin =
    event.headers?.origin ||
    event.headers?.Origin ||
    "*";

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

    return json(404, { error: "Not found", path: rawPath }, origin);
  } catch (e) {
    console.error(e);
    return json(500, { error: "ServerError", message: String(e.message || e) }, origin);
  }
}
