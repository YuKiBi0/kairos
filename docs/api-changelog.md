# API 变更记录

## v2 / MVP 2.0（开发中）

- 增加真实账号、个人/群组工作空间、群组花名册和绑定历史。
- 增加普通邀请码与花名册认领邀请码，最长 30 天并支持次数限制。
- 增加固定 L1/L2/L3 角色、作用域授权和不可越级规则；L2 可在本群组授予 L1/L2。
- 同步路径按 workspace_id 隔离，WebSocket 通知增加工作空间标识。
- 增加不可逆的群组协作开关和显式任务共享。
- 增加大小写敏感的 /KairosAdmin/ 页面与 /api/v2/kairos-admin/* 管理接口。
- Redis 用于限流、管理会话、缓存和多实例通知，不替代 PostgreSQL 权威状态。

完整契约见 [API v2](api-v2.md)。

## v1 / server 0.1.0

- 单用户登录、refresh token 轮换、退出和设备会话。
- snapshot、cursor changes、批量幂等 push 与字段级冲突结果。
- 任务、困难点、标签、项目和清单分组同步实体。
- 只发送 `change_hint` 的 WebSocket、15 秒心跳和连接探针确认。
- `/healthz`、带数据库迁移检查的 `/readyz` 和 `/version`。
- 增量响应增加固定的 `server_cursor` 高水位；本机游标超前时返回 `CURSOR_AHEAD` 并要求重建快照。
