export type WechatIdentity = {
  subject: string;
  nickname: string | null;
  avatarUrl: string | null;
};

type TokenResponse = {
  access_token?: string;
  openid?: string;
  unionid?: string;
  errcode?: number;
};

type ProfileResponse = {
  openid?: string;
  unionid?: string;
  nickname?: string;
  headimgurl?: string;
  errcode?: number;
};

export async function exchangeWechatCode(
  appId: string,
  appSecret: string,
  code: string,
  fetcher: typeof fetch = fetch,
): Promise<WechatIdentity> {
  const tokenUrl = new URL('https://api.weixin.qq.com/sns/oauth2/access_token');
  tokenUrl.searchParams.set('appid', appId);
  tokenUrl.searchParams.set('secret', appSecret);
  tokenUrl.searchParams.set('code', code);
  tokenUrl.searchParams.set('grant_type', 'authorization_code');
  const tokenResponse = await fetcher(tokenUrl);
  if (!tokenResponse.ok) throw new Error('WeChat token exchange failed');
  const token = (await tokenResponse.json()) as TokenResponse;
  if (token.errcode || !token.access_token || !token.openid) throw new Error('WeChat authorization failed');

  const profileUrl = new URL('https://api.weixin.qq.com/sns/userinfo');
  profileUrl.searchParams.set('access_token', token.access_token);
  profileUrl.searchParams.set('openid', token.openid);
  profileUrl.searchParams.set('lang', 'zh_CN');
  const profileResponse = await fetcher(profileUrl);
  if (!profileResponse.ok) throw new Error('WeChat profile request failed');
  const profile = (await profileResponse.json()) as ProfileResponse;
  if (profile.errcode) throw new Error('WeChat profile request failed');

  return {
    subject: profile.unionid ?? token.unionid ?? profile.openid ?? token.openid,
    nickname: profile.nickname ?? null,
    avatarUrl: profile.headimgurl ?? null,
  };
}
