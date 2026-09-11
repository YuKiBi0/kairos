# Kairos CLI 使用说明

Kairos CLI（命令名为 `kairos`）是 Kairos 服务的命令行客户端，适用于开发者、运维人员、CI/CD 脚本和 Runner 主机。CLI 不保存任务数据库，也不绕过服务端的工作空间授权；所有远程任务和执行操作都由 Kairos Server 鉴权并记录审计信息。

CLI 使用独立的 Go 模块，源码目录为 `cli/`。Flutter 客户端、Go 服务端和 CLI 可以分别构建、发布和升级。

## 1. 安装与构建

### 从源码构建

需要 Go 1.26 或更高版本。在仓库根目录执行：

```powershell
cd cli
go build -trimpath -o kairos.exe .\cmd\kairos
```

Linux 或 macOS：

```bash
cd cli
go build -trimpath -o kairos ./cmd/kairos
```

将生成的单文件复制到 `PATH` 中即可。确认安装成功：

```text
kairos version
# kairos 1.0.0 (protocol v3)
```

交叉构建示例：

```powershell
$env:GOOS = "linux"
$env:GOARCH = "amd64"
go build -trimpath -o kairos-linux-amd64 .\cmd\kairos
```

### 运行测试

```powershell
cd cli
go test -p 1 ./...
```

## 2. 第一次使用

先添加一个服务 Profile：

```text
kairos server add --url https://kairos.example.com prod
```

然后登录。密码可以通过环境变量传入，避免出现在 shell 历史中：

```powershell
$env:KAIROS_USERNAME = "owner"
$env:KAIROS_PASSWORD = "密码"
kairos login --server prod
```

也可以显式传参：

```text
kairos login --server prod --username owner --password "密码"
```

登录成功后选择工作空间并查询任务：

```text
kairos workspace list
kairos workspace use personal
kairos task list
```

脚本建议使用 JSON 输出：

```text
kairos --output json task list
```

## 3. 全局参数与环境变量

全局参数可以放在命令前，也可以放在命令参数中：

| 参数                             | 说明                        | 默认值                |
| ------------------------------ | ------------------------- | ------------------ |
| `--server NAME`                | 使用指定服务 Profile            | 当前服务               |
| `--workspace ID`               | 使用指定工作空间                  | 当前工作空间或 `personal` |
| `--output table\|json\|ndjson` | 输出格式                      | `table`            |
| `--quiet`                      | 表格模式下隐藏成功输出，错误仍写入 stderr  | 关闭                 |
| `--request-timeout DURATION`   | 单次 HTTP 请求超时，例如 `15s`     | `15s`              |
| `--wait-timeout DURATION`      | `task run --wait` 的本地等待超时 | `30m`              |
| `--no-color`                   | 禁用颜色输出                    | 关闭                 |
| `--insecure`                   | 开发环境跳过 TLS 证书校验           | 关闭                 |

`--insecure` 必须同时设置 `KAIROS_ALLOW_INSECURE=1`，并在交互终端输入 `INSECURE` 确认；CI 和其他非交互环境会被拒绝。生产环境应使用 HTTPS，并保持证书校验开启。

可用环境变量如下，命令行参数优先级最高：

```text
KAIROS_SERVER_URL       服务 URL，可不创建 Profile 直接使用
KAIROS_SERVER           当前服务名称
KAIROS_TOKEN            访问 Token，优先于本地登录凭据
KAIROS_WORKSPACE        默认工作空间 ID
KAIROS_OUTPUT           table、json 或 ndjson
KAIROS_REQUEST_TIMEOUT  HTTP 请求超时
KAIROS_WAIT_TIMEOUT     本地等待超时
KAIROS_USERNAME         login 的用户名
KAIROS_PASSWORD         login 的密码
KAIROS_RUNNER_TOKEN     runner serve 使用的一次性 Runner Token
```

例如 CI 可以完全不写入本地凭据：

```powershell
$env:KAIROS_SERVER_URL = "https://kairos.example.com"
$env:KAIROS_TOKEN = $env:CI_KAIROS_TOKEN
kairos --output json task list
```

## 4. 配置文件与凭据

配置文件位置：

- Windows：`%APPDATA%\Kairos\config.yaml`
- Linux/macOS：`$XDG_CONFIG_HOME/kairos/config.yaml`；未设置时为 `~/.config/kairos/config.yaml`

