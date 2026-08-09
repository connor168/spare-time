# 客户端与后端数据契约

## 任务

客户端保存本地任务后，通过同步接口发送完整实体或变更记录。时间使用 UTC instant，`timezone_id` 保存合法 IANA 时区 ID，例如 `Asia/Tokyo`。

```json
{
  "id": "uuid",
  "title": "深度工作",
  "description": "完成同步一致性方案",
  "start_at": "2026-08-07T00:00:00Z",
  "end_at": "2026-08-07T01:30:00Z",
  "timezone_id": "Asia/Tokyo",
  "repeat_rule": {"type": "none"},
  "reminder_minutes": 15,
  "status": "planned",
  "priority": 3,
  "version": 1,
  "updated_at": "2026-08-06T15:00:00Z",
  "deleted_at": null
}
```

任务和笔记上传分别调用 `sync_task_cas`、`sync_note_cas` RPC，并携带本轮拉取到的 `base_version`。新实体使用 `base_version=0`；已有实体仅在服务端当前版本仍等于 `base_version` 且新版本更高时写入。RPC 返回 `accepted` 或 `conflict`，客户端统计冲突并保留本地修改，不允许无条件 upsert。列表读取以 `updated_at,id` 稳定排序并循环分页。

## 知识库

笔记正文使用 Markdown，编辑会递增 `version` 和 `updated_at`。删除使用 `deleted_at` 软删除，确认所有设备同步后才允许物理清理。

## GitHub 资讯

资讯必须包含 `source_url`、`repository_full_name`、`fetched_at` 和 `summary_version`。摘要服务不可用时，`summary_version` 为 `raw-description`，客户端不得把原始描述标记为 AI 生成摘要。

- `GET /functions/v1/github-digest`：读取缓存，返回 `{ "items": [...] }`。
- `POST /functions/v1/github-digest`：Cron 抓取并写库，必须提供 `x-cron-secret`。

设备 Token 不允许客户端直接用 `on_conflict=token` 改归属。登录恢复后调用 `claim_device_token` RPC 原子认领，退出前调用 `revoke_device_token` RPC 撤销。单账号最多保留 20 个有效 Token。

## 状态与失败回退

| 状态 | 客户端行为 |
|---|---|
| `loading` | 显示稳定尺寸的加载状态，不改变列表布局 |
| `cached` | 展示最近一次成功数据和最后抓取时间 |
| `stale` | 允许阅读缓存，提示下次重试时间 |
| `error` | 显示可重试入口，不清空已有本地任务或笔记 |
| `conflict` | 显示冲突对象和版本，不静默覆盖用户内容 |
