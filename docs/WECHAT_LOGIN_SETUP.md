# 微信登录接入说明

## 已实现

- Android 使用微信 OpenSDK 发起 `snsapi_userinfo` 授权。
- Flutter 通过 `focusflow/wechat` MethodChannel 获取一次性授权 code。
- Supabase Edge Function `wechat-login` 在服务端换取微信身份，并把微信 `unionid`/`openid` 映射到 Supabase 用户。
- AppSecret 只从 Supabase secrets 读取，不进入 Flutter、Android 或 Git。

## 部署前配置

在 Supabase 项目中设置以下 secrets：

```text
WECHAT_APP_ID=wx64ba2d4d4d4fb15370
WECHAT_APP_SECRET=<微信开放平台 AppSecret>
```

`SUPABASE_URL`、`SUPABASE_ANON_KEY` 和 `SUPABASE_SERVICE_ROLE_KEY` 使用 Supabase 项目默认环境变量。先执行迁移，再部署函数：

```text
supabase db push
supabase functions deploy wechat-login --no-verify-jwt
```

## Android 联调条件

- 安装微信客户端。
- 使用 `com.focusflow.planner` 包名构建。
- 使用生产签名构建，证书 MD5 必须是 `8d79f05abd5d17e83b2a903aa4292e3b`。
- Supabase secrets、迁移和函数部署完成后，点击账户页的 `Continue with WeChat`。

当前代码已通过 Flutter 静态分析，但尚未完成 Supabase 线上函数部署和微信真机联调；不要把此状态当作登录功能验收完成。