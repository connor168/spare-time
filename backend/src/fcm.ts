import { importPKCS8, SignJWT } from 'jose';
import type pg from 'pg';
import type { Config } from './config.js';

const oauthEndpoint = 'https://oauth2.googleapis.com/token';

export async function sendDailyDigestNotifications(
  pool: pg.Pool,
  config: Pick<Config, 'fcmProjectId' | 'fcmClientEmail' | 'fcmPrivateKey'>,
  digestDate: string,
): Promise<number> {
  if (!config.fcmProjectId || !config.fcmClientEmail || !config.fcmPrivateKey) return 0;
  const accessToken = await getAccessToken(config.fcmClientEmail, config.fcmPrivateKey);
  const tokens = await pool.query<{ id: string; token: string }>(
    `select id, token from device_tokens where provider = 'fcm'`,
  );
  let sent = 0;
  for (const device of tokens.rows) {
    const delivery = await pool.query(
      `insert into daily_digest_deliveries (digest_date, device_token_id)
       values ($1, $2) on conflict do nothing returning device_token_id`,
      [digestDate, device.id],
    );
    if (!delivery.rowCount) continue;
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${config.fcmProjectId}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message: {
        token: device.token,
        notification: { title: 'Focus Flow 每日 GitHub 热点', body: '今日 50 条精选项目已更新，点击查看。' },
        data: { deep_link: 'focusflow://news/daily', digest_date: digestDate },
      }}),
    });
    if (!response.ok) {
      await pool.query('delete from daily_digest_deliveries where digest_date = $1 and device_token_id = $2', [digestDate, device.id]);
      continue;
    }
    sent += 1;
  }
  return sent;
}

async function getAccessToken(email: string, privateKey: string): Promise<string> {
  const key = await importPKCS8(privateKey, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(email)
    .setAudience(oauthEndpoint)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
  const response = await fetch(oauthEndpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!response.ok) throw new Error(`FCM OAuth returned ${response.status}`);
  const payload = await response.json() as { access_token?: unknown };
  if (typeof payload.access_token !== 'string') throw new Error('FCM OAuth response has no access token');
  return payload.access_token;
}
