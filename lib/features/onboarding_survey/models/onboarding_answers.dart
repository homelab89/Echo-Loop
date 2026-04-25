/// Onboarding 问卷答案模型
///
/// 不可变，用于在 Provider 中累积草稿和最终持久化。
library;

import 'package:flutter/foundation.dart';

@immutable
class OnboardingAnswers {
  /// Q1 学习目标编码（见 [OnboardingGoal]）；未答时为 null
  final String? goal;

  /// Q2 每日学习时长编码（见 [OnboardingDailyMinutes]）；未答时为 null
  final String? dailyMinutes;

  const OnboardingAnswers({this.goal, this.dailyMinutes});

  /// 两题都已答
  bool get isComplete => goal != null && dailyMinutes != null;

  OnboardingAnswers copyWith({String? goal, String? dailyMinutes}) {
    return OnboardingAnswers(
      goal: goal ?? this.goal,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingAnswers &&
          other.goal == goal &&
          other.dailyMinutes == dailyMinutes;

  @override
  int get hashCode => Object.hash(goal, dailyMinutes);

  @override
  String toString() =>
      'OnboardingAnswers(goal: $goal, dailyMinutes: $dailyMinutes)';
}
