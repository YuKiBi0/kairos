# Kairos MVP 2.0 实施与发布计划

MVP2 的核心实现已经完成。本文件记录当前交付状态、发布顺序和后续工程门禁，不再把已完成能力列为待开发功能。

## 当前交付状态

| 领域 | 状态 | 验收依据 |
| --- | --- | --- |
| PostgreSQL 迁移与个人工作空间 | 已完成 | `000001`-`000007` 迁移和迁移脚本 |
| Redis 健康、限流、管理会话和失败关闭 | 已完成 | Redis client/HTTP 测试 |
| 群组、花名册、绑定和多群组访问 | 已完成 | store/http 集成测试 |
| 普通/认领邀请码、30 天边界、次数和幂等 | 已完成 | invite store/http 测试 |
| L1/L2/L3 RBAC、作用域和最后管理员保护 | 已完成 | group/admin 集成测试 |
| v2 工作空间同步、客户端切换和隔离 | 已完成 | workspace sync 测试和客户端数据测试 |
| 协作永久开启、显式任务共享和任务归属 | 已完成 | collaboration/roster ownership 测试 |
| 撤权只读恢复区和恢复包导出 | 已完成 | HTTP 403 和客户端恢复测试 |
| KairosAdmin 页面、CSRF/CSP/会话和入口保护 | 已完成 | static/admin API 测试 |
| Flutter 全平台发布构建 | 发布前门禁 | 取决于本机 Flutter SDK、签名和平台工具链 |

## 版本交付顺序

后续发布按以下顺序执行，每一步通过门禁后再进入下一步：

1. 备份 PostgreSQL，记录当前服务版本、迁移版本和 Redis 状态。
2. 在临时数据库执行完整迁移和集成测试，确认空库及已有 v1 数据均可升级。
3. 构建 Go 服务端，记录二进制 SHA-256；执行 `go test`、`go vet` 和 `git diff --check`。
4. 恢复 Flutter SDK 权限后执行 `flutter analyze`、单元/组件/集成测试和 Windows/Android 构建。
5. 在预发布环境运行 `/healthz`、`/readyz`、登录、创建群组、邀请码兑换、切换空间和撤权恢复流程。
6. 先发布服务端，再发布客户端；保留上一版二进制用于回滚。
7. 发布后观察登录失败、邀请码兑换、Redis 降级、同步冲突和工作空间拒绝指标。

## Git 合并策略

当前远端保留 `codex/feature-mvp2-client-workspaces` 这一条包含完整 MVP2 提交链的分支。推荐创建一个总 PR：

```text
codex/feature-mvp2-client-workspaces -> develop
```

本地的 `codex/feature-mvp2-foundation`、`codex/feature-mvp2-sync-v2` 和 `codex/feature-mvp2-admin` 是阶段性分支；只有需要拆分评审时才将它们推送为 stacked PR，并按 foundation → sync-v2 → admin → client-workspaces 顺序合并。

## 回滚策略

- 应用回滚：停止服务，恢复上一版二进制，重新启动并检查 `/readyz`。
- 数据库回滚：优先恢复备份；已有 MVP2 数据后不执行破坏性的 down migration。
- 客户端回滚：保留本地 SQLite 和 outbox，先完成兼容的服务端回滚，再发布客户端旧版本。
- Redis 故障：保持服务运行在降级模式；敏感操作失败关闭，恢复 Redis 后再重试，不从 Redis 恢复 PostgreSQL 权威数据。

## 后续候选工作

正式发布后再评估：后台任务同步、JSON 导入、回收站、外部身份提供商、细粒度权限码、群组嵌套、跨群组共享和正式 API 弃用周期。任何新增能力都必须先更新 [MVP2 规格](mvp-2.0-spec.md)、API 文档、迁移说明和测试门禁。
