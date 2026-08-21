import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'apikey, content-type',
};

type WeChatTokenResponse = {
  access_token?: string;
  openid?: string;
  unionid?: string;
  errcode?: number;
  errmsg?: string;
};

type WeChatProfile = {
  openid?: string;
  unionid?: string;
  nickname?: string;
  headimgurl?: string;
  errcode?: number;
  errmsg?: string;
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

function randomPassword(): string {
  return `${crypto.randomUUID()}-${crypto.randomUUID()}-Aa1!`;
}

async function exchangeCode(appId: string, appSecret: string, code: string): Promise<WeChatTokenResponse> {
  const url = new URL('https://api.weixin.qq.com/sns/oauth2/access_token');
  url.searchParams.set('appid', appId);
  url.searchParams.set('secret', appSecret);
  url.searchParams.set('code', code);
  url.searchParams.set('grant_type', 'authorization_code');
  const response = await fetch(url);
  if (!response.ok) throw new Error('WeChat token exchange failed.');
  return await response.json() as WeChatTokenResponse;
}

async function loadProfile(token: string, openid: string): Promise<WeChatProfile> {
  const url = new URL('https://api.weixin.qq.com/sns/userinfo');
  url.searchParams.set('access_token', token);
  url.searchParams.set('openid', openid);
  url.searchParams.set('lang', 'zh_CN');
  const response = await fetch(url);
  if (!response.ok) throw new Error('WeChat profile request failed.');
  return await response.json() as WeChatProfile;
}

async function passwordSession(url: string, anonKey: string, email: string, password: string) {
  const response = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      authorization: `Bearer ${anonKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ email, password }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error('Unable to create an application session.');
  return body;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Use POST' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const appId = Deno.env.get('WECHAT_APP_ID');
  const appSecret = Deno.env.get('WECHAT_APP_SECRET');
  if (!supabaseUrl || !serviceRoleKey || !anonKey || !appId || !appSecret) {
    return json({ error: 'Missing WeChat server configuration' }, 500);
  }

  let code: unknown;
  try {
    const payload = await request.json();
    code = payload?.code;
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
  if (typeof code !== 'string' || code.length < 1 || code.length > 256) {
    return json({ error: 'Missing authorization code' }, 400);
  }

  try {
    const token = await exchangeCode(appId, appSecret, code);
    if (token.errcode || !token.access_token || !token.openid) {
      console.error('WeChat rejected authorization code', { errcode: token.errcode });
      return json({ error: 'WeChat authorization failed' }, 401);
    }
    const profile = await loadProfile(token.access_token, token.openid);
    if (profile.errcode) return json({ error: 'Unable to load WeChat profile' }, 401);

    const subject = profile.unionid ?? token.unionid ?? profile.openid ?? token.openid;
    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: identity, error: identityError } = await admin
      .from('oauth_identities')
      .select('user_id')
      .eq('provider', 'wechat')
      .eq('subject', subject)
      .maybeSingle();
    if (identityError) throw identityError;

    const password = randomPassword();
    let email: string;
    if (identity?.user_id) {
      const { data: user, error } = await admin.auth.admin.getUserById(identity.user_id);
      if (error || !user.user?.email) throw error ?? new Error('WeChat user is missing email.');
      email = user.user.email;
      const { error: updateError } = await admin.auth.admin.updateUserById(identity.user_id, { password });
      if (updateError) throw updateError;
    } else {
      const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(subject));
      const fingerprint = [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, '0')).join('');
      email = `wechat-${fingerprint}@wechat.focusflow.invalid`;
      const { data: created, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { auth_provider: 'wechat', nickname: profile.nickname ?? null, avatar_url: profile.headimgurl ?? null },
      });
      if (error || !created.user) throw error ?? new Error('Unable to create WeChat user.');
      const { error: insertError } = await admin.from('oauth_identities').insert({
        provider: 'wechat',
        subject,
        user_id: created.user.id,
        profile: { nickname: profile.nickname ?? null, avatar_url: profile.headimgurl ?? null },
      });
      if (insertError) throw insertError;
    }

    return json(await passwordSession(supabaseUrl, anonKey, email, password));
  } catch (error) {
    console.error('wechat-login failed', error);
    return json({ error: 'WeChat login failed' }, 502);
  }
});
