# Focus Flow 项目完成情况

更新时间：2026-08-08

## 1. 当前结论

Focus Flow 已完成本地核心 MVP 的主要代码，包括手机/平板响应式界面、日程管理、SQLite 持久化、知识库、登录与同步基础、GitHub AI 资讯客户端、通知调度和设备 Token 注册。

当前还不能视为“可以正式发布”的产品。主要缺口不是页面代码，而是真实云端部署、Firebase/HMS/APNs 配置、真机验收、Windows 原生构建修复以及正式签名发布。

按交付层级判断：

| 层级 | 状态 | 说明 |
| --- | --- | --- |
| 本地功能 MVP | 基本完成 | 日程和知识库可以使用 SQLite 保存，响应式界面和主要交互已有自动化测试 |
| 云端功能 | 部分完成 | Supabase 客户端、同步引擎和 Edge Function 代码已存在，但尚未完成完整线上联调 |
| 推送能力 | 部分完成 | 本地通知代码已接入；FCM、APNs、HMS 缺真实平台配置和真机验证 |
| 发布准备 | 未完成 | 没有正式 keystore、签名 AAB、iOS 签名包和商店真机验收记录 |

## 2. 已完成并有代码或测试证明的功能

### 2.1 手机、平板和大屏适配

- Flutter 响应式界面已实现。
- 手机窄屏使用底部导航，平板和大屏使用侧边导航。
- 自动化测试覆盖 `599dp`、`600dp`、`840dp`、`841dp` 等关键断点。
- 测试已覆盖任务完成、知识库搜索和新增笔记等主要交互。

相关代码：

- `lib/main.dart`
- `lib/ui/window_class.dart`
- `test/app_shell_test.dart`
- `test/window_class_test.dart`

### 2.2 日程和提醒

- 任务新增、读取、更新、完成和软删除的数据层已实现。
- 任务保存到 Drift/SQLite，关闭应用后数据不会只停留在内存中。
- 支持开始时间、结束时间、提醒提前量、时区和重复规则。
- 本地通知调度器已接入应用启动、任务保存和任务完成流程。
- Android Manifest 已声明通知、精确闹钟和开机恢复相关能力。
- 自动化测试覆盖任务持久化、重复规则、版本递增和软删除恢复。

尚未证明的部分：锁屏、杀进程、重启、省电模式和厂商后台限制下的提醒准确性仍需要 Android 真机验证。

### 2.3 个人知识库

- 知识库已接入 Drift/SQLite，不再只是内存数据。
- 支持创建、编辑、搜索、标签、收藏、版本号和软删除。
- 自动化测试覆盖保存、更新、搜索、删除和恢复。

相关代码：

- `lib/data/knowledge_note_repository.dart`
- `lib/domain/knowledge_note.dart`
- `test/note_repository_test.dart`
- `test/knowledge_note_repository_test.dart`

### 2.4 Supabase 登录和同步基础

- 登录、注册、邮箱确认提示和退出页面已实现。
- 会话使用安全存储保存，包含恢复和刷新 Token 的逻辑。
- 任务和笔记的双向同步引擎已经存在。
- UUID 实体 ID、版本字段、软删除墓碑和冲突计数基础已经实现。
- Supabase URL、公开客户端 Key 和 GitHub Digest URL 已通过本地配置文件注入。
- Supabase `0001_core.sql` 已由用户在控制台执行成功，RLS 策略页面已确认存在。

尚未证明的部分：真实账号注册、登录、两台设备同时修改、离线恢复、冲突解决和账号隔离还没有完成端到端验收。

### 2.5 GitHub AI 热点资讯基础

- GitHub Digest Flutter 客户端已实现。
- Supabase Edge Function 已包含 GitHub 抓取、评分和每日摘要代码框架。
- 代码中包含失败时的本地示例数据，界面不会完全空白。
- 客户端和评分逻辑已有测试文件。

尚未完成的部分：Edge Function 尚未确认部署成功，GitHub Token、定时任务、API 限流、真实每日数据和新闻推送没有完成线上验证。

### 2.6 应用标识和平台工程

- Android 包名已修改为 `com.focusflow.planner`。
- iOS Bundle Identifier 已修改为 `com.focusflow.planner`。
- Android、iOS 和 Windows 平台工程目录均已生成。
- Windows 启动脚本已加入 Visual Studio 开发环境和 `Path/PATH` 重复变量处理。

## 3. 当前验证结果

2026-08-08 在当前工作区重新执行：

