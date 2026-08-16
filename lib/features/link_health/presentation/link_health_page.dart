import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/theme/organic_theme.dart';
import '../../../domain/entities/realtime_status.dart';

class LinkHealthPage extends ConsumerWidget {
  const LinkHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(realtimeStatusProvider);
    final events = ref.watch(healthEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('链路健康')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final main = <Widget>[
            _ConnectionSummary(
              status: status,
              onCheck: () =>
                  ref.read(realtimeActionsProvider).checkConnection(),
              onReconnect: () => ref.read(realtimeActionsProvider).reconnect(),
            ),
            const SizedBox(height: 16),
            _SyncSummary(
              status: status,
              onSync: () => ref.read(realtimeActionsProvider).synchronizeNow(),
            ),
          ];
          final secondary = <Widget>[
            _EndpointInfo(
              status: status,
              onOpenSettings: () => context.go('/settings'),
            ),
            const SizedBox(height: 16),
            _EventTimeline(events: events),
          ];
          if (constraints.maxWidth >= 960) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: Column(children: main)),
                  const SizedBox(width: 20),
                  Expanded(child: Column(children: secondary)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: <Widget>[
              ...main,
              const SizedBox(height: 16),
              ...secondary,
            ],
          );
        },
      ),
    );
  }
}

class GlobalLinkStatusIcon extends StatelessWidget {
  const GlobalLinkStatusIcon({required this.status, super.key});

  final RealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(status.state);
    final heartbeat = status.lastHeartbeatAtUtc;
    return Tooltip(
      message: heartbeat == null
          ? visual.label
          : '${visual.label} · 最近心跳 ${_formatTime(heartbeat)}',
      child: Semantics(
        label: visual.label,
        child: Icon(visual.icon, color: visual.color),
      ),
    );
  }
}

class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({
    required this.status,
    required this.onCheck,
    required this.onReconnect,
  });

  final RealtimeStatus status;
  final VoidCallback onCheck;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(status.state);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(visual.icon, color: visual.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      visual.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(visual.impact),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _HeartbeatTrace(status: status),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: status.state == RealtimeConnectionState.unconfigured
                    ? null
                    : onCheck,
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('检查连接'),
              ),
              if (status.state == RealtimeConnectionState.reconnecting ||
                  status.state == RealtimeConnectionState.error)
                FilledButton.icon(
                  onPressed: onReconnect,
                  icon: const Icon(Icons.refresh),
                  label: const Text('立即重连'),
                ),
            ],
          ),
          if (status.lastError != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              '${status.lastError!.message}\n${status.lastError!.suggestion}',
              style: const TextStyle(color: KairosColors.clay),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeartbeatTrace extends StatelessWidget {
  const _HeartbeatTrace({required this.status});

  final RealtimeStatus status;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KairosColors.sage, width: 2)),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            status.lastHeartbeatAtUtc == null
                ? '尚无心跳记录'
                : '最近心跳 ${_formatTime(status.lastHeartbeatAtUtc!)}'
                      '${status.roundTripMs == null ? '' : ' · ${status.roundTripMs} ms'}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KairosColors.quietInk),
          ),
        ),
      ),
    ),
  );
}

class _SyncSummary extends StatelessWidget {
  const _SyncSummary({required this.status, required this.onSync});

  final RealtimeStatus status;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('HTTP 增量同步', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _MetricRow(
          label: '最近同步',
          value: status.lastIncrementalSyncAtUtc == null
              ? '尚未完成增量同步'
              : _formatTime(status.lastIncrementalSyncAtUtc!),
        ),
        _MetricRow(label: '服务端游标', value: '${status.serverCursor}'),
        _MetricRow(label: '待上传操作', value: '${status.pendingOperations}'),
        _MetricRow(label: '最近结果', value: status.lastSyncResult ?? '尚无同步结果'),
        _MetricRow(
          label: '最近通知',
          value: status.lastNotificationAtUtc == null
              ? '尚未收到变更通知'
              : '${status.lastNotificationType ?? 'unknown'} · '
                    '${_formatTime(status.lastNotificationAtUtc!)}',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: status.endpoint == null ? null : onSync,
            icon: const Icon(Icons.sync),
            label: const Text('立即同步'),
          ),
        ),
      ],
    ),
  );
}

class _EndpointInfo extends StatelessWidget {
  const _EndpointInfo({required this.status, required this.onOpenSettings});

