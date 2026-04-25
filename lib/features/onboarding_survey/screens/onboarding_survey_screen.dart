/// Onboarding 问卷页：首启用户必经的 2 题画像调研。
///
/// 设计要点：
/// - PopScope.canPop=false 拦截物理返回 / 边缘滑动
/// - 不能后退到上一题（按钮只显示"下一题/完成"）
/// - 老用户兜底：initState 检测 progressMap 非空立即 markCompleted + go(study)
/// - 完成时先 await 写 SP，再切状态，最后导航——保证崩溃也不会丢一致性
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../analytics/analytics_providers.dart';
import '../../../analytics/models/event_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/app_logger.dart';
import '../models/onboarding_answers.dart';
import '../models/onboarding_question.dart';
import '../providers/onboarding_survey_provider.dart';
import '../widgets/survey_choice_tile.dart';
import '../widgets/survey_progress_bar.dart';

class OnboardingSurveyScreen extends ConsumerStatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  ConsumerState<OnboardingSurveyScreen> createState() =>
      _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState
    extends ConsumerState<OnboardingSurveyScreen> {
  final _pageController = PageController();
  int _currentIndex = 0;
  late final DateTime _startedAt;
  bool _showSuccessAnimation = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    // 进入问卷打 shown 事件（包括老用户被异步 bypass 的也算 shown，
    // 但他们会立刻被跳到 study，对漏斗影响极小）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeBypassForExistingUser();
      ref.read(analyticsServiceProvider).track(
        Events.onboardingSurveyShown,
        const {EventParams.isFirstLaunch: true},
      );
    });
  }

  /// 老用户兜底：哨兵缺失但已有学习进度的用户秒过。
  void _maybeBypassForExistingUser() {
    final progress = ref.read(learningProgressNotifierProvider);
    if (progress.isLoading) return;
    if (progress.progressMap.isEmpty) return;
    AppLogger.log(
      'OnboardingSurvey',
      'bypass for existing user: progressMap=${progress.progressMap.length}',
    );
    ref.read(onboardingCompletedProvider.notifier).markCompleted();
    if (mounted) context.go(AppRoutes.study);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onChoiceSelected(int questionIndex, String code) {
    final notifier = ref.read(onboardingAnswersProvider.notifier);
    final question = onboardingQuestions[questionIndex];
    switch (question.id) {
      case OnboardingQuestionId.goal:
        notifier.setGoal(code);
      case OnboardingQuestionId.dailyMinutes:
        notifier.setDailyMinutes(code);
    }
    ref.read(analyticsServiceProvider).track(
      Events.onboardingSurveyQuestionAnswered,
      {EventParams.questionId: question.id, EventParams.answerCode: code},
    );
  }

  bool _isCurrentAnswered(OnboardingAnswers answers) {
    final question = onboardingQuestions[_currentIndex];
    switch (question.id) {
      case OnboardingQuestionId.goal:
        return answers.goal != null;
      case OnboardingQuestionId.dailyMinutes:
        return answers.dailyMinutes != null;
    }
    return false;
  }

  Future<void> _onPrimaryPressed() async {
    if (_submitting) return;
    if (_currentIndex < onboardingQuestions.length - 1) {
      setState(() => _currentIndex += 1);
      await _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    setState(() => _submitting = true);
    final answers = ref.read(onboardingAnswersProvider);
    try {
      await ref.read(onboardingAnswersProvider.notifier).submit();
    } catch (e, st) {
      AppLogger.log('OnboardingSurvey', 'submit failed: $e');
      AppLogger.log('OnboardingSurvey', st.toString());
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final analytics = ref.read(analyticsServiceProvider);
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    await analytics.track(Events.onboardingSurveyCompleted, {
      EventParams.goal: answers.goal!,
      EventParams.dailyMinutes: answers.dailyMinutes!,
      EventParams.elapsedSeconds: elapsed,
    });
    await analytics.setUserProperty(UserProperties.englishGoal, answers.goal);
    await analytics.setUserProperty(
      UserProperties.dailyMinutesTarget,
      answers.dailyMinutes,
    );

    if (!mounted) return;
    setState(() => _showSuccessAnimation = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    context.go(AppRoutes.study);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final answers = ref.watch(onboardingAnswersProvider);
    final isAnswered = _isCurrentAnswered(answers);
    final isLast = _currentIndex == onboardingQuestions.length - 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: _showSuccessAnimation
              ? _SuccessOverlay(message: l10n.onboardingFinishedToast)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                l10n.onboardingTitle,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.onboardingSubtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              SurveyProgressBar(
                                current: _currentIndex + 1,
                                total: onboardingQuestions.length,
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: onboardingQuestions.length,
                                  itemBuilder: (context, index) =>
                                      _buildQuestionPage(index, answers),
                                ),
                              ),
                              SafeArea(
                                top: false,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: FilledButton(
                                    onPressed:
                                        (isAnswered && !_submitting)
                                            ? _onPrimaryPressed
                                            : null,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                                CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                          )
                                        : Text(
                                            isLast
                                                ? l10n.onboardingDone
                                                : l10n.onboardingNext,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildQuestionPage(int index, OnboardingAnswers answers) {
    final l10n = AppLocalizations.of(context)!;
    final question = onboardingQuestions[index];
    final selectedCode = switch (question.id) {
      OnboardingQuestionId.goal => answers.goal,
      OnboardingQuestionId.dailyMinutes => answers.dailyMinutes,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _resolvePrompt(l10n, question.promptKey),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final option in question.options)
                SurveyChoiceTile(
                  label: _resolveOption(l10n, option.labelKey),
                  selected: option.code == selectedCode,
                  onTap: () => _onChoiceSelected(index, option.code),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- l10n key 反查（小映射，避免在 model 层依赖 build_context） ----

  String _resolvePrompt(AppLocalizations l10n, String key) {
    return switch (key) {
      'onboardingQ1Prompt' => l10n.onboardingQ1Prompt,
      'onboardingQ2Prompt' => l10n.onboardingQ2Prompt,
      _ => key,
    };
  }

  String _resolveOption(AppLocalizations l10n, String key) {
    return switch (key) {
      'onboardingQ1OptionExam' => l10n.onboardingQ1OptionExam,
      'onboardingQ1OptionDaily' => l10n.onboardingQ1OptionDaily,
      'onboardingQ1OptionWork' => l10n.onboardingQ1OptionWork,
      'onboardingQ1OptionTravel' => l10n.onboardingQ1OptionTravel,
      'onboardingQ1OptionOther' => l10n.onboardingQ1OptionOther,
      'onboardingQ2Option5' => l10n.onboardingQ2Option5,
      'onboardingQ2Option10' => l10n.onboardingQ2Option10,
      'onboardingQ2Option20' => l10n.onboardingQ2Option20,
      'onboardingQ2Option30' => l10n.onboardingQ2Option30,
      'onboardingQ2OptionFlexible' => l10n.onboardingQ2OptionFlexible,
      _ => key,
    };
  }
}

class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
