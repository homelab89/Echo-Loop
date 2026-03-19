/// 段落进度信息行
///
/// 左侧显示 "段落 X/Y"，右侧显示 "段落时长 Xs"。
/// 复述和盲听页面共用。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 段落进度信息行
class ParagraphProgressHeader extends StatelessWidget {
  /// 当前段落索引（0-based）
  final int currentIndex;

  /// 总段落数
  final int totalParagraphs;

  /// 当前段落时长
  final Duration paragraphDuration;

  const ParagraphProgressHeader({
    super.key,
    required this.currentIndex,
    required this.totalParagraphs,
    required this.paragraphDuration,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final durationText = '${paragraphDuration.inSeconds}s';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.retellParagraphProgress(currentIndex + 1, totalParagraphs),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.retellParagraphDuration(durationText),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
