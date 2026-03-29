import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/database/app_database.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('WordTimestampCacheDao', () {
    test('getByAudioItemId 空表返回 null', () async {
      final result =
          await db.wordTimestampCacheDao.getByAudioItemId('nonexistent');
      expect(result, isNull);
    });

    test('upsert 后 getByAudioItemId 返回数据', () async {
      const audioId = 'audio-1';
      const json = '[{"word":"hello","startTime":1.0,"endTime":2.0,"confidence":0.9}]';

      await db.wordTimestampCacheDao.upsert(audioId, json);
      final result = await db.wordTimestampCacheDao.getByAudioItemId(audioId);

      expect(result, json);
    });

    test('upsert 覆盖写入', () async {
      const audioId = 'audio-1';
      const json1 = '[{"word":"old"}]';
      const json2 = '[{"word":"new"}]';

      await db.wordTimestampCacheDao.upsert(audioId, json1);
      await db.wordTimestampCacheDao.upsert(audioId, json2);
      final result = await db.wordTimestampCacheDao.getByAudioItemId(audioId);

      expect(result, json2);
    });

    test('deleteByAudioItemId 删除数据', () async {
      const audioId = 'audio-1';
      const json = '[]';

      await db.wordTimestampCacheDao.upsert(audioId, json);
      final deleted =
          await db.wordTimestampCacheDao.deleteByAudioItemId(audioId);

      expect(deleted, 1);
      expect(
        await db.wordTimestampCacheDao.getByAudioItemId(audioId),
        isNull,
      );
    });

    test('deleteByAudioItemId 不存在时返回 0', () async {
      final deleted =
          await db.wordTimestampCacheDao.deleteByAudioItemId('nonexistent');
      expect(deleted, 0);
    });

    test('不同 audioId 互不影响', () async {
      const json1 = '[{"word":"a"}]';
      const json2 = '[{"word":"b"}]';

      await db.wordTimestampCacheDao.upsert('audio-1', json1);
      await db.wordTimestampCacheDao.upsert('audio-2', json2);

      expect(
        await db.wordTimestampCacheDao.getByAudioItemId('audio-1'),
        json1,
      );
      expect(
        await db.wordTimestampCacheDao.getByAudioItemId('audio-2'),
        json2,
      );

      // 删除其中一个不影响另一个
      await db.wordTimestampCacheDao.deleteByAudioItemId('audio-1');
      expect(
        await db.wordTimestampCacheDao.getByAudioItemId('audio-1'),
        isNull,
      );
      expect(
        await db.wordTimestampCacheDao.getByAudioItemId('audio-2'),
        json2,
      );
    });

    test('deleteAll 清空所有记录', () async {
      await db.wordTimestampCacheDao.upsert('audio-1', '[{"word":"a"}]');
      await db.wordTimestampCacheDao.upsert('audio-2', '[{"word":"b"}]');

      final deleted = await db.wordTimestampCacheDao.deleteAll();
      expect(deleted, 2);
      expect(
        await db.wordTimestampCacheDao.getByAudioItemId('audio-1'),
        isNull,
      );
      expect(
        await db.wordTimestampCacheDao.getByAudioItemId('audio-2'),
        isNull,
      );
    });
  });
}
