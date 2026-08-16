# API v1

基础路径为 `/api/v1`，正文使用 JSON，时间使用 RFC 3339 UTC。受保护接口要求 `Authorization: Bearer <access_token>`。访问令牌或刷新令牌不得出现在 URL、日志或 WebSocket query 中。

错误响应：

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "请求无效",
    "request_id": "uuid"
  }
}
```

## 认证

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/auth/login` | 用户名、密码和设备信息换取 access/refresh token |
| POST | `/auth/refresh` | 轮换 refresh token |
| POST | `/auth/logout` | 撤销当前 refresh token |
| GET | `/auth/me` | 当前用户和设备 |

登录正文：

```json
{
  "username": "owner",
  "password": "<not-logged>",
  "device": {"id": "uuid", "name": "Kairos Windows", "platform": "windows"}
}
```

## 同步

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/sync/snapshot` | 首次完整快照与 cursor |
| GET | `/sync/changes?after=0&limit=200` | cursor 后的完整实体或 tombstone |
| POST | `/sync/push` | 最多 50 个幂等 operation |
| GET | `/sync/status` | 服务端 cursor 与设备 ID |

Push operation：

```json
{
  "operation_id": "uuid",
  "entity_type": "task",
  "entity_id": "uuid",
  "base_version": 12,
  "changes": {"title": "新的标题"},
  "changed_fields": ["title"]
}
```

逐项结果为 `applied`、`duplicate`、`conflict` 或 `rejected`。`conflict` 包含当前服务端实体和冲突字段；客户端必须保留本地草稿并让用户选择版本。

支持的同步实体：`task`、`blocker`、`tag`、`project`、`checklist_group`。任务树深度、循环、归类所有权和字段级版本在服务端再次验证。

## 实时通知

连接 `GET /api/v1/realtime`，在握手 header 中发送 Bearer token。消息只含连接、心跳、游标和实体标识，不含任务标题、描述或 DDL：

```json
{"type":"ready","connection_id":"uuid","server_cursor":42,"heartbeat_interval_sec":15}
{"type":"heartbeat","server_time":"2026-08-16T10:42:03Z"}
{"type":"heartbeat_ack","client_time":"2026-08-16T10:42:03Z"}
{"type":"change_hint","cursor":43,"entity_type":"task","entity_id":"uuid","entity_version":3}
```

`change_hint` 只是提示。客户端始终调用 `/sync/changes` 获取实际数据；重连、心跳和前台恢复也会按本地 cursor 补拉。

## 读取与健康

- `GET /tasks/{id}`、`GET /tasks/{id}/descendants?depth=5`
- `GET /tags`、`GET /projects`、`GET /checklist-groups`
- `GET /healthz`、`GET /readyz`、`GET /version`（无 `/api/v1` 前缀）

正常任务写入走本地 outbox 和 `/sync/push`，按需读取接口不能绕过离线优先模型。