文件内容是标准 YAML；CLI 同时接受 JSON（JSON 是 YAML 的有效子集）。典型内容如下：

```yaml
current_server: prod
current_workspace: personal
servers:
  prod:
    url: https://kairos.example.com
    verify_tls: true
    ca_file: null
    default_runner: build-01
  dev:
    url: http://127.0.0.1:8080
    verify_tls: false
```

服务 Profile 管理：

```text
kairos server list
kairos server use dev
kairos server doctor --server dev
kairos server remove dev
```

Token 不写入 YAML：

- Windows 使用 Credential Manager。
- Unix 自动保存到 `$XDG_CONFIG_HOME/kairos/credentials.json`（默认 `~/.config/kairos/credentials.json`），目录权限为 `0700`、凭据和锁文件权限为 `0600`；不需要额外密钥或登录参数。
- access token 临期时，CLI 使用保存的 refresh token 自动续期。Unix 使用跨进程文件锁串行化续期，因此同一服务器用户打开的新终端可以直接复用登录态。

- CI 推荐使用 `KAIROS_TOKEN`，不会把 Token 写入磁盘。

不要把密码、Token、Runner 一次性注册 Token 或任务正文提交到 Git，也不要将它们写入诊断日志。

## 5. 认证命令

```text
kairos login --server prod --username USER --password PASSWORD
kairos logout
kairos logout --all
kairos whoami
```

`logout` 删除本地凭据；`logout --all` 还会请求服务端撤销当前 refresh token。CLI 会在请求前自动刷新临期登录态；refresh token 失效或刷新后仍收到 `401` 时提示重新登录，不会打印请求头或 Token。

## 6. 工作空间命令

```text
kairos workspace list
kairos workspace current
kairos workspace use WORKSPACE_ID
```

`workspace use` 只修改本地默认上下文；工作空间列表和所有任务请求仍由服务端重新检查成员身份。成员被解绑后，服务端可能返回 `FORBIDDEN_SCOPE`，此时不能继续写入或执行任务。

## 7. 任务命令

### 查询任务

```text
kairos task list
kairos task list --status 0 --limit 20
kairos task list --tag TAG_ID --assignee ACCOUNT_ID
kairos task get TASK_ID
```

默认任务列表从当前工作空间快照读取，并支持 `--status`、`--tag`、`--assignee` 和 `--limit` 过滤。机器调用使用：

```text
kairos --output json task get TASK_ID
kairos --output ndjson task list
```

### 创建、更新和评论

```text
kairos task create --title "修复登录超时" --description "检查 refresh token"
kairos task create --json-file task.json
kairos task create --json-file - < task.json
kairos task update TASK_ID --title "新的标题"
kairos task update TASK_ID --base-version 3 --description "补充说明"
kairos task comment TASK_ID --body "已完成复现"
```

`--json-file` 接受文件路径或 `-`（标准输入）。创建和更新通过同步 API 提交操作；更新未显式指定 `--base-version` 时会先读取当前任务版本，避免无意覆盖并发修改。

写操作可以指定跨进程复用的幂等键：

```text
kairos task create --title "部署" --idempotency-key 550e8400-e29b-41d4-a716-446655440000
```

未指定时 CLI 会生成只在当前进程重试期间复用的键。需要跨进程重试的 CI 必须自行保存并再次传入同一个键。

### 执行、取消、日志和结果

```text
kairos task run TASK_ID --runner build-01 --input '{"branch":"main"}'
kairos task run TASK_ID --input @input.json --consent
kairos task run TASK_ID --input - --wait --wait-timeout 10m
kairos task cancel TASK_ID --run RUN_ID --reason "用户取消"
kairos task logs TASK_ID --run RUN_ID
kairos task logs TASK_ID --run RUN_ID --follow --since 2026-09-03T00:00:00Z
kairos task result TASK_ID --run RUN_ID
kairos task result TASK_ID --run RUN_ID --artifact report.zip
```

`--input` 支持内联 JSON、`@FILE` 和 `-`；省略时发送空对象。`--consent` 只代表发起人确认高风险请求，不等同于审批。旧参数 `--approve` 会被拒绝，请改用 `--consent`。

默认 `task run` 只创建 Run 并立即返回。只有 `--wait` 才会轮询等待；本地等待超时返回 7，不会自动取消仍在服务端运行的 Run。

