# Kairos CLI 产品需求与开发 PRD

**文档状态**：Draft v0.4
**日期**：2026-09-02  
**产品负责人**：Kairos Team  
**目标版本**：CLI MVP 1.0

## 0. 术语、依赖与决策状态

### 0.1 术语表

| 术语 | 定义 |
| --- | --- |
| Task | Kairos 中的任务记录，包含标题、描述、状态和工作空间归属；Task 本身不等于一次执行。 |
| Run | 对一个 Task 发起的一次可审计执行实例，有独立状态、日志、产物和幂等键。 |
| Workspace | 任务和权限的最小隔离边界。分为每个账号唯一的个人工作空间和群组对应的群组工作空间。 |
| Group | 成员、花名册和群组工作空间的管理边界；个人工作空间不属于任何 Group。 |
| Runner | 部署在目标服务器上的受限执行宿主进程，负责连接服务端、领取 Run、启动执行器、上报事件。一个 Runner 可承载多个 Agent Adapter。 |
| Agent | 面向某类自动化能力的逻辑适配器或子进程，例如代码 Agent、测试 Agent；Agent 不直接持有服务端长期凭据，也不直接暴露公网端口。 |
| Capability | Runner/Agent 可执行的版本化能力声明，例如 `shell`、`filesystem`、`llm`；能力不是权限，最终权限由服务端策略决定。 |
| L1/L2/L3 | 现有 MVP2 RBAC 等级：L1 独立成员/群组成员，L2 群组管理员，L3 超级管理员。详见 9.1。 |
| MVP2 | 本仓库当前产品基线，定义账号、个人/群组工作空间、同步、RBAC 和审计规则；权威文档为 `docs/mvp-2.0-spec.md`。 |

### 0.2 依赖与边界

- CLI 依赖现有 Kairos Server 的认证、工作空间授权、RBAC、PostgreSQL 权威数据和实时基础设施；CLI 不直接连接数据库或 Redis。
- Task 读写继续使用现有兼容 API；Runner、Run、审批和执行策略使用新的版本化执行 API。
- Runner 是执行边界，Agent 是 Runner 内的能力提供者；“Agent Runner”不是第三种实体，流程中统一称为 Runner + Agent Adapter。
- L3 是全服务器管理角色，但个人工作空间数据仍只对其所有者可见；L3 的全局权限不等于读取其他账号个人任务的权限。

### 0.3 决策状态

本文中标记为 **已定案** 的内容可进入开发；标记为 **OPEN** 的内容不得作为实现前提，必须在 M0 结束前关闭。v0.4 已将个人工作空间审批、API 版本、实时通道、状态机、安装通道、参数语义和退出码原则定为已定案。

## 1. 摘要

Kairos CLI 是面向开发者、运维人员和 Agent 的命令行入口。它连接一个 Kairos Server，读取和更新任务、启动任务执行、查看实时日志，并把执行请求路由到一个或多个 Runner-hosted Agent Adapter。

CLI 支持三种部署拓扑：

1. **控制端模式**：CLI 在用户电脑上运行，只负责调用 Kairos Server。
2. **服务器本机模式**：CLI 与 Runner 部署在 Kairos Server 所在机器，任务在该机器执行。
3. **跨服务器模式**：CLI 可在任意机器运行，Kairos Server 将任务派发给目标服务器上的 Runner。

CLI 本身不是新的任务数据库，也不绕过服务端授权。Kairos Server 继续作为账号、工作空间、任务、Agent 注册和执行审计的权威来源。

## 2. 背景与问题

当前 Kairos 已具备离线优先客户端、Go 服务端、个人/群组工作空间、RBAC、同步和实时通道，但自动化入口仍缺少：

- 不能在脚本、CI 或终端中稳定地操作任务；
- 不能把任务交给指定服务器或 Agent 执行并持续查看日志；
- Agent 接入缺少统一的注册、能力声明、心跳、任务生命周期和取消协议；
- 服务器地址、凭据、工作空间和执行目标没有统一的可脚本化配置。

CLI 需要同时满足人工交互和机器调用：人类用户要有清晰的提示和可读输出，脚本和 Agent 要有稳定的 JSON 输出、退出码和幂等行为。

## 3. 产品目标

### 3.1 MVP 目标

- 在 10 分钟内完成服务地址配置、登录和首次任务查询。
- 用命令行完成任务的查看、创建、更新、执行、取消和日志查看。
- 通过 Runner 将任务派发到 Kairos Server 本机或另一台服务器。
- 为 Agent 提供可验证身份、能力发现、任务领取、事件上报和安全停止能力。
- 为所有敏感操作提供服务端授权、审计和可追踪的执行记录。
- 提供人类可读输出和 `--output json` 机器输出，适合 CI/CD、脚本和自动化 Agent。

### 3.2 非目标

