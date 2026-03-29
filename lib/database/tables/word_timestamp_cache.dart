import 'package:drift/drift.dart';

/// 词级时间戳缓存表
///
/// 每个音频对应一行，data 列存储 `List<WordTimestamp>` 的 JSON 编码。
/// 转录完成时写入，精听页面打开时读取。
class WordTimestampCache extends Table {
  /// 关联的音频 ID（同时作为主键，一个音频只有一份词级时间戳）
  TextColumn get audioItemId => text()();

  /// JSON 编码的 List<WordTimestamp>
  TextColumn get data => text()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {audioItemId};
}
