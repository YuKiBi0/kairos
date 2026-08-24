# API 变更记录

## MVP 2.0 / API v2

当前实现包含：

- 真实账号、个人工作空间、群组工作空间、花名册和绑定历史。
- 普通邀请码与指定花名册邀请码；有效期最长 30 天，支持无限次或次数限制。
- 固定 L1/L2/L3 角色、群组作用域、不可越级和最后管理员保护。
- 按 `workspace_id` 隔离的 snapshot、changes、push、status 和实时提示。
- 群组协作永久开启开关、显式任务共享，以及任务花名册归属和操作者记录。
- `/KairosAdmin/` 原生管理页面与 `/KairosAdmin/api/*` 管理接口；不提供 `/admin/` 别名。
- Redis 限流、KairosAdmin 会话和敏感操作失败关闭；PostgreSQL 继续作为权威业务存储。
- 被撤权工作空间进入客户端只读恢复区并支持恢复包导出。

完整接口见 [API v2](api-v2.md)，产品和数据边界见 [架构文档](architecture.md) 与 [MVP2 规格](mvp-2.0-spec.md)。

## API v1 / server 0.1.0

- 单真实账号登录、refresh token 轮换、退出和设备会话。
- 个人工作空间 snapshot、cursor changes、批量幂等 push 和字段级冲突。
- 任务、困难点、标签、项目和清单分组同步实体。
- 只发送 `change_hint` 的 WebSocket、15 秒心跳和连接探针确认。
- `/healthz`、带数据库迁移检查的 `/readyz` 和 `/version`。
- 增量响应携带固定 `server_cursor` 高水位；本机游标超前返回 `CURSOR_AHEAD` 并要求重建快照。

## 路径兼容策略

v1 保留用于个人同步兼容；新客户端和群组功能使用 v2。服务端暂未删除 v1 路由，也未承诺永久兼容周期；任何弃用都会先更新本文件、API 文档和客户端迁移说明。
