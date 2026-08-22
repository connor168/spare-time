import { loadConfig } from './config.js';
import { createPool } from './db.js';
import { sendDailyDigestNotifications } from './fcm.js';
import { refreshGitHubDigest, shanghaiDate } from './news_digest.js';

const config = loadConfig();
const pool = createPool(config);
try {
  const now = new Date();
  const count = await refreshGitHubDigest(pool, config.githubApiToken, now);
  const sent = await sendDailyDigestNotifications(pool, config, shanghaiDate(now));
  console.log(JSON.stringify({ refreshed: count, notifications_sent: sent, digest_date: shanghaiDate(now) }));
} finally {
  await pool.end();
}
