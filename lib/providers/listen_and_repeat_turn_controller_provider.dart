/// 跟读回合状态机 provider。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import 'speech_practice_session_provider.dart';

const _awaitingSpeechReminderDelay = Duration(seconds: 5);
const _awaitingSpeechFallbackDelay = Duration(seconds: 15);
const _defaultSilenceThreshold = Duration(seconds: 5);
const _maxRecordingMultiplier = 2.5;
const _maxRecordingBuffer = Duration(seconds: 5);
const _maxRecordingFloor = Duration(seconds: 10);
const _reviewCountdownDuration = Duration(seconds: 5);
const _fairScoreThreshold = 0.45;
const _autoRetryDelay = Duration(seconds: 4);
const _maxConsecutiveFailures = 3;

enum ListenAndRepeatTurnPhase {
  idle,
  awaitingSpeech,
  speaking,
  processing,
  reviewCountdown,

  /// 评级未达 Fair，短暂展示反馈后自动重新录音。
  retryPending,
  manualFallback,
}

class ListenAndRepeatTurnState {
  final ListenAndRepeatTurnPhase phase;
  final String? promptId;
  final String? referenceText;
  final bool hasShownSpeechReminder;
  final Duration reviewCountdownRemaining;
  final bool isReviewCountdownPaused;

  const ListenAndRepeatTurnState({
    this.phase = ListenAndRepeatTurnPhase.idle,
    this.promptId,
    this.referenceText,
    this.hasShownSpeechReminder = false,
    this.reviewCountdownRemaining = _reviewCountdownDuration,
    this.isReviewCountdownPaused = false,
  });

  bool get isActive =>
      phase != ListenAndRepeatTurnPhase.idle &&
      phase != ListenAndRepeatTurnPhase.manualFallback &&
      phase != ListenAndRepeatTurnPhase.retryPending;

  ListenAndRepeatTurnState copyWith({
    ListenAndRepeatTurnPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    String? referenceText,
    bool clearReferenceText = false,
    bool? hasShownSpeechReminder,
    Duration? reviewCountdownRemaining,
    bool? isReviewCountdownPaused,
  }) {
    return ListenAndRepeatTurnState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      referenceText: clearReferenceText
          ? null
          : (referenceText ?? this.referenceText),
      hasShownSpeechReminder:
          hasShownSpeechReminder ?? this.hasShownSpeechReminder,
      reviewCountdownRemaining:
          reviewCountdownRemaining ?? this.reviewCountdownRemaining,
      isReviewCountdownPaused:
          isReviewCountdownPaused ?? this.isReviewCountdownPaused,
    );
  }
}

class SpeechPracticeCompletionHeuristic {
  const SpeechPracticeCompletionHeuristic();

  static final RegExp _englishWordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

  /// 根据实时转录与参考句的匹配程度，计算所需静音等待时长。
  ///
  /// 三条规则取最小值：
  /// A. 连续尾部匹配 ≥ 1 且唯一 → 1s
  /// B. 全句匹配率：100% → 1s, ≥95% → 2s, ≥90% → 3s
  /// C. 末尾 5 词命中数 → 5s/4s/3s/2s/1s
  Duration computeSilenceThreshold({
    required String referenceText,
    required String partialTranscript,
  }) {
    final referenceTokens = _tokenize(referenceText);
    final transcriptTokens = _tokenize(partialTranscript);
    if (referenceTokens.isEmpty || transcriptTokens.isEmpty) {
      return _defaultSilenceThreshold;
    }

    final lcsPairs = _computeLcsPairs(referenceTokens, transcriptTokens);
    if (lcsPairs.isEmpty) {
      return _defaultSilenceThreshold;
    }

    final matchedRefIndexes = lcsPairs.map((p) => p.$1).toSet();
    final tailSize = referenceTokens.length < 5 ? referenceTokens.length : 5;
    final tailStart = referenceTokens.length - tailSize;

    // 规则 A：连续尾部完整匹配 + 唯一 → 1s
    var ruleA = _defaultSilenceThreshold;
    var consecutiveTail = 0;
    for (var i = referenceTokens.length - 1; i >= 0; i--) {
      if (matchedRefIndexes.contains(i)) {
        consecutiveTail++;
      } else {
        break;
      }
    }
    if (consecutiveTail >= 1) {
      final uniqueStart = referenceTokens.length - consecutiveTail;
      if (_isSubsequenceUnique(referenceTokens, uniqueStart)) {
        ruleA = const Duration(seconds: 1);
      }
    }

    // 规则 B：全句匹配率
    var ruleB = _defaultSilenceThreshold;
    final score = lcsPairs.length / referenceTokens.length;
    if (score >= 1.0) {
      ruleB = const Duration(seconds: 1);
    } else if (score >= 0.95) {
      ruleB = const Duration(seconds: 2);
    } else if (score >= 0.90) {
      ruleB = const Duration(seconds: 3);
    }

    // 规则 C：末尾 5 词命中数
    var tailMatchCount = 0;
    for (var i = tailStart; i < referenceTokens.length; i++) {
      if (matchedRefIndexes.contains(i)) {
        tailMatchCount++;
      }
    }
    final ruleC = switch (tailMatchCount) {
      <= 1 => const Duration(seconds: 5),
      2 => const Duration(seconds: 4),
      3 => const Duration(seconds: 3),
      4 => const Duration(seconds: 2),
      _ => const Duration(seconds: 1),
    };

    // 取三条规则最小值
    var result = ruleA;
    if (ruleB < result) result = ruleB;
    if (ruleC < result) result = ruleC;
    return result;
  }

