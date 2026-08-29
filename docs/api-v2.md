# API v2

API v2 是 MVP 2.0 的多工作空间接口。基础路径为 `/api/v2`，正文使用 JSON，时间使用 RFC 3339 UTC。客户端使用 Bearer token；KairosAdmin 使用 HttpOnly、Secure、SameSite 管理会话 Cookie 和 CSRF token。服务端每次请求重新校验工作空间和群组角色。

## 工作空间与同步

| 方法 | 路径 | 最低条件 | 说明 |
| --- | --- | --- | --- |
| GET | `/workspaces` | 已登录 | 当前真实账号可访问的个人和群组空间 |
| GET | `/workspaces/{workspace_id}` | 空间成员 | 工作空间摘要、群组身份和角色 |
| GET | `/workspaces/{workspace_id}/sync/snapshot` | 空间成员 | 首次快照 |
| GET | `/workspaces/{workspace_id}/sync/changes` | 空间成员 | 游标增量 |
| POST | `/workspaces/{workspace_id}/sync/push` | 空间成员 | 幂等批量上传 |
| GET | `/workspaces/{workspace_id}/sync/status` | 空间成员 | 服务端游标 |

群组任务默认仅创建者可见。L2/L3 开启协作后，任务所有者或管理员可通过同步操作写入 `shared_at` 显式共享；未共享任务对其他成员不可见，也不能写入。个人工作空间不接受 `shared_at`。

群组任务中的 `group_account_id`、`created_by_user_id` 和 `last_operated_by_user_id` 由服务端维护，客户端不能通过 operation 伪造。

当前服务端的实时连接仍是 v1 的 `GET /api/v1/realtime`；v2 路由提供空间目录和按工作空间隔离的同步接口。实时消息不包含任务正文，客户端始终以 changes 接口为准。

## 群组与花名册

| 方法 | 路径 | 最低角色 | 说明 |
| --- | --- | --- | --- |
| POST | `/groups` | 已登录 | 创建群组，创建者自动成为首个 L2 |
| GET | `/groups/{group_id}` | 群组成员 | 群组资料 |
| PUT | `/groups/{group_id}/archived` | L2/L3 | 停用或恢复群组；停用后禁止新建任务，历史数据保留 |
| DELETE | `/groups/{group_id}` | L3 | 永久删除服务端群组及其工作空间数据；客户端本地数据库不删除 |
| GET | `/groups/{group_id}/accounts` | L2/L3 | 花名册 |
| POST | `/groups/{group_id}/accounts` | L2/L3 | 创建群组账号 |
| POST | `/groups/{group_id}/accounts/{account_id}/bind` | L2/L3 | 绑定真实账号 |
| POST | `/groups/{group_id}/accounts/{account_id}/unbind` | L2/L3 | 解绑并撤权 |
| PUT | `/groups/{group_id}/accounts/{account_id}/role` | L2/L3 | 分配 L1/L2/L3，受越级规则限制 |
| POST | `/groups/{group_id}/collaboration` | L2/L3 | 永久开启协作 |

停用群组不会删除任务、花名册或同步记录，恢复后可继续创建任务。移出成员使用解绑接口：该成员立即失去群组目录和同步权限，已有本地数据保留且不会被客户端强制删除。正在进行的上传以服务端权限检查为准，可能返回 `403 FORBIDDEN_SCOPE`。

L2 只能管理自己具有 L2 身份的群组，不能查看全服务器账号或授予 L3。L3 可以管理所有群组和服务器账号。绑定请求使用精确的 `user_id`，不会提供模糊账号枚举。

## 邀请码

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/groups/{group_id}/invites` | 查看元数据，不返回原始码 |
| POST | `/groups/{group_id}/invites` | 创建邀请码，原始码只在创建响应返回 |
| DELETE | `/groups/{group_id}/invites/{invite_id}` | 撤销邀请码 |
| POST | `/group-invites/redeem` | 当前真实账号兑换邀请码 |

创建请求示例：

```json
{
  "target_group_account_id": "uuid-or-omit",
  "max_uses": null,
  "expires_at": "2026-08-30T12:00:00Z"
}
```

`expires_at` 必须晚于当前时间且不超过创建后 30 天；`max_uses=null` 表示有效期内不限次数；指定 `target_group_account_id` 时强制单次使用。兑换请求必须携带 UUID `idempotency_key`，每个真实账号每 60 秒最多 10 次尝试。Redis 不可用返回 `503 DEPENDENCY_UNAVAILABLE`，超限返回 `429 RATE_LIMITED`。

## KairosAdmin

页面入口是大小写敏感的 `/KairosAdmin/`，`/admin/`、`/Admin/` 和其他变体均返回 404。

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/KairosAdmin/api/login` | 建立管理会话 |
| GET | `/KairosAdmin/api/me` | 当前管理员和 CSRF token |
| POST | `/KairosAdmin/api/logout` | 注销会话 |
| GET/POST | `/KairosAdmin/api/users` | L3 查看/创建服务器账号 |
| PUT | `/KairosAdmin/api/users/{user_id}/disabled` | L3 停用或恢复账号 |
| PUT | `/KairosAdmin/api/users/{user_id}/super-admin` | L3 管理 L3 |
| GET/POST | `/KairosAdmin/api/groups` | 按作用域查看或创建群组 |
| PUT/DELETE | `/KairosAdmin/api/groups/{group_id}/archived`、`/KairosAdmin/api/groups/{group_id}` | L2/L3 停用/恢复；仅 L3 可永久删除 |
| GET/POST | `/KairosAdmin/api/groups/{group_id}/accounts` | 花名册 |
| PUT/POST | `/KairosAdmin/api/groups/{group_id}/accounts/{account_id}/role` | 角色、绑定和解绑 |
| POST | `/KairosAdmin/api/groups/{group_id}/collaboration` | 开启协作 |
| GET/POST/DELETE | `/KairosAdmin/api/groups/{group_id}/invites` | 邀请码管理 |

所有写请求带 `X-CSRF-Token`。L2 只能看到和管理自己的群组，L3 管理全服务器。管理登录和敏感写操作依赖 Redis，按账号摘要限流每 60 秒最多 10 次。

## 错误码

常见错误包括：`UNAUTHORIZED`、`FORBIDDEN_SCOPE`、`GROUP_ARCHIVED`、`ROLE_ESCALATION`、`LAST_SUPER_ADMIN`、`LAST_GROUP_ADMIN`、`INVITE_INVALID`、`INVITE_EXPIRED`、`INVITE_REVOKED`、`INVITE_EXHAUSTED`、`INVITE_ACCOUNT_BOUND`、`ALREADY_GROUP_MEMBER`、`DEPENDENCY_UNAVAILABLE`、`RATE_LIMITED` 和 `CURSOR_AHEAD`。

## 撤权恢复

群组成员失去访问权后，工作空间同步返回 `403 FORBIDDEN_SCOPE`。客户端把该空间标记为只读、暂停待上传操作，并可导出 `kairos-recovery-*.json` 恢复包；恢复包包含本地业务数据和待上传操作，不包含凭据。
