# Focus Flow 明日执行手册

这份手册按依赖顺序执行。不要在包名、签名和 Firebase/HMS 配置未确定前生成正式包，因为这些配置都绑定应用包名。

## 今日准备

明天开始前准备好：

- 一个永久 Android/iOS 包名，例如 `com.yourcompany.focusflow`。
- Supabase 项目权限。
- Firebase 项目权限。
- Huawei AppGallery Connect 权限。
- Android keystore 密码。
- 一台 Android 手机、一台 iPhone/iPad、一台无 GMS 华为手机。
- macOS/Xcode 环境，用于 iOS 签名。

应用当前仍使用占位包名：

- Android/iOS：`com.focusflow.planner`

## 1. 备份和检查环境

在 PowerShell 中执行：

```powershell
cd E:\AICoding\spare_time
$env:APPDATA = "$PWD\.tools\appdata"
$env:LOCALAPPDATA = "$PWD\.tools\localappdata"
$env:PUB_CACHE = "$PWD\.tools\pub-cache"
$env:JAVA_HOME = "$PWD\.tools\jdk-17"
$env:GRADLE_USER_HOME = "$PWD\.tools\gradle"

Copy-Item -Recurse -Force . "E:\AICoding\spare_time_backup_$(Get-Date -Format yyyyMMdd_HHmmss)"
\.tools\flutter\bin\flutter.bat analyze
\.tools\flutter\bin\flutter.bat test
```

检查点：`flutter analyze` 无问题，全部测试通过。若失败，先停止，不要继续配置发布证书。

## 2. 修改永久包名

把第 1 步确定的包名写入：

- `android/app/build.gradle.kts`：`namespace`、`applicationId`
- `android/app/src/main/kotlin/.../MainActivity.kt`：包声明
- Android Kotlin 文件目录：与新包名一致
- `ios/Runner.xcodeproj/project.pbxproj`：`PRODUCT_BUNDLE_IDENTIFIER`

包名修改后执行：

```powershell
\.tools\flutter\bin\flutter.bat clean
\.tools\flutter\bin\flutter.bat pub get --offline
\.tools\flutter\bin\flutter.bat analyze
\.tools\flutter\bin\flutter.bat test
```

检查点：包名只能在正式发布前修改一次。之后 Firebase、HMS、Apple 配置都必须使用这个包名。

## 3. 配置 Supabase

在 Supabase 控制台完成：

1. 创建项目。
2. 按顺序执行 `supabase/migrations/0001_core.sql` 和 `0002_release_hardening.sql`。
3. 创建或确认 Auth 邮箱登录功能。
4. 保存项目 URL 和 anon key。
5. 给 Edge Functions 配置以下 secrets：

```text
GITHUB_TOKEN
SUPABASE_SERVICE_ROLE_KEY
CRON_SECRET
PUSH_GATEWAY_URL
PUSH_GATEWAY_TOKEN
```

部署函数时使用 Supabase CLI 或控制台：

```powershell
supabase functions deploy github-digest
supabase functions deploy daily-digest
```

本地运行 App：

```powershell
\.tools\flutter\bin\flutter.bat run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY `
  --dart-define=GITHUB_DIGEST_URL=https://YOUR_PROJECT.supabase.co/functions/v1/github-digest