- CLI 不替代 Flutter 客户端的完整任务看板、离线编辑体验或管理后台。
- MVP 不实现任意 SSH 命令代理、反向 Shell、桌面远程控制或浏览器自动化。
- MVP 不允许 Agent 自行提升权限、绕过工作空间隔离或直接访问 PostgreSQL/Redis。
- MVP 不做云托管、计费、多区域调度和跨群组共享。
- 不在 CLI 中嵌入某一家 LLM；Agent 通过适配器或外部进程接入。

## 4. 用户与典型场景

| 用户 | 目标 | 典型场景 |
| --- | --- | --- |
| 个人用户 | 快速管理个人任务 | `kairos task list`、终端中更新截止时间 |
| 群组成员（L1） | 处理被授权的群组任务 | 查看任务、领取可执行任务、查看结果 |
| 群组管理员（L2） | 管理群组 Agent 和执行目标 | 注册 Runner、撤销 Runner、查看执行审计 |
| 超级管理员（L3） | 管理全服务器策略 | 查看全局 Runner 健康和失败任务 |
| CI/脚本 | 无交互地驱动任务 | 以短期 Token 创建任务并等待完成 |
| Agent 开发者 | 接入执行能力 | 声明 `shell`、`filesystem`、`llm` 等能力并消费任务 |

### 4.1 核心用户流程

**首次使用**

```text
kairos server add prod --url https://kairos.example.com
        -> kairos login --server prod
        -> kairos workspace list
        -> kairos workspace use personal
        -> kairos task list
```

**在远程服务器执行任务**

```text
用户/脚本 -> kairos task run TASK_ID --runner build-01
          -> Kairos Server 校验权限并创建 Run
          -> build-01 Runner 领取 Run
          -> Runner 上报状态、日志、产物
          -> CLI 通过 SSE 订阅并展示结果
```

**Agent 自动化**

```text
Runner 启动并加载 Agent Adapter
  -> 使用一次性注册 Token 注册并声明能力
  -> 维持 WSS 心跳
  -> 领取匹配任务
  -> 执行允许的动作
  -> 上报事件/结果/产物
```

## 5. 产品原则

1. 服务端授权优先：CLI 和 Runner 提交的 `user_id`、`workspace_id`、角色、Runner 归属均不可信。
2. 默认安全：TLS、最小权限、短期凭据、命令白名单和明确的人工审批优先于便利性。
3. 可脚本化：命令稳定、输出可预测、JSON Schema 可版本化、退出码有文档。
4. 可恢复：网络断开后可查询 Run 状态；重复提交使用幂等键，不产生重复执行。
5. 人类可读：默认输出适合终端，敏感值和长日志自动脱敏或分页。

## 6. CLI 形态与配置

### 6.1 二进制与兼容性

- 二进制名称：`kairos`。
- 初始实现语言：Go，与现有 Go Server 共享协议模型和版本策略。
- 目标平台：Windows、Linux、macOS；优先提供单文件二进制。
- `kairos version` 输出 CLI 版本、协议版本和构建信息。
- 全局参数：`--server NAME`、`--workspace ID|NAME`、`--output table|json|ndjson`、`--quiet`、`--request-timeout DURATION`、`--wait-timeout DURATION`、`--no-color`、`--insecure`。
- `--request-timeout` 只控制单次 HTTP 请求，默认 15 秒；`--wait-timeout` 只控制 `run --wait` 的本地等待，默认 30 分钟。两者不使用同一个 flag，也不改变服务端 Run 的截止时间。
- `--insecure` 仅允许开发环境跳过证书校验；必须同时设置 `KAIROS_ALLOW_INSECURE=1`，并在交互终端再次输入确认。CI 和非交互模式拒绝该参数。
- `--quiet` 抑制成功时的 stdout；stderr 错误仍保留。与 `--output json/ndjson` 同时使用时仍输出机器可读结果，不能用来隐藏错误。

### 6.2 配置文件

默认路径：

- Windows：`%APPDATA%\\Kairos\\config.yaml`
- Linux/macOS：`$XDG_CONFIG_HOME/kairos/config.yaml`，未设置时为 `~/.config/kairos/config.yaml`
- 凭据不直接写入配置文件，使用操作系统 Keychain/Credential Manager；无可用密钥环时必须显式选择受保护文件并给出警告。

示例：

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

`verify_tls` 只对 HTTPS/WSS 生效；生产 Profile 必须使用 HTTPS/WSS 并保持为 `true`。配置优先级：命令行参数 > 环境变量 > 当前服务 Profile > 配置文件默认值。本文中的“Profile”仅指 `servers.<name>` 下的一条服务配置，不是独立的第二种配置对象；因此不再提供 `--profile` 参数，统一使用 `--server NAME`。支持的环境变量包括 `KAIROS_SERVER_URL`、`KAIROS_TOKEN`、`KAIROS_WORKSPACE`、`KAIROS_OUTPUT`、`KAIROS_REQUEST_TIMEOUT` 和 `KAIROS_WAIT_TIMEOUT`。凭据脱敏、存储和日志规则以 9.2 为唯一权威来源。

