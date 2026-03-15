import '../database/daos/daily_study_record_dao.dart';

/// 学习时长存储服务
///
/// 使用 Drift (SQLite) daily_study_records 表按日累计学习统计。
/// 每天一行，5 个计数器（学习时长、输入/输出词数、输入/输出时间）。
class StudyTimeService {
  final DailyStudyRecordDao _dao;

  StudyTimeService(this._dao);

  /// 获取指定日期的学习时长（秒）
  Future<int> getStudyTime(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.studyTimeSeconds ?? 0;
  }

  /// 获取今日学习时长（秒）
  Future<int> getTodayStudyTime() => getStudyTime(DateTime.now());

  /// 累加学习时长（秒）到指定日期
  ///
  /// [seconds] 必须 > 0，否则忽略。
  /// [date] 默认为今天。
  Future<void> addStudyTime(int seconds, {DateTime? date}) async {
    if (seconds <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), studyTime: seconds);
  }

  /// 获取连续学习天数（streak）
  ///
  /// 从昨天往回数连续有学习记录的天数，今天有学习则 +1。
  Future<int> getStudyStreak({DateTime? now}) {
    return _dao.getStreak(now: now);
  }

  /// 获取过去 7 天每天的学习时长（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyStudyTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final records = await _dao.getBetween(start, today);

    // 按日期建立查找表
    final Map<int, int> dayMap = {};
    for (final r in records) {
      final key = _dayKey(r.date);
      dayMap[key] = r.studyTimeSeconds;
    }

    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(dayMap[_dayKey(date)] ?? 0);
    }
    return result;
  }

  /// 获取本周一至今的累计学习时长（秒）
  Future<int> getWeekTotalStudyTime({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final daysSinceMonday = today.weekday - 1;
    final monday = today.subtract(Duration(days: daysSinceMonday));
    final records = await _dao.getBetween(monday, today);

    int total = 0;
    for (final r in records) {
      total += r.studyTimeSeconds;
    }
    return total;
  }

  // ========== 输入词数 ==========

  /// 获取指定日期的输入词数
  Future<int> getInputWords(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.inputWords ?? 0;
  }

  /// 获取今日输入词数
  Future<int> getTodayInputWords() => getInputWords(DateTime.now());

  /// 累加输入词数到指定日期
  ///
  /// [count] 必须 > 0，否则忽略。
  Future<void> addInputWords(int count, {DateTime? date}) async {
    if (count <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), inputWords: count);
  }

  // ========== 输出词数 ==========

  /// 获取指定日期的输出词数
  Future<int> getOutputWords(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.outputWords ?? 0;
  }

  /// 获取今日输出词数
  Future<int> getTodayOutputWords() => getOutputWords(DateTime.now());

  /// 累加输出词数到指定日期
  ///
  /// [count] 必须 > 0，否则忽略。
  Future<void> addOutputWords(int count, {DateTime? date}) async {
    if (count <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), outputWords: count);
  }

  // ========== 输入时间（秒） ==========

  /// 获取指定日期的输入时间（秒）
  Future<int> getInputTime(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.inputTimeSeconds ?? 0;
  }

  /// 获取今日输入时间（秒）
  Future<int> getTodayInputTime() => getInputTime(DateTime.now());

  /// 累加输入时间（秒）到指定日期
  ///
  /// [seconds] 必须 > 0，否则忽略。
  Future<void> addInputTime(int seconds, {DateTime? date}) async {
    if (seconds <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), inputTime: seconds);
  }

  /// 获取过去 7 天每天的输入时间（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyInputTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final records = await _dao.getBetween(start, today);

    final Map<int, int> dayMap = {};
    for (final r in records) {
      dayMap[_dayKey(r.date)] = r.inputTimeSeconds;
    }

    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(dayMap[_dayKey(date)] ?? 0);
    }
    return result;
  }

  // ========== 输出时间（秒） ==========

  /// 获取指定日期的输出时间（秒）
  Future<int> getOutputTime(DateTime date) async {
    final record = await _dao.getByDate(date);
    return record?.outputTimeSeconds ?? 0;
  }

  /// 获取今日输出时间（秒）
  Future<int> getTodayOutputTime() => getOutputTime(DateTime.now());

  /// 累加输出时间（秒）到指定日期
  ///
  /// [seconds] 必须 > 0，否则忽略。
  Future<void> addOutputTime(int seconds, {DateTime? date}) async {
    if (seconds <= 0) return;
    await _dao.upsertAdd(date ?? DateTime.now(), outputTime: seconds);
  }

  /// 获取过去 7 天每天的输出时间（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyOutputTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final records = await _dao.getBetween(start, today);

    final Map<int, int> dayMap = {};
    for (final r in records) {
      dayMap[_dayKey(r.date)] = r.outputTimeSeconds;
    }

    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(dayMap[_dayKey(date)] ?? 0);
    }
    return result;
  }

  /// 截断时间部分，只保留日期
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// 将日期转换为用于 Map key 的整数（yyyymmdd）
  int _dayKey(DateTime dt) => dt.year * 10000 + dt.month * 100 + dt.day;
}
