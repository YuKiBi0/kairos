# API 变更记录

## v1 / server 0.1.0

- 单用户登录、refresh token 轮换、退出和设备会话。
- snapshot、cursor changes、批量幂等 push 与字段级冲突结果。
- 任务、困难点、标签、项目和清单分组同步实体。
- 只发送 `change_hint` 的 WebSocket、15 秒心跳和连接探针确认。
- `/healthz`、带数据库迁移检查的 `/readyz` 和 `/version`。
- 增量响应增加固定的 `server_cursor` 高水位；本机游标超前时返回 `CURSOR_AHEAD` 并要求重建快照。
