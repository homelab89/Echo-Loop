/// 盲听设置模型
///
/// 控制盲听段落播放的重复次数和段间停顿模式。
/// 仅在会话内临时生效，不持久化。
library;

import 'intensive_listen_settings.dart' show PauseMode;

/// 盲听设置（会话内临时生效）
class BlindListenSettings {
  /// 每段重复次数（1-5，默认 1）
  final int repeatCount;

  /// 停顿模式（默认 multiplier）
  final PauseMode pauseMode;

  /// 固定间隔秒数（默认 15）
  final int fixedPauseSeconds;

  /// 段长倍数（默认 1.5）
  final double pauseMultiplier;

  /// 固定间隔可选值（秒）
  static const List<int> fixedPauseOptions = [5, 8, 10, 15, 20, 25, 30];

  /// 倍数可选值
  static const List<double> multiplierOptions = [
    0.3, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0,
  ];

  const BlindListenSettings({
    this.repeatCount = 1,
    this.pauseMode = PauseMode.multiplier,
    this.fixedPauseSeconds = 15,
    this.pauseMultiplier = 1.5,
  });

  /// 根据段落时长计算段间停顿时长
  Duration calculatePauseDuration(Duration paragraphDuration) {
    final ms = switch (pauseMode) {
      PauseMode.smart => (2000 + paragraphDuration.inMilliseconds * 3)
          .clamp(5000, 300000),
      PauseMode.fixed => fixedPauseSeconds * 1000,
      PauseMode.multiplier =>
        (paragraphDuration.inMilliseconds * pauseMultiplier).round(),
    };
    // 最少 3 秒
    return Duration(milliseconds: ms < 3000 ? 3000 : ms);
  }

  BlindListenSettings copyWith({
    int? repeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
  }) {
    return BlindListenSettings(
      repeatCount: repeatCount ?? this.repeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
    );
  }
}
