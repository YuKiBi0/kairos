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