凭据存储使用独立的本地凭据存储，不与普通 YAML 配置混用：优先使用 OS Keychain/Credential Manager；无可用密钥环时，默认拒绝保存凭据，仅在显式传入 `--allow-encrypted-file` 后使用由 OS 数据保护 API 加密的凭据文件。Unix 凭据文件权限为 `0600`，Windows 使用当前用户 ACL；“受保护文件”指加密文件，不是仅依赖文件权限的明文文件。

### 6.3 服务地址命令

| 命令 | 说明 | MVP |
| --- | --- | --- |
| `kairos server add NAME --url URL` | 新增服务 Profile | 是 |
| `kairos server list` | 列出 Profile，不显示 Token | 是 |
| `kairos server use NAME` | 切换当前 Profile | 是 |
| `kairos server remove NAME` | 删除 Profile 与凭据 | 是 |
| `kairos server doctor` | 检查 DNS、TLS、版本、认证和依赖 | 是 |

## 7. 功能需求

### 7.1 认证与会话

- `kairos login` 支持浏览器设备码登录；无浏览器环境支持一次性用户码或显式 Token 输入。
- `kairos logout` 撤销本地凭据，并可通过 `--all` 撤销服务端会话。
- `kairos whoami` 显示当前账号、服务地址、全局角色和按工作空间列出的角色；不使用单一“当前角色”字段。
- 支持个人 Token、CI 短期 Token 和 Runner Token 三类凭据；Token 需包含作用域、签发时间、过期时间和撤销状态。凭据安全规则统一见 9.2。
- CLI 在收到 `401` 时只提示重新登录，不自动打印请求头或 Token。
- `kairos token create --scope SCOPE --expires-in DURATION` 创建短期 Token。中央委派使用已定案的 `central:tasks:create` scope 和 `KAIROS_CENTRAL_TOKEN`；其他 CI scope 需由对应的 Token 服务实现。Token 最长 24 小时且只在创建响应中显示一次，CLI 不将 Token 写入配置或日志。

### 7.2 工作空间

| 命令 | 说明 |
| --- | --- |
| `kairos workspace list` | 列出当前账号可访问的个人和群组工作空间 |
| `kairos workspace use ID` | 设置默认工作空间 |
| `kairos workspace current` | 显示当前工作空间 |

`workspace list` 和 `workspace use` 是本地上下文操作，读取列表仍需通过服务端认证。服务端必须按 MVP2 的 Workspace 边界复查每个请求；个人 Workspace 不属于 Group。成员解绑后 CLI 进入只读恢复提示，不能继续上传或执行。

### 7.3 任务操作

| 命令 | 关键参数 | 说明 |
| --- | --- | --- |
| `kairos task list` | `--status`、`--tag`、`--assignee`、`--limit`、`--cursor` | 分页列出任务 |
| `kairos task get ID` | `--events`、`--json` | 查看任务详情和最近事件 |
| `kairos task create` | `--title`、`--description`、`--priority`、`--json-file` | 创建任务，支持 stdin JSON |
| `kairos task update ID` | 字段参数或 `--json-file` | 部分更新，使用版本号防止覆盖 |
| `kairos task comment ID` | `--body` | 追加评论/执行上下文 |
| `kairos task run ID` | `--runner`、`--input JSON|@FILE|-`、`--wait`、`--wait-timeout`、`--consent` | 创建执行 Run |
| `kairos task cancel ID` | `--run RUN_ID`（必填）、`--reason` | 取消指定 Run；省略 `--run` 直接报参数错误，不会批量取消 |
| `kairos task logs ID` | `--run RUN_ID`、`--follow`、`--since RFC3339` | 查看或跟随日志；`--since` 只接受 RFC3339 时间戳 |
| `kairos task result ID` | `--run RUN_ID`、`--artifact NAME|ID` | 查看结果摘要或按唯一名称/ID 下载产物 |

要求：

- 所有写操作支持 `--idempotency-key`，未提供时 CLI 可生成并在重试中复用。
- `task run` 默认只创建 Run 并返回 `run_id`；只有指定 `--wait` 才阻塞等待。输入 `--input JSON` 直接接收 JSON，`--input @FILE` 从文件读取，`--input -` 从 stdin 读取；未传入时为空对象。
- `--wait` 使用 `--wait-timeout`（默认 30 分钟）；超时只代表 CLI 停止等待，不自动取消 Run，并返回退出码 7。
- `--consent` 表示发起人确认本次高风险执行请求，不代表审批通过；旧别名 `--approve` 在 v0.3 中拒绝并提示使用 `--consent`。
- 默认任务正文和日志不写入 shell 历史、诊断报告或错误消息。

