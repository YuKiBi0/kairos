# Kairos

Kairos 是面向 Windows 与 Android 的离线优先个人任务管理器。客户端使用 Flutter、Riverpod 与 Drift；自部署同步服务使用 Go、PostgreSQL、HTTP 增量同步和只传递变更提示的 WebSocket。

## MVP 能力

- 列表、树和四象限视图，共享搜索、范围、状态、DDL、困难点及归类筛选。
- 最多五层的任务树、同级排序、任务移动、递归进度和软删除撤销。
- 标签、项目、清单分组、推进困难点、可选 DDL 和 JSON 导出。
- 本地事务写入与 outbox；登录后执行 snapshot、pull、push、pull 同步闭环。
- 字段级冲突提示、WebSocket 重连/心跳诊断和通知触发 HTTP 补同步。
- Windows 自定义标题栏与置顶；Android 单列布局和下拉同步。

## 开发

要求 Flutter `3.41.7` / Dart `3.11.5`、Go `1.26` 和 PostgreSQL `18`。

```bash
flutter pub get
flutter analyze
flutter test

cd server
go test ./...
KAIROS_TEST_DATABASE_URL='postgres://...' go test -tags integration ./...
```

服务端本地启动、数据库迁移与用户初始化见 [部署文档](docs/deployment.md)。客户端构建见 [构建文档](docs/build.md)，协议见 [API 文档](docs/api.md)。

真实 `.env`、数据库密码、令牌、证书和签名文件不得提交。仓库只跟踪 [server/.env.example](server/.env.example)。
