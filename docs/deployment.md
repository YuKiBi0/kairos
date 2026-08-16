# 服务端部署与运维

## 本地开发

1. 创建 PostgreSQL 数据库。
2. 复制 `server/.env.example` 为仓库外的本地配置文件，并填入数据库 URL 与至少 32 字符的随机会话密钥。
3. 在 `server/` 目录执行迁移并创建单用户账号。

```bash
set -a
source /secure/path/kairos.env
set +a
go run ./cmd/kairos-server migrate
KAIROS_BOOTSTRAP_PASSWORD='choose-a-password' go run ./cmd/kairos-server create-user owner
go run ./cmd/kairos-server serve
```

账号密码只通过当前进程环境传入，不写回配置文件。检查：

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/readyz
curl http://127.0.0.1:8080/version
```

`/healthz` 只检查进程，`/readyz` 同时检查 PostgreSQL 和 schema metadata。

## PostgreSQL Compose

`deploy/docker-compose.postgres.yml` 只管理 PostgreSQL，不管理 Kairos、域名或 TLS。密码在 shell 或仓库外的 Compose env 文件中提供：

```bash
POSTGRES_PASSWORD='choose-a-password' docker compose \
  -f deploy/docker-compose.postgres.yml up -d
```

## Linux 安装

先在可信构建机生成 Linux 二进制：

```bash
cd server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath \
  -ldflags='-s -w' -o kairos-server ./cmd/kairos-server
```

准备 shell-compatible 的环境文件，敏感值用引号包裹且权限设为 0600。然后以 root 执行：

```bash
sudo deploy/install.sh \
  --binary ./server/kairos-server \
  --env-file /secure/path/kairos.env \
  --migrations ./server/migrations
```

脚本创建受限的 `kairos` 系统用户，安装 systemd unit，执行迁移并启用开机自启。最终配置位于 `/etc/kairos/kairos.env`，权限为 `root:kairos 0640`。

首次安装后创建唯一账号，密码通过隐藏输入进入临时环境变量：

```bash
read -rsp 'Kairos account password: ' KAIROS_BOOTSTRAP_PASSWORD && echo
export KAIROS_BOOTSTRAP_PASSWORD
sudo --preserve-env=KAIROS_BOOTSTRAP_PASSWORD bash -c '
  set -a
  source /etc/kairos/kairos.env
  set +a
  cd /opt/kairos
  runuser -u kairos --preserve-environment -- bin/kairos-server create-user owner
'
unset KAIROS_BOOTSTRAP_PASSWORD
```

## 更新与卸载

```bash
sudo deploy/update.sh --binary ./kairos-server \
  --migrations ./server/migrations --sha256 '<expected-sha256>'

sudo deploy/uninstall.sh
sudo deploy/uninstall.sh --purge-data
```

更新脚本保留上一版二进制并在启动失败时恢复。数据库迁移不会自动回滚，发布迁移必须保持向后兼容。普通卸载保留 `/etc/kairos`、`/var/lib/kairos` 和迁移；`--purge-data` 会永久删除这些目录。

## Nginx 与 WSS

复制并修改 `deploy/nginx-kairos.conf.example`，自行配置域名和证书。反向代理必须保留 `Upgrade`、`Connection`、`Host`、`X-Forwarded-*` 和 `X-Request-ID` 请求头。项目不会修改 DNS、证书、防火墙或现有 Nginx。

生产环境仅开放 Nginx 的 443；Go 服务和 PostgreSQL 绑定回环地址。客户端服务地址填写 `https://kairos.example.com`，WebSocket 会自动使用 `wss://kairos.example.com/api/v1/realtime`。

## 备份与恢复

备份在迁移或更新之前执行，输出文件放在受限目录：

```bash
pg_dump --format=custom --no-owner --file=/secure/backup/kairos.dump "$KAIROS_DATABASE_URL"
pg_restore --list /secure/backup/kairos.dump
```

恢复到空数据库并重新检查迁移：

```bash
createdb kairos_restore
pg_restore --no-owner --dbname=kairos_restore /secure/backup/kairos.dump
KAIROS_DATABASE_URL='postgres://.../kairos_restore' /opt/kairos/bin/kairos-server migrate
```

恢复演练后检查 `/readyz`、登录、snapshot 和一次增量同步。备份包含任务和会话哈希，应按敏感数据保护。

## 日志与排障

```bash
systemctl status kairos-server
journalctl -u kairos-server --since today
```

日志不得包含 Authorization、刷新令牌、密码或任务正文。认证失败停止 WebSocket 自动重连；DNS、TLS、服务端拒绝和心跳超时可在客户端链路健康页区分。