`--runner` 为可选参数：指定时服务端只在该 Runner 上调度；省略时服务端按 Workspace 策略、能力匹配、健康状态和并发限制自动选择 Runner，无可匹配 Runner 时 Run 保持 `queued` 直到队列超时。高风险判定由服务端根据请求能力、Workspace 执行策略和 Runner 能力完成；CLI 可在提交前读取策略用于提示，但不能将本地预判作为授权依据。服务端若判定请求为高风险且缺少 `consent`，创建接口返回结构化 `CONSENT_REQUIRED`（不创建 Run）；CLI 据此提示用户重新提交 `--consent`。低风险 Run 不需要 consent。群组高风险 Run 在 consent 后等待非发起人的 L2/L3 审批；个人 Workspace 按已定案的自服务规则免审批，任务所有者可直接 consent 后执行。

### 7.3.1 中央委派任务创建（已定案）

服务器内的中央 CLI/Agent 可使用 L3 账号签发的短期 `central:tasks:create` Token，在指定群组工作空间中为另一名有效群组成员创建任务。该能力必须使用独立命令 `kairos central task create` 和 `/api/v3/central/tasks`，不得通过普通同步操作伪造 `user_id` 或 `created_by_user_id`。

服务端在事务中重新校验：Token scope、当前 L3 角色、Token 对应设备未撤销、群组与工作空间的一致性、群组未归档、目标用户启用且属于群组并绑定有效群组账号。个人工作空间永远不允许中央委派。成功任务的 `tasks.user_id` 与 `tasks.created_by_user_id` 均为目标用户，`tasks.last_operated_by_user_id` 为中央操作者；`source_agent_id` 只用于审计和后续路由，不构成权限提升。

中央 Token 由 `POST /api/v3/tokens` 签发，最长 24 小时且只允许 `central:tasks:create` scope。每个创建请求必须携带 UUID 幂等键；服务端以事务锁和 `sync_operations` 保证并发重试只创建一条任务。审计事件 `central.task.create` 至少包含中央操作者、目标用户、群组、工作空间、Agent ID、请求 ID、幂等键和成功/失败结果。L1/L2、无 scope 的 L3 Token、已解绑/禁用成员和跨群组工作空间请求均返回结构化错误。

示例：

```text
kairos token create --scope central:tasks:create --expires-in 2h
# PowerShell: $env:KAIROS_CENTRAL_TOKEN = "<access_token>"
# Bash: export KAIROS_CENTRAL_TOKEN='<access_token>'
kairos central task create --group GROUP_ID --workspace WORKSPACE_ID \
  --creator-user USER_ID --title "中央 Agent 创建的任务" --agent backup-agent
```

### 7.3.2 Run 命令

| 命令 | 关键参数 | 说明 |
| --- | --- | --- |
| `kairos run list` | `--task TASK_ID`、`--workspace ID`、`--status`、`--limit`、`--cursor` | 发现和分页查看 Run，默认按创建时间倒序 |
| `kairos run get RUN_ID` | `--events`、`--json` | 查看 Run 状态、审批状态、Runner 和时间线 |
| `kairos run approve RUN_ID` | `--reason` | 所属 Workspace 的授权 L2/L3 审批高风险 Run；个人 Workspace 不使用此命令 |
| `kairos run reject RUN_ID` | `--reason`（必填） | 拒绝待审批 Run 并进入 `cancelled` |

### 7.4 Runner/Agent 管理

| 命令 | 说明 | 角色 |
| --- | --- | --- |
| `kairos runner list` | 查看 Runner 状态、版本、能力和最后心跳 | L1 可看被授权目标，L2/L3 可管理 |
| `kairos runner create NAME` | 创建 Runner 注册信息和一次性 Token | L2/L3 |
| `kairos runner revoke ID` | 立即撤销 Runner | L2/L3 |
| `kairos runner inspect ID` | 查看能力、策略、最近 Run 和审计 | L2/L3 |
| `kairos runner install --server URL` | 生成本地安装包/脚本；不负责远程执行 | L2/L3 |
| `kairos runner unquarantine ID` | 解除隔离并触发健康检查 | L2/L3 |
| `kairos runner serve` | 在目标服务器启动 Runner 进程 | Runner 主机 |

Runner 注册信息至少包含：`runner_id`、名称、服务端、所属工作空间/群组、能力清单、版本、平台、最后心跳、并发上限、策略版本和撤销时间。一次性 Token 只显示一次。

