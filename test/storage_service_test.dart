import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('同一文件的并发写入按提交顺序完成', () async {
    final directory = await Directory.systemTemp.createTemp('storage_test_');
    addTearDown(() async {
      StorageService.instance.setTestDirectory(null);
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    StorageService.instance.setTestDirectory(directory);

    await Future.wait([
      StorageService.instance.writeJsonFile(
        fileName: 'state.json',
        currentSchemaVersion: 1,
        encode: () => {'value': 1},
      ),
      StorageService.instance.writeJsonFile(
        fileName: 'state.json',
        currentSchemaVersion: 1,
        encode: () => {'value': 2},
      ),
    ]);

    final data =
        jsonDecode(await File('${directory.path}/state.json').readAsString())
            as Map<String, dynamic>;
    expect((data['data'] as Map<String, dynamic>)['value'], 2);
  });
}
