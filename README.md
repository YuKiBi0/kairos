# Kairos

Kairos 是一款面向 Windows 和 Android 的离线优先个人任务管理器。任务会先事务性地写入本地 SQLite，断网时仍可正常创建、编辑、移动和完成；恢复网络后，客户端通过自部署的 Go 服务与 PostgreSQL 进行最终一致同步。

项目适合希望在手机上快速记录、在电脑上集中整理，同时自行掌控服务端和数据库的个人用户。当前 MVP 按单用户实例设计，不包含多人协作、公共注册或云托管服务。

## 主要功能

- 列表、五层任务树和四象限视图，共享搜索、范围、状态和归类筛选。
- 标签、轻量项目、清单分组、截止时间、任务状态和推进困难点。
- 子任务移动、同级排序、递归进度、软删除撤销和本地 JSON 导出。
- 本地事务写入与 outbox，支持首次快照、增量拉取和批量上传。
- 字段级冲突检测与明确的“保留本地/使用服务端”选择，不静默覆盖。
- WebSocket 仅传递变更提示，实际数据始终通过 HTTP 增量同步。
- 链路健康页提供连接状态、心跳延迟、重连、同步结果和脱敏诊断信息。
- Windows 自定义标题栏与窗口置顶，Android 窄屏布局与下拉同步。

## 技术架构

```text
Windows / Android Flutter 客户端
  ├─ Drift / SQLite：任务、分类、同步状态和 outbox
  ├─ 平台安全存储：刷新令牌
  ├─ HTTPS：认证、快照、增量同步和冲突处理
  └─ WSS：心跳与 change_hint 通知
                    │
                    ▼
Go API 服务（systemd）
  ├─ 单用户认证与令牌轮换
  ├─ 幂等 push、cursor changes 和字段冲突检测
  └─ WebSocket 在线通知
                    │
                    ▼
PostgreSQL 18
```

客户端即使无法连接服务端也能继续工作。WebSocket 在线只表示通知通道可用，不代表数据已经完成同步；最终状态以 HTTP 增量同步结果为准。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `lib/` | Flutter 客户端、领域模型、本地数据层和同步引擎 |
| `server/` | Go API 服务、认证、同步逻辑和数据库迁移 |
| `deploy/` | systemd、Bash 安装/更新脚本、PostgreSQL Compose 和 Nginx 示例 |
| `test/` | Dart 单元测试和 Flutter 组件测试 |
| `integration_test/` | Windows 客户端集成流程 |
| `docs/` | 构建、部署、API、限制和协议变更文档 |

## 环境要求

开发环境：

- Flutter `3.41.7` stable / Dart `3.11.5`。
- Go `1.26`。
- PostgreSQL `18`。
- Windows 构建需要 Visual Studio 的 Desktop development with C++ 和 Windows SDK。
- Android 构建需要 Android Studio、Android SDK 和 JDK 17；以 `flutter doctor -v` 为准。

生产服务器建议：

- 使用 systemd 的主流 Linux 发行版。
- PostgreSQL 18，使用现有实例或操作系统包安装。
- Nginx 或等价反向代理，以及有效的公网 TLS 证书。
- Go 服务和 PostgreSQL 仅监听回环地址，只向公网开放 HTTPS 端口。

## 本地开发

### 客户端

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Windows 和 Android 构建命令见 [客户端构建文档](docs/build.md)。Drift schema 发生变化后执行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 服务端

先创建 PostgreSQL 数据库。将 `server/.env.example` 复制到仓库外的受限目录并替换所有占位值，程序会直接读取该文件：

```text
cd server
go run ./cmd/kairos-server --env-file /secure/path/kairos.env migrate
go run ./cmd/kairos-server --env-file /secure/path/kairos.env create-user
go run ./cmd/kairos-server --env-file /secure/path/kairos.env serve
```

