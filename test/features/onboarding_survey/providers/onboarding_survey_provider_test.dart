import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:fluency/features/onboarding_survey/models/onboarding_answers.dart';
import 'package:fluency/features/onboarding_survey/models/onboarding_question.dart';
import 'package:fluency/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/new_user_guide_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用 LearningProgressNotifier，注入指定初始状态
class _TestLearningProgressNotifier extends LearningProgressNotifier {
  _TestLearningProgressNotifier(this._initial);

  final LearningProgressState _initial;

  @override
  LearningProgressState build() => _initial;
}

ProviderContainer _makeContainer({
  required bool isFirstLaunch,
  required bool initialOnboardingCompleted,
  required LearningProgressState progressState,
  required SharedPreferences prefs,
}) {
  return ProviderContainer(
    overrides: [
      isFirstLaunchProvider.overrideWithValue(isFirstLaunch),
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialOnboardingCompletedProvider.overrideWithValue(
        initialOnboardingCompleted,
      ),
      learningProgressNotifierProvider.overrideWith(
        () => _TestLearningProgressNotifier(progressState),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('shouldShowSurveyProvider —— gate 矩阵', () {
    test('首启 + 未完成 + 无进度 → true', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isTrue);
    });

    test('首启 + 已完成 → false（用户答过问卷）', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: true,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });

    test('非首启 + 未完成 → false（关键：老用户绝对不弹）', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: false,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });

    test('首启 + 未完成 + 有学习进度 → false（哨兵缺失老用户兜底）', () async {
      final prefs = await SharedPreferences.getInstance();
      final progress = LearningProgress(
        audioItemId: 'a1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.blindListen,
        difficulty: DifficultyLevel.medium,
        totalStudyDurationMs: 5000,
        currentStageStartedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: LearningProgressState(
          progressMap: {'a1': progress},
          isLoading: false,
        ),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });

    test('首启 + 未完成 + 进度仍在 loading → true（loading 中不阻塞）', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(isLoading: true),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isTrue);
    });

    test('完成后 shouldShowSurveyProvider 立即变 false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);

      expect(container.read(shouldShowSurveyProvider), isTrue);
      container.read(onboardingCompletedProvider.notifier).markCompleted();
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });
  });

  group('OnboardingAnswersNotifier', () {
    test('每次 setAnswer 累积答案', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setGoal(OnboardingGoal.work);
      expect(
        container.read(onboardingAnswersProvider),
        equals(const OnboardingAnswers(goal: OnboardingGoal.work)),
      );

      notifier.setDailyMinutes(OnboardingDailyMinutes.flexible);
      expect(
        container.read(onboardingAnswersProvider),
        equals(
          const OnboardingAnswers(
            goal: OnboardingGoal.work,
            dailyMinutes: OnboardingDailyMinutes.flexible,
          ),
        ),
      );
    });

    test('submit 写 SP + 翻转完成态', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);
      notifier.setGoal(OnboardingGoal.exam);
      notifier.setDailyMinutes(OnboardingDailyMinutes.m20);

      await notifier.submit();

      expect(container.read(onboardingCompletedProvider), isTrue);

      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue);
      expect(storage.loadAnswers()?.goal, equals(OnboardingGoal.exam));
      expect(
        storage.loadAnswers()?.dailyMinutes,
        equals(OnboardingDailyMinutes.m20),
      );
    });

    test('未完成时 submit 抛 StateError', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);
      notifier.setGoal(OnboardingGoal.daily);
      // 没设 dailyMinutes
      expect(notifier.submit, throwsStateError);
    });
  });

  group('OnboardingCompletedNotifier', () {
    test('初值来自 initialOnboardingCompletedProvider', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: true,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('markCompleted 幂等', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        isFirstLaunch: true,
        initialOnboardingCompleted: false,
        progressState: const LearningProgressState(),
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingCompletedProvider.notifier);
      notifier.markCompleted();
      notifier.markCompleted();
      notifier.markCompleted();
      expect(container.read(onboardingCompletedProvider), isTrue);
    });
  });
}