`runner install` 只下载或生成安装包、配置模板和一次性注册命令到本地 stdout/文件；MVP 不通过 SSH 或其他远程命令通道执行安装。管理员需要在目标服务器上人工执行生成的安装步骤，再运行 `kairos runner serve`。未来如增加 SSH，必须作为独立、受策略限制的适配器评审。

### 7.5 执行与 Agent 协议

**已定案**：Runner 与服务端使用服务端中转的双向 WSS；CLI 只读订阅使用 SSE，控制操作使用 HTTPS。Runner 只需向外建立连接，目标服务器无需暴露入站端口。SSE 断线后使用 `Last-Event-ID` 恢复，不重复展示已确认事件。

Run 状态转移如下，状态变更责任方和超时均由服务端判定：

| 当前状态 | 目标状态 | 触发事件 | 判定者 | 默认时限 |
| --- | --- | --- | --- | --- |
| `approval_pending` | `queued` | 授权审批人通过 | 服务端 | 默认 15 分钟内 |
| `approval_pending` | `cancelled` | 授权审批人拒绝或用户取消 | 服务端 | 立即，P95 小于 10 秒 |
| `approval_pending` | `timed_out` | 超过审批期限 | 服务端 | 默认 15 分钟 |
| `queued` | `claimed` | Runner 原子领取 | 服务端 | 队列等待策略，默认 24 小时 |
| `queued` | `cancelled` | 用户/审批人取消 | 服务端 | 立即，P95 小于 10 秒 |
| `queued` | `timed_out` | 超过 queue deadline 且未被领取 | 服务端 | 默认 24 小时 |
| `claimed` | `running` | Runner 确认已启动 | 服务端接收 Runner 事件 | 领取后 60 秒 |
| `claimed` | `queued` | 启动确认超时或 Runner 断线 | 服务端 | 60 秒；最多回收 3 次 |
| `claimed` | `cancelled` | 用户/审批人取消 | 服务端 | 立即，P95 小于 10 秒 |
| `claimed` | `timed_out` | 领取阶段超过启动期限且达到回收上限 | 服务端 | 最长 3 分钟 |
| `running` | `succeeded` | Runner 上报成功且校验通过 | 服务端 | 执行策略定义 |
| `running` | `failed` | Runner 上报失败、协议错误或资源限制 | 服务端 | 执行策略定义 |
| `running` | `cancelled` | 服务端下发取消且 Runner 确认停止 | 服务端 | 取消请求后 60 秒 |
| `running` | `cancelled` | 取消请求超过 60 秒仍未收到停止确认，服务端强制结束 Run 并隔离 Runner | 服务端 | 取消请求后 60 秒 |
| `running` | `timed_out` | 超过 Run deadline | 服务端 | 默认 30 分钟，可由策略覆盖 |
| `running` | `timed_out` | Run lease 超过 30 秒未续租 | 服务端 | 30 秒 |

终态为 `succeeded`、`failed`、`cancelled`、`timed_out`，终态不可逆。`queued` 排队等待超过 24 小时（或 Workspace 策略配置的 queue deadline）时进入 `timed_out`。Runner 标记为 `unhealthy` 时，只影响其 `claimed` Run 的回收和新 Run 调度；已经 `running` 的 Run 不因 Runner 进程级健康状态直接改为 `failed`，而是继续由 Run lease 和 Run deadline 判定，Run lease 失效统一进入 `timed_out`。取消强制结束后被隔离的 Runner 会被标记为 `quarantined`：服务端拒绝其领取新 Run、暂停其所有能力调度并保留现有凭据以供审计；只有 L2/L3 显式执行 `kairos runner unquarantine ID` 且重新通过健康检查后才能恢复。Runner 恢复后只可领取新 Run，不能自行恢复已结束 Run。

Run 租约与 Runner 心跳是两套独立机制：Runner 每 15 秒发送进程级心跳，服务端连续 3 个周期未收到即标记 Runner `unhealthy`。`claimed` 阶段不启用 Run lease，只使用服务端记录的 60 秒 claim lease；Runner 必须在该期限内发送启动确认，超时即按表回收或重排队。只有进入 `running` 后，Runner 才为每个 Run 每 10 秒发送 Run lease heartbeat，服务端将租约有效期设为 30 秒，连续超过 30 秒未续租即判定 Run lease expired。Run lease expired 优先于 Runner 健康状态，触发唯一的 `running -> timed_out` 租约失效路径；Runner `unhealthy` 只触发 `claimed -> queued/timed_out` 的回收逻辑。服务端是两类心跳和所有状态转移的唯一判定者。Runner 上报执行失败、协议错误或资源限制均归入唯一的 `running -> failed` 转移。

Runner 能力声明使用版本化 JSON，例如：

```json
{
  "capabilities": [
    {"name": "shell", "version": "1", "allowlist": ["go", "dart", "git"]},
    {"name": "filesystem", "version": "1", "roots": ["D:/workspaces/kairos"]}
  ],
  "max_concurrency": 2
}
```

