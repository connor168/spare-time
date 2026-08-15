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

## 验证结果

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 通过，`No issues found` |
| `flutter test --no-pub` | 通过，51/51 |
| `flutter build apk --debug --no-pub` | 通过 |
| 当前 debug APK | `build/app/outputs/flutter-apk/app-debug.apk` |

## 尚未完成

- 课程/任务时间轴的完整新增、编辑、拖动、删除和历史状态闭环。
- 本地规则计划草稿、确认生效、当日重排和“今日未完成”历史。
- 用户真实课程表的一次性解析与导入。
- GitHub、AI、科技、Linux/开源约 50 条资讯聚合与每日 07:00 单条通知。
- Android 设备本地翻译、中英文切换和翻译缓存。
- 微信和 QQ 登录 SDK、服务端账号交换及真实平台凭据联调。
- 真实 Supabase 双设备同步、冲突操作流程和离线恢复验收。
- Android 发布签名、release AAB、隐私合规和真机矩阵。

第一版完成标准以 `docs/PRODUCT_REQUIREMENTS.md` 为准。
