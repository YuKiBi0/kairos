# 服务端部署

Kairos 服务端统一通过一个环境文件读取配置。Windows、Linux、源码运行和编译后的二进制运行都使用同一套命令格式：

```text
kairos-server --env-file <环境文件> <命令>
```

环境文件只在程序运行时读取，不会被编译进二进制文件。数据库密码、会话密钥和首次账号密码都不会出现在命令行参数中。

## 1. 准备环境文件

复制 `server/.env.example`，放到仓库外的受限目录，例如 Windows 的 `D:\secure\kairos.env` 或 Linux 的 `/etc/kairos/kairos.env`。把所有占位值替换为真实值：

```dotenv
KAIROS_ENV=production
KAIROS_HTTP_ADDR=127.0.0.1:8080
KAIROS_DATABASE_URL=postgres://kairos:URI编码后的数据库密码@127.0.0.1:5432/kairos?sslmode=disable
KAIROS_BASE_URL=https://kairos.example.com
KAIROS_SESSION_SECRET=至少32个字符的随机会话密钥
KAIROS_ACCESS_TTL=15m
KAIROS_REFRESH_TTL=720h
KAIROS_LOG_LEVEL=info
KAIROS_CORS_ORIGINS=
KAIROS_MIGRATIONS_DIR=/opt/kairos/migrations
KAIROS_BOOTSTRAP_USERNAME=owner
KAIROS_BOOTSTRAP_PASSWORD=首次创建账号时使用的强密码
```

本地 Windows 开发时，将 `KAIROS_BASE_URL` 改为 `http://127.0.0.1:8080`，并将 `KAIROS_MIGRATIONS_DIR` 改为实际的 Windows 路径，例如 `D:/Trae/kairos/server/migrations`。密码中的 `@`、`:`、`/`、`#` 等字符必须进行 URI 编码。

`KAIROS_BOOTSTRAP_USERNAME` 和 `KAIROS_BOOTSTRAP_PASSWORD` 只用于 `create-user`，服务启动时不会使用它们。账号创建成功后，建议从环境文件删除这两行；如果保留，必须像数据库密码一样保护该文件。

## 2. PostgreSQL

部署不需要 Docker。使用现有 PostgreSQL 或系统包安装的 PostgreSQL，创建数据库和用户，并让 `KAIROS_DATABASE_URL` 指向它。生产环境建议 PostgreSQL 和 Kairos 都只监听回环地址或内网地址。

## 3. 源码运行

在仓库的 `server/` 目录执行。Windows PowerShell 和 Linux Bash 使用相同的程序参数，不需要先设置或导出环境变量：

```text
go run ./cmd/kairos-server --env-file /path/to/kairos.env migrate
go run ./cmd/kairos-server --env-file /path/to/kairos.env create-user
go run ./cmd/kairos-server --env-file /path/to/kairos.env serve
```

Windows 示例：

```powershell
cd D:\Trae\kairos\server
go run .\cmd\kairos-server --env-file D:\secure\kairos.env migrate
go run .\cmd\kairos-server --env-file D:\secure\kairos.env create-user
go run .\cmd\kairos-server --env-file D:\secure\kairos.env serve
```

Linux 示例：

```bash
cd /opt/kairos-src/server
go run ./cmd/kairos-server --env-file /etc/kairos/kairos.env migrate
go run ./cmd/kairos-server --env-file /etc/kairos/kairos.env create-user
go run ./cmd/kairos-server --env-file /etc/kairos/kairos.env serve
```

`migrate` 数据库初始化，只需在首次部署或数据库结构更新时执行；

`create-user` 用于创建账号，通常只执行一次，也可以创建多个账号。账号名与密码会根据传入的env环境文件来创建；

`serve` 是正式的持续运行的服务。

## 4. 编译后二进制运行

环境文件不参与编译。先编译，再在运行时传入环境文件即可。

Windows：

```powershell
cd D:\Trae\kairos\server
go build -trimpath -ldflags='-s -w' -o kairos-server.exe .\cmd\kairos-server
.\kairos-server.exe --env-file D:\secure\kairos.env migrate
.\kairos-server.exe --env-file D:\secure\kairos.env create-user
.\kairos-server.exe --env-file D:\secure\kairos.env serve
```

Linux amd64：

```bash
cd server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o kairos-server ./cmd/kairos-server
./kairos-server --env-file /etc/kairos/kairos.env migrate
./kairos-server --env-file /etc/kairos/kairos.env create-user
./kairos-server --env-file /etc/kairos/kairos.env serve
```

ARM64 服务器将 `GOARCH=amd64` 改为 `GOARCH=arm64`。二进制运行时，`KAIROS_MIGRATIONS_DIR` 必须指向包含 `*.sql` 文件的目录。

## 5. Linux systemd 安装（可选）

如果希望服务开机自启，可使用安装脚本；它也直接把环境文件交给 Kairos，不依赖 shell 环境变量：

```bash
sudo deploy/install.sh \
  --binary ./server/kairos-server \
  --env-file /etc/kairos/kairos.env \
  --migrations ./server/migrations
```

脚本会安装到 `/opt/kairos`，创建受限的 `kairos` 系统用户，执行迁移并启用 `kairos-server.service`。创建首次账号：

```bash
sudo -u kairos /opt/kairos/bin/kairos-server \
  --env-file /etc/kairos/kairos.env create-user
```

检查服务：

```bash
systemctl status kairos-server --no-pager
curl http://127.0.0.1:8080/readyz
```

## 6. 更新、卸载和反向代理

更新二进制并迁移：

```bash
sudo deploy/update.sh --binary ./kairos-server \
  --migrations ./server/migrations --sha256 '<expected-sha256>'
```

普通卸载保留 `/etc/kairos`、`/var/lib/kairos` 和迁移；`sudo deploy/uninstall.sh --purge-data` 会永久删除这些目录。

生产公网入口仍需自行配置 Nginx、域名、TLS 和防火墙。以 `deploy/nginx-kairos.conf.example` 为起点，反向代理必须保留 `Upgrade`、`Connection`、`Host`、`X-Forwarded-*` 和 `X-Request-ID` 请求头。公网只开放 Nginx 的 443，Kairos 和 PostgreSQL 绑定回环地址。

## 7. 检查、备份和排障

```text
GET http://127.0.0.1:8080/healthz  只检查进程
GET http://127.0.0.1:8080/readyz   检查进程、PostgreSQL 和迁移
GET http://127.0.0.1:8080/version
```

备份应在迁移或更新前执行。`pg_dump` 不会读取 Kairos 的环境文件，应使用 PostgreSQL 自己的 `.pgpass` 或 service 配置提供凭据：

```bash
pg_dump --format=custom --no-owner --dbname=kairos --file=/secure/backup/kairos.dump
pg_restore --list /secure/backup/kairos.dump
```

systemd 日志：

```bash
systemctl status kairos-server
journalctl -u kairos-server --since today
```

日志不得包含 Authorization、刷新令牌、密码或任务正文。备份包含任务和会话哈希，应按敏感数据保护。