服务端在派发前同时检查：用户权限、工作空间、Runner 归属、能力匹配、策略和审批状态。Runner 不接受客户端直接传来的任意可执行路径或环境变量覆盖。

### 7.6 人工审批

- 低风险只读任务可按工作空间策略自动执行。
- `shell`、网络访问、写入工作空间外目录、上传产物等高风险能力默认需要审批。
- `kairos task run --consent` 表示发起人确认本次高风险请求。个人 Workspace 采用自服务免审批：任务所有者本人 consent 后即可进入 `queued`，不产生审批任务；群组 Workspace 才需要任务所属群组的非发起人 L2/L3 审批。发起人不能审批自己发起的群组高风险 Run；低风险 Run 不需要 consent 或审批。
- 需要审批的 Run 先进入 `approval_pending`（不属于执行状态机终态），审批通过后进入 `queued`；拒绝进入 `cancelled`，审批超时进入 `timed_out`。默认审批时限 15 分钟，可按 Workspace 策略覆盖。
- CLI `task run --wait` 在审批等待期间保持 SSE 订阅；审批拒绝和审批超时均是服务端 Run 终态，分别返回退出码 6 和 6，并在 JSON 中返回 `approval_status`。只有 CLI 自己停止等待而 Run 尚未进入终态时才返回退出码 7。
- 审批动作通过 `kairos run approve RUN_ID` 和 `kairos run reject RUN_ID --reason` 完成；审批、拒绝、超时和撤销都写入审计事件。

## 8. 服务端配套需求

**已定案**：现有 `/api/v1`、`/api/v2` 保持兼容；执行能力统一进入 `/api/v3`，包括 `/api/v3/runs`、`/api/v3/runners`、`/api/v3/execution-policies` 和 `/api/v3/audit`。不在 `/api/v2` 追加 Run/Runner 字段，避免破坏现有客户端。

建议接口集合：

| 领域 | 接口 |
| --- | --- |
| 认证 | 设备码登录、Token 创建/撤销、当前用户 |
| Runner | 注册、心跳、能力更新、撤销、状态查询 |
| Run | 创建、领取、心跳、取消、状态、日志、事件、产物 |
| 策略 | 工作空间执行策略、审批策略、并发限制 |
| 审计 | Run 和 Runner 的操作审计查询 |

服务端新增数据实体建议：`runners`、`runner_tokens`、`runs`、`run_events`、`run_logs`、`run_artifacts`、`execution_policies`。日志和产物应有大小上限、保留期、内容类型和校验摘要；正文不放入普通审计日志。

## 9. 权限与安全要求

### 9.1 权限矩阵

现有 MVP2 RBAC 映射为：L1=独立成员/群组成员，只能操作本人或被授权的 Workspace；L2=某个 Group 的群组管理员，只在该 Group 生效；L3=全服务器管理员，但个人 Workspace 仍只对所有者可见。

| 能力 | L1 | L2 | L3 |
| --- | --- | --- | --- |
| 查看/选择可访问 Workspace | 是 | 是 | 是（个人仅本人，群组全局） |
| 创建/更新/评论已授权 Task | 是 | 是 | 是（群组范围） |
| 查看自己的 Task Run | 是 | 是 | 是（群组范围） |
| 执行已授权 Task | 是 | 是 | 是 |
| 审批自己发起的高风险 Run | 不适用（个人 Workspace 免审批）；群组为否 | 不适用（个人 Workspace 免审批）；群组为否 | 不适用（个人 Workspace 免审批）；群组为否 |
| 审批所属 Group 的高风险 Run | 否 | 是 | 是 |
| 创建/撤销群组 Runner | 否 | 是（所属 Group） | 是 |
| `runner inspect` | 被授权目标 | 所属 Group | 全服务器 Runner（不含个人任务正文） |
| `runner install` 生成安装包 | 否 | 是（所属 Group） | 是 |
| 修改群组执行策略 | 否 | 是（所属 Group） | 是 |
| 查看全服务器 Runner | 否 | 否 | 是 |
| 导出其他账号个人任务 | 否 | 否 | 否 |

L2/L3 的审批动作必须满足目标 Workspace 的作用域；L3 的全局管理权限不扩大个人 Workspace 的任务读取权限。`runner list` 对 L1 只返回其有权执行的目标，不返回其他群组的 Runner 元数据。

### 9.2 安全底线

