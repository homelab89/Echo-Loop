/// Onboarding 问卷题目静态元数据
///
/// 第一期只有 2 题：学习目标 + 每日学习时长。
/// 题目和选项不可变，运行时不会从配置或后端拉取。
library;

import 'package:flutter/foundation.dart';

/// 题目 ID（用于埋点参数 question_id）
abstract final class OnboardingQuestionId {
  static const goal = 'goal';
  static const dailyMinutes = 'daily_minutes';
}

/// 学习目标编码（Q1）
abstract final class OnboardingGoal {
  static const exam = 'exam';
  static const daily = 'daily';
  static const work = 'work';
  static const travel = 'travel';
  static const other = 'other';

  /// 全部合法值，用于 SP 解码时校验
  static const all = [exam, daily, work, travel, other];
}

/// 每日学习时长编码（Q2）
///
/// 含 `flexible` 故用 String 而非 int。
abstract final class OnboardingDailyMinutes {
  static const m5 = '5';
  static const m10 = '10';
  static const m20 = '20';
  static const m30 = '30';
  static const flexible = 'flexible';

  static const all = [m5, m10, m20, m30, flexible];
}

/// 单个选项的元数据。
///
/// 显示文本通过 [labelKey] 在 ARB 中查表，编码 [code] 用于持久化和埋点。
@immutable
class OnboardingOption {
  /// 写入 SP / 埋点的稳定编码
  final String code;

  /// l10n key（见 app_zh.arb / app_en.arb）
  final String labelKey;

  const OnboardingOption({required this.code, required this.labelKey});
}

/// 单道题的元数据。
@immutable
class OnboardingQuestion {
  /// 题目 ID（埋点用）
  final String id;

  /// 题干 l10n key
  final String promptKey;

  /// 选项列表，按界面展示顺序
  final List<OnboardingOption> options;

  const OnboardingQuestion({
    required this.id,
    required this.promptKey,
    required this.options,
  });
}

/// 第一期问卷的两道题。顺序固定。
const onboardingQuestions = <OnboardingQuestion>[
  OnboardingQuestion(
    id: OnboardingQuestionId.goal,
    promptKey: 'onboardingQ1Prompt',
    options: [
      OnboardingOption(
        code: OnboardingGoal.exam,
        labelKey: 'onboardingQ1OptionExam',
      ),
      OnboardingOption(
        code: OnboardingGoal.daily,
        labelKey: 'onboardingQ1OptionDaily',
      ),
      OnboardingOption(
        code: OnboardingGoal.work,
        labelKey: 'onboardingQ1OptionWork',
      ),
      OnboardingOption(
        code: OnboardingGoal.travel,
        labelKey: 'onboardingQ1OptionTravel',
      ),
      OnboardingOption(
        code: OnboardingGoal.other,
        labelKey: 'onboardingQ1OptionOther',
      ),
    ],
  ),
  OnboardingQuestion(
    id: OnboardingQuestionId.dailyMinutes,
    promptKey: 'onboardingQ2Prompt',
    options: [
      OnboardingOption(
        code: OnboardingDailyMinutes.m5,
        labelKey: 'onboardingQ2Option5',
      ),
      OnboardingOption(
        code: OnboardingDailyMinutes.m10,
        labelKey: 'onboardingQ2Option10',
      ),
      OnboardingOption(
        code: OnboardingDailyMinutes.m20,
        labelKey: 'onboardingQ2Option20',
      ),
      OnboardingOption(
        code: OnboardingDailyMinutes.m30,
        labelKey: 'onboardingQ2Option30',
      ),
      OnboardingOption(
        code: OnboardingDailyMinutes.flexible,
        labelKey: 'onboardingQ2OptionFlexible',
      ),
    ],
  ),
];
