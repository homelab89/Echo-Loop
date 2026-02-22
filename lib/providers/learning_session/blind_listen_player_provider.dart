/// 盲听专用播放器 Provider
///
/// 轻量级播放器，直接操作 AudioEngine，绕过 ListeningPractice
/// 的句子追踪和 session 管理。只提供播放/暂停/拖动/完成检测。
///
/// 核心设计：
/// - `isDragging` 标志位在拖动期间屏蔽 position stream 更新 → 消除抖动
/// - `play()` 直接调用 engine.play()，不做 resume 判断 → 消除 seek-then-play bug
/// - 不追踪 currentFullIndex → 消除所有竞态条件
library;

import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../audio_engine/audio_engine_provider.dart';

part 'blind_listen_player_provider.g.dart';

/// 盲听播放器状态
class BlindListenPlayerState {
  /// 是否正在播放
  final bool isPlaying;

  /// 当前播放位置（拖动时显示拖动位置）
  final Duration position;

  /// 音频总时长
  final Duration totalDuration;

  /// 是否已播放完成
  final bool isCompleted;

  /// 是否正在拖动进度条
  final bool isDragging;

  const BlindListenPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isCompleted = false,
    this.isDragging = false,
  });

  BlindListenPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? totalDuration,
    bool? isCompleted,
    bool? isDragging,
  }) {
    return BlindListenPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      isDragging: isDragging ?? this.isDragging,
    );
  }
}

/// 盲听专用播放器 Provider
///
/// 直接操作 AudioEngine，只提供盲听所需的最小控制集：
/// 播放、暂停、拖动进度条、完成检测、重播。
@Riverpod(keepAlive: true)
class BlindListenPlayer extends _$BlindListenPlayer {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ja.PlayerState>? _playerStateSub;

  @override
  BlindListenPlayerState build() {
    ref.onDispose(_cancelSubscriptions);
    return const BlindListenPlayerState();
  }

  /// 初始化盲听播放器（由 LearningSession 调用）
  ///
  /// 订阅 engine 的 position 和 playerState stream，
  /// 设置音频总时长。
  void initialize(Duration totalDuration) {
    _cancelSubscriptions();

    state = BlindListenPlayerState(totalDuration: totalDuration);

    final engine = ref.read(audioEngineProvider.notifier);

    // 订阅位置流 — isDragging 时不更新 position
    _positionSub = engine.absolutePositionStream.listen((pos) {
      if (!state.isDragging) {
        state = state.copyWith(position: pos);
      }
    });

    // 订阅播放状态流 — 检测完成 + 同步 isPlaying
    _playerStateSub = engine.playerStateStream.listen((playerState) {
      final playing = playerState.playing;
      if (playerState.processingState == ja.ProcessingState.completed) {
        state = state.copyWith(isPlaying: false, isCompleted: true);
      } else {
        state = state.copyWith(isPlaying: playing);
      }
    });
  }

  /// 开始播放
  Future<void> play() async {
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.clearClip();
    await engine.play();
    state = state.copyWith(isCompleted: false);
  }

  /// 暂停播放
  Future<void> pause() async {
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.pause();
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration pos) async {
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.clearClip();
    await engine.seek(pos);
    state = state.copyWith(position: pos, isCompleted: false);
  }

  /// 进度条拖动开始
  void onDragStart() {
    state = state.copyWith(isDragging: true);
  }

  /// 进度条拖动中 — 只更新显示位置，不 seek
  void onDragUpdate(Duration pos) {
    state = state.copyWith(position: pos);
  }

  /// 进度条拖动结束 — 执行实际 seek
  Future<void> onDragEnd(Duration pos) async {
    state = state.copyWith(isDragging: false);
    await seekTo(pos);
  }

  /// 重播 — 从头开始播放
  Future<void> resetAndPlay() async {
    await seekTo(Duration.zero);
    await play();
  }

  /// 释放资源 — 取消所有 stream 订阅
  void disposePlayer() {
    _cancelSubscriptions();
    state = const BlindListenPlayerState();
  }

  void _cancelSubscriptions() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub = null;
    _playerStateSub = null;
  }
}
