# 发布与每日摘要推送

## Android 正式签名

1. 在安全位置创建上传密钥，不要把 `.jks` 或 `android/key.properties` 提交到 Git。
2. 可运行 `scripts/create_android_keystore.ps1`，脚本会安全地提示密码并生成 keystore 与 `android/key.properties`；也可以手工复制 `android/key.properties.example`。
3. 执行 `scripts/build_release.ps1 -Format appbundle` 生成 Play 商店使用的 AAB；需要 APK 时传 `-Format apk`。

没有 `key.properties` 时，发布构建会主动失败，避免误发 debug 签名包。

## 每日摘要推送

GitHub digest Edge Function 每日运行后，应由服务端按 `user_preferences.digest_time` 和 `timezone_id` 选择用户，读取 `device_tokens`，通过 FCM/APNs/HMS 对每个 token 发送幂等消息。客户端只负责注册 token、处理点击深链和提供免打扰设置，推送服务密钥不能进入 APK。

当前仓库已完成 digest API 客户端、设备 token/偏好数据表、通知权限请求和 payload 约定。尚未完成且无法在 Windows 无账号环境验证：真实 FCM/APNs/HMS 凭据、iOS 真机后台投递、华为 HMS 通道和商店审核。

## Supabase 配置

客户端通过 `SupabaseRestClient` 调用 Auth 和 notes upsert；生产环境从安全配置注入 Supabase URL/anon key。`SUPABASE_SERVICE_ROLE_KEY`、`GITHUB_TOKEN`、FCM/APNs/HMS 密钥只配置在 Edge Function secrets 中。

## Firebase / APNs / HMS

- Android Firebase：在 Firebase 控制台创建永久包名对应的 Android App，下载真实 `google-services.json` 到 `android/app/`。本工程会在该文件存在时自动应用 Google Services Gradle 插件，然后再构建并验收 Cloud Messaging；占位 example 文件不能用于推送。
- iOS APNs：在 macOS/Xcode 中把 `GoogleService-Info.plist` 加入 `ios/Runner`，开启 Push Notifications 和 Background Modes/Remote notifications，配置 Apple Team 与 APNs Key。示例文件仅用于说明字段，不能直接使用。
- 华为 HMS：在 AppGallery Connect 创建同一永久包名的应用，下载 `agconnect-services.json` 到 `android/`，配置 Push Kit 服务和签名证书；代码中的 `HuaweiDeviceTokenSource` 只有在 HMS 原生配置存在时才会返回 Token。

运行时构建参数示例：

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key `
  --dart-define=GITHUB_DIGEST_URL=https://your-project.supabase.co/functions/v1/github-digest
```

不要把真实 JSON、私钥或服务端 Token 提交到 Git；仓库中的 `.example` 文件只提供结构参考。