```

检查点：打开“账号”页面，注册测试账号、退出、重新启动 App，确认会话可以恢复。

## 4. 配置 Firebase FCM

在 Firebase 控制台创建与永久 Android 包名完全一致的 App。

下载 `google-services.json`，放到：

```text
android/google-services.json
```

不要提交真实文件。仓库中只有 `android/google-services.json.example`。

在 Firebase 控制台启用 Cloud Messaging。然后执行：

```powershell
\.tools\flutter\bin\flutter.bat pub get --offline
\.tools\flutter\bin\flutter.bat build apk --debug
```

检查点：登录后进入账号页面，点击“同步”，Supabase 的 `device_tokens` 表中出现 Android FCM token。

## 5. 配置 Huawei HMS

在 AppGallery Connect：

1. 创建与永久包名一致的应用。
2. 开启 Push Kit。
3. 配置签名证书指纹。
4. 下载 `agconnect-services.json`。

将文件放到：

```text
android/agconnect-services.json
```

确认 `huawei_push` 依赖已安装：

```powershell
\.tools\flutter\bin\flutter.bat pub get --offline
\.tools\flutter\bin\flutter.bat analyze
```

检查点：在无 GMS 华为手机上安装包，登录后确认 `device_tokens.provider` 为 `hms`。

## 6. 创建 Android 正式签名

不要使用测试密码，也不要把 keystore 发到聊天或提交到 Git。

在项目根目录运行：

```powershell
\.\scripts\create_android_keystore.ps1
```

脚本会生成：

```text
android/focus-flow-upload.jks
android/key.properties
```

把 keystore 复制到安全备份位置。丢失 keystore 后，应用更新会受影响。

生成 AAB：

```powershell
\.\scripts\build_release.ps1 -Format appbundle
```

验证签名：

```powershell
& ".\.tools\jdk-17\bin\jarsigner.exe" -verify -verbose -certs `
  build/app/outputs/bundle/release/app-release.aab
```

检查点：输出包含 `jar verified`，AAB 位于 `build/app/outputs/bundle/release/`。

## 7. Android 模拟器和真机验收

启动项目已经创建的 AVD：

```powershell
$env:ANDROID_SDK_ROOT = "$PWD\.tools\android-sdk"
$env:ANDROID_AVD_HOME = "$PWD\.tools\avd"
& "$env:ANDROID_SDK_ROOT\emulator\emulator.exe" `
  -avd FocusFlow_API35 `
  -gpu swiftshader_indirect
```

另开终端检查：

```powershell
& ".\.tools\android-sdk\platform-tools\adb.exe" devices
```

状态必须是 `device`，不能是 `offline`。

安装 debug APK：

```powershell
& ".\.tools\android-sdk\platform-tools\adb.exe" install -r `
  build/app/outputs/flutter-apk/app-debug.apk
```

逐项验收：

- 创建任务并设置提醒。
- 锁屏等待提醒。
- 杀进程后重启，确认任务和笔记仍在。
- 拒绝通知权限，确认页面有恢复入口。
- 登录、退出、重新登录。
- 两个设备分别编辑同一笔记，确认同步结果和冲突数量。
- 手机竖屏、横屏和平板分屏均无溢出。

## 8. iOS 真机验收

必须在 macOS/Xcode 执行：

1. 将 `ios/Runner/GoogleService-Info.plist` 加入 Xcode Runner target。
2. 开启 Push Notifications capability。
3. 开启 Background Modes 的 Remote notifications。
4. 选择 Apple Team 和正式 Bundle Identifier。
5. 配置 APNs Auth Key 到 Firebase。
6. 执行 `pod install`。
7. 连接 iPhone/iPad，运行 Release 配置。

重点测试：通知授权、APNs token 注册、后台推送、点击通知深链、iPad Split View、横竖屏。

## 9. 发布前检查

确认以下条件全部满足后再上传商店：

- Android AAB 使用正式 keystore 签名。
- Firebase、Supabase、HMS secrets 不在仓库中。
- Android、iOS、HMS 三个平台包名一致。
- Android 普通手机和平板测试通过。
- iPhone/iPad APNs 测试通过。
- 无 GMS 华为手机 HMS 测试通过。
- 隐私政策、账号删除、数据导出说明已准备。
- 应用崩溃、同步失败、推送失败都有日志记录。

## 10. 提交代码

当前 Codex 环境无法写入上级 `E:\AICoding\.git`。在有 Git 权限的终端执行：

```powershell
cd E:\AICoding
git add spare_time
git commit -m "Complete auth sync push and release setup"
git push
```

完成当天工作后，把以下结果记录下来：

```text
永久包名：
Supabase 项目：
Firebase Android：通过/失败
HMS 华为设备：通过/失败
iOS 真机：通过/失败
Android AAB：路径和签名结果
未解决问题：
```