- 生产环境只允许 HTTPS/WSS；证书校验默认开启，`--insecure` 必须显式输入确认且仅用于开发。
- 凭据使用 OS 密钥存储；配置文件权限在 Unix 上必须为 `0600`，Windows 使用用户 ACL。
- Runner Token 仅一次显示，支持轮换和立即撤销；日志不输出 Token、Cookie、密码、原始邀请码或完整任务正文。
- Runner 进程使用专用系统用户运行；工作目录、文件根目录、网络出口、CPU/内存/时间和并发受策略限制。
- 命令执行使用参数数组和白名单，不通过 shell 字符串拼接执行。可判定的禁止项包括：任何 `/bin/sh -c`、`cmd.exe /c`、`powershell -Command` 或等效 shell 解析；任何 `eval`、反引号、用户可控字符串拼接为命令的执行路径。
- 服务端验证资源版本和幂等键，防止重放、越权和重复 Run。
- 每次 Run 记录发起人、审批人、Runner、版本、策略摘要、开始/结束时间、退出原因和产物摘要。

## 10. 输出、退出码与错误

默认表格输出适合人类；`--output json` 输出单个 JSON；流式日志使用 NDJSON，每行一个事件。JSON 字段和错误码必须向后兼容并提供 Schema 版本。任何命令在 `--output json` 或 `--output ndjson` 下，成功和失败都输出 JSON 到 stdout；stderr 只输出诊断性文本，脚本应以 stdout 的 `code`、`message`、`request_id` 判断结果。

建议退出码：

| 退出码 | 含义 |
| --- | --- |
| 0 | 成功 |
| 1 | 通用错误 |
| 2 | 参数或配置错误 |
| 3 | 未认证或 Token 过期 |
| 4 | 无权限 |
| 5 | 服务不可达/TLS/协议错误 |
| 6 | Run 已进入服务端非成功终态：`failed`、`cancelled` 或 `timed_out`（包括审批、排队、执行和租约超时） |
| 7 | 仅 CLI 本地等待超时：CLI 停止等待，但 Run 尚未进入终态并继续由服务端运行 |

表格模式的错误输出到 stderr；JSON/NDJSON 模式的错误事件输出到 stdout，并同时以退出码表示失败。所有错误必须包含 `code`、`message`、`request_id` 和可选 `details`，不得包含凭据或未脱敏日志。

## 11. 非功能需求

- 首次命令启动时间：本地配置已存在时 P95 小于 500 ms，不含网络请求。
- 普通查询请求超时默认 15 秒；流式连接支持自动重连和最后事件游标。
- CLI 在网络短暂断开后可恢复查询 Run，不能重复执行同一幂等请求。
- Runner 心跳间隔默认 15 秒，连续 3 个周期无心跳标记为 `unhealthy`。
- 单个 Run 日志默认上限 100 MB，单个产物默认上限 1 GB；超限行为可配置为失败或截断。
- 兼容至少最近两个协议版本；CLI 能对服务端版本给出明确不兼容提示。
- 所有新 API、协议、迁移和 CLI 命令都必须有自动化测试和文档示例。

幂等键策略：服务端写请求必须由调用方显式提供 `--idempotency-key` 才保证跨进程重试一致性；CLI 自动生成的 key 只在当前进程及其重试生命周期内复用，不写入任务正文或普通日志。需要跨进程重试的 CI/脚本必须自行持久化并再次传入同一个 key。

## 12. 里程碑与交付物

### M0：协议与安全设计（第 1 周；后续所有里程碑依赖）

- 冻结已定案的 Run/Runner 状态机、权限矩阵、Token 生命周期和错误码；关闭所有 OPEN 问题。
- 交付 API 草案、事件 JSON Schema、威胁建模和迁移草案；服务端与 CLI 共同评审并签字。

### M1-S：服务端执行基础（第 2-3 周，与 M1 并行；依赖 M0；1 名服务端工程师）

- 实现 `/api/v3` 的认证 Token、Runner 注册/撤销、Run 创建/查询/取消和基础权限中间件。
- 完成数据库迁移、幂等键存储、审计事件和 API 合约测试；M1-S 结束时提供可供 CLI 集成的稳定测试环境。

### M1：CLI 基础与只读能力（第 2-3 周；依赖 M0；1 名 Go 工程师 + 1 名测试工程师）

- Go CLI 工程、配置/Profile、Keychain、登录、`whoami`、工作空间和任务只读命令。
- 交付跨平台构建、命令帮助、JSON 输出和基础测试。

### M2：任务写入与 Run 控制（第 4-5 周；依赖 M1、M1-S 和服务端 API；1 名 Go 工程师 + 1 名服务端工程师）

- 任务创建/更新、Run 创建/取消/等待、日志流和结果查询。
- 服务端幂等、审计、权限和 WebSocket/SSE 事件支持。

### M3：Runner MVP（第 6-8 周；依赖 M2；1 名 Runner/系统工程师 + 1 名服务端工程师）

- Runner 注册、心跳、能力声明、领取任务、受限执行器和产物上传。
- 完成服务器本机与跨服务器部署文档及健康检查。

