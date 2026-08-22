# Focus Flow 阿里云部署步骤

本方案使用：阿里云 ECS 运行 Docker API 和 Caddy HTTPS，阿里云 RDS PostgreSQL
保存数据。生产环境不使用 Supabase。

## 部署前准备

准备以下内容：

1. 一个可管理 DNS 的域名，例如 `example.com`。
2. 阿里云账号及已开通的 ECS、RDS 权限。
3. 本地 GitHub 仓库已经推送最新提交。
4. 微信审核尚未通过时，先不要填写 `WECHAT_APP_SECRET`；邮件登录和同步可以先部署。

如果 ECS 位于中国内地并通过域名对外提供 HTTP/HTTPS 服务，通常需要完成相应的
备案要求。请在购买实例前确认该地域和域名的当前要求。

## 第 1 步：创建 ECS

在阿里云控制台创建 ECS：

1. 地域选择离用户和 RDS 都近的同一个地域。
2. 镜像选择 Ubuntu 24.04 LTS。
3. 建议从 2 vCPU、4 GB 内存起步；API、Caddy 和 Docker 都运行在这台机器上。
4. 分配固定公网 IPv4 地址。
5. 创建 SSH 密钥对，或设置一个强密码。
6. 安全组只放行：
   - TCP `22`：仅你的家庭/办公公网 IP，用于 SSH。
   - TCP `80`：所有来源，用于 HTTPS 证书校验和 HTTP 跳转。
   - TCP `443`：所有来源，用于 API HTTPS。
7. 不要放行 `5432`，也不要放行 `8080`。

记录 ECS 的私网 IP 和公网 IP。

## 第 2 步：创建 PostgreSQL RDS

在同一地域创建 RDS PostgreSQL：

1. 网络选择与 ECS 相同的 VPC；优先使用 PostgreSQL 16。
2. 创建数据库：`focusflow`。
3. 创建专用账号：`focusflow`，设置新的强密码。
4. 在 RDS 的 IP 白名单或安全组关联中，仅加入 ECS 的私网 IP/安全组。
5. 使用 RDS 私网连接地址，不要创建或使用数据库公网地址。
6. 在 RDS 的 SSL/TLS 配置中启用 SSL，并下载 CA 证书链。

数据库密码不能发到聊天中。如果密码含有 `@`、`:`、`/`、`#`、`?` 等字符，后面写入
`DATABASE_URL` 时需要 URL 编码。

## 第 3 步：设置 API 域名

在域名 DNS 管理里新建 A 记录：

```text
主机记录：api
记录类型：A
记录值：ECS 公网 IP
```

例如域名是 `example.com`，最终 API 地址应为：

```text
https://api.example.com
```

等待 DNS 生效后再启动 Caddy；Caddy 会自动申请 HTTPS 证书。

## 第 4 步：登录 ECS 并安装 Docker

在本机 PowerShell 登录服务器：

```powershell
ssh ubuntu@ECS公网IP
```

在 ECS 的 Ubuntu 24.04 终端执行：

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git openssl
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
exit
```

重新 SSH 登录后确认：

```bash
docker version
docker compose version
```

## 第 5 步：下载项目和 RDS CA 证书

在 ECS 执行：

```bash
sudo mkdir -p /opt/focus-flow
sudo chown $USER:$USER /opt/focus-flow
git clone https://github.com/connor168/spare-time.git /opt/focus-flow/spare-time
cd /opt/focus-flow/spare-time/backend
mkdir -p secrets
chmod 700 secrets
```

把从 RDS 下载的 CA 证书保存为：

```text
/opt/focus-flow/spare-time/backend/secrets/rds-ca.pem
```

然后在 ECS 执行：

```bash
chmod 600 secrets/rds-ca.pem
```

可以通过 ECS Workbench 上传文件，或从本机执行：

```powershell
scp 本地CA证书路径 ubuntu@ECS公网IP:/opt/focus-flow/spare-time/backend/secrets/rds-ca.pem
```

## 第 6 步：创建生产环境变量

在 ECS 的 `backend` 目录创建 `.env`：

```bash
nano .env
```

填写以下内容并替换大写占位符：

```dotenv
NODE_ENV=production
PORT=8080
DATABASE_URL=postgres://focusflow:URL编码后的数据库密码@RDS私网地址:5432/focusflow
DATABASE_SSL_CA_FILE=/run/secrets/rds-ca.pem
JWT_SECRET=新生成的64位十六进制随机字符串
JWT_ISSUER=focus-flow-api
ACCESS_TOKEN_TTL_SECONDS=900
WECHAT_APP_ID=
WECHAT_APP_SECRET=
API_DOMAIN=api.你的域名
GITHUB_API_TOKEN=可选的GitHub令牌
NEWS_CRON_SECRET=新生成的定时任务密钥
FCM_PROJECT_ID=Firebase项目ID
FCM_CLIENT_EMAIL=Firebase服务账号邮箱
FCM_PRIVATE_KEY=Firebase服务账号私钥（换行用\\n）
```

生成 JWT 密钥：

```bash
openssl rand -hex 32
```

保存后限制权限：

```bash
chmod 600 .env
```

ECS 的 crontab 需要先设置 `CRON_TZ=Asia/Shanghai`，再加入每日 07:00 的刷新命令，避免
服务器默认使用 UTC 导致推送时间偏移。

## 第 7 步：构建、迁移、启动

仍在 ECS 的 `backend` 目录执行：

```bash
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml run --rm api npm run migrate
docker compose -f docker-compose.production.yml up -d
docker compose -f docker-compose.production.yml ps
```

第二条命令会依次执行 SQL 迁移。迁移有数据库锁和记录表，可以在后续版本重复运行。

查看日志：

```bash
docker compose -f docker-compose.production.yml logs --tail=100 api caddy
```

验证 HTTPS：

```bash
curl --fail https://api.你的域名/health
```

成功时返回：

```json
{"status":"ok"}
```

如果 Caddy 证书申请失败，首先检查 DNS A 记录是否已生效，以及 ECS 安全组的 80 和
443 是否开放。

## 第 8 步：让 Flutter 使用自有后端

在本机项目根目录构建测试 APK 时加入：

```powershell
flutter build apk --debug --dart-define=FOCUS_FLOW_API_URL=https://api.你的域名
```

先验证邮箱登录、刷新 Token、登出、账号导出、账号删除和双设备同步。全部通过后，再
填写服务器端微信 AppSecret 并进行微信真机登录测试。

## 后续更新

每次发布新代码，在 ECS 执行：

```bash
cd /opt/focus-flow/spare-time
git pull --ff-only
cd backend
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml run --rm api npm run migrate
docker compose -f docker-compose.production.yml up -d
```

同时在 RDS 控制台开启自动备份，并定期在非生产实例上验证备份恢复。
