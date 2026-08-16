import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/organic_theme.dart';
import '../../../domain/entities/taxonomy.dart';
import '../../sync/application/auth_controller.dart';
import '../../sync/application/sync_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _endpointController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _endpointLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_endpointLoaded) {
      _endpointLoaded = true;
      _loadEndpoint();
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadEndpoint() async {
    final value = await ref
        .read(settingsRepositoryProvider)
        .readServiceEndpoint();
    if (mounted) {
      _endpointController.text = value ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(workspaceControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final sync = ref.watch(syncControllerProvider);
    final localSync = ref.watch(localSyncStateProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        children: <Widget>[
          _SettingsSection(
            title: '同步服务',
            description: '服务地址保存在本机；密码和令牌不会写入此处。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _endpointController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '服务地址',
                    hintText: 'https://kairos.example.com',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _saveEndpoint,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存地址'),
                  ),
                ),
              ],
            ),
          ),
          _SettingsSection(
            title: '账户与同步',
            description: '访问令牌只驻留内存，刷新令牌保存在系统安全凭据库。',
            child: auth.phase == AuthPhase.authenticated && auth.session != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified_user_outlined),
                        title: Text(auth.session!.user.username),
                        subtitle: Text(
                          '${auth.session!.device.name} · ${auth.session!.device.platform}',
                        ),
                      ),
                      localSync.when(
                        data: (state) => Text(
                          '服务端游标 ${state?.serverCursor ?? 0} · '
                          '待上传 ${state?.pendingCount ?? 0}',
                        ),
                        error: (error, _) => Text('无法读取同步状态：$error'),
                        loading: () => const LinearProgressIndicator(),
                      ),
                      const SizedBox(height: 6),
                      conflicts.when(
                        data: (items) => Text('待处理冲突 ${items.length}'),
                        error: (error, _) => Text('无法读取冲突：$error'),
                        loading: () => const SizedBox.shrink(),
                      ),
                      if (sync.message != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          sync.message!,
                          style: const TextStyle(color: KairosColors.clay),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: sync.phase == SyncPhase.running
                                ? null
                                : _synchronize,
                            icon: sync.phase == SyncPhase.running
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: const Text('立即同步'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('退出登录'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _usernameController,
                        autofillHints: const <String>[AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const <String>[AutofillHints.password],
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      if (auth.message != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          auth.message!,
                          style: const TextStyle(color: KairosColors.clay),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _login,
                          icon: const Icon(Icons.login),
                          label: const Text('登录同步服务'),
                        ),
                      ),
                    ],
                  ),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            _SettingsSection(
              title: 'Windows 窗口',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('窗口置顶'),
                subtitle: const Text('切换到其他应用时仍保持 Kairos 在前面'),
                value: preferences.alwaysOnTop,
                onChanged: (value) => _setAlwaysOnTop(value),
              ),
            ),
          _TaxonomySettings(),
          _SettingsSection(
            title: '数据',
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined),
                label: const Text('导出 JSON'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEndpoint() async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveServiceEndpoint(_endpointController.text);
      await ref.read(authControllerProvider.notifier).endpointChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('同步服务地址已保存')));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写用户名和密码')));
      return;
    }
    try {
      final deviceId = await ref.read(deviceIdProvider.future);
      await ref
          .read(authControllerProvider.notifier)
          .login(
            username: username,
            password: password,
            deviceId: deviceId,
            deviceName: defaultTargetPlatform == TargetPlatform.windows
                ? 'Kairos Windows'
                : 'Kairos Android',
          );
      _passwordController.clear();
      await _synchronize();
    } on Object {
      _passwordController.clear();
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _synchronize() async {
    try {
      await ref.read(syncControllerProvider.notifier).synchronize();
    } on Object {
      // SyncController exposes the actionable error in its immutable state.
    }
  }

  Future<void> _setAlwaysOnTop(bool value) async {
    try {
      await ref.read(windowsWindowServiceProvider).setAlwaysOnTop(value);
      ref.read(workspaceControllerProvider.notifier).setAlwaysOnTop(value);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('置顶设置未更新：${error.code}')));
      }
    }
  }
}

