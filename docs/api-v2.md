# API v2（MVP 2.0 开发中）

基础路径为 /api/v2，时间使用 RFC 3339 UTC。客户端使用 Bearer 令牌，管理面板使用 HttpOnly、Secure、SameSite=Strict 会话 Cookie 和 CSRF token。所有 workspace_id、group_id、角色均由服务端重新授权。

## 工作空间

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | /workspaces | 当前真实账号可访问的个人和群组空间 |
| GET | /workspaces/{workspace_id} | 工作空间摘要与群组身份 |
| GET | /workspaces/{workspace_id}/sync/snapshot | 首次快照 |
| GET | /workspaces/{workspace_id}/sync/changes | 游标增量 |
| POST | /workspaces/{workspace_id}/sync/push | 幂等批量上传 |
| GET | /workspaces/{workspace_id}/sync/status | 服务端游标状态 |
| GET | /realtime | WebSocket 通知，消息包含 workspace_id，不包含任务正文 |

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
- expires_at 必须晚于当前时间且不超过创建后 30 天。
- max_uses 为空表示有效期内无限次，否则必须大于零。
- 指定 target_group_account_id 时 max_uses 强制为 1，目标必须未绑定。
- 兑换在 PostgreSQL 单事务中锁定邀请和花名册账号；绑定成功后才增加次数。
- 重复提交同一次成功兑换幂等，不重复计数。

## KairosAdmin

- 页面入口：/KairosAdmin/，大小写敏感。
- 管理登录：POST `/KairosAdmin/api/login`；登录后使用 `/KairosAdmin/api/*`。
- 当前管理 API：`/me`、`/logout`、`/groups`、`/groups/{group_id}/accounts`、`/users`（仅 L3）。写请求必须带 `X-CSRF-Token`。
- /admin/、/Admin/ 和其他大小写变体返回 404，不做重定向。
- L2 只能查看自己具有 L2 身份的群组；L3 管理服务器全部资源。

主要错误码：FORBIDDEN_SCOPE、ROLE_ESCALATION、LAST_SUPER_ADMIN、LAST_GROUP_ADMIN、INVITE_EXPIRED、INVITE_REVOKED、INVITE_EXHAUSTED、INVITE_ACCOUNT_BOUND、ALREADY_GROUP_MEMBER、DEPENDENCY_UNAVAILABLE。