### M4：灰度与自动化接入（第 9-10 周；依赖 M3；1 名工程师 + 0.5 名 QA/运维）

- CI 示例、Agent SDK/适配器示例、指标面板、故障演练和发布包。

## 13. 验收标准

### 13.1 用户验收

- **控制端拓扑**：新用户只通过 CLI 在 Windows、Linux、macOS 各完成 Profile 配置、登录、选择 Workspace 并查询任务，首次查询成功率 100%。
- **服务器本机拓扑**：在 Kairos Server 同机安装并注册 Runner，创建一个只读 Run；Run 在 60 秒内从 `queued` 进入 `running`，成功或失败均可查询到终态。
- **跨服务器拓扑**：CLI、Kairos Server、Runner 分处三台网络隔离主机；Runner 仅通过出站 WSS 连接，Run 可完成创建、日志跟随和结果下载。
- L1 无法创建或撤销群组 Runner，也无法执行未授权工作空间任务。
- L2 可在所属群组创建 Runner，L3 可查看全服务器 Runner；任何人都不能读取其他账号的个人任务。
- 同一个 `--idempotency-key` 重试不会创建第二个 Task 或 Run。
- `task run --wait --output json` 在成功、失败、取消、审批拒绝、审批超时、CLI 等待超时、Run 执行/排队/租约超时七种结果下分别返回退出码 0、6、6、6、6、7、6，并包含 `run_id`、`status`、`request_id`；所有服务端 `timed_out` 终态统一返回 6。
- 群组 Workspace 的高风险 Run 由非发起 L2/L3 审批通过后才能执行；拒绝在 10 秒内进入 `cancelled`，15 分钟无审批进入 `timed_out`。个人 Workspace 的高风险 Run 按自服务规则免审批，但仍受 owner policy、能力白名单和 `--consent` 约束。
- Runner 断线后，`claimed` Run 按 60 秒启动确认租约回收并最多重排队 3 次；`running` Run 的 lease 每 10 秒续租、有效期 30 秒，超过 30 秒未续租进入 `timed_out`。取消请求 P95 小于 10 秒返回服务端确认；超过 60 秒无停止确认时服务端强制结束 Run 并将 Runner 置为 `quarantined`。
- 任意失败响应都能用 `request_id` 在服务端审计中定位，不泄露凭据。

### 13.2 工程验收

- CLI 单元、协议、集成、跨平台构建和安全回归测试全部通过；关键路径覆盖率不低于 80%。
- TLS 校验、Token 存储、命令白名单、路径逃逸、日志脱敏、重放和越权测试覆盖关键路径。
- 服务器本机 Runner 和独立服务器 Runner 各有一套可重复部署的验收脚本。

## 14. 指标与运营

- 激活：内测用户中 80% 在 10 分钟内完成首次登录和 `task list`。
- 自动化成功率：受策略允许的 Run 成功率不低于 95%，按 Workspace、Runner 和任务类型拆分。
- 调度延迟：健康 Runner 的创建到领取 P50 小于 5 秒、P95 小于 15 秒。
- 执行可靠性：断线回收覆盖率 100%，重复执行率小于 0.1%，取消请求 99% 在 60 秒内生效。
- 安全：撤销 Token 拒绝率 100%，越权请求成功数为 0，命令策略拦截事件 100% 可审计。
- 运维：生产 Runner 月在线率不低于 99%，日志/产物超限事件 100% 告警。

## 15. 风险与决策点

| 风险/问题 | 决策状态与结论 |
| --- | --- |
| CLI 是否直接支持 SSH | 已定案：MVP 不支持任意 SSH；统一通过 Runner，后续增加受限 SSH 适配器 |
| Agent 是进程还是外部服务 | 已定案：MVP 为独立 Runner 进程，Agent 通过本地适配器或子进程接入 |
| 实时通道选 WebSocket 还是 SSE | 已定案：Runner 使用 WSS；CLI 事件订阅使用 SSE；控制操作使用 HTTPS |
| 是否允许服务器本机自动执行 | 已定案：允许，但必须显式安装/注册 Runner，CLI 不隐式启动任意进程 |
| 产物存储位置 | 已定案：MVP 由服务端配置对象存储或本地受限目录，CLI 只通过授权接口访问 |
| CLI 是否离线写入任务 | 已定案：MVP 不做完整离线 outbox；网络恢复后只保证 Run 状态可查询 |

## 16. 后续版本方向

- 受策略约束的 SSH Runner、容器/Kubernetes Runner。
- Agent SDK（Go/Python/TypeScript）和任务触发器（Webhook、定时器、Git 事件）。
- DAG/依赖任务、并发队列、重试策略、人工接管和审批中心。
- 本地缓存和离线任务编辑，与 Flutter 客户端共享同步协议。
- 更细粒度的能力权限、租户级配额、远程缓存和多区域调度。
