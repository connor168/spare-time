/// <reference lib="deno.ns" />

// Push Gateway: unified FCM / APNs / HMS delivery.
// Receives idempotent push requests from daily-digest (or any other
// caller with a valid gateway token) and forwards them to the
// provider-specific API.

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type, idempotency-key',
};

interface PushRequest {
  provider: 'fcm' | 'apns' | 'hms';
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

async function sendFcm(
  token: string,
  title: string,
  body: string,
  data: Record<string, string> | undefined,
): Promise<Response> {
  const serverKey = Deno.env.get('FCM_SERVER_KEY');
  if (!serverKey) throw new Error('Missing FCM_SERVER_KEY');
  const message: Record<string, unknown> = {
    to: token,
    notification: { title, body },
    data: data ?? {},
    priority: 'high',
  };
  const response = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `key=${serverKey}`,
    },
    body: JSON.stringify(message),
  });
  const result = await response.json();
  if (!response.ok) {
    console.error('FCM send failed', result);
    // Mark token invalid for NotRegistered / InvalidRegistration errors.
    if (
      result?.results?.[0]?.error === 'NotRegistered' ||
      result?.results?.[0]?.error === 'InvalidRegistration'
    ) {
      return new Response(JSON.stringify({ error: 'token-invalid' }), {
        status: 410,
        headers: {
          ...corsHeaders,
          'content-type': 'application/json',
          'x-push-token-invalid': 'true',
        },
      });
    }
  }
  return new Response(JSON.stringify(result), {
    status: response.status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

async function sendApns(
  _token: string,
  _title: string,
  _body: string,
  _data: Record<string, string> | undefined,
): Promise<Response> {
  // APNs delivery via JWT provider token.
  // Requires APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY (P8 contents).
  // Placeholder — implement when Apple credentials are available.
  return new Response(JSON.stringify({ skipped: 'apns not configured' }), {
    status: 501,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

async function sendHms(
  _token: string,
  _title: string,
  _body: string,
  _data: Record<string, string> | undefined,
): Promise<Response> {
  // HMS Push Kit delivery via OAuth 2.0 access token.
  // Requires HMS_APP_ID, HMS_APP_SECRET.
  // Placeholder — implement when Huawei credentials are available.
  return new Response(JSON.stringify({ skipped: 'hms not configured' }), {
    status: 501,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return new Response('Use POST', { status: 405, headers: corsHeaders });
  }

  const gatewayToken = Deno.env.get('PUSH_GATEWAY_TOKEN');
  if (!gatewayToken) {
    return new Response('Missing gateway configuration', { status: 500, headers: corsHeaders });
  }
  const auth = request.headers.get('authorization');
  if (!auth || auth !== `Bearer ${gatewayToken}`) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders });
  }

  let body: PushRequest;
  try {
    body = await request.json();
  } catch {
    return new Response('Invalid JSON', { status: 400, headers: corsHeaders });
  }

  if (!body.provider || !body.token || !body.title) {
    return new Response('Missing provider, token, or title', { status: 400, headers: corsHeaders });
  }

  switch (body.provider) {
    case 'fcm':
      return sendFcm(body.token, body.title, body.body, body.data);
    case 'apns':
      return sendApns(body.token, body.title, body.body, body.data);
    case 'hms':
      return sendHms(body.token, body.title, body.body, body.data);
    default:
      return new Response('Unsupported provider', { status: 400, headers: corsHeaders });
  }
});