账号、密码、数据库 URL、迁移目录和其他运行配置全部放在环境文件中，不需要在 PowerShell 或 Bash 中导出变量。开发服务启动后检查：

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/readyz
curl http://127.0.0.1:8080/version
```

`/healthz` 检查进程，`/readyz` 还会检查 PostgreSQL 连接和数据库迁移版本。

## Linux 自部署

推荐拓扑为：公网 HTTPS/WSS -> Nginx -> `127.0.0.1:8080` 的 Kairos 服务 -> 本机或内网 PostgreSQL。仓库不会自动修改 DNS、证书或防火墙。

### 1. 准备 PostgreSQL

使用已有 PostgreSQL 18 或通过操作系统包管理器安装 PostgreSQL。Kairos 的部署流程不依赖 Docker；数据库的创建和权限配置由 PostgreSQL 管理工具完成。

如果数据库密码包含 `@`、`:`、`/` 等字符，写入 PostgreSQL URL 前必须进行 URI 编码。

### 2. 构建 Linux 服务端

在可信构建机的仓库根目录执行：

```bash
cd server
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath \
  -ldflags='-s -w' -o kairos-server ./cmd/kairos-server
cd ..
sha256sum server/kairos-server
```

ARM64 服务器将 `GOARCH=amd64` 改为 `GOARCH=arm64`。将二进制、`server/migrations/` 和 `deploy/` 安全传输到服务器。

### 3. 创建服务端环境文件

在服务器的仓库外创建 `/secure/path/kairos.env`，文件权限建议为 `0600`：

```dotenv
KAIROS_ENV=production
KAIROS_HTTP_ADDR=127.0.0.1:8080
KAIROS_DATABASE_URL=postgres://kairos:replace-with-uri-encoded-password@127.0.0.1:5432/kairos?sslmode=disable
KAIROS_BASE_URL=https://kairos.example.com
KAIROS_SESSION_SECRET=replace-with-at-least-32-random-characters
KAIROS_ACCESS_TTL=15m
KAIROS_REFRESH_TTL=720h
KAIROS_LOG_LEVEL=info
KAIROS_CORS_ORIGINS=
KAIROS_MIGRATIONS_DIR=/opt/kairos/migrations
KAIROS_BOOTSTRAP_USERNAME=owner
KAIROS_BOOTSTRAP_PASSWORD=replace-with-a-strong-account-password
```

`KAIROS_SESSION_SECRET` 至少 32 个字符，应使用密码学安全随机数生成器创建，并与数据库密码分别保管。`KAIROS_BASE_URL` 必须与用户最终访问的 HTTPS 地址一致。

### 4. 安装 systemd 服务

以 root 运行安装脚本：

```bash
sudo deploy/install.sh \
  --binary ./server/kairos-server \
  --env-file /secure/path/kairos.env \
  --migrations ./server/migrations
```

安装脚本会：

- 创建不可登录的 `kairos` 系统用户。
- 安装二进制和迁移到 `/opt/kairos/`。
- 将环境文件安装到 `/etc/kairos/kairos.env`，权限为 `root:kairos 0640`。
- 执行数据库迁移。
- 安装、启用并立即启动 `kairos-server.service`。

验证服务：

```bash
systemctl status kairos-server --no-pager
curl http://127.0.0.1:8080/readyz
```

### 5. 创建首次账号

MVP 不提供公开注册。安装完成后在服务器上创建唯一账号：

```bash
sudo -u kairos /opt/kairos/bin/kairos-server \
  --env-file /etc/kairos/kairos.env create-user
```

程序从受限环境文件读取首次账号和密码，数据库中只保存密码哈希。创建成功后建议从环境文件删除 `KAIROS_BOOTSTRAP_USERNAME` 和 `KAIROS_BOOTSTRAP_PASSWORD`。

### 6. 配置 Nginx 与 TLS

以 `deploy/nginx-kairos.conf.example` 为起点，替换域名和证书路径后加载配置。反向代理必须保留 WebSocket upgrade、`Host`、`X-Forwarded-*` 和 `X-Request-ID` 请求头。

```bash
sudo nginx -t
sudo systemctl reload nginx
curl https://kairos.example.com/readyz
```

生产环境只向公网开放 443。不要暴露 Go 服务的 8080 端口或 PostgreSQL 的 5432 端口。客户端填写 `https://kairos.example.com`，WebSocket 会自动连接 `wss://kairos.example.com/api/v1/realtime`。

### 7. 连接客户端

1. 打开 Kairos 的同步设置。
2. 输入完整服务地址，例如 `https://kairos.example.com`，不要附带账号、query 或 fragment。
3. 使用创建的用户名和密码登录。
4. 首次登录会拉取完整快照，之后使用增量同步。
5. 在链路健康页分别确认“通知通道”和“HTTP 增量同步”状态。

局域网开发可以显式使用 HTTP/WS，客户端会显示未加密警告；公网环境必须使用 HTTPS/WSS。

