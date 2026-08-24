import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/data/remote/remote_models.dart';

void main() {
  test('parses personal and group workspace summaries', () {
    final personal = RemoteWorkspace.fromJson(const <String, dynamic>{
      'id': 'personal-id',
      'kind': 'personal',
      'display_name': '个人任务',
      'role': 'L1',
    });
    final group = RemoteWorkspace.fromJson(const <String, dynamic>{
      'id': 'workspace-id',
      'kind': 'group',
      'display_name': '研发组',
      'role': 'L2',
      'group_id': 'group-id',
    });

    expect(personal.isPersonal, isTrue);
    expect(group.isPersonal, isFalse);
    expect(group.displayName, '研发组');
    expect(group.role, 'L2');
    expect(group.groupId, 'group-id');
  });
}