  final RealtimeStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final endpoint = status.endpoint;
    final safeEndpoint = endpoint == null
        ? '尚未配置'
        : endpoint.replace(query: '', fragment: '').toString();
    final secure = endpoint?.scheme == 'wss';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('端点与会话', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SelectableText(safeEndpoint),
          const SizedBox(height: 10),
          _MetricRow(
            label: '安全状态',
            value: endpoint == null
                ? '未配置'
                : secure
                ? '连接已加密'
                : 'WS 连接未加密',
          ),
          if (endpoint?.scheme == 'ws') ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: KairosColors.clay.withValues(alpha: 0.12),
                border: Border.all(color: KairosColors.clay),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: KairosColors.clay),
                  SizedBox(width: 8),
                  Expanded(child: Text('连接未加密；WS 仅用于可信局域网，公网请改用 HTTPS/WSS。')),
                ],
              ),
            ),
          ],
          _MetricRow(label: '当前会话重连', value: '${status.reconnectCount} 次'),
          _MetricRow(
            label: '心跳结果',
            value:
                '${status.heartbeatSuccesses} 次成功 · ${status.heartbeatFailures} 次失败',
          ),
          _MetricRow(
            label: '下次重试',
            value: status.retryAtUtc == null
                ? '无计划重试'
                : '${_formatTime(status.retryAtUtc!)} · '
                      '${status.retryInterval.inSeconds} 秒退避',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _copyDiagnostics(context),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('复制诊断信息'),
              ),
              TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('打开同步设置'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyDiagnostics(BuildContext context) async {
    final endpoint = status.endpoint
        ?.replace(query: '', fragment: '')
        .toString();
    final text = <String>[
      'state=${status.state.name}',
      'endpoint=${endpoint ?? 'unconfigured'}',
      'last_heartbeat=${status.lastHeartbeatAtUtc?.toIso8601String() ?? 'none'}',
      'round_trip_ms=${status.roundTripMs ?? 'none'}',
      'reconnect_count=${status.reconnectCount}',
      'heartbeat_successes=${status.heartbeatSuccesses}',
      'heartbeat_failures=${status.heartbeatFailures}',
      'server_cursor=${status.serverCursor}',
      'pending_operations=${status.pendingOperations}',
      'error_code=${status.lastError?.code ?? 'none'}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制脱敏诊断信息')));
    }
  }
}

class _EventTimeline extends StatelessWidget {
  const _EventTimeline({required this.events});

  final List<HealthEvent> events;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('最近事件', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text('当前会话尚无连接事件')
        else
          for (final event in events.take(50))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle_outlined, size: 18),
              title: Text(event.type),
              subtitle: Text(
                '${event.stage} · ${_formatTime(event.occurredAtUtc)}',
              ),
            ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFF9F8F2),
      border: Border.all(color: KairosColors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: KairosColors.quietInk),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

({Color color, IconData icon, String label, String impact}) _visualFor(
  RealtimeConnectionState state,
) => switch (state) {
  RealtimeConnectionState.healthy => (
    color: KairosColors.moss,
    icon: Icons.link,
    label: '通知通道在线',
    impact: 'WebSocket 通知可用，数据状态仍以 HTTP 同步为准。',
  ),
  RealtimeConnectionState.reconnecting ||
  RealtimeConnectionState.connecting => (
    color: KairosColors.pollen,
    icon: Icons.sync,
    label: '正在恢复实时通知',
    impact: '任务仍保存在本地，恢复后将执行增量同步。',
  ),
  RealtimeConnectionState.error => (
    color: KairosColors.clay,
    icon: Icons.link_off,
    label: '实时通知不可用',
    impact: '任务仍会保存在本地；恢复连接后通过 HTTP 补齐变更。',
  ),
  RealtimeConnectionState.offline => (
    color: KairosColors.quietInk,
    icon: Icons.cloud_off_outlined,
    label: '设备离线',
    impact: '任务将保存在本地，网络恢复后再同步。',
  ),
  RealtimeConnectionState.authExpired => (
    color: KairosColors.clay,
    icon: Icons.lock_outline,
    label: '需要重新登录',
    impact: '认证已失效，自动重连已停止。',
  ),
  RealtimeConnectionState.unconfigured => (
    color: KairosColors.quietInk,
    icon: Icons.link_off_outlined,
    label: '尚未连接同步服务',
    impact: '当前仅在本机保存任务。',
  ),
};

String _formatTime(DateTime value) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(value.toLocal());
