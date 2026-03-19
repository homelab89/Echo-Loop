/// 盲听段落选择底部弹窗
///
/// 复用 [showParagraphSelectionSheet] 通用组件，
/// 增加段间停顿倍数选项。
library;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/sentence.dart';
import 'common/paragraph_selection_sheet.dart';

/// 显示盲听段落选择弹窗
Future<void> showBlindListenParagraphSheet({
  required BuildContext context,
  required List<Sentence> sentences,
  required void Function(Duration targetDuration, double pauseMultiplier)
      onStartPractice,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showParagraphSelectionSheet(
    context: context,
    icon: Icons.headphones,
    title: l10n.blindListenBriefingTitle,
    subtitle: l10n.blindListenBriefingTip,
    sentences: sentences,
    showPauseMultiplier: true,
    pauseMultiplierOptions: const [0.5, 1.0, 1.5, 2.0, 3.0],
    onStartPractice: onStartPractice,
  );
}
