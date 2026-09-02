# Kairos

Kairos 是一个离线优先的任务管理系统，提供 Windows/Android 客户端、可自部署的 Go 服务端，以及轻量的 `KairosAdmin` 管理后台。

当前仓库对应 **MVP 2.0**：一个真实账号可以拥有个人工作空间并加入多个群组；群组通过花名册、邀请码和 L1/L2/L3 角色管理成员；任务和同步数据按工作空间隔离；Redis 用于限流和 KairosAdmin 会话，PostgreSQL 保存权威业务数据。

## 主要能力

- 任务列表、任务树、四象限、标签、项目、清单和困难点。
- 本地 Drift/SQLite 持久化，outbox 记录离线写入，网络恢复后增量同步。
- 个人工作空间与多个群组工作空间快速切换，游标、冲突和待上传队列按空间隔离。
- 群组花名册：群组账号不能登录，可以先建立名册再绑定真实账号；绑定关系保留历史。
- 邀请码：普通邀请码支持有效期内不限次数或次数上限；指定花名册账号时强制单次使用；有效期最长 30 天。
- RBAC：独立成员/群组成员 L1、群组管理员 L2、超级管理员 L3。角色不能越级，保护最后一个 L3 和群组最后一个 L2。
- 群组协作默认关闭。开启后不可关闭，任务必须显式共享，不会自动公开历史任务。
- `KairosAdmin` 原生 HTML/CSS/JavaScript 管理后台，入口固定为大小写敏感的 `/KairosAdmin/`。
- Redis 不可用时，个人任务同步尽量继续；登录、邀请码、管理后台和角色变更等敏感操作失败关闭。

## 架构概览

```text
Flutter (Windows / Android)
        |
        | HTTPS / WSS, /api/v1 + /api/v2
        v
Go HTTP/WebSocket server ---- Redis (限流、KairosAdmin 会话)
        |
        +---- PostgreSQL (账号、群组、花名册、任务、同步、审计权威数据)
        |
        +---- KairosAdmin (embed.FS 原生管理页面)
```

客户端仍以本地数据库为首写入点。服务端每次请求重新校验真实账号、工作空间和群组角色，不信任客户端提交的 `user_id`、`workspace_id` 或角色字段。

## 快速开始

### 1. 启动 PostgreSQL 和 Redis

仓库提供本地 Compose 文件：

```powershell
docker compose -f deploy/docker-compose.postgres.yml up -d
```

### 2. 准备服务端环境文件

复制 `server/.env.example` 到仓库外的受限目录，至少设置数据库 URL、长度不少于 32 个字符的 `KAIROS_SESSION_SECRET`，以及引导账号密码。开发环境可保留 `KAIROS_REDIS_REQUIRED=false`。

### 3. 迁移、创建账号并启动

```powershell
cd server
go run .\cmd\kairos-server --env-file D:\secure\kairos.env migrate
go run .\cmd\kairos-server --env-file D:\secure\kairos.env create-user
go run .\cmd\kairos-server --env-file D:\secure\kairos.env bootstrap-super-admin owner
go run .\cmd\kairos-server --env-file D:\secure\kairos.env serve
```

启动后检查：

```text
GET http://127.0.0.1:8080/healthz
GET http://127.0.0.1:8080/readyz
GET http://127.0.0.1:8080/version
```

`bootstrap-super-admin` 只在数据库还没有 L3 时生效。完成后应从环境文件删除 `KAIROS_BOOTSTRAP_PASSWORD`。

### 4. 启动客户端

```powershell
flutter pub get
flutter run -d windows
```

客户端服务地址在设置中配置。公网部署必须使用 HTTPS/WSS；局域网明文 HTTP/WS 只适合开发和明确确认过风险的环境。

## 工程文档

- [架构与数据模型](docs/architecture.md)
- [部署与运维](docs/deployment.md)
- [客户端构建](docs/build.md)
- [测试与质量门禁](docs/testing.md)
- [API v1](docs/api.md)
- [API v2：群组、工作空间与 KairosAdmin](docs/api-v2.md)
- [API 变更记录](docs/api-changelog.md)
- [Kairos CLI 产品需求与开发 PRD](docs/kairos-cli-prd.md)
- [MVP 2.0 产品与技术基线](docs/mvp-2.0-spec.md)
- [MVP 2.0 实施与发布计划](docs/mvp-2.0-plan.md)
- [当前限制与明确不支持的范围](docs/known-limitations.md)

## 版本与分支

MVP2 的最终提交链在 `codex/feature-mvp2-client-workspaces`，提交到 `develop` 时建议使用一个总 PR。`codex/feature-mvp2-foundation`、`codex/feature-mvp2-sync-v2` 和 `codex/feature-mvp2-admin` 是本地阶段性分支，不是当前远端必需分支。

## 安全底线

不要提交 `.env`、密码、令牌、原始邀请码、私钥或生产数据库备份。管理 Cookie 使用 HttpOnly/Secure/SameSite 属性，写请求需要 CSRF token。日志和错误响应不得包含密码、令牌、原始邀请码或任务正文。

## 许可证

见 [LICENSE](LICENSE)。
