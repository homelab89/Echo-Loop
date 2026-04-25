/// Onboarding 问卷的 SharedPreferences 读写。
///
/// 复用项目已有的"是否新用户"判定（`first_launch_done` + `isFirstLaunchProvider`）。
/// 本模块只负责"问卷答案"的本地持久化。
///
/// SP 设计：
/// - `onboarding_completed_at_ms` 存在性 = 是否已完成
/// - `onboarding_goal` / `onboarding_daily_minutes` 存答案
/// - 不引入冗余的 `onboarding_completed` bool，避免双写不一致
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_answers.dart';
import '../models/onboarding_question.dart';

/// SharedPreferences key 常量
abstract final class OnboardingSurveyKeys {
  static const goal = 'onboarding_goal';
  static const dailyMinutes = 'onboarding_daily_minutes';
  static const completedAtMs = 'onboarding_completed_at_ms';
}

/// SP 读写封装。
///
/// 所有对 onboarding SP 的访问必须经此类，方便测试和后续重构。
class OnboardingSurveyStorage {
  OnboardingSurveyStorage(this._prefs);

  final SharedPreferences _prefs;

  /// 当前问卷是否已完成。
  ///
  /// 判定依据：[OnboardingSurveyKeys.completedAtMs] 是否存在。
  bool get isCompleted => _prefs.containsKey(OnboardingSurveyKeys.completedAtMs);

  /// 同步读取静态判定（在 main 启动期使用，避免 redirect 异步等待）。
  static bool readIsCompletedSync(SharedPreferences prefs) {
    return prefs.containsKey(OnboardingSurveyKeys.completedAtMs);
  }

  /// 加载已完成的答案；未完成或字段缺失返回 null。
  ///
  /// 校验答案编码必须落在合法集合内，否则视为无效返回 null。
  OnboardingAnswers? loadAnswers() {
    if (!isCompleted) return null;
    final goal = _prefs.getString(OnboardingSurveyKeys.goal);
    final dailyMinutes = _prefs.getString(OnboardingSurveyKeys.dailyMinutes);
    if (goal == null || dailyMinutes == null) return null;
    if (!OnboardingGoal.all.contains(goal)) return null;
    if (!OnboardingDailyMinutes.all.contains(dailyMinutes)) return null;
    return OnboardingAnswers(goal: goal, dailyMinutes: dailyMinutes);
  }

  /// 完成时的时间戳；未完成返回 null。
  DateTime? get completedAt {
    final ms = _prefs.getInt(OnboardingSurveyKeys.completedAtMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 一次性写入所有答案 + 完成时间戳。
  ///
  /// 调用方必须保证 [answers.isComplete] 为 true，否则抛 [ArgumentError]。
  /// `completed_at_ms` 最后写入，作为"完成"判定锚点；写入失败不会留下半完成状态。
  Future<void> saveCompleted(OnboardingAnswers answers, {DateTime? now}) async {
    if (!answers.isComplete) {
      throw ArgumentError('OnboardingAnswers must be complete before saving');
    }
    final completedAt = now ?? DateTime.now();
    // 先写答案，再写完成锚点。如果中间失败，下次启动会被识别为未完成
    // （但因 first_launch_done 已写，仍不会再弹——失去画像但不损坏状态）
    await _prefs.setString(OnboardingSurveyKeys.goal, answers.goal!);
    await _prefs.setString(
      OnboardingSurveyKeys.dailyMinutes,
      answers.dailyMinutes!,
    );
    await _prefs.setInt(
      OnboardingSurveyKeys.completedAtMs,
      completedAt.millisecondsSinceEpoch,
    );
  }

  /// 清空所有 onboarding 数据（仅供测试和"重答问卷"功能使用）。
  Future<void> clear() async {
    await _prefs.remove(OnboardingSurveyKeys.goal);
    await _prefs.remove(OnboardingSurveyKeys.dailyMinutes);
    await _prefs.remove(OnboardingSurveyKeys.completedAtMs);
  }
}
