export type Config = {
  nodeEnv: string;
  port: number;
  databaseUrl: string;
  databaseSslCaFile: string | null;
  jwtSecret: Uint8Array;
  jwtIssuer: string;
  accessTokenTtlSeconds: number;
  wechatAppId: string | null;
  wechatAppSecret: string | null;
};

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export function loadConfig(env = process.env): Config {
  const jwtSecret = env.JWT_SECRET?.trim() ?? '';
  if (jwtSecret.length < 32) {
    throw new Error('JWT_SECRET must contain at least 32 characters');
  }
  const ttl = Number(env.ACCESS_TOKEN_TTL_SECONDS ?? 900);
  if (!Number.isInteger(ttl) || ttl < 60 || ttl > 86_400) {
    throw new Error('ACCESS_TOKEN_TTL_SECONDS must be between 60 and 86400');
  }
  const databaseSslCaFile = env.DATABASE_SSL_CA_FILE?.trim() || null;
  if ((env.NODE_ENV ?? 'development') === 'production' && !databaseSslCaFile) {
    throw new Error('DATABASE_SSL_CA_FILE is required in production');
  }
  return {
    nodeEnv: env.NODE_ENV ?? 'development',
    port: Number(env.PORT ?? 8080),
    databaseUrl: requiredFrom(env, 'DATABASE_URL'),
    databaseSslCaFile,
    jwtSecret: new TextEncoder().encode(jwtSecret),
    jwtIssuer: env.JWT_ISSUER?.trim() || 'focus-flow-api',
    accessTokenTtlSeconds: ttl,
    wechatAppId: env.WECHAT_APP_ID?.trim() || null,
    wechatAppSecret: env.WECHAT_APP_SECRET?.trim() || null,
  };
}

function requiredFrom(env: NodeJS.ProcessEnv, name: string): string {
  const value = env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}
