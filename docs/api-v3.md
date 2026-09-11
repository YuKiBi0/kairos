# API v3：中央委派

中央委派 API 供服务器内的 Kairos CLI、CI 控制器或 Agent 调用。它只允许在群组工作空间中为指定的有效群组成员创建任务，不能访问或写入个人工作空间。

## 安全模型

1. 使用 `POST /api/v1/auth/login` 登录服务器 L3 账号；中央 CLI 与普通 CLI 共享这份登录会话。
2. CLI 在当前系统用户的凭据存储中保存 access/refresh token，并在 access token 临期时自动续期，因此同一服务器用户的新终端可以复用登录态。
3. 调用中央任务接口时，服务端重新校验登录令牌、对应设备未撤销、当前账号仍是 L3，以及目标成员、群组和工作空间关系。
4. 不提供中央令牌签发接口，也不需要中央 scope 或单独注入中央凭据。
5. 请求中的 `creator_user_id` 只表示任务归属成员，不会改变真实认证操作者。服务端写入：
   - `tasks.user_id`：目标成员；
   - `tasks.created_by_user_id`：目标成员；
   - `tasks.last_operated_by_user_id`：中央操作者。

## 创建委派任务

```http
POST /api/v3/central/tasks
Authorization: Bearer <L3 login access token>
Idempotency-Key: 44444444-4444-4444-4444-444444444444
Content-Type: application/json

{
  "group_id": "11111111-1111-1111-1111-111111111111",
  "workspace_id": "22222222-2222-2222-2222-222222222222",
  "creator_user_id": "33333333-3333-3333-3333-333333333333",
  "title": "检查生产备份",
  "description": "由中央 Agent 创建",
  "quadrant": 1,
  "source_agent_id": "backup-agent",
  "idempotency_key": "44444444-4444-4444-4444-444444444444"
}
```

也可以使用 `creator_username` 代替 `creator_user_id`。用户名必须精确匹配；两个字段不能同时提供。`Idempotency-Key` 请求头和 JSON 字段必须对应同一个 UUID，至少提供一个。

首次创建返回 `201`，响应包含任务 JSON（内部 `user_id`、工作空间字段不会直接暴露）：

```json
{
  "task": {
    "id": "55555555-5555-5555-5555-555555555555",
    "title": "检查生产备份",
    "quadrant": 1,
    "status": 0,
    "created_by_user_id": "33333333-3333-3333-3333-333333333333",
    "last_operated_by_user_id": "<central operator>"
  },
  "request_id": "<server request id>"
}
```

使用相同幂等键重试返回 `200` 和 `"duplicate": true`，不会创建第二个任务。服务端用事务锁、任务插入、同步变更、审计事件和幂等记录保证原子性。

## 错误码

| HTTP | 错误码 | 说明 |
| ---: | --- | --- |
| 400 | `VALIDATION_ERROR` | UUID、标题、优先级或幂等键无效 |
| 400 | `WORKSPACE_GROUP_MISMATCH` | 工作空间不是指定群组工作空间 |
| 401 | `UNAUTHORIZED` | 令牌无效、过期或设备已撤销 |
| 403 | `FORBIDDEN_ROLE` | 当前登录账号不是 L3 |
| 403 | `TARGET_NOT_GROUP_MEMBER` | 目标账号未绑定、已解绑、已禁用或不属于群组 |
| 409 | `GROUP_ARCHIVED` | 归档群组不能创建新任务 |
| 409 | `IDEMPOTENCY_KEY_REUSED` | 幂等键已被其他中央操作者使用 |

失败请求也会尝试写入 `central.task.create` 审计事件；成功审计至少包含中央操作者、目标用户、群组、工作空间、Agent ID、请求 ID 和幂等键。
