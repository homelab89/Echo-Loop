/// 问卷顶部进度条 + 文字。
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class SurveyProgressBar extends StatelessWidget {
  const SurveyProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = total == 0 ? 0.0 : current / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingProgress(current, total),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
