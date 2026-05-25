/// Onboarding 问卷题目静态元数据
///
/// 四道题：学习目标 → （仅当目标=应对考试）考试类型 → 每日学习时长 → 来源渠道。
/// 题目和选项不可变，运行时不会从配置或后端拉取。
library;

import 'package:flutter/foundation.dart';

/// 题目 ID（用于埋点参数 question_id）
abstract final class OnboardingQuestionId {
  static const goal = 'goal';
  static const examType = 'exam_type';
  static const dailyMinutes = 'daily_minutes';
  static const referralSource = 'referral_source';
}

/// 学习目标编码（Q1）
abstract final class OnboardingGoal {
  static const exam = 'exam';
  static const daily = 'daily';
  static const work = 'work';
  static const travel = 'travel';
  static const content = 'content';
  static const other = 'other';

  /// 全部合法值，用于 SP 解码时校验
  static const all = [exam, daily, work, travel, content, other];
}

/// 应对考试时的二级菜单：考试类型编码
abstract final class OnboardingExamType {
  static const gaokao = 'gaokao';
  static const cet = 'cet';
  static const tem = 'tem';
  static const ielts = 'ielts';
  static const toefl = 'toefl';
  static const other = 'other';

  static const all = [gaokao, cet, tem, ielts, toefl, other];
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

/// 来源渠道编码（Q3）
///
/// 中英文用户看到的渠道列表不同（详见 onboarding_survey_screen.dart 的
/// `_buildReferralSourceStep`），但编码集合统一以便埋点分析。
abstract final class OnboardingReferralSource {
  // 中文用户主要渠道
  static const xiaohongshu = 'xiaohongshu';
  static const wechat = 'wechat';
  static const douyin = 'douyin';
  static const kuaishou = 'kuaishou';
  static const bilibili = 'bilibili';
  static const baiduSearch = 'baidu_search';
  // 英文用户主要渠道
  static const youtube = 'youtube';
  static const reddit = 'reddit';
  static const xTwitter = 'x_twitter';
  static const tiktok = 'tiktok';
  static const instagram = 'instagram';
  static const googleSearch = 'google_search';
  // 通用渠道
  static const github = 'github';
  static const appStore = 'app_store';
  static const googlePlay = 'google_play';
  static const friend = 'friend';
  static const other = 'other';

  static const all = [
    xiaohongshu,
    wechat,
    douyin,
    kuaishou,
    bilibili,
    baiduSearch,
    youtube,
    reddit,
    xTwitter,
    tiktok,
    instagram,
    googleSearch,
    github,
    appStore,
    googlePlay,
    friend,
    other,
  ];
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