| 检查项 | 结果 |
| --- | --- |
| `flutter analyze` | 通过，`No issues found` |
| `flutter test` | 通过，共 36 个测试 |
| Android debug APK | 以前构建通过；当前 `build` 目录内没有现成 APK，需要重新构建 |
| Android release AAB | 未生成 |
| Windows EXE | 未生成，Windows 原生构建仍未验证通过 |
| iOS 构建 | 当前 Windows 电脑无法完成，需要 macOS 和 Xcode |

测试时需要保留网络代理供 SQLite 原生库下载，同时把 `127.0.0.1,localhost` 加入 `NO_PROXY`，否则测试服务或依赖下载可能失败。这属于本机工具环境问题，不是业务代码错误。

## 4. 已写代码但尚不能直接使用的部分

### 4.1 FCM 推送

代码依赖和设备 Token 注册逻辑已经存在，但以下真实文件不存在：

- `android/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

因此目前不能确认 Android FCM 或 iOS APNs 能收到真实远程推送。

### 4.2 华为 HMS 推送

`huawei_push` 依赖和 HMS Token 来源代码已经存在，但真实的 `android/agconnect-services.json` 不存在，也没有华为真机验收记录。

### 4.3 Windows 桌面版

Windows Runner 已生成，但当前没有生成 `focus_flow.exe`。最近的构建问题集中在 Visual Studio/CMake/Windows SDK 链接环境，而不是 Flutter 页面代码。已经增加的修正包括：

- 关闭可能触发权限错误的 MSBuild FileTracker。
- 固定 Windows SDK 版本为 `10.0.26100.0`。
- 启动脚本调用 Visual Studio 开发环境。
- 清理同时存在的 `Path` 和 `PATH` 环境变量。

仍需要重新执行 Windows 构建并以实际 EXE 作为完成证据。

## 5. 尚未完成的发布项

- 没有 `android/key.properties`。
- 没有正式 Android keystore。
- 没有签名 AAB。
- 没有 Firebase Android/iOS 正式配置文件。
- 没有 AppGallery Connect HMS 正式配置文件。
- 没有 iOS Development/Distribution 证书和 Provisioning Profile 验证。
- 没有 Android 手机、Android 平板、iPhone、iPad、无 GMS 华为手机的完整验收记录。
- 没有应用商店隐私政策、截图、描述、分级和上架审核记录。

## 6. 当前主要问题与根因

### Android 模拟器一直显示 `offline`

本地 AVD 启动不稳定，ADB 无法与模拟器保持正常连接。反复执行 `adb kill-server/start-server` 只能重启 ADB，不能修复未正常启动的模拟器系统。当前更可靠的验证方式是连接一台开启 USB 调试的 Android 真机，或者后续重新建立可正常启动的 AVD。

### Windows 构建找不到原生工具或 SDK 库

Visual Studio C++ 工作负载和 Windows SDK 已安装，但 Flutter、CMake、MSBuild 继承到的环境变量不一致，曾出现 `CMAKE_CXX_COMPILER`、`ucrtd.lib`、FileTracker 权限和重复 `Path/PATH` 问题。项目脚本已经处理其中一部分，但还没有成功生成 Windows EXE，所以该问题仍处于“修复中”。

## 7. 下一步执行顺序

1. 先修复并验证 Windows 构建，生成可启动的 `focus_flow.exe`，证明桌面调试链路正常。
2. 重新构建 Android debug APK，优先连接 Android 真机测试，不继续在不稳定的离线模拟器上消耗时间。
3. 用真实 Supabase 测试账号验证注册、登录、退出、会话恢复和任务/笔记同步。
4. 部署 `github-digest` 和 `daily-digest` Edge Functions，配置 GitHub Token 并确认能返回真实数据。
5. 在 Firebase 创建 `com.focusflow.planner` 应用，放入真实配置文件并验证 FCM。
6. 在 AppGallery Connect 创建相同包名应用，配置 Push Kit 并用无 GMS 华为真机验证 HMS。
7. 在 macOS/Xcode 上完成 iPhone/iPad、APNs、横竖屏和 Split View 验收。
8. 创建并安全备份 Android keystore，生成签名 AAB，最后进行商店发布前测试。

## 8. 完成标准

只有以下条件全部满足，项目才能标记为正式完成：

- Android 手机和平板核心流程通过。
- iPhone 和 iPad 核心流程通过。
- 本地通知、FCM、APNs、HMS 都有真实设备测试证据。
- Supabase 登录、同步、离线恢复和双设备冲突通过。
- GitHub AI 摘要每日自动抓取和推送通过。
- 正式 Android AAB 和 iOS Archive 使用生产证书签名。
- 隐私政策、数据删除、数据导出、商店资料和发布检查完成。

