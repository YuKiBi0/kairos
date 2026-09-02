# Kairos CLI 产品需求与开发 PRD

**文档状态**：Draft v0.1  
**日期**：2026-09-02  
**产品负责人**：Kairos Team  
**目标版本**：CLI MVP 1.0

## 1. 摘要

Kairos CLI 是面向开发者、运维人员和 Agent 的命令行入口。它连接一个 Kairos Server，读取和更新任务、启动任务执行、查看实时日志，并把执行请求路由到一个或多个 Agent Runner。

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
          -> CLI 通过 SSE/WebSocket 订阅并展示结果
```

**Agent 自动化**

```text
Agent Runner 启动
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
- 全局参数：`--server NAME`、`--workspace ID|NAME`、`--profile NAME`、`--output table|json|ndjson`、`--quiet`、`--timeout DURATION`、`--no-color`。

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
    verify_tls: true
```

配置优先级：命令行参数 > 环境变量 > 当前 Profile > 配置文件默认值。支持的环境变量包括 `KAIROS_SERVER_URL`、`KAIROS_TOKEN`、`KAIROS_WORKSPACE`、`KAIROS_OUTPUT`；Token 不得在普通日志中回显。

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
- `kairos whoami` 显示当前账号、角色和服务地址，不显示完整 Token。
- 支持个人 Token、CI 短期 Token 和 Runner Token 三类凭据；Token 需包含作用域、签发时间、过期时间和撤销状态。
- CLI 在收到 `401` 时只提示重新登录，不自动打印请求头或 Token。

### 7.2 工作空间

| 命令 | 说明 |
| --- | --- |
| `kairos workspace list` | 列出当前账号可访问的个人和群组工作空间 |
| `kairos workspace use ID` | 设置默认工作空间 |
| `kairos workspace current` | 显示当前工作空间 |

服务端必须按现有 MVP2 规则复查工作空间权限；成员解绑后 CLI 进入只读恢复提示，不能继续上传或执行。

### 7.3 任务操作

| 命令 | 关键参数 | 说明 |
| --- | --- | --- |
| `kairos task list` | `--status`、`--tag`、`--assignee`、`--limit`、`--cursor` | 分页列出任务 |
| `kairos task get ID` | `--events`、`--json` | 查看任务详情和最近事件 |
| `kairos task create` | `--title`、`--description`、`--priority`、`--json-file` | 创建任务，支持 stdin JSON |
| `kairos task update ID` | 字段参数或 `--json-file` | 部分更新，使用版本号防止覆盖 |
| `kairos task comment ID` | `--body` | 追加评论/执行上下文 |
| `kairos task run ID` | `--runner`、`--input`、`--wait`、`--approve` | 创建执行 Run |
| `kairos task cancel ID` | `--run RUN_ID`、`--reason` | 取消排队或运行中的 Run |
| `kairos task logs ID` | `--run`、`--follow`、`--since` | 查看或跟随日志 |
| `kairos task result ID` | `--run`、`--artifact` | 查看结果摘要或下载产物 |

要求：

- 所有写操作支持 `--idempotency-key`，未提供时 CLI 可生成并在重试中复用。
- `task run` 默认只创建 Run 并返回 `run_id`；只有指定 `--wait` 才阻塞等待。
- `--wait` 默认超时 30 分钟，可用 `--timeout` 覆盖；超时只代表 CLI 停止等待，不自动取消 Run。
- 默认任务正文和日志不写入 shell 历史、诊断报告或错误消息。

### 7.4 Runner/Agent 管理

| 命令 | 说明 | 角色 |
| --- | --- | --- |
| `kairos runner list` | 查看 Runner 状态、版本、能力和最后心跳 | L1 可看被授权目标，L2/L3 可管理 |
| `kairos runner create NAME` | 创建 Runner 注册信息和一次性 Token | L2/L3 |
| `kairos runner revoke ID` | 立即撤销 Runner | L2/L3 |
| `kairos runner inspect ID` | 查看能力、策略、最近 Run 和审计 | L2/L3 |
| `kairos runner install --server URL` | 输出或执行安装脚本 | L2/L3，默认仅输出 |
| `kairos runner serve` | 在目标服务器启动 Runner 进程 | Runner 主机 |

Runner 注册信息至少包含：`runner_id`、名称、服务端、所属工作空间/群组、能力清单、版本、平台、最后心跳、并发上限、策略版本和撤销时间。一次性 Token 只显示一次。

### 7.5 执行与 Agent 协议

MVP 采用服务端中转的双向 WSS 协议；Runner 只需向外建立连接，目标服务器无需暴露入站端口。HTTP API 用于查询和控制，WSS/SSE 用于实时事件。

Run 状态机：

```text
queued -> claimed -> running -> succeeded
                         |-> failed
                         |-> cancelled
                         |-> timed_out
