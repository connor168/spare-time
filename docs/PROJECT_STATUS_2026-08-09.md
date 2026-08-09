# Focus Flow 项目完成情况

更新时间：2026-08-09

## 当前结论

Focus Flow 的本地移动 MVP 已接近可验收状态，但距离正式发布仍有两类完整工作：真实云端/远程推送联调，以及生产证书/真实设备/商店发布验收。按当前证据估算，本地功能约完成 90%，云端与远程推送代码约完成 60%，生产发布准备约完成 25%；整体距离可正式发布约还有 35% 的工作量。百分比只用于排期，最终仍以验收项为准。

| 交付层级 | 当前状态 | 证据或阻塞 |
| --- | --- | --- |
| 本地移动 MVP | 基本完成 | `flutter analyze` 通过；48 个 Flutter 测试通过；Android debug APK 已生成 |
| Windows 调试壳 | 已打通 | EXE 已生成并完成 5 秒启动烟雾测试；桌面调试使用内存仓库，不承诺持久化/推送 |
| 云端同步 | 待部署联调 | 已修账号隔离/切换竞态、墓碑、全字段、分页和版本 CAS；冲突解决 UI 与真实双设备验收仍缺 |
| GitHub 资讯后端 | 待部署验收 | 已统一 GET 缓存读取与 POST Cron 契约；真实部署、GitHub 限流和缓存回退未验收 |
| 远程推送 | 进行中 | 已补默认偏好、时区/安静时段筛选和 Token 认领 RPC；真实网关、客户端消息处理和真机未完成 |
| 正式发布 | 未完成 | 缺生产签名、Firebase/HMS/APNs 配置、iOS 构建、商店资料和真机矩阵 |

## 本轮完成并验证

- 本地任务和笔记新增 `owner_user_id` 命名空间；游客、账号 A、账号 B 不再共用同一同步视图。
- Drift schema 升级到 v2，旧数据保留在游客命名空间，不会自动上传给新登录账号。
- 同步引擎读取软删除墓碑；远端应用使用专用入口保留 `version/updated_at/deleted_at`。
- 新增同步回归测试：本地墓碑上传、远端元数据落地后第二次同步零回传。
- 任务模型、SQLite、创建界面和同步补齐 `description/priority`，不再清空云端字段。
- 任务/笔记读取按稳定顺序循环分页；非法远端时间戳会明确失败，不再伪装为本机当前时间。
- 任务/笔记上传改用服务端 CAS RPC；并发版本不匹配会返回冲突，不再无条件覆盖。
- 认证切换使用 generation 丢弃旧加载结果并中止旧同步；切换账号时先清理旧账号通知。
- 推送 Token 登录恢复后自动认领，刷新串行处理，认领失败时保留最后一个有效 Token。
- `github-digest` 支持 GET 读取缓存，POST 抓取要求 `CRON_SECRET`，成功响应包含 `items`。
- `daily-digest` 按 IANA 时区、发送时间和安静时段筛选；推送 payload 只携带深链和摘要日期。
- 每日摘要增加数据库投递账本与原子 claim；已成功的同账号/日期/设备不会因 Cron 重跑而重复发送。
- GitHub 资讯改为每个仓库一条最新快照，避免相同仓库长期重复和旧评分滞留。
- 新增 `0002_release_hardening.sql`：资讯 RLS、默认用户偏好、Token 认领/撤销和同步 CAS RPC。
- Android debug APK：`build/app/outputs/flutter-apk/app-debug.apk`，包名 `com.focusflow.planner`。
- Windows debug EXE：`build/windows/x64/runner/Debug/focus_flow.exe`，已实际启动验证。

## 仍需完成的代码工作

1. 增加可操作的冲突详情与保留本地/采用云端/复制副本流程；目前 CAS 已阻止覆盖，但 UI 只显示冲突数量。
2. 增加资讯本地缓存、失败重试和 stale 状态；当前有 URL 时请求失败仍只显示错误。
3. 完成推送消息前台/后台/冷启动处理和 `focusflow://news/daily` 导航。
4. 实现 FCM/HMS 运行时能力选择；当前 HMS Token source 有代码但没有产品调用路径。
5. 为推送安装实例增加持久标识和离线撤销重试；当前在线退出会撤销，离线退出仍可能留下旧 Token。
6. 增加游客数据“导入当前账号”流程；迁移后的游客数据会保留但登录时隐藏。
7. 增加账号数据导出、账号删除、隐私政策入口和商店合规资料。

## 仍需外部配置和验收

- 在真实 Supabase 项目应用 `0002_release_hardening.sql`，部署两个 Edge Functions 并配置 Cron/secrets。
- 提供并联调真实 Push Gateway；当前仓库没有 FCM/APNs/HMS 服务端发送实现。
- 放入 Firebase、AppGallery Connect 和 iOS 配置文件，完成 FCM/APNs/HMS 真机测试。
- 在 Android 手机/平板、iPhone/iPad、无 GMS 华为设备完成锁屏、杀进程、重启、弱网和多账号验收。
- 创建生产 Android keystore、签名 AAB；在 macOS/Xcode 创建生产 iOS Archive。
- 完成隐私政策、数据删除说明、商店截图/描述/分级和发布审核。

## 当前验证记录

| 检查项 | 结果 |
| --- | --- |
| `flutter analyze` | 通过，`No issues found` |
| `flutter test` | 通过，48 个测试 |
| Edge Function TypeScript 语法 | Node 24 type stripping 语法检查通过 |
| 每日摘要时区纯逻辑 | Tokyo 正常窗口、提前窗口、跨夜安静时段通过 |
| Android debug APK | 构建通过，compile/target SDK 36，min SDK 24 |
| Windows debug EXE | 构建通过，进程启动烟雾测试通过 |
| Deno/Supabase 本地集成测试 | 未运行，当前机器未安装 Deno/Supabase CLI |
| 真实云端/真机 | 未完成，需要外部账号、配置和设备 |
