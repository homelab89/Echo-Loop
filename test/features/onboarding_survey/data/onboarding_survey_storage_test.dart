import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:fluency/features/onboarding_survey/models/onboarding_answers.dart';
import 'package:fluency/features/onboarding_survey/models/onboarding_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit 测试 SP 读写、完成判定锚点、答案校验。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingSurveyStorage', () {
    test('completed_at_ms 缺失时 isCompleted 为 false', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isFalse);
      expect(storage.loadAnswers(), isNull);
      expect(storage.completedAt, isNull);
    });

    test('saveCompleted 同时写入答案和时间戳', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      final now = DateTime(2026, 4, 25, 10, 0, 0);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.work,
          dailyMinutes: OnboardingDailyMinutes.m20,
        ),
        now: now,
      );

      expect(storage.isCompleted, isTrue);
      expect(storage.completedAt, equals(now));
      final loaded = storage.loadAnswers();
      expect(loaded, isNotNull);
      expect(loaded!.goal, equals(OnboardingGoal.work));
      expect(loaded.dailyMinutes, equals(OnboardingDailyMinutes.m20));
    });

    test('未完成的答案不能保存', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(
        () => storage.saveCompleted(const OnboardingAnswers()),
        throwsArgumentError,
      );
      expect(
        () => storage.saveCompleted(
          const OnboardingAnswers(goal: OnboardingGoal.exam),
        ),
        throwsArgumentError,
      );
    });

    test('flexible 时长可以正常保存和读取', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.daily,
          dailyMinutes: OnboardingDailyMinutes.flexible,
        ),
      );
      final loaded = storage.loadAnswers();
      expect(loaded?.dailyMinutes, equals(OnboardingDailyMinutes.flexible));
    });

    test('非法答案编码会被识别为无效，loadAnswers 返回 null', () async {
      // 模拟 SP 中存在非法编码（例如 schema 漂移或人为篡改）
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.goal: 'unknown_goal',
        OnboardingSurveyKeys.dailyMinutes: '99',
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue); // 锚点存在仍视为完成（防重复弹）
      expect(storage.loadAnswers(), isNull); // 但答案不可用
    });

    test('只有锚点没有答案字段时，loadAnswers 返回 null（不抛异常）', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: 1000,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue);
      expect(storage.loadAnswers(), isNull);
    });

    test('clear 清空所有 onboarding key', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingSurveyStorage(prefs);
      await storage.saveCompleted(
        const OnboardingAnswers(
          goal: OnboardingGoal.exam,
          dailyMinutes: OnboardingDailyMinutes.m10,
        ),
      );
      await storage.clear();
      expect(storage.isCompleted, isFalse);
      expect(storage.loadAnswers(), isNull);
    });

    test('readIsCompletedSync 静态方法可在 main() 同步调用', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingSurveyKeys.completedAtMs: 12345,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(OnboardingSurveyStorage.readIsCompletedSync(prefs), isTrue);
    });
  });

  group('OnboardingAnswers', () {
    test('isComplete 仅当两题都答时为 true', () {
      expect(const OnboardingAnswers().isComplete, isFalse);
      expect(
        const OnboardingAnswers(goal: OnboardingGoal.work).isComplete,
        isFalse,
      );
      expect(
        const OnboardingAnswers(
          goal: OnboardingGoal.work,
          dailyMinutes: OnboardingDailyMinutes.m10,
        ).isComplete,
        isTrue,
      );
    });

    test('copyWith 不会清空已设置的字段', () {
      const original = OnboardingAnswers(goal: OnboardingGoal.exam);
      final updated = original.copyWith(
        dailyMinutes: OnboardingDailyMinutes.m20,
      );
      expect(updated.goal, equals(OnboardingGoal.exam));
      expect(updated.dailyMinutes, equals(OnboardingDailyMinutes.m20));
    });

    test('相同字段值的实例相等', () {
      const a = OnboardingAnswers(
        goal: OnboardingGoal.work,
        dailyMinutes: OnboardingDailyMinutes.m30,
      );
      const b = OnboardingAnswers(
        goal: OnboardingGoal.work,
        dailyMinutes: OnboardingDailyMinutes.m30,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