## 更新与卸载

更新前先备份数据库并校验新二进制的 SHA-256：

```bash
sudo deploy/update.sh \
  --binary ./kairos-server \
  --migrations ./server/migrations \
  --sha256 '<expected-sha256>'
```

更新脚本会保留上一版二进制，并在新服务启动失败时恢复。数据库迁移不会自动回滚，因此发布迁移必须保持向后兼容。

普通卸载会保留配置、迁移和数据：

```bash
sudo deploy/uninstall.sh
```

永久清除 `/etc/kairos`、`/var/lib/kairos` 和已安装迁移时才使用：

```bash
sudo deploy/uninstall.sh --purge-data
```

`--purge-data` 不可恢复，执行前必须确认备份可用。Compose 数据卷需要单独管理，不会被卸载脚本删除。

## 备份与恢复

在迁移、更新或主机维护前创建 PostgreSQL custom-format 备份：

```bash
pg_dump --format=custom --no-owner \
  --file=/secure/backup/kairos.dump "$KAIROS_DATABASE_URL"
pg_restore --list /secure/backup/kairos.dump
```

建议定期恢复到空数据库进行演练：

```bash
createdb kairos_restore
pg_restore --no-owner --dbname=kairos_restore /secure/backup/kairos.dump
KAIROS_DATABASE_URL='postgres://.../kairos_restore' \
  /opt/kairos/bin/kairos-server migrate
```

恢复后检查 `/readyz`、登录、首次快照和一次增量同步。备份包含任务数据和会话哈希，应按敏感数据保护并设置保留周期。

## 日志与排障

```bash
systemctl status kairos-server --no-pager
journalctl -u kairos-server --since today
journalctl -u kairos-server -f
```

常见检查顺序：

1. `/healthz` 失败：确认 systemd 服务、监听地址和反向代理状态。
2. `/healthz` 正常但 `/readyz` 失败：检查数据库连接、账号权限和迁移是否完成。
3. 登录失败：确认首次账号已创建，客户端服务地址没有多余路径或参数。
4. HTTPS 正常但实时通知失败：检查 Nginx 的 WebSocket upgrade 请求头和证书。
5. 有待上传操作：在客户端执行“立即同步”，再查看链路健康页的 HTTP 同步结果。
6. Android 无法连接局域网服务：确认手机与服务器网络可达，并检查防火墙；公网不要改用明文 HTTP 规避证书问题。

日志、诊断和工单中不得包含 `Authorization`、刷新令牌、密码、完整数据库 URL 或任务正文。

## 安全注意事项

- 永远不要提交真实 `.env`、数据库密码、令牌、证书、私钥、keystore 或签名配置。
- 仓库只跟踪 `server/.env.example`，其中必须保持占位值。
- PostgreSQL 和 Go API 默认绑定回环地址，公网只暴露经过 TLS 的反向代理。
- 为 `/etc/kairos/kairos.env`、备份和 Compose env 文件设置最小读取权限。
- 定期轮换账号密码、会话密钥和数据库密码；轮换会话密钥会使现有登录会话失效。
- 发布前对服务端二进制执行 SHA-256 校验，并使用受信任的构建环境。
- Android 正式发布必须在仓库外配置 keystore；不要使用 debug signing 发布。
- 删除客户端应用数据会删除尚未同步的本地任务，清理前先完成同步或导出 JSON。

## MVP 已知限制

- 仅支持个人单用户实例，没有注册、多用户协作或权限管理 UI。
- Android 只保证前台同步，没有后台任务、系统通知或提醒调度。
- 支持 JSON 导出，不支持导入；软删除暂不提供完整回收站页面。
- Windows 和 Android 发布签名、商店打包和自动更新不在 MVP 范围内。
- DNS、TLS 证书、Nginx、防火墙和数据库备份策略由部署者维护。

完整限制见 [已知限制](docs/known-limitations.md)。

## 测试

```bash
flutter analyze
flutter test
flutter test integration_test -d windows

cd server
go test ./...
KAIROS_TEST_DATABASE_URL='postgres://...' go test -tags integration ./...
```

集成测试必须使用独立测试数据库，不要指向生产数据库。

## 更多文档

- [客户端构建](docs/build.md)
- [服务端部署与运维](docs/deployment.md)
- [API v1](docs/api.md)
- [API 变更记录](docs/api-changelog.md)
- [MVP 已知限制](docs/known-limitations.md)