## 8. Run 命令

```text
kairos run list
kairos run list --task TASK_ID --status running --limit 50
kairos run get RUN_ID
kairos run approve RUN_ID --reason "已完成风险确认"
kairos run reject RUN_ID --reason "缺少必要审批"
```

Run 的服务端终态包括 `succeeded`、`failed`、`cancelled` 和 `timed_out`。审批拒绝、排队超时、执行超时和租约超时都属于服务端终态；CLI 统一返回退出码 6。

## 9. Runner 命令

管理员可先生成目标服务器上的人工安装信息：

```text
kairos runner install --server https://kairos.example.com --name build-01
```

创建、查看和撤销 Runner：

```text
kairos runner create build-01
kairos runner list
kairos runner inspect RUNNER_ID
kairos runner revoke RUNNER_ID
kairos runner unquarantine RUNNER_ID
```

在目标服务器上使用一次性 Runner Token 启动 Runner：

```bash
export KAIROS_RUNNER_TOKEN='一次性 Token'
kairos runner serve \
  --server https://kairos.example.com \
  --name build-01 \
  --capabilities shell,filesystem \
  --concurrency 2
```

Runner 会注册能力、发送 15 秒心跳，并在收到 SIGINT/SIGTERM 时通知服务端退出。Runner Token 不应写入普通配置文件或命令历史。

## 10. 跨终端登录态

`kairos login` 会保存普通登录会话。后续命令优先复用有效的 access token，临期时自动调用 `/api/v1/auth/refresh` 并原子更新 access/refresh token；服务器上的新终端无需重新登录，也无需导出任何凭据密钥。

显式设置 `KAIROS_TOKEN` 时仍以环境变量为准，适合由现有部署系统注入的 CI 会话；CLI 不会把环境变量 Token 写入磁盘，也不会尝试刷新它。

## 11. 中央委派 CLI（L3 / Agent）

中央委派是独立于普通 `task create` 的服务器级能力，适合部署在服务器上的自动化 Agent、CI 控制器或运维编排服务。它不会把任务创建者伪装成当前登录的中央账号：服务端会把指定成员写入 `user_id` 和 `created_by_user_id`，把中央操作者写入 `last_operated_by_user_id`，并记录一条包含操作者、目标成员、群组、工作空间、Agent ID 和请求 ID 的审计事件。

### 11.1 前置条件

1. 服务端已完成最新数据库迁移并部署中央 API。
2. 当前登录账号具有服务器 `L3` 角色。
3. 目标工作空间必须是指定群组的群组工作空间，不能是任何个人工作空间。
4. 目标用户必须是该群组中仍处于绑定、启用状态的成员。

直接登录 L3 账号：

```text
kairos login --server prod --username super-admin --password "..."
```

中央命令与普通命令共享该登录态。服务端在每次中央请求中校验当前账号仍为 L3 且登录设备未撤销；L1/L2 会被拒绝。服务端不再提供中央令牌签发接口，也无需单独注入中央凭据或申请中央 scope。

### 11.2 为指定成员创建任务

推荐使用不可变的用户 UUID：

```text
kairos --server prod central task create \
  --group 11111111-1111-1111-1111-111111111111 \
  --workspace 22222222-2222-2222-2222-222222222222 \
  --creator-user 33333333-3333-3333-3333-333333333333 \
  --title "检查生产备份" \
  --description "由中央 Agent 创建，交给目标成员处理" \
  --priority 1 \
  --agent backup-agent \
  --idempotency-key 44444444-4444-4444-4444-444444444444
```

也可以用唯一用户名（服务端按精确匹配解析，不能模糊搜索）：

```text
kairos central task create \
  --group GROUP_ID --workspace WORKSPACE_ID \
  --creator-username alice --title "处理告警"
```

`--creator-user` 与 `--creator-username` 只能二选一。`--group`、`--workspace` 和创建者参数均为必填；`--priority` 取值为 1 到 4，默认 2；`--agent` 用于审计和后续 Agent 路由，不会让客户端绕过 Runner 策略。

### 11.3 JSON 文件与幂等重试

复杂任务可以从 JSON 文件读取。命令行参数会覆盖文件中的同名字段；如果同时提供幂等键，两者必须完全一致：

