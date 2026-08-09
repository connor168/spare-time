# Supabase 后端

## 环境变量

`github-digest` 需要配置：

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GITHUB_TOKEN`
- `CRON_SECRET`（必需）

`SUPABASE_SERVICE_ROLE_KEY` 和 `GITHUB_TOKEN` 只能存在 Edge Function 的服务端环境变量中，不能编译进 Flutter 客户端，也不能写入日志。

## 迁移与本地验证

按顺序应用迁移：

```text
supabase db push
```

`0002_release_hardening.sql` 会启用资讯 RLS、为新旧账号补默认推送偏好，安装设备 Token 认领/撤销与任务/笔记版本 CAS RPC，并创建每日摘要投递账本。资讯迁移后每个 GitHub 仓库只保留最新快照。

在安装 Supabase CLI 后：

```text
supabase db reset
supabase functions serve github-digest --env-file .env.local
```

`github-digest` 的 `POST` 用于受保护的 Cron 抓取，必须提供 `x-cron-secret`；`GET` 只读取最近缓存并返回 `{ "items": [...] }`，供 Flutter 客户端使用。`daily-digest` 应由高频 Cron 调用，函数内部按用户时区、发送时间和安静时段筛选。

两个函数均在 `supabase/config.toml` 中关闭网关 JWT 校验，由函数内的 `CRON_SECRET` 保护写入/推送入口。`daily-digest` 仍依赖仓库外的 `PUSH_GATEWAY_URL`；网关只有在确定 Token 已失效时才可返回 `x-push-token-invalid: true`。部署前必须用真实 FCM/APNs/HMS 网关完成该契约测试。
