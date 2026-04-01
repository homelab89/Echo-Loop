/// 跟读会话阶段状态机
///
/// 表达跟读流程的顶层阶段，每个阶段互斥。
/// 流程：PlayingPrompt → Recording → (ReviewingRecording) → WaitingInterval → 下一遍/句
///
/// 关键设计：
/// - **倒计时只在 WaitingInterval**：播放/录音/回放时没有倒计时
/// - **Interrupted 统一处理打断**：区分 manualPause（恢复剩余时间）和其他打断（恢复后重置 T）
/// - **flowToken 防异步竞态**：所有异步回调校验 token，过期直接丢弃
library;

/// 跟读流程阶段
sealed class ShadowingPhase {
  const ShadowingPhase();
}

/// 空闲（未开始或已停止）
class Idle extends ShadowingPhase {
  const Idle();
}

/// 播放原句中
class PlayingPrompt extends ShadowingPhase {
  const PlayingPrompt();
}

/// 录音中（用户跟读）
class ShadowingRecording extends ShadowingPhase {
  const ShadowingRecording();
}

/// 播放录音回放中
class ReviewingRecording extends ShadowingPhase {
  const ReviewingRecording();
}

/// 遍间等待（倒计时 T 秒，唯一可以有倒计时的阶段）
class WaitingInterval extends ShadowingPhase {
  const WaitingInterval();
}

/// 被打断（查词典、改设置、手动暂停等）
class Interrupted extends ShadowingPhase {
  /// 打断原因
  final InterruptReason reason;

  /// 打断前所在的阶段（恢复时回到这个阶段）
  final ShadowingPhase phaseBeforeInterrupt;

  const Interrupted({required this.reason, required this.phaseBeforeInterrupt});
}

/// 当前句子所有遍数完成（短暂过渡，自动推进到下一句或完成）
class SentenceCompleted extends ShadowingPhase {
  const SentenceCompleted();
}

/// 整个会话完成（所有句子全部跟读完）
class SessionCompleted extends ShadowingPhase {
  const SessionCompleted();
}

/// 打断原因
enum InterruptReason {
  /// 用户手动暂停（恢复后继续剩余倒计时间）
  manualPause,

  /// 查词典（恢复后重置完整 T 秒）
  lookupWord,

  /// 打开设置（恢复后重置完整 T 秒）
  settings,
}
