# 测试与质量门禁

## 本地检查

服务端：

```powershell
cd server
go test ./... -count=1 -p 1
go vet ./...
```

迁移脚本：

```powershell
pwsh -File .\scripts\test-migrations.ps1
```

客户端：

```powershell
flutter pub get
flutter analyze
flutter test
flutter test integration_test
```

Drift schema 变化后先生成代码：

```powershell
dart run build_runner build --delete-conflicting-outputs
```

提交前还应执行：

```powershell
git diff --check
node --check server/internal/httpapi/admin/app.js
```

## 覆盖范围

服务端测试必须覆盖：

- PostgreSQL 迁移在空库和已有 v1 数据上的升级。
- 个人与群组工作空间隔离、游标超前、重复 operation 和字段冲突。
- 普通邀请码、指定花名册邀请码、30 天边界、无限次、次数耗尽、撤销和并发兑换。
- 一人一号、多群组加入、解绑撤权、重绑、L2/L3 作用域、角色越级和最后管理员保护。
- 协作开关不可逆、任务显式共享、创建者与最后操作者字段不可伪造。
- Redis 正常、断连、超时和限流；敏感写操作必须失败关闭。
- `/KairosAdmin/` 入口、`/admin/` 404、会话 Cookie、CSRF、CSP、L2/L3 管理范围。

客户端测试必须覆盖：

- 每个工作空间独立的本地数据库、游标、冲突和 outbox。
- 在个人任务和多个群组任务之间切换不会串数据。
- 被撤权空间进入只读恢复区，恢复包不包含凭据。
- Windows/Android 目标平台的基本构建。

## 发布门禁

发布前必须确认：

1. Go 格式化、`go vet`、单元测试和 PostgreSQL/Redis 集成测试通过。
2. Flutter `analyze`、单元/组件/集成测试和目标平台构建通过。
3. 迁移、部署、API、错误码和已知限制文档与实现一致。
4. 日志、响应、管理页面和测试夹具不包含密码、令牌、原始邀请码或任务正文。
5. 备份、回滚二进制、Redis 断连和最后管理员保护均有演练记录。

当前环境若 Flutter SDK 的全局 lockfile 权限阻塞测试，应在发布前恢复权限并补跑完整 Flutter 门禁；不能将未运行的测试标记为通过。