  /// 检查 [tokens] 从 [start] 到末尾的连续子序列在 [tokens] 中是否只出现一次。
  bool _isSubsequenceUnique(List<String> tokens, int start) {
    final tail = tokens.sublist(start);
    final tailLength = tail.length;
    var count = 0;
    for (var i = 0; i <= tokens.length - tailLength; i++) {
      var match = true;
      for (var j = 0; j < tailLength; j++) {
        if (tokens[i + j] != tail[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        count++;
        if (count > 1) return false;
      }
    }
    return count == 1;
  }

  List<String> _tokenize(String text) {
    return _englishWordPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((token) => token.isNotEmpty)
        .toList();
  }

  List<(int, int)> _computeLcsPairs(
    List<String> referenceTokens,
    List<String> transcriptTokens,
  ) {
    final rows = referenceTokens.length + 1;
    final cols = transcriptTokens.length + 1;
    final dp = List.generate(rows, (_) => List.filled(cols, 0));

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final pairs = <(int, int)>[];
    var i = referenceTokens.length;
    var j = transcriptTokens.length;
    while (i > 0 && j > 0) {
      if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
        pairs.add((i - 1, j - 1));
        i -= 1;
        j -= 1;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i -= 1;
      } else {
        j -= 1;
      }
    }
    return pairs.reversed.toList();
  }
}

final speechPracticeCompletionHeuristicProvider =
    Provider<SpeechPracticeCompletionHeuristic>((ref) {
      return const SpeechPracticeCompletionHeuristic();
    });

final listenAndRepeatTurnControllerProvider =
    NotifierProvider<ListenAndRepeatTurnController, ListenAndRepeatTurnState>(
      ListenAndRepeatTurnController.new,
    );

class ListenAndRepeatTurnController extends Notifier<ListenAndRepeatTurnState> {
  Timer? _speechReminderTimer;
  Timer? _speechFallbackTimer;
  Timer? _reviewTickTimer;
  Timer? _maxDurationTimer;
  Timer? _autoRetryTimer;
  Timer? _transcriptStaleTimer;
  String? _lastKnownTranscript;
  Duration _sentenceDuration = Duration.zero;
  int _consecutiveFailureCount = 0;
  bool _isStopping = false;

  /// 手动控制模式标志：录音评估后不自动倒计时推进。
  bool _isManualMode = false;

  /// 外部注入的"继续"回调，由使用方（跟读页/难句补练页）注册。
  Future<void> Function()? _onContinue;

