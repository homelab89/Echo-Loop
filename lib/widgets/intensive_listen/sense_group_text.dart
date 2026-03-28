/// 意群标注文本组件
///
/// 将句子按意群渲染为内联 badge 样式，保持自然文本排版。
/// 不同意群使用不同的柔和背景色区分，可点击播放对应音频片段。
/// 支持三种状态：空闲 / 播放中 / 已播放。
/// 意群内单词仍可点击查词典。
library;

import 'package:flutter/material.dart';
import '../../models/sense_group_result.dart';
import '../../utils/sense_group_timing.dart';

/// 意群 badge 背景色板（亮色主题）
const _groupColorsLight = [
  Color(0xFFE3F2FD), // 浅蓝
  Color(0xFFFCE4EC), // 浅粉
  Color(0xFFE8F5E9), // 浅绿
  Color(0xFFFFF8E1), // 浅黄
  Color(0xFFF3E5F5), // 浅紫
  Color(0xFFE0F7FA), // 浅青
];

/// 意群 badge 背景色板（暗色主题）
const _groupColorsDark = [
  Color(0xFF1A3A5C), // 深蓝
  Color(0xFF4A2030), // 深粉
  Color(0xFF1A3A2A), // 深绿
  Color(0xFF3A3520), // 深黄
  Color(0xFF2E1A3A), // 深紫
  Color(0xFF1A3A3A), // 深青
];

/// 意群标注文本
///
/// 使用 Wrap + badge 实现，意群间留出间距，意群内单词保持正常间距。
class SenseGroupText extends StatefulWidget {
  /// 意群列表
  final List<SenseGroup> groups;

  /// 各意群时间范围
  final List<SenseGroupTiming> timings;

  /// 正在播放的意群索引（null 表示无播放）
  final int? playingGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex) onTapGroup;

  const SenseGroupText({
    super.key,
    required this.groups,
    required this.timings,
    this.playingGroupIndex,
    this.playedGroupIndices = const {},
    required this.onTapGroup,
  });

  @override
  State<SenseGroupText> createState() => _SenseGroupTextState();
}

class _SenseGroupTextState extends State<SenseGroupText> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
      height: 1.4,
      color: colorScheme.onSurface,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < widget.groups.length; i++)
          _buildGroupBadge(i, baseStyle, colorScheme),
      ],
    );
  }

  /// 构建单个意群 badge
  Widget _buildGroupBadge(
    int index,
    TextStyle? baseStyle,
    ColorScheme colorScheme,
  ) {
    final group = widget.groups[index];
    final isPlaying = widget.playingGroupIndex == index;
    final isPlayed = widget.playedGroupIndices.contains(index);

    // 背景色：播放中用主题色，否则按索引循环使用色板
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? _groupColorsDark : _groupColorsLight;
    final bgColor = isPlaying
        ? colorScheme.primaryContainer
        : palette[index % palette.length];

    // 边框：始终保留相同宽度，避免点击时布局偏移
    final borderColor = isPlaying
        ? colorScheme.primary
        : isPlayed
        ? colorScheme.primary.withValues(alpha: 0.3)
        : Colors.transparent;
    final border = Border.all(color: borderColor, width: 1.5);

    return GestureDetector(
      onTap: () => widget.onTapGroup(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: border,
        ),
        child: Text(
          group.text.trim(),
          style: baseStyle?.copyWith(
            fontWeight: group.isCore ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
