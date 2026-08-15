# Focus Flow Android identity and social login setup

## Permanent application identity

- App name: `Focus Flow`
- Android application ID: `com.focusflow.planner`
- Treat the application ID as permanent. WeChat, QQ, Firebase, signing, and any
  future store listing must all use the same value.

Do not register the social-login applications until this identifier is final.

## Development and production signing

Android debug builds use the automatically generated debug key. Social-login
platforms normally bind an Android application to its package name and signing
certificate, so a debug registration is only suitable for local testing.

Before production testing:

1. Create one upload keystore with `scripts/create_android_keystore.ps1`.
2. Use a unique password and store it in a password manager. Never paste it into
   chat, commit it, or upload the keystore to a public drive.
3. Keep at least two encrypted backups of the keystore and record the alias.
4. Obtain the certificate fingerprints with `keytool -list -v` and use the
   production package name and production signature when registering WeChat,
   QQ, Firebase, and the app store.
5. Keep `android/key.properties` and the `.jks` file out of Git.

Changing the signing key or application ID later can break social-login
callbacks and prevent application updates.

## WeChat login: user-owned setup

1. Register and complete the current developer verification required by the
   WeChat Open Platform: <https://open.weixin.qq.com/>.
2. Create a mobile application named Focus Flow.
3. Enter `com.focusflow.planner` and the production Android application
   signature requested by the platform.
4. Apply for the mobile WeChat Login capability and wait for approval.
5. Save the issued AppID and AppSecret in a private password manager.
6. Give the project only the AppID through local or deployment configuration.
   Configure the AppSecret as a server-side Supabase secret; never put it in
   Dart code, Android resources, the APK, Git, screenshots, or chat.

The mobile client requests an authorization code through the WeChat SDK. A
server-side endpoint exchanges that one-time code for the WeChat identity and
then creates or links the Focus Flow account. The AppSecret must not participate
in a client-side exchange.

## QQ login: user-owned setup

1. Register and complete the current developer verification required by QQ
   Connect: <https://connect.qq.com/>.
2. Create an Android mobile application named Focus Flow.
3. Enter `com.focusflow.planner` and the production signing information required
   by the platform.
4. Apply for QQ Login, add the personal QQ account as a tester if the console
   offers a test-account list, and wait for approval.
5. Store the issued AppID and AppKey privately.
6. Expose only the public AppID to the Android client. Keep AppKey and any
   account-linking secret in Supabase Edge Function secrets.

The Android client obtains the QQ authorization result through the official SDK.
The backend verifies it and creates or links the same Focus Flow cloud account
used for synchronization.

## Information needed from the user later

- Confirmation that both mobile applications passed platform review.
- WeChat AppID (public configuration only).
- QQ AppID (public configuration only).
- The production certificate fingerprints/signature values shown by the
  platform consoles.
- Confirmation that the package name shown in both consoles is exactly
  `com.focusflow.planner`.

Secrets stay in the user's platform consoles or deployment secret store. They
must not be committed to this repository.
