/// 盲听段落选择底部弹窗
///
/// 进入段落盲听前显示，两行下拉菜单选择段落时长和段间停顿。
library;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/blind_listen_settings.dart';
import '../models/sentence.dart';
import '../theme/app_theme.dart';
import '../utils/paragraph_grouping.dart';

/// 目标段落时长选项（秒）
const _durationOptions = [10, 20, 30, 45, 60, 90];

/// 显示盲听段落选择弹窗
Future<void> showBlindListenParagraphSheet({
  required BuildContext context,
  required List<Sentence> sentences,
  required void Function(Duration targetDuration, double pauseMultiplier) onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _BlindListenParagraphSheet(
      sentences: sentences,
      onStartPractice: onStartPractice,
    ),
  );
}

class _BlindListenParagraphSheet extends StatefulWidget {
  final List<Sentence> sentences;
  final void Function(Duration targetDuration, double pauseMultiplier) onStartPractice;

  const _BlindListenParagraphSheet({
    required this.sentences,
    required this.onStartPractice,
  });

  @override
  State<_BlindListenParagraphSheet> createState() =>
      _BlindListenParagraphSheetState();
}

class _BlindListenParagraphSheetState
    extends State<_BlindListenParagraphSheet> {
  int _targetSeconds = 30;
  double _pauseMultiplier = 1.5;

  int get _paragraphCount {
    return groupSentencesIntoParagraphs(
      widget.sentences,
      Duration(seconds: _targetSeconds),
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 耳机图标
            Icon(Icons.headphones, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.m),

            // 标题
            Text(
              l10n.blindListenBriefingTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 说明
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                l10n.blindListenBriefingTip,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 段落时长行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.blindListenTargetDuration,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<int>(
                      value: _targetSeconds,
                      underline: const SizedBox.shrink(),
                      items: _durationOptions.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text('${s}s'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _targetSeconds = v);
                      },
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      l10n.blindListenParagraphCount(_paragraphCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s),

            // 段长倍数行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.blindListenPauseBetween,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DropdownButton<double>(
                  value: _pauseMultiplier,
                  underline: const SizedBox.shrink(),
                  items: BlindListenSettings.multiplierOptions.map((m) {
                    final label = m == m.roundToDouble()
                        ? '${m.toInt()}x'
                        : '${m}x';
                    return DropdownMenuItem(
                      value: m,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _pauseMultiplier = v);
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.l),

            // 开始练习按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStartPractice(
                    Duration(seconds: _targetSeconds),
                    _pauseMultiplier,
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startPractice),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
