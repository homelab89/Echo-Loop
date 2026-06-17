/// 按难句比例自动判定音频难度
///
/// 逐句精听完成后，根据用户收藏的难句占总句数的比例自动推断音频难度，
/// 取代原来「盲听后让用户手动选择难度」的交互。判定出的难度仅用于决定
/// 后续各步骤 / 各复习轮次的默认播放速度（见 [defaultPlaybackSpeedFor]）。
library;

import '../database/enums.dart';

/// 根据「难句比例 = [difficult] / [total]」映射到 5 档难度。
///
/// 阈值（含上界）：
/// - `ratio == 0`        → veryEasy
/// - `ratio <= 0.05`     → easy
/// - `ratio <= 0.15`     → medium
/// - `ratio <= 0.30`     → hard
/// - `ratio >  0.30`     → veryHard
///
/// [total] <= 0（无句子）按 veryEasy 处理，避免除零。
DifficultyLevel difficultyFromDifficultRatio(int total, int difficult) {
  if (total <= 0) return DifficultyLevel.veryEasy;
  final ratio = difficult / total;
  if (ratio == 0) return DifficultyLevel.veryEasy;
  if (ratio <= 0.05) return DifficultyLevel.easy;
  if (ratio <= 0.15) return DifficultyLevel.medium;
  if (ratio <= 0.30) return DifficultyLevel.hard;
  return DifficultyLevel.veryHard;
}
