import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/link_health/presentation/link_health_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tasks/presentation/task_detail_page.dart';
import '../features/tasks/presentation/task_workspace_page.dart';
import 'adaptive_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) =>
          AdaptiveAppShell(location: state.uri.path, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage<void>(child: TaskWorkspacePage()),
        ),
        GoRoute(
          path: '/link-health',
          pageBuilder: (context, state) =>
              const NoTransitionPage<void>(child: LinkHealthPage()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage<void>(child: SettingsPage()),
        ),
      ],
    ),
    GoRoute(
      path: '/tasks/:id',
      builder: (context, state) =>
          TaskDetailPage(taskId: state.pathParameters['id']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('页面不可用')),
    body: Center(child: Text(state.error.toString())),
  ),
);
