# Focus Flow 当前状态

更新时间：2026-08-15

## 本轮完成

- 根据项目作者确认的信息建立 Android-first 个人版产品需求基线。
- 永久 Android 包名确认为 `com.focusflow.planner`。
- 修复 `main.dart` 的乱码、字符串损坏、Widget/State 生命周期错位和同步接线错误。
- 修复设备 Token 注册器的方法嵌套、重复撤销代码和有限重试队列。
- 修复 Android 主 Manifest 的嵌套 `intent-filter`，并为 release 主 Manifest 增加网络权限。
- 恢复资讯深链和前台/点击/冷启动 Firebase 消息入口。
- 恢复游客数据计数与导入入口，并在同步后刷新本地界面。
- 将默认任务提醒改为提前 5 分钟，将个人版默认时区改为 `Asia/Shanghai`。
- 新增微信/QQ 开放平台与 Android 发布签名操作清单。
- 固定生产签名证书并校验 APK 包名、证书 MD5 与 v2 签名。
- 生成正式应用图标及微信开放平台 28/108 像素审核资源。
- 新增可部署的官网、隐私政策、用户协议和 GitHub Pages 工作流。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 通过，`No issues found` |
| `flutter test --no-pub` | 通过，51/51 |
| `flutter build apk --debug --no-pub` | 通过 |
| `assembleRelease` | 通过，生产签名 APK 已生成 |
| APK 包名 | `com.focusflow.planner` |
| APK 证书 MD5 | `8d79f05abd5d17e83b2a903aa4292e3b` |
| APK 签名验证 | v2 通过，单一签名者 |
| 当前 debug APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| 当前 release APK | `build/app/outputs/flutter-apk/app-release.apk` |

## 尚未完成

- 课程/任务时间轴的完整新增、编辑、拖动、删除和历史状态闭环。
- 本地规则计划草稿、确认生效、当日重排和“今日未完成”历史。
- 用户真实课程表的一次性解析与导入。
- GitHub、AI、科技、Linux/开源约 50 条资讯聚合与每日 07:00 单条通知。
- Android 设备本地翻译、中英文切换和翻译缓存。
- 微信和 QQ 登录 SDK、服务端账号交换及真实平台凭据联调。
- 真实 Supabase 双设备同步、冲突操作流程和离线恢复验收。
- Release AAB、应用内首次隐私同意流程和 Android 真机矩阵。

第一版完成标准以 `docs/PRODUCT_REQUIREMENTS.md` 为准。