queued -----------------> cancelled
```

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
- `kairos task run --approve` 只表示用户确认本次请求，最终仍由服务端重新校验权限。
- 审批、拒绝、超时和撤销都写入审计事件。

## 8. 服务端配套需求

现有 `/api/v1`、`/api/v2` 保持兼容；新增能力建议挂在 `/api/v3` 或在版本化的 `/api/v2/runs`、`/api/v2/runners` 下，经 API 评审后确定。

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

| 能力 | L1 | L2 | L3 |
| --- | --- | --- | --- |
| 查看自己的任务 Run | 是 | 是 | 是（群组范围） |
| 执行已授权任务 | 是 | 是 | 是 |
| 创建/撤销群组 Runner | 否 | 是 | 是 |
| 修改群组执行策略 | 否 | 是 | 是 |
| 查看全服务器 Runner | 否 | 否 | 是 |
| 导出其他账号个人任务 | 否 | 否 | 否 |

### 9.2 安全底线

- 生产环境只允许 HTTPS/WSS；证书校验默认开启，`--insecure` 必须显式输入确认且仅用于开发。
- 凭据使用 OS 密钥存储；配置文件权限在 Unix 上必须为 `0600`，Windows 使用用户 ACL。
- Runner Token 仅一次显示，支持轮换和立即撤销；日志不输出 Token、Cookie、密码、原始邀请码或完整任务正文。
- Runner 进程使用专用系统用户运行；工作目录、文件根目录、网络出口、CPU/内存/时间和并发受策略限制。
- 命令执行使用参数数组和白名单，不通过 shell 字符串拼接执行；禁止 `eval`、任意反引号和隐式 shell。
- 服务端验证资源版本和幂等键，防止重放、越权和重复 Run。
- 每次 Run 记录发起人、审批人、Runner、版本、策略摘要、开始/结束时间、退出原因和产物摘要。

## 10. 输出、退出码与错误

默认表格输出适合人类；`--output json` 输出单个 JSON；流式日志使用 NDJSON，每行一个事件。JSON 字段和错误码必须向后兼容并提供 Schema 版本。

建议退出码：

| 退出码 | 含义 |
| --- | --- |
| 0 | 成功 |
| 1 | 通用错误 |
| 2 | 参数或配置错误 |
| 3 | 未认证或 Token 过期 |
| 4 | 无权限 |
| 5 | 服务不可达/TLS/协议错误 |
| 6 | Run 失败或被取消 |
| 7 | 等待超时（Run 继续在服务端运行） |

错误输出到 stderr；脚本依赖的机器可读错误必须包含 `code`、`message`、`request_id` 和可选 `details`，不得包含凭据或未脱敏日志。

## 11. 非功能需求

- 首次命令启动时间：本地配置已存在时 P95 小于 500 ms，不含网络请求。
- 普通查询请求超时默认 15 秒；流式连接支持自动重连和最后事件游标。
- CLI 在网络短暂断开后可恢复查询 Run，不能重复执行同一幂等请求。
- Runner 心跳间隔默认 15 秒，连续 3 个周期无心跳标记为 `unhealthy`。
- 单个 Run 日志默认上限 100 MB，单个产物默认上限 1 GB；超限行为可配置为失败或截断。
- 兼容至少最近两个协议版本；CLI 能对服务端版本给出明确不兼容提示。
- 所有新 API、协议、迁移和 CLI 命令都必须有自动化测试和文档示例。

## 12. 里程碑与交付物

### M0：协议与安全设计（1 周）

- 确认 Run/Runner 状态机、权限矩阵、Token 生命周期和错误码。
- 交付 API 草案、事件 JSON Schema、威胁建模和迁移草案。

### M1：CLI 基础与只读能力（1-2 周）

- Go CLI 工程、配置/Profile、Keychain、登录、`whoami`、工作空间和任务只读命令。
- 交付跨平台构建、命令帮助、JSON 输出和基础测试。

### M2：任务写入与 Run 控制（2 周）

- 任务创建/更新、Run 创建/取消/等待、日志流和结果查询。
- 服务端幂等、审计、权限和 WebSocket/SSE 事件支持。

### M3：Runner MVP（2-3 周）

- Runner 注册、心跳、能力声明、领取任务、受限执行器和产物上传。
- 完成服务器本机与跨服务器部署文档及健康检查。

### M4：灰度与自动化接入（1-2 周）

- CI 示例、Agent SDK/适配器示例、指标面板、故障演练和发布包。

## 13. 验收标准

### 13.1 用户验收

- 新用户只通过 CLI 完成 Profile 配置、登录、选择工作空间并查询任务。
- L1 无法创建或撤销群组 Runner，也无法执行未授权工作空间任务。
- L2 可在所属群组创建 Runner，L3 可查看全服务器 Runner；任何人都不能读取其他账号的个人任务。
- 同一个 `--idempotency-key` 重试不会创建第二个 Task 或 Run。
- `task run --wait --output json` 能在成功、失败、取消和超时四种结果下返回稳定退出码。
- Runner 断线后 Run 状态可恢复查询；取消请求最终有明确结果。
- 任意失败响应都能用 `request_id` 在服务端审计中定位，不泄露凭据。

### 13.2 工程验收

- CLI 单元、协议、集成、跨平台构建和安全回归测试全部通过。
- TLS 校验、Token 存储、命令白名单、路径逃逸、日志脱敏、重放和越权测试覆盖关键路径。
- 服务器本机 Runner 和独立服务器 Runner 各有一套可重复部署的验收脚本。

## 14. 指标与运营

- 激活：完成首次登录并成功执行 `task list` 的用户数。
- 自动化成功率：按工作空间、Runner 和任务类型统计 Run 成功率。
- 调度延迟：从 Run 创建到 Runner 领取的 P50/P95。
- 执行可靠性：断线恢复率、重复执行率、取消生效率。
- 安全：被撤销 Token 的拒绝率、越权请求数、命令策略拦截数。
- 运维：Runner 在线率、心跳异常数、日志/产物超限数。

## 15. 风险与决策点

| 风险/问题 | 默认决策 |
| --- | --- |
| CLI 是否直接支持 SSH | MVP 不支持任意 SSH；统一通过 Runner，后续增加受限 SSH 适配器 |
| Agent 是进程还是外部服务 | MVP 为独立 Runner 进程，Agent 通过本地适配器或子进程接入 |
| 实时通道选 WebSocket 还是 SSE | Runner 使用 WSS；CLI 订阅优先 SSE，服务端已有 WebSocket 能力可复用 |
| 是否允许服务器本机自动执行 | 允许，但必须显式安装/注册 Runner，不能由 CLI 隐式启动任意进程 |
| 产物存储位置 | MVP 由服务端配置对象存储或本地受限目录，CLI 只通过授权接口访问 |
| CLI 是否离线写入任务 | MVP 不做完整离线 outbox；网络恢复后只保证 Run 状态可查询 |

## 16. 后续版本方向

- 受策略约束的 SSH Runner、容器/Kubernetes Runner。
- Agent SDK（Go/Python/TypeScript）和任务触发器（Webhook、定时器、Git 事件）。
- DAG/依赖任务、并发队列、重试策略、人工接管和审批中心。
- 本地缓存和离线任务编辑，与 Flutter 客户端共享同步协议。
- 更细粒度的能力权限、租户级配额、远程缓存和多区域调度。
