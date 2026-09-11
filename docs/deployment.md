# 服务端部署与运维

Kairos 服务端是 Go HTTP/WebSocket 程序，依赖 PostgreSQL 和 Redis。服务启动、迁移和账号引导都通过同一个环境文件完成；环境文件不进入二进制、不提交 Git，也不放在仓库目录。

## 配置

复制 `server/.env.example` 到受限目录，例如 `D:\secure\kairos.env` 或 `/etc/kairos/kairos.env`。生产环境必须设置数据库 URL、长度不少于 32 个字符的 `KAIROS_SESSION_SECRET`，并建议设置 `KAIROS_REDIS_REQUIRED=true`。

```dotenv
KAIROS_ENV=production
KAIROS_HTTP_ADDR=127.0.0.1:8080
KAIROS_DATABASE_URL=postgres://kairos:URI编码后的密码@127.0.0.1:5432/kairos?sslmode=disable
KAIROS_REDIS_URL=redis://127.0.0.1:6379/0
KAIROS_REDIS_REQUIRED=true
KAIROS_REDIS_DIAL_TIMEOUT=500ms
KAIROS_REDIS_COMMAND_TIMEOUT=500ms
KAIROS_BASE_URL=https://kairos.example.com
KAIROS_SESSION_SECRET=至少32个字符的随机值
KAIROS_ACCESS_TTL=15m
KAIROS_REFRESH_TTL=720h
KAIROS_LOG_LEVEL=info
KAIROS_CORS_ORIGINS=
KAIROS_MIGRATIONS_DIR=/opt/kairos/migrations
KAIROS_BOOTSTRAP_USERNAME=owner
KAIROS_BOOTSTRAP_PASSWORD=首次引导使用的强密码
```

`KAIROS_BOOTSTRAP_PASSWORD` 只由 `create-user` 和 `bootstrap-super-admin` 使用。引导完成后立即删除该变量。数据库 URL 和 Redis URL 中的特殊字符必须进行 URI 编码。

## 本地依赖

```powershell
docker compose -f deploy/docker-compose.postgres.yml up -d
```

Compose 仅监听回环地址，包含 PostgreSQL 18 和 Redis 8。生产环境可以使用已有服务，但必须保证数据库和 Redis 只对 Kairos 服务开放。

## 源码运行

```powershell
cd server
go run .\cmd\kairos-server --env-file D:\secure\kairos.env migrate
go run .\cmd\kairos-server --env-file D:\secure\kairos.env create-user
go run .\cmd\kairos-server --env-file D:\secure\kairos.env bootstrap-super-admin owner
go run .\cmd\kairos-server --env-file D:\secure\kairos.env serve
```

`migrate` 应在首次部署和版本升级时执行；`create-user` 创建真实账号；`bootstrap-super-admin` 只在数据库尚无 L3 时将已有账号设为首个 L3；`serve` 启动服务；`version` 打印服务版本。

## 二进制部署

### Ubuntu 一键构建与系统更新

在仓库根目录运行：

```bash
bash ./build-ubuntu.sh
```

脚本会根据当前 Ubuntu 主机自动选择 `linux/amd64` 或 `linux/arm64`，并把所有可保留的构建输入与产物统一放在仓库上级的 `kairos-build`：

```text
<仓库上级>/kairos-build/
├── kairos.env
├── SHA256SUMS
├── cli/kairos
└── server/
    ├── kairos-server
    └── migrations/*.sql
```

首次运行且系统尚未安装 Kairos 时，脚本会从 `server/.env.example` 创建权限为 `0600` 的 `kairos.env`，自动生成会话密钥并设置生产环境和迁移目录。由于数据库地址无法安全猜测，脚本会要求编辑其中的 `KAIROS_DATABASE_URL` 后重新运行。已有系统安装但尚无构建目录时，脚本会自动把 `/etc/kairos/kairos.env` 复制到上述位置作为后续更新的配置来源。

配置有效后，一次运行会依次完成：

1. 运行 server 和 CLI 的 Go 测试；
2. 使用 `CGO_ENABLED=0` 构建两个 Linux 二进制并生成 SHA-256；
3. 首次安装时创建 `kairos` 系统用户、迁移数据库并注册 systemd 服务；
4. 已安装时备份 server 二进制和环境文件，迁移后重启服务，失败则回滚；
5. 把 CLI 安装为 `/usr/local/bin/kairos`，并确认 `kairos-server.service` 正常运行。

只生成构建目录、不修改系统：

```bash
bash ./build-ubuntu.sh --build-only
```

紧急构建时可以显式跳过测试：

```bash
bash ./build-ubuntu.sh --skip-tests
```

脚本需要 Go、`sudo` 和 systemd；构建过程本身不要求 root，只有安装或更新系统文件时才调用 `sudo`。`kairos-build/kairos.env` 含有生产凭据，不应复制到仓库、提交 Git 或放宽文件权限。

### 手动构建与部署

```powershell
cd server
go build -trimpath -ldflags='-s -w' -o kairos-server.exe .\cmd\kairos-server
```

Linux amd64：

```bash
cd server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o kairos-server ./cmd/kairos-server
```

Linux 推荐使用安装脚本：

```bash
sudo deploy/install.sh \
  --binary ./server/kairos-server \
  --env-file /etc/kairos/kairos.env \
  --migrations ./server/migrations
```

脚本安装到 `/opt/kairos`，创建受限的 `kairos` 用户和 systemd 服务，并在启动前执行迁移。升级时：

```bash
sudo deploy/update.sh --binary ./kairos-server \
  --migrations ./server/migrations \
  --sha256 '<expected-sha256>'
```

升级脚本会保存旧二进制，迁移失败或服务无法启动时恢复旧二进制。升级前仍必须做 PostgreSQL 备份。

## 反向代理和网络

公网只暴露 Nginx/负载均衡的 443，Kairos、PostgreSQL 和 Redis 绑定回环地址或内网地址。可以从 `deploy/nginx-kairos.conf.example` 开始配置，并保留 `Upgrade`、`Connection`、`Host`、`X-Forwarded-*` 和 `X-Request-ID` 请求头。

客户端公网连接必须是 HTTPS/WSS。局域网 HTTP/WS 只用于开发，并应在客户端设置页面明确显示未加密警告。

## 健康检查

```text
GET /healthz  进程和 Redis 状态；Redis 断开时 status=degraded
GET /readyz   PostgreSQL、迁移和必需的 Redis
GET /version  服务版本、API 版本和迁移版本
```

负载均衡使用 `/readyz`，不要使用 `/healthz` 作为接收流量的唯一条件。

## 备份、卸载与排障

```bash
pg_dump --format=custom --no-owner --dbname=kairos --file=/secure/backup/kairos.dump
pg_restore --list /secure/backup/kairos.dump
```

普通卸载保留 `/etc/kairos`、`/var/lib/kairos` 和迁移；确认不再需要数据时才执行：

```bash
sudo deploy/uninstall.sh --purge-data
```

systemd 日志：

```bash
systemctl status kairos-server --no-pager
journalctl -u kairos-server --since today
```

日志、备份和故障报告不得包含密码、access/refresh token、原始邀请码或任务正文。
