# WeChat Open Platform submission sheet

This sheet contains the stable, non-secret values for the Focus Flow Android
mobile-app registration. Confirm the live values one final time before review.

## Basic information

| Field | Value |
| --- | --- |
| Mobile app name | `Focus Flow` |
| English name | `Focus Flow` |
| Chinese introduction | `面向学生的时间管理与科技资讯应用，支持课程计划、任务提醒和资讯聚合。` |
| English introduction | `Student planner with reminders and GitHub, AI, tech, and Linux news.` |
| Official website | `https://connor168.github.io/spare-time/` |
| 28 px icon | `assets/branding/focus-flow-wechat-28.png` |
| 108 px icon | `assets/branding/focus-flow-wechat-108.png` |

## Remaining application-form fields

| Field | Recommended value |
| --- | --- |
| High-definition application image | `assets/branding/focus-flow-wechat-108.png` |
| App-market status | `未上架任何应用市场` |
| Application category | Prefer `工具 → 效率` |
| Application operation flow | Upload both PNG files under `assets/wechat-review/` |
| Application/change explanation | `Focus Flow 是面向学生的 Android 时间管理与科技资讯应用，现申请创建移动应用并接入微信登录。当前为个人测试版，暂未上架应用市场；官网、隐私政策和测试 APK 已公开。审核通过后，微信登录将用于账号关联和多设备同步。` |

The category list can vary by verified-account type and is only authoritative in
the signed-in Open Platform console. If `工具 → 效率` is unavailable, prefer
`工具 → 日历`, then `工具 → 备忘录` or `工具 → 办公`. Do not choose online
education: Focus Flow manages study time but does not deliver teaching content.
Do not use news as the primary category because news aggregation is a supporting
feature and may trigger unrelated qualification requirements.

The explanation above is below the 200-character form limit. Because this is a
public personal preview and no review-only login is required to open the core
local features, do not place a password in the form. If the reviewer later asks
for an account, create a dedicated non-personal test account and add only that
account's credentials.

### Review image upload order

1. Upload `assets/branding/focus-flow-wechat-108.png` for the required 108 x 108
   high-definition application image.
2. Upload `assets/wechat-review/focus-flow-app-operation-flow.png` as the first
   operation-flow image.
3. Upload `assets/wechat-review/focus-flow-wechat-login-flow.png` as the second
   image. It is explicitly labelled as an integration that will be enabled after
   approval.

Do not submit the website field until the public URL opens successfully without
a login wall. Replace the generic developer label and GitHub Issues contact if
the platform requires the verified developer's legal name and a direct email.

## Android identity

| Field | Value |
| --- | --- |
| Application ID / package | `com.focusflow.planner` |
| Release key alias | `focus-flow-upload` |
| Certificate MD5 / WeChat app signature | `8d79f05abd5d17e83b2a903aa4292e3b` |
| Certificate SHA-1 | `82:79:61:9A:9E:31:C7:1D:B5:61:72:AB:4E:03:BD:DF:69:E0:36:54` |
| Certificate SHA-256 | `6C:98:DB:9B:60:8C:26:20:CA:4F:99:A2:9C:FD:DF:8E:45:DC:5E:93:82:41:77:09:91:33:75:05:46:CA:BE:2C` |
| Certificate validity | 2026-08-09 through 2053-12-25 |

The WeChat value is the lower-case MD5 fingerprint with colons removed. Before
submitting, install the signed release APK on an Android phone and confirm the
same value with WeChat's official signature-generation tool. Never use the
debug certificate or a debug APK.

## Private files and backup

The following files are intentionally ignored by Git and must never be uploaded
to the repository, website, chat, or an app-store form:

- `android/focus-flow-upload.jks`
- `android/key.properties`

Keep at least two encrypted backups of the JKS file and store its password in a
password manager. Losing this key can prevent future updates and break social
login identity matching.

## Review checklist

- The release APK reports package `com.focusflow.planner`.
- The installed release APK reports signature MD5
  `8d79f05abd5d17e83b2a903aa4292e3b`.
- The APK, website, WeChat form, QQ form, and future store listing use the same
  Focus Flow name and icon.
- The website, privacy policy, user agreement, and download link open publicly.
- Screenshots are taken from the actual Android build, not only from a design
  mockup or desktop build.
- The WeChat AppSecret stays on the server; only the public AppID enters Android
  client configuration.

Official references:

- Android OpenSDK access guide: <https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/Android.html>
- WeChat Login development guide: <https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Login/Development_Guide.html>
- Android resources and signature tool: <https://developers.weixin.qq.com/doc/oplatform/Downloads/Android_Resource.html>