```json
{
  "group_id": "GROUP_ID",
  "workspace_id": "WORKSPACE_ID",
  "creator_user_id": "USER_ID",
  "title": "发布检查",
  "description": "检查清单见工单附件",
  "quadrant": 1,
  "source_agent_id": "release-agent"
}
```

```text
kairos central task create --json-file task.json --idempotency-key REQUEST_UUID
```

写入操作必须带 UUID 格式的幂等键；未提供时 CLI 会自动生成。网络超时后使用同一个键重试，服务端只返回第一次创建的任务，不会产生第二条任务。重复请求通常返回 HTTP 200，并在 JSON 中标记 `duplicate: true`。

### 11.4 权限拒绝与排障

| 错误码                        | 含义                             |
| -------------------------- | ------------------------------ |
| `UNAUTHENTICATED`          | 尚未登录，或保存的 refresh token 已失效       |
| `INVALID_REFRESH_TOKEN`    | 服务端已撤销会话或 refresh token 已过期       |
| `FORBIDDEN_ROLE`           | 当前登录账号不是 L3                       |
| `TARGET_NOT_GROUP_MEMBER`  | 目标用户不是群组的有效成员，或已解绑/禁用          |
| `WORKSPACE_GROUP_MISMATCH` | 工作空间不是该群组的群组工作空间               |
| `GROUP_ARCHIVED`           | 归档群组禁止新建任务                     |
| `IDEMPOTENCY_KEY_REUSED`   | 幂等键已被其他中央操作者使用                 |
| `VALIDATION_ERROR`         | UUID、标题、优先级或幂等键格式错误            |

中央接口明确禁止个人工作空间委派。中央账号也不会因为 L3 角色自动获得其他用户个人任务的读取权限；需要读取时必须使用目标产品授权的群组工作空间流程。

## 12. 输出、错误和退出码

表格模式的错误写入 stderr；`json` 和 `ndjson` 模式的错误事件写入 stdout。错误对象包含 `code`、`message`、`request_id`，必要时包含 `details`。

| 退出码 | 含义                                        |
| ---:| ----------------------------------------- |
| 0   | 成功                                        |
| 1   | 通用错误                                      |
| 2   | 参数或配置错误                                   |
| 3   | 未认证或 Token 过期                             |
| 4   | 无权限                                       |
| 5   | 服务不可达、TLS 或协议错误                           |
| 6   | Run 进入 `failed`、`cancelled` 或 `timed_out` |
| 7   | 仅 CLI 本地等待超时，Run 尚未结束                     |

脚本示例：

```bash
set -o pipefail
result="$(kairos --output json task run "$TASK_ID" --wait)"
status=$?
printf '%s\n' "$result"
case "$status" in
  0) echo "执行成功" ;;
  6) echo "Run 未成功结束" >&2; exit 1 ;;
  7) echo "CLI 停止等待，Run 仍在服务端运行" >&2; exit 2 ;;
  *) echo "CLI 请求失败" >&2; exit "$status" ;;
esac
```

## 13. 服务端兼容性与排障

当前仓库服务端已提供 `/api/v1` 认证、任务同步、`/api/v2` 工作空间接口，以及中央委派所需的 `/api/v3/central/tasks`。Run、Runner 等其他 v3 能力仍需对应服务端模块；在尚未部署目标 v3 能力的服务端上，CLI 会返回结构化 404，这是版本不兼容而不是 CLI 参数错误。

常用排障命令：

```text
kairos server doctor --server prod
kairos --request-timeout 30s server doctor --server prod
kairos --output json whoami
```

检查顺序建议为：确认 URL 和 DNS，确认 HTTPS 证书或 `ca_file`，确认服务端 `/healthz` 和 `/version`，最后确认 Token 未过期且具有目标工作空间权限。错误中的 `request_id` 可交给服务端管理员查询审计记录。

## 14. API 对应关系

| CLI 能力     | 服务端接口                              |
| ---------- | ---------------------------------- |
| 登录、注销、当前用户 | `/api/v1/auth/*`                   |
| 个人任务同步与读取  | `/api/v1/sync/*`、`/api/v1/tasks/*` |
| 群组工作空间     | `/api/v2/workspaces/*`             |
| Run、日志、结果  | `/api/v3/runs/*`                   |
| Runner     | `/api/v3/runners/*`                |
| 中央委派任务     | `/api/v3/central/tasks`            |

CLI 不直接连接 PostgreSQL 或 Redis，也不通过 SSH 执行远程命令。
