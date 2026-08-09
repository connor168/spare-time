import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';


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

type DeliveryPreference = {
  timezone_id: string;
  digest_time: string;
  quiet_start: string | null;
  quiet_end: string | null;
};

type LocalClock = {
  dateKey: string;
  minuteOfDay: number;
};

function parseTime(value: string | null): number | null {
  if (!value) return null;
  const match = /^(\d{1,2}):(\d{2})/.exec(value);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

function localClock(now: Date, timeZone: string): LocalClock | null {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(now);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return {
      dateKey: `${values.year}-${values.month}-${values.day}`,
      minuteOfDay: Number(values.hour) * 60 + Number(values.minute),
    };
  } catch {
    return null;
  }
}

function previousDateKey(dateKey: string): string {
  const date = new Date(`${dateKey}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

function effectiveDeliveryMinute(preference: DeliveryPreference): {
  minute: number;
  nextDay: boolean;
} | null {
  const digest = parseTime(preference.digest_time);
  if (digest === null) return null;
  const quietStart = parseTime(preference.quiet_start);
  const quietEnd = parseTime(preference.quiet_end);
  if (quietStart === null || quietEnd === null || quietStart === quietEnd) {
    return { minute: digest, nextDay: false };
  }

  const wrapsMidnight = quietStart > quietEnd;
  const isQuiet = wrapsMidnight
    ? digest >= quietStart || digest < quietEnd
    : digest >= quietStart && digest < quietEnd;
  if (!isQuiet) return { minute: digest, nextDay: false };
  return {
    minute: quietEnd,
    nextDay: wrapsMidnight && digest >= quietStart,
  };
}

export function dueDigestKey(
  preference: DeliveryPreference,
  now = new Date(),
  windowMinutes = 15,
): string | null {
  const clock = localClock(now, preference.timezone_id);
  const delivery = effectiveDeliveryMinute(preference);
  if (!clock || !delivery || windowMinutes < 1) return null;

  const end = delivery.minute + windowMinutes;
  const insideWindow = end <= 1440
    ? clock.minuteOfDay >= delivery.minute && clock.minuteOfDay < end
    : clock.minuteOfDay >= delivery.minute || clock.minuteOfDay < end - 1440;
  if (!insideWindow) return null;

  const deliveredAfterMidnight = end > 1440 && clock.minuteOfDay < end - 1440;
  return delivery.nextDay || deliveredAfterMidnight
    ? previousDateKey(clock.dateKey)
    : clock.dateKey;
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