class _TaxonomySettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    final projects = ref.watch(projectsProvider);
    final groups = ref.watch(checklistGroupsProvider);
    return Column(
      children: <Widget>[
        _SettingsSection(
          title: '标签',
          trailing: IconButton(
            tooltip: '新建标签',
            onPressed: () => _createTag(context, ref),
            icon: const Icon(Icons.add),
          ),
          child: tags.when(
            data: (values) => _TaxonomyList<Tag>(
              values: values,
              nameOf: (tag) => tag.name,
              archivedOf: (tag) => tag.archived,
              onRename: (tag) => _renameTag(context, ref, tag),
              onArchive: (tag, _) =>
                  ref.read(metadataRepositoryProvider).deleteTag(tag.id),
            ),
            error: (error, _) => Text('无法读取标签：$error'),
            loading: () => const LinearProgressIndicator(),
          ),
        ),
        _SettingsSection(
          title: '项目',
          trailing: IconButton(
            tooltip: '新建项目',
            onPressed: () => _createProject(context, ref),
            icon: const Icon(Icons.add),
          ),
          child: projects.when(
            data: (values) => _TaxonomyList<Project>(
              values: values,
              nameOf: (project) => project.name,
              archivedOf: (project) => project.archived,
              onRename: (project) => _renameProject(context, ref, project),
              onArchive: (project, archived) => ref
                  .read(metadataRepositoryProvider)
                  .setProjectArchived(project.id, archived: archived),
            ),
            error: (error, _) => Text('无法读取项目：$error'),
            loading: () => const LinearProgressIndicator(),
          ),
        ),
        _SettingsSection(
          title: '清单分组',
          trailing: IconButton(
            tooltip: '新建清单分组',
            onPressed: () => _createGroup(context, ref),
            icon: const Icon(Icons.add),
          ),
          child: groups.when(
            data: (values) => _TaxonomyList<ChecklistGroup>(
              values: values,
              nameOf: (group) => group.name,
              archivedOf: (group) => group.archived,
              onRename: (group) => _renameGroup(context, ref, group),
              onArchive: (group, archived) => ref
                  .read(metadataRepositoryProvider)
                  .setChecklistGroupArchived(group.id, archived: archived),
            ),
            error: (error, _) => Text('无法读取清单分组：$error'),
            loading: () => const LinearProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final name = await _requestName(context, '新建标签');
    if (name != null) {
      await ref.read(metadataRepositoryProvider).createTag(name);
    }
  }

  Future<void> _renameTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final name = await _requestName(context, '重命名标签', initial: tag.name);
    if (name != null) {
      await ref.read(metadataRepositoryProvider).renameTag(tag.id, name);
    }
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final name = await _requestName(context, '新建项目');
    if (name != null) {
      await ref.read(metadataRepositoryProvider).createProject(name);
    }
  }

  Future<void> _renameProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final name = await _requestName(context, '重命名项目', initial: project.name);
    if (name != null) {
      await ref
          .read(metadataRepositoryProvider)
          .renameProject(project.id, name);
    }
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await _requestName(context, '新建清单分组');
    if (name != null) {
      await ref.read(metadataRepositoryProvider).createChecklistGroup(name);
    }
  }

  Future<void> _renameGroup(
    BuildContext context,
    WidgetRef ref,
    ChecklistGroup group,
  ) async {
    final name = await _requestName(context, '重命名清单分组', initial: group.name);
    if (name != null) {
      await ref
          .read(metadataRepositoryProvider)
          .renameChecklistGroup(group.id, name);
    }
  }

  Future<String?> _requestName(
    BuildContext context,
    String title, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _TaxonomyList<T> extends StatelessWidget {
  const _TaxonomyList({
    required this.values,
    required this.nameOf,
    required this.archivedOf,
    required this.onRename,
    required this.onArchive,
  });

  final List<T> values;
  final String Function(T value) nameOf;
  final bool Function(T value) archivedOf;
  final ValueChanged<T> onRename;
  final void Function(T value, bool archived) onArchive;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Text('尚未创建');
    }
    return Column(
      children: <Widget>[
        for (final value in values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              archivedOf(value)
                  ? Icons.inventory_2_outlined
                  : Icons.label_outline,
            ),
            title: Text(nameOf(value)),
            subtitle: archivedOf(value) ? const Text('已归档') : null,
            trailing: Wrap(
              children: <Widget>[
                IconButton(
                  tooltip: '重命名',
                  onPressed: () => onRename(value),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: archivedOf(value) ? '恢复' : '归档',
                  onPressed: () => onArchive(value, !archivedOf(value)),
                  icon: Icon(
                    archivedOf(value)
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: KairosColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ?trailing,
          ],
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            description!,
            style: const TextStyle(color: KairosColors.quietInk),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}
