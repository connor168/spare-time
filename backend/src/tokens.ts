import { createHash, randomBytes } from 'node:crypto';
import { SignJWT, jwtVerify } from 'jose';
import type { Config } from './config.js';

export type AccessClaims = { userId: string };

export async function issueAccessToken(config: Config, userId: string): Promise<string> {
  return new SignJWT({ sub: userId, typ: 'access' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuer(config.jwtIssuer)
    .setIssuedAt()
    .setExpirationTime(`${config.accessTokenTtlSeconds}s`)
    .sign(config.jwtSecret);
}

export async function verifyAccessToken(config: Config, token: string): Promise<AccessClaims> {
  const { payload } = await jwtVerify(token, config.jwtSecret, { issuer: config.jwtIssuer });
  if (payload.typ !== 'access' || typeof payload.sub !== 'string') throw new Error('Invalid access token');
  return { userId: payload.sub };
}

export function createRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
