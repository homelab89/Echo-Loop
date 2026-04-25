/// Onboarding 问卷 Riverpod Provider 集合
///
/// 单文件包含所有 provider，避免分散在多个小文件中。命名风格对齐
/// `lib/providers/new_user_guide_provider.dart`，使用手动 Notifier
/// （不走 riverpod_generator，简化构建链路）。
///
/// 三层 gate 体现在 `shouldShowSurveyProvider`：
///   isFirstLaunch && !onboardingCompleted && !hasLearningProgress
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/learning_progress_provider.dart';
import '../../../providers/new_user_guide_provider.dart';
import '../../../services/app_logger.dart';
import '../data/onboarding_survey_storage.dart';
import '../models/onboarding_answers.dart';

/// SharedPreferences 实例。
///
/// 在 `main()` 加载 SP 之后通过 `ProviderScope.overrideWithValue` 注入。
/// 未 override 时抛出，避免误用未初始化的 SP。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

/// 问卷存储入口。
final onboardingStorageProvider = Provider<OnboardingSurveyStorage>((ref) {
  return OnboardingSurveyStorage(ref.read(sharedPreferencesProvider));
});

/// "问卷是否已完成"的初始值。
///
/// 在 `main()` 启动时同步读 SP（`completed_at_ms` 是否存在），通过
/// `overrideWithValue` 注入。GoRouter `redirect:` 是同步函数，
/// 必须在 main 提前读取，否则启动闪屏期间 redirect 拿不到状态。
final initialOnboardingCompletedProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'initialOnboardingCompletedProvider must be overridden in main()',
  );
});

/// 当前进程内的"问卷已完成"状态。
///
/// 启动时从 [initialOnboardingCompletedProvider] 拿到初值；用户答完
/// 问卷后由 `OnboardingAnswersNotifier.submit()` 调用 [markCompleted]
/// 翻转为 true。
class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(initialOnboardingCompletedProvider);

  /// 标记为已完成（仅写内存状态，不重复写 SP——SP 由 storage 层负责）。
  void markCompleted() {
    if (state) return;
    state = true;
    AppLogger.log('OnboardingSurvey', 'markCompleted');
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );

/// 当前问卷草稿答案。
///
/// 用户在两题之间切换时累积；点"完成"时调用 [submit] 写 SP +
/// 触发 [OnboardingCompletedNotifier.markCompleted]。
class OnboardingAnswersNotifier extends Notifier<OnboardingAnswers> {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  /// 设置 Q1（学习目标）。
  void setGoal(String goal) {
    state = state.copyWith(goal: goal);
  }

  /// 设置 Q2（每日学习时长）。
  void setDailyMinutes(String dailyMinutes) {
    state = state.copyWith(dailyMinutes: dailyMinutes);
  }

  /// 提交答案：写 SP（先答案后完成锚点），再翻转完成状态。
  ///
  /// 调用方必须保证两题都已答（按钮 disabled 已经保证）；否则抛错。
  Future<void> submit() async {
    final answers = state;
    if (!answers.isComplete) {
      throw StateError('Cannot submit: answers incomplete');
    }
    final storage = ref.read(onboardingStorageProvider);
    await storage.saveCompleted(answers);
    ref.read(onboardingCompletedProvider.notifier).markCompleted();
  }
}

final onboardingAnswersProvider =
    NotifierProvider<OnboardingAnswersNotifier, OnboardingAnswers>(
      OnboardingAnswersNotifier.new,
    );

/// 是否应该展示问卷（router redirect 同步判定）。
///
/// 三层 gate（任一失败即不展示）：
/// 1. `isFirstLaunch`（硬门槛，老用户永远 false）
/// 2. 问卷未完成
/// 3. 没有学习进度（兜底：哨兵缺失但已学习的老用户）
///
/// 第 3 条的 `progressMap.isEmpty` 在加载完成（`!isLoading`）时才准——
/// 加载中时返回 true（不阻塞首启用户进入问卷），由 onboarding 页 initState
/// 异步兜底：检测到 progressMap 非空立即 markCompleted + 跳学习页。
final shouldShowSurveyProvider = Provider<bool>((ref) {
  final isFirstLaunch = ref.watch(isFirstLaunchProvider);
  if (!isFirstLaunch) return false;

  final completed = ref.watch(onboardingCompletedProvider);
  if (completed) return false;

  final progress = ref.watch(learningProgressNotifierProvider);
  if (!progress.isLoading && progress.progressMap.isNotEmpty) {
    return false;
  }

  return true;
});
