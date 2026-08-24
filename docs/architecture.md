# 架构与数据模型

## 分层

Kairos 由三个运行时组成：

1. Flutter 客户端：界面、Riverpod 状态、Drift/SQLite 本地数据、outbox 和同步控制器。
2. Go 服务端：认证、HTTP/WebSocket API、授权、事务、迁移和 Redis 依赖检查。
3. 基础设施：PostgreSQL 保存权威业务状态，Redis 提供限流和 KairosAdmin 会话；当前实时 Hub 为服务进程内实现。

客户端使用 `/api/v1` 维持个人账号兼容路径，MVP2 使用带 `workspace_id` 的 `/api/v2`。WebSocket 只发送游标和实体标识提示，客户端仍通过 changes 接口读取正文。

## 核心边界

### 真实账号与群组账号

`users` 是服务器范围内唯一的可登录真实账号，一人一号。`group_accounts` 是群组花名册身份，不保存密码、不能登录。`group_account_links` 表示真实账号与花名册账号的当前或历史绑定；存在有效绑定即表示加入群组。

约束：一个群组账号同时最多绑定一个真实账号；一个真实账号在同一群组同时最多绑定一个群组账号。解绑不删除花名册、任务归属、历史绑定或审计记录。

### 工作空间

每个真实账号自动拥有一个 `personal` 工作空间。每个群组对应一个 `group` 工作空间。任务、标签、项目、清单、困难点、outbox、变更游标和冲突都通过 `workspace_id` 隔离。

群组任务额外保存 `group_account_id`、`created_by_user_id` 和 `last_operated_by_user_id`。这些字段由服务端生成，客户端不能通过同步操作伪造。

### 角色

| 角色 | 作用域 | 可分配角色 |
| --- | --- | --- |
| L1 独立成员/群组成员 | 个人空间或已加入的群组 | 无角色管理能力 |
| L2 群组管理员 | 自己管理的群组 | L1、L2 |
| L3 超级管理员 | 全服务器 | L1、L2、L3 |

L2 不能跨群组操作，也不能授予 L3。系统保护最后一个 L3；群组保留最后一个 L2，除非 L3 正在接管该群组。所有角色、停用、绑定和邀请操作写入追加式 `audit_events`。

## 邀请码事务

邀请码只保存带服务端密钥摘要，原始码仅在创建响应中返回。创建时 `expires_at` 必填，不能超过创建时间后 30 天；`max_uses = null` 表示有效期内不限次数。指定 `target_group_account_id` 时强制 `max_uses = 1`。

兑换在 PostgreSQL 单事务中锁定邀请码和目标花名册账号，复查撤销、过期、次数、绑定和成员关系后创建绑定及兑换记录。只有绑定事务成功才增加次数；幂等键重复提交返回原结果。Redis 只负责每个真实账号每 60 秒最多 10 次尝试的限流。

## 协作与撤权

群组协作默认关闭，`collaboration_enabled_at` 只能从空写入一次，数据库触发器阻止回退。开启后，任务仍需通过 `shared_at` 显式共享；历史任务不会自动暴露。

成员撤权后，服务端同步返回 `403 FORBIDDEN_SCOPE`。客户端将空间置为只读，暂停 outbox 上传，并允许导出不含凭据的 `kairos-recovery-*.json` 恢复包。

## Redis 降级

Redis 不是账号、任务、邀请次数或审计的权威来源。当前代码使用 Redis 限流和 KairosAdmin 会话，实时通知仍由单进程 Hub 提供。Redis 不可用时：

- 个人任务读写和 PostgreSQL 同步不丢数据。
- 管理登录、管理会话、邀请码兑换、群组/角色/绑定/协作写操作失败关闭，返回 `503 DEPENDENCY_UNAVAILABLE`。
- `/healthz` 返回 `degraded`；`KAIROS_REDIS_REQUIRED=true` 时 `/readyz` 返回 `503 REDIS_UNAVAILABLE`。

## 迁移

迁移位于 `server/migrations/`，当前包含 `000001` 至 `000007`。生产升级先备份 PostgreSQL，再执行 `kairos-server migrate`，确认 `/readyz` 后启动新二进制。已有群组数据后不执行破坏性的 down migration；回滚以旧二进制和备份恢复为主。
