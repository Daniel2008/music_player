import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final broken in [
    '',
    '[]',
    '{"_v":1,"data":42}',
    '{"_v":"invalid","data":[]}',
  ]) {
    test('主文件不可解码时恢复备份: $broken', () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage_recovery_',
      );
      StorageService.instance.setTestDirectory(directory);
      addTearDown(() async {
        StorageService.instance.setTestDirectory(null);
        await directory.delete(recursive: true);
      });
      await File('${directory.path}/state').writeAsString(broken);
      await File(
        '${directory.path}/state.bak',
      ).writeAsString('{"_v":1,"data":["kept"]}');
      final restored = await StorageService.instance.readJsonFile<List<String>>(
        fileName: 'state',
        currentSchemaVersion: 1,
        decode: (raw, _) => raw is List ? raw.cast<String>() : null,
      );
      expect(restored, ['kept']);
      await StorageService.instance.writeJsonFile(
        fileName: 'state',
        currentSchemaVersion: 1,
        encode: () => ['updated'],
      );
      expect(
        jsonDecode(
          await File('${directory.path}/state.bak').readAsString(),
        )['data'],
        ['kept'],
      );
    });
  }

  test('保存失败能被等待方观察且不阻塞下一次保存', () async {
    final directory = await Directory.systemTemp.createTemp('storage_failure_');
    StorageService.instance.setTestDirectory(directory);
    addTearDown(() async {
      StorageService.instance.setTestDirectory(null);
      await directory.delete(recursive: true);
    });
    await expectLater(
      StorageService.instance.writeJsonFile(
        fileName: 'state',
        currentSchemaVersion: 1,
        encode: () => throw StateError('cannot encode'),
      ),
      throwsStateError,
    );
    await StorageService.instance.writeJsonFile(
      fileName: 'state',
      currentSchemaVersion: 1,
      encode: () => ['saved'],
    );
    expect(
      jsonDecode(await File('${directory.path}/state').readAsString())['data'],
      ['saved'],
    );
  });

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
