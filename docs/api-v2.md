# API v2（MVP 2.0 开发中）

基础路径为 /api/v2，时间使用 RFC 3339 UTC。客户端使用 Bearer 令牌，管理面板使用 HttpOnly、Secure、SameSite=Strict 会话 Cookie 和 CSRF token。所有 workspace_id、group_id、角色均由服务端重新授权。

## 工作空间

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | /workspaces | 当前真实账号可访问的个人和群组空间，包含 display_name 与 role |
| GET | /workspaces/{workspace_id} | 工作空间摘要与群组身份 |
| GET | /workspaces/{workspace_id}/sync/snapshot | 首次快照 |
| GET | /workspaces/{workspace_id}/sync/changes | 游标增量 |
| POST | /workspaces/{workspace_id}/sync/push | 幂等批量上传 |
| GET | /workspaces/{workspace_id}/sync/status | 服务端游标状态 |
| GET | /realtime | WebSocket 通知，消息包含 workspace_id，不包含任务正文 |

群组任务默认只对创建者可见。群组管理员开启协作后，任务所有者（或群组管理员）可通过同步操作写入 `shared_at` 时间戳显式共享；将其写回 `null` 会撤销共享。未共享任务对其他成员的快照和增量接口返回不可见/删除标记，成员不能写入。个人工作空间不接受 `shared_at`。

群组任务同步实体额外包含 `group_account_id`、`created_by_user_id` 和 `last_operated_by_user_id`：前者记录花名册归属，后两者记录真实账号的创建者和最后操作者；这些字段由服务端写入，客户端不能通过任务变更伪造。

## 群组和花名册

| 方法 | 路径 | 最低角色 |
| --- | --- | --- |
| POST | /groups | 已登录真实账号；创建者自动成为首个 L2 |
| GET | /groups/{group_id} | 群组 L1 |
| GET/POST | /groups/{group_id}/accounts | 群组 L2 |
| PATCH | /groups/{group_id}/accounts/{id} | 群组 L2 |
| POST | /groups/{group_id}/accounts/{id}/bind | 群组 L2，精确账号标识 |
| POST | /groups/{group_id}/accounts/{id}/unbind | 群组 L2 |
| POST | /groups/{group_id}/collaboration | 群组 L2，永久开启 |
| PUT | /groups/{group_id}/accounts/{id}/role | L2 可授予 L1/L2，L3 可授予 L1/L2/L3 |

## 邀请码

- GET /groups/{group_id}/invites 查看邀请码元数据（不返回原始码）。
- POST /groups/{group_id}/invites 创建邀请码；原始码只在创建响应返回。
- DELETE /groups/{group_id}/invites/{id} 撤销邀请码。
- POST /group-invites/redeem 由当前真实账号兑换邀请码。
- 兑换请求必须携带 UUID `idempotency_key`；同一成功兑换重复提交返回原结果，不重复计数。
- 兑换按真实账号限制为每 60 秒最多 10 次尝试；超限返回 `429 RATE_LIMITED`，Redis 不可用时失败关闭并返回 `503 DEPENDENCY_UNAVAILABLE`。
- expires_at 必须晚于当前时间且不超过创建后 30 天。
- max_uses 为空表示有效期内无限次，否则必须大于零。
- 指定 target_group_account_id 时 max_uses 强制为 1，目标必须未绑定。
- 兑换在 PostgreSQL 单事务中锁定邀请和花名册账号；绑定成功后才增加次数。
- KairosAdmin 在 `/KairosAdmin/api/groups/{group_id}/invites` 提供同等的列表、创建和撤销能力，并沿用管理会话、CSRF 与 L2/L3 群组作用域。
- 群组创建、花名册创建/绑定/解绑、邀请码创建/撤销、协作开关、角色变更和 KairosAdmin 全部写操作在 Redis 不可用时失败关闭并返回 `503 DEPENDENCY_UNAVAILABLE`。
- 重复提交同一次成功兑换幂等，不重复计数。

## KairosAdmin

- 页面入口：/KairosAdmin/，大小写敏感。
- 管理登录：POST `/KairosAdmin/api/login`；登录后使用 `/KairosAdmin/api/*`。
- 管理登录按账号摘要每 60 秒最多允许 10 次尝试；Redis 不可用时返回 `503 DEPENDENCY_UNAVAILABLE`，超限返回 `429 RATE_LIMITED`。
- 当前管理 API：`/me`、`/logout`、`/groups`、`/groups/{group_id}/accounts`、`/users`（仅 L3）。写请求必须带 `X-CSRF-Token`。
- /admin/、/Admin/ 和其他大小写变体返回 404，不做重定向。
- L2 只能查看自己具有 L2 身份的群组；L3 管理服务器全部资源。

主要错误码：FORBIDDEN_SCOPE、ROLE_ESCALATION、LAST_SUPER_ADMIN、LAST_GROUP_ADMIN、INVITE_EXPIRED、INVITE_REVOKED、INVITE_EXHAUSTED、INVITE_ACCOUNT_BOUND、ALREADY_GROUP_MEMBER、DEPENDENCY_UNAVAILABLE、RATE_LIMITED。

## 客户端撤权恢复

群组成员失去访问权后，工作空间同步返回 `403 FORBIDDEN_SCOPE`；客户端将该空间标记为只读，暂停待上传操作，不再重试提交。设置页可导出 `kairos-recovery-*.json` 恢复包，文件包含本地业务数据和待上传操作，不包含凭据。
