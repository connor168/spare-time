import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { dueDigestKey } from './delivery.ts';

type Preference = { user_id: string; timezone_id: string; digest_time: string; push_enabled: boolean; quiet_start: string | null; quiet_end: string | null };
type DeviceToken = { user_id: string; provider: 'fcm' | 'apns' | 'hms'; token: string };

async function tokenFingerprint(token: string): Promise<string> {
  const bytes = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .slice(0, 8)
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('');
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Use POST', { status: 405 });
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const pushGatewayUrl = Deno.env.get('PUSH_GATEWAY_URL');
  const pushGatewayToken = Deno.env.get('PUSH_GATEWAY_TOKEN');
  if (!supabaseUrl || !serviceRoleKey || !pushGatewayUrl || !pushGatewayToken) return new Response('Missing daily digest configuration', { status: 500 });
  const cronSecret = Deno.env.get('CRON_SECRET');
  if (!cronSecret || request.headers.get('x-cron-secret') !== cronSecret) return new Response('Unauthorized', { status: 401 });

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data: preferences, error: preferenceError } = await supabase.from('user_preferences').select('user_id,timezone_id,digest_time,push_enabled,quiet_start,quiet_end').eq('push_enabled', true);
  if (preferenceError) return Response.json({ error: preferenceError.message }, { status: 502 });
  const now = new Date();
  const duePreferences = ((preferences ?? []) as Preference[])
    .map((preference) => ({ preference, digestKey: dueDigestKey(preference, now) }))
    .filter((entry): entry is { preference: Preference; digestKey: string } => entry.digestKey !== null);
  if (duePreferences.length === 0) {
    return Response.json({ sent: 0, users: 0, news: 0 });
  }
  const { data: news, error: newsError } = await supabase.from('news_items').select('repository_full_name,title,summary,source_url,stars').order('score', { ascending: false }).limit(10);
  if (newsError) return Response.json({ error: newsError.message }, { status: 502 });

  let sent = 0;
  for (const { preference, digestKey } of duePreferences) {
    const { data: tokens, error: tokenError } = await supabase.from('device_tokens').select('user_id,provider,token').eq('user_id', preference.user_id).is('invalid_at', null);
    if (tokenError) {
      console.error('device token lookup failed', { userId: preference.user_id, error: tokenError.message });
      continue;
    }
    for (const device of (tokens ?? []) as DeviceToken[]) {
      let claimedDeliveryId: string | null = null;
      try {
        const fingerprint = await tokenFingerprint(device.token);
        const idempotencyKey = `digest:${preference.user_id}:${digestKey}:${device.provider}:${fingerprint}`;
        const { data: deliveryId, error: claimError } = await supabase.rpc('claim_digest_delivery', {
          p_user_id: preference.user_id,
          p_digest_date: digestKey,
          p_provider: device.provider,
          p_token_fingerprint: fingerprint,
        });
        if (claimError) {
          console.error('digest delivery claim failed', { userId: preference.user_id, error: claimError.message });
          continue;
        }
        if (!deliveryId) continue;
        claimedDeliveryId = deliveryId as string;
        const response = await fetch(pushGatewayUrl, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${pushGatewayToken}`,
            'idempotency-key': idempotencyKey,
          },
          body: JSON.stringify({
            provider: device.provider,
            token: device.token,
            title: '今日 AI 资讯',
            body: `${news?.length ?? 0} 条 GitHub 热点项目`,
            data: { deep_link: 'focusflow://news/daily', digest_date: digestKey },
          }),
        });
        if (response.ok) {
          sent += 1;
          const { error: deliveryError } = await supabase
            .from('digest_deliveries')
            .update({ status: 'sent', last_error: null, updated_at: new Date().toISOString() })
            .eq('id', claimedDeliveryId);
          if (deliveryError) console.error('digest delivery completion failed', { deliveryId: claimedDeliveryId, error: deliveryError.message });
        } else if (response.headers.get('x-push-token-invalid') === 'true') {
          await supabase
            .from('device_tokens')
            .update({ invalid_at: new Date().toISOString() })
            .eq('token', device.token);
          await supabase
            .from('digest_deliveries')
            .update({ status: 'failed', last_error: `token rejected: ${response.status}`, updated_at: new Date().toISOString() })
            .eq('id', claimedDeliveryId);
        } else {
          await supabase
            .from('digest_deliveries')
            .update({ status: 'failed', last_error: `gateway status: ${response.status}`, updated_at: new Date().toISOString() })
            .eq('id', claimedDeliveryId);
          console.error('push gateway rejected digest', {
            userId: preference.user_id,
            provider: device.provider,
            status: response.status,
          });
        }
      } catch (error) {
        if (claimedDeliveryId) {
          await supabase
            .from('digest_deliveries')
            .update({ status: 'failed', last_error: String(error), updated_at: new Date().toISOString() })
            .eq('id', claimedDeliveryId);
        }
        console.error('push delivery failed', {
          userId: preference.user_id,
          provider: device.provider,
          error,
        });
      }
    }
  }
  return Response.json({ sent, users: duePreferences.length, news: (news ?? []).length });
});