  @override
  ListenAndRepeatTurnState build() {
    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _cancelAllTimers();
    });
    ref.listen<SpeechPracticeSessionState>(
      speechPracticeSessionProvider,
      _handleSpeechPracticeStateChanged,
    );
    return const ListenAndRepeatTurnState();
  }

  /// 注册"继续"回调，由使用方在 initState 中调用。
  void setOnContinue(Future<void> Function()? callback) {
    _onContinue = callback;
  }

  /// 设置手动控制模式。
  ///
  /// 手动模式下录音评估完成后不自动启动倒计时推进，
  /// 用户需手动点击下一句。
  void setManualMode(bool value) {
    _isManualMode = value;
  }

  Future<void> ensureTurn({
    required String promptId,
    required String referenceText,
    bool allowAutoFallback = true,
    Duration sentenceDuration = Duration.zero,
  }) async {
    if (state.promptId == promptId && state.isActive) {
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    _lastKnownTranscript = null;
    _sentenceDuration = sentenceDuration;
    state = ListenAndRepeatTurnState(
      phase: ListenAndRepeatTurnPhase.awaitingSpeech,
      promptId: promptId,
      referenceText: referenceText,
      reviewCountdownRemaining: _reviewCountdownDuration,
    );

    final session = ref.read(speechPracticeSessionProvider.notifier);
    await session.startRecording(promptId: promptId);
    final currentAttempt = ref
        .read(speechPracticeSessionProvider.notifier)
        .attemptFor(promptId);
    if (currentAttempt?.status != SpeechPracticeAttemptStatus.recording) {
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
      return;
    }

    // 手动模式：不启动任何自动计时器，完全由用户控制
    if (!_isManualMode) {
      _scheduleMaxDurationTimer(
        promptId: promptId,
        referenceText: referenceText,
        sentenceDuration: sentenceDuration,
      );

      if (allowAutoFallback) {
        _scheduleAwaitingSpeechTimers(promptId);
      }
    }
  }

  /// 自动跟读回合开始：启动录音并启用提醒与回退。
  Future<void> ensureAutoTurn({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: true,
      sentenceDuration: sentenceDuration,
    );
  }

  /// 手动回退后的重新录音：仍然使用同一状态机，但不再显示 5/15 秒自动提醒。
  Future<void> startManualRecording({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: false,
      sentenceDuration: sentenceDuration,
    );
  }

  void enterProcessing(String promptId) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.processing);
  }

  Future<void> handleManualStop() async {
    final promptId = state.promptId;
    final referenceText = state.referenceText;
    if (promptId == null || referenceText == null) {
      return;
    }
    _isStopping = true;
    enterProcessing(promptId);
    await ref
        .read(speechPracticeSessionProvider.notifier)
        .stopRecordingAndEvaluate(
          promptId: promptId,
          referenceText: referenceText,
        );
  }

  Future<void> handleContinue() async {
    _cancelReviewCountdown();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
    if (_onContinue != null) {
      await _onContinue!();
    } else {
      debugPrint('[TurnController] handleContinue: _onContinue 未注册');
    }
  }

  void pauseReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(isReviewCountdownPaused: true);
  }

  void resumeReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (state.reviewCountdownRemaining <= Duration.zero) {
      unawaited(handleContinue());
      return;
    }
    state = state.copyWith(isReviewCountdownPaused: false);
    _startReviewCountdown();
  }

  /// 快进倒计时：立即跳过，进入下一句。
  void fastForwardReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    unawaited(handleContinue());
  }

  void resetReviewCountdownOnPlayback() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: true,
    );
  }

  void activateReviewCountdown({required String promptId}) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    state = state.copyWith(
      phase: ListenAndRepeatTurnPhase.reviewCountdown,
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: false,
    );
    _startReviewCountdown();
  }

  /// App 进入后台时清理 turn，停止所有定时器。
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      clearTurn();
    }
  }

  /// 清除当前回合状态（保留页面级配置 _isManualMode / _onContinue）。
  void clearTurn() {
    _cancelAllTimers();
    _isStopping = false;
    _consecutiveFailureCount = 0;
    state = const ListenAndRepeatTurnState();
  }

  /// 完全重置（页面 dispose 时调用）。
  void fullReset() {
    clearTurn();
    _isManualMode = false;
    _onContinue = null;
  }

  void _handleSpeechPracticeStateChanged(
    SpeechPracticeSessionState? previous,
    SpeechPracticeSessionState next,
  ) {
    final promptId = state.promptId;
    if (promptId == null) {
      return;
    }
    final previousAttempt = previous?.attempts[promptId];
    final attempt = next.attempts[promptId];
    if (attempt == null) {
      return;
    }

    _handleAttemptPlaybackChanged(
      previousPlayingPromptId: previous?.playingPromptId,
      nextPlayingPromptId: next.playingPromptId,
      promptId: promptId,
    );

    if (attempt.status == SpeechPracticeAttemptStatus.awaitingFinal) {
      enterProcessing(promptId);
      return;
    }

    if (attempt.hasFinalFeedback &&
        !(previousAttempt?.hasFinalFeedback ?? false)) {
      // 权限被拒或平台不可用时回退为手动录音，重试也无法解决
      if (attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable) {
        _cancelAllTimers();
        state = state.copyWith(phase: ListenAndRepeatTurnPhase.manualFallback);
        return;
      }
      // 检测失败、识别错误或评级未达 Fair 时自动重试
      final isFailed =
          attempt.status == SpeechPracticeAttemptStatus.noEnglishDetected ||
          attempt.status == SpeechPracticeAttemptStatus.error ||
          (attempt.score ?? 0) < _fairScoreThreshold;
      if (isFailed) {
        // 手动模式下不自动重试，回到 idle 让用户自行操作
        if (_isManualMode) {
          _cancelAllTimers();
          state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
          return;
        }
        _consecutiveFailureCount++;
        if (_consecutiveFailureCount >= _maxConsecutiveFailures) {
          _consecutiveFailureCount = 0;
          _cancelAllTimers();
          state = state.copyWith(
            phase: ListenAndRepeatTurnPhase.manualFallback,
          );
        } else {
          _scheduleAutoRetry(promptId: promptId);
        }
      } else {
        _consecutiveFailureCount = 0;
        if (_isManualMode) {
          // 手动模式：评估成功后回到 idle，由用户手动点击下一句
          _cancelAllTimers();
          state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
        } else {
          activateReviewCountdown(promptId: promptId);
        }
      }
      return;
    }

    // VAD 检测到语音，或 ASR 已产出文字（用户压低声音时 VAD 可能不触发）
    final hasVoiceInput =
        attempt.hasDetectedSpeech ||
        (attempt.liveTranscript?.trim().isNotEmpty ?? false);

    if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech &&
        hasVoiceInput) {
      _cancelAwaitingSpeechTimers();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.speaking);
    }

    // 手动模式：不做静音检测/转录停滞检测，完全由用户点击停止
    if (state.phase == ListenAndRepeatTurnPhase.speaking &&
        !_isStopping &&
        !_isManualMode) {
      _handleSpeakingAttemptUpdate(
        promptId: promptId,
        attempt: attempt,
        previousAttempt: previousAttempt,
      );
    }
  }

  void _scheduleAwaitingSpeechTimers(String promptId) {
    _speechReminderTimer?.cancel();
    _speechFallbackTimer?.cancel();
    _speechReminderTimer = Timer(_awaitingSpeechReminderDelay, () {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      state = state.copyWith(hasShownSpeechReminder: true);
    });
    _speechFallbackTimer = Timer(_awaitingSpeechFallbackDelay, () async {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      await ref
          .read(speechPracticeSessionProvider.notifier)
          .cancelActiveRecording();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.manualFallback);
    });
  }

  void _handleSpeakingAttemptUpdate({
    required String promptId,
    required SpeechPracticeAttempt attempt,
    required SpeechPracticeAttempt? previousAttempt,
  }) {
    final prompt = state.promptId;
    final referenceText = state.referenceText;
    if (prompt != promptId || referenceText == null) {
      return;
    }
    if (!attempt.hasDetectedSpeech) {
      return;
    }

    final liveTranscript = attempt.liveTranscript?.trim() ?? '';

    // ── 通道 1：声学静音 ──
    final currentSilence = attempt.silenceDuration;
    if (currentSilence > Duration.zero && liveTranscript.isNotEmpty) {
      final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
      final required = heuristic.computeSilenceThreshold(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      );
      if (currentSilence >= required) {
        _stopForEvaluation(promptId: promptId, referenceText: referenceText);
        return;
      }
    }
    // 静音 5s 兜底（无转录时）
    if (currentSilence >= _defaultSilenceThreshold) {
      _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      return;
    }

    // ── 通道 2：转录停滞（应对嘈杂环境） ──
    if (liveTranscript.isNotEmpty && liveTranscript != _lastKnownTranscript) {
      _lastKnownTranscript = liveTranscript;
      _resetTranscriptStaleTimer(
        promptId: promptId,
        referenceText: referenceText,
        transcript: liveTranscript,
      );
    }
  }

  /// 转录内容停止更新时的定时器。
  ///
  /// 阈值与声学静音相同（动态计算）。在嘈杂环境中，
  /// 声学静音检测失效，此计时器作为备用结束通道。
  void _resetTranscriptStaleTimer({
    required String promptId,
    required String referenceText,
    required String transcript,
  }) {
    _transcriptStaleTimer?.cancel();
    final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
    final threshold = heuristic.computeSilenceThreshold(
      referenceText: referenceText,
      partialTranscript: transcript,
    );
    _transcriptStaleTimer = Timer(threshold, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != ListenAndRepeatTurnPhase.speaking) return;
      _stopForEvaluation(promptId: promptId, referenceText: referenceText);
    });
  }

  void _handleAttemptPlaybackChanged({
    required String? previousPlayingPromptId,
    required String? nextPlayingPromptId,
    required String promptId,
  }) {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (previousPlayingPromptId != promptId &&
        nextPlayingPromptId == promptId) {
      resetReviewCountdownOnPlayback();
      return;
    }
    if (previousPlayingPromptId == promptId &&
        nextPlayingPromptId != promptId) {
      state = state.copyWith(
        reviewCountdownRemaining: _reviewCountdownDuration,
        isReviewCountdownPaused: false,
      );
      _startReviewCountdown();
    }
  }

  void _startReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown ||
          state.isReviewCountdownPaused) {
        return;
      }
      final nextRemaining =
          state.reviewCountdownRemaining - const Duration(milliseconds: 100);
      if (nextRemaining <= Duration.zero) {
        timer.cancel();
        state = state.copyWith(reviewCountdownRemaining: Duration.zero);
        await handleContinue();
        return;
      }
      state = state.copyWith(reviewCountdownRemaining: nextRemaining);
    });
  }

  void _stopForEvaluation({
    required String promptId,
    required String referenceText,
  }) {
    _isStopping = true;
    enterProcessing(promptId);
    unawaited(
      ref
          .read(speechPracticeSessionProvider.notifier)
          .stopRecordingAndEvaluate(
            promptId: promptId,
            referenceText: referenceText,
          ),
    );
  }

  void _cancelAwaitingSpeechTimers() {
    _speechReminderTimer?.cancel();
    _speechFallbackTimer?.cancel();
    _speechReminderTimer = null;
    _speechFallbackTimer = null;
  }

  void _cancelReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = null;
  }

  /// 评级未达 Fair 时短暂展示反馈，然后自动重新开始录音。
  void _scheduleAutoRetry({required String promptId}) {
    _cancelAllTimers();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.retryPending);
    _autoRetryTimer = Timer(_autoRetryDelay, () {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.retryPending) {
        return;
      }
      final referenceText = state.referenceText;
      if (referenceText == null) return;
      unawaited(
        ensureTurn(
          promptId: promptId,
          referenceText: referenceText,
          allowAutoFallback: false,
          sentenceDuration: _sentenceDuration,
        ),
      );
    });
  }

  /// 启动录音最大时长兜底计时器。
  ///
  /// 超时后静默停止录音并正常评分，用户无感知。
  void _scheduleMaxDurationTimer({
    required String promptId,
    required String referenceText,
    required Duration sentenceDuration,
  }) {
    _maxDurationTimer?.cancel();
    final maxDuration = _computeMaxRecordingDuration(sentenceDuration);
    _maxDurationTimer = Timer(maxDuration, () {
      if (state.promptId != promptId) return;
      if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
          state.phase == ListenAndRepeatTurnPhase.speaking) {
        _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      }
    });
  }

  /// 计算录音最大时长：`max(2.5 × sentenceDuration + 5s, 10s)`。
  Duration _computeMaxRecordingDuration(Duration sentenceDuration) {
    final computed =
        sentenceDuration * _maxRecordingMultiplier + _maxRecordingBuffer;
    return computed < _maxRecordingFloor ? _maxRecordingFloor : computed;
  }

  void _cancelAllTimers() {
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
    _transcriptStaleTimer?.cancel();
    _transcriptStaleTimer = null;
  }
}
