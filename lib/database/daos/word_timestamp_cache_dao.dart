import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/word_timestamp_cache.dart';

part 'word_timestamp_cache_dao.g.dart';

/// 词级时间戳缓存 DAO
///
/// 提供词级时间戳 JSON 的存取操作。
/// 以 audioItemId 为主键，一个音频只有一份词级时间戳。
@DriftAccessor(tables: [WordTimestampCache])
class WordTimestampCacheDao extends DatabaseAccessor<AppDatabase>
    with _$WordTimestampCacheDaoMixin {
  WordTimestampCacheDao(super.db);

  /// 根据音频 ID 获取词级时间戳 JSON
  ///
  /// 返回 JSON 字符串，未找到返回 null。
  Future<String?> getByAudioItemId(String audioItemId) async {
    final query = select(wordTimestampCache)
      ..where((t) => t.audioItemId.equals(audioItemId));
    final row = await query.getSingleOrNull();
    return row?.data;
  }

  /// 插入或替换词级时间戳 JSON
  ///
  /// 以 audioItemId 为主键，冲突时替换。
  Future<void> upsert(String audioItemId, String dataJson) {
    return into(wordTimestampCache).insert(
      WordTimestampCacheCompanion.insert(
        audioItemId: audioItemId,
        data: dataJson,
        createdAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 删除指定音频的词级时间戳
  Future<int> deleteByAudioItemId(String audioItemId) {
    return (delete(wordTimestampCache)
          ..where((t) => t.audioItemId.equals(audioItemId)))
        .go();
  }

  /// 清空所有词级时间戳缓存
  Future<int> deleteAll() {
    return delete(wordTimestampCache).go();
  }
}
