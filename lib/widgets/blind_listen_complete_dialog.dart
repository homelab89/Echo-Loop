/// 全文盲听完成对话框
///
/// 播放完成后弹出，展示已听遍数和 5 档难度选择。
/// 无默认值，必须选择难度后才能点击"下一步"。
/// "再听一遍"按钮不需要选择难度即可点击。
/// 不可通过返回键或点击外部区域关闭。
library;

import 'package:flutter/material.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 显示盲听完成对话框
///
/// 返回 `null` 表示用户选择"再听一遍"，
/// 返回 [DifficultyLevel] 表示用户选择难度后点击"下一步"。
Future<DifficultyLevel?> showBlindListenCompleteDialog({
  required BuildContext context,
  required int passCount,
}) {
  return showDialog<DifficultyLevel?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BlindListenCompleteDialog(passCount: passCount),
  );
}

/// 盲听完成对话框
class BlindListenCompleteDialog extends StatefulWidget {
  /// 已完成的盲听遍数
  final int passCount;

  const BlindListenCompleteDialog({super.key, required this.passCount});

  @override
  State<BlindListenCompleteDialog> createState() =>
      _BlindListenCompleteDialogState();
}

class _BlindListenCompleteDialogState extends State<BlindListenCompleteDialog> {
  /// 选中的难度等级（null = 未选择）
  DifficultyLevel? _selectedDifficulty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    /// 难度标签（国际化）
    final difficultyLabels = {
      DifficultyLevel.veryEasy: l10n.difficultyVeryEasy,
      DifficultyLevel.easy: l10n.difficultyEasy,
      DifficultyLevel.medium: l10n.difficultyMedium,
      DifficultyLevel.hard: l10n.difficultyHard,
      DifficultyLevel.veryHard: l10n.difficultyVeryHard,
    };

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Text(l10n.blindListenComplete),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 已听遍数
            Text(
              l10n.blindListenPassInfo(widget.passCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 难度选择标题
            Text(
              l10n.selectDifficulty,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // 5 档难度选择
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: DifficultyLevel.values.map((level) {
                final isSelected = _selectedDifficulty == level;
                return ChoiceChip(
                  label: Text(difficultyLabels[level] ?? level.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDifficulty = selected ? level : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          // 再听一遍按钮
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(l10n.listenAgain),
          ),
          // 下一步按钮（未选择难度时置灰）
          FilledButton(
            onPressed: _selectedDifficulty != null
                ? () => Navigator.of(context).pop(_selectedDifficulty)
                : null,
            child: Text(l10n.nextStage),
          ),
        ],
      ),
    );
  }
}
