import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:fluency/features/onboarding_survey/models/onboarding_question.dart';
import 'package:fluency/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:fluency/features/onboarding_survey/screens/onboarding_survey_screen.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/new_user_guide_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_providers.dart';

class _TestLearningProgressNotifier extends LearningProgressNotifier {
  _TestLearningProgressNotifier(this._initial);
  final LearningProgressState _initial;
  @override
  LearningProgressState build() => _initial;
}

/// 创建一个最小化的可路由测试 App，承载 onboarding 页 + study 占位页。
Widget _wrap({
  required SharedPreferences prefs,
  bool isFirstLaunch = true,
  bool initialOnboardingCompleted = false,
  LearningProgressState progress = const LearningProgressState(),
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.onboardingSurvey,
    routes: [
      GoRoute(
        path: AppRoutes.onboardingSurvey,
        builder: (_, __) => const OnboardingSurveyScreen(),
      ),
      GoRoute(
        path: AppRoutes.study,
        builder: (_, __) => const Scaffold(body: Text('STUDY_PLACEHOLDER')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      isFirstLaunchProvider.overrideWithValue(isFirstLaunch),
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialOnboardingCompletedProvider
          .overrideWithValue(initialOnboardingCompleted),
      learningProgressNotifierProvider.overrideWith(
        () => _TestLearningProgressNotifier(progress),
      ),
      analyticsOverride(),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('初次进入按钮 disabled，选答后 enabled', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('下一题'), findsOneWidget);

    // 找到 FilledButton：未选时应 disabled
    final buttonFinder = find.byType(FilledButton);
    expect(buttonFinder, findsOneWidget);
    final disabledButton = tester.widget<FilledButton>(buttonFinder);
    expect(disabledButton.onPressed, isNull);

    // 选第一个答案
    await tester.tap(find.text('考试（四六级 / 考研 / 雅思托福）'));
    await tester.pumpAndSettle();

    final enabledButton = tester.widget<FilledButton>(buttonFinder);
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('完整 2 题流程能走通并写入 SP', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    // Q1: 选职场英语
    await tester.tap(find.text('职场英语（工作沟通、邮件、会议）'));
    await tester.pumpAndSettle();
    expect(find.text('下一题'), findsOneWidget);
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();

    // Q2: 选灵活安排
    expect(find.text('完成'), findsOneWidget);
    await tester.tap(find.text('不固定，灵活安排'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 应导航到 study 页
    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);

    // SP 已写入
    final storage = OnboardingSurveyStorage(prefs);
    expect(storage.isCompleted, isTrue);
    final answers = storage.loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.work));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.flexible));
  });

  testWidgets('无跳过按钮渲染', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('以后再说'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('物理返回键被 PopScope 拦截', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    // 模拟系统返回手势
    // ignore: deprecated_member_use
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();

    // 仍在 onboarding 页（题目仍可见）
    expect(find.text('你为什么学英语？'), findsOneWidget);
  });

  testWidgets('进度条文字按题号变化', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('第 1 题 / 共 2 题'), findsOneWidget);

    await tester.tap(find.text('考试（四六级 / 考研 / 雅思托福）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 题 / 共 2 题'), findsOneWidget);
  });

  testWidgets('老用户兜底：progressMap 非空时 initState 自动跳转 study', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final stub = LearningProgress(
      audioItemId: 'a1',
      currentStage: LearningStage.firstLearn,
      currentSubStage: SubStageType.blindListen,
      difficulty: DifficultyLevel.medium,
      currentStageStartedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final progress = LearningProgressState(
      progressMap: {'a1': stub},
      isLoading: false,
    );
    await tester.pumpWidget(_wrap(prefs: prefs, progress: progress));
    await tester.pumpAndSettle();

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
  });
}
