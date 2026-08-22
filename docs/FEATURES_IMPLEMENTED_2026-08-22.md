# Focus Flow 功能阶段验收

本阶段先完成产品功能，阿里云正式部署、微信开放平台登记和最终验收留到下一阶段。

## 已完成

- 每日规划：`今日` 页面可以按现有课程和任务的空档生成专注时间块，默认每块 50 分钟、间隔 10 分钟，并保留已有安排不移动；生成结果先进入草稿预览，支持编辑、删除和重叠检查，确认后才写入正式日程。
- 课表截图：Android 端从相册选择课表截图，使用中文 OCR 提取文字，进入人工确认列表后再写入未来课表。也支持粘贴 JSON 或 OCR 文本进行导入。
- 课程提醒：导入的课程自动创建课前 5 分钟提醒；导入多个课程时只请求一次通知权限。Android 通知权限仍需用户在系统设置中允许。
- GitHub 每日资讯：后台从 GitHub Search API 拉取最多 50 个热门仓库，按星标和 fork 数排序，写入当天摘要；Flutter 自建 API 客户端读取当天摘要，支持手动刷新。
- GitHub 推送：`backend/src/refresh-news.ts` 支持刷新摘要并调用 FCM HTTP v1 给已登记设备发送每日通知。服务器配置 `FCM_*` 后由 ECS cron 每天 07:00（Asia/Shanghai）执行。

## 运行配置

后端 `.env` 需要配置 `GITHUB_API_TOKEN`、`NEWS_CRON_SECRET`。要发送 Android 推送，还需要配置 Firebase 服务账号对应的 `FCM_PROJECT_ID`、`FCM_CLIENT_EMAIL`、`FCM_PRIVATE_KEY`。这些值只放在阿里云服务器环境变量中，不能放进 Flutter 或 Git。

## 当前验证

- Flutter 静态分析：通过。
- Flutter 全量测试：82 个通过。
- 后端 typecheck/build/unit test：通过。
- Android Debug APK：当前机器因 Gradle 8.13.1 依赖下载被网络权限拒绝，尚未完成构建；这属于环境阻塞，不是 Dart 或 TypeScript 编译错误。

## 下一阶段

1. 恢复 Gradle 下载或准备完整本地 Maven 缓存，构建 Debug 和 Release APK/AAB。
2. 启动 PostgreSQL 后运行真实 integration test。
3. 在阿里云配置数据库、HTTPS、微信 AppSecret、GitHub/FCM 密钥和 cron。
4. 真机验证截图识别、课程提醒、微信登录、每日推送、双设备同步后再做登记和最终验收。
