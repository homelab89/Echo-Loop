/// 通用音频播放服务。
///
/// 封装 just_audio 的 [AudioPlayer]，提供简洁的 play/stop API。
/// [play] 返回 Future，播放完成或 [stop] 时 complete。
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'app_logger.dart';

/// 通用音频播放服务。
class AudioPlaybackService {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _currentFilePath;
  Completer<void> _playCompleter = Completer<void>()..complete();
  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  bool _isDisposed = false;

  /// 当前是否正在播放。
  bool get isPlaying => _player?.playing ?? false;

  /// 当前播放的文件路径。
  String? get currentFilePath => _currentFilePath;

  // TODO: 等其他页面迁移到新架构后删除，改用 play() 返回的 Future
  /// 播放状态流（其他页面使用）。
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  /// 播放音频文件，返回 Future 在播放完成或被 [stop] 时 complete。
  Future<void> play(String filePath) async {
    if (_isDisposed) {
      AppLogger.log('AudioPlayback', '播放失败: service 已释放 path=$filePath');
      throw StateError('AudioPlaybackService has been disposed');
    }

    // 停止当前播放
    if (_player != null) {
      await _player!.stop();
    }
    // 结束旧的 Future
    if (!_playCompleter.isCompleted) {
      _playCompleter.complete();
    }
    _playCompleter = Completer<void>();

    final player = await _ensurePlayer();
    _currentFilePath = filePath;
    AppLogger.log('AudioPlayback', '开始播放: path=$filePath');
    _isPlayingController.add(true);
    await player.setFilePath(filePath);
    await player.play();

    return _playCompleter.future;
  }

  /// 停止播放。
  Future<void> stop() async {
    if (_isDisposed) {
      AppLogger.log('AudioPlayback', '停止播放跳过: service 已释放');
      return;
    }

    AppLogger.log('AudioPlayback', '停止播放: path=$_currentFilePath');
    _currentFilePath = null;
    _isPlayingController.add(false);
    if (_player != null) {
      await _player!.stop();
    }
    if (!_playCompleter.isCompleted) {
      _playCompleter.complete();
    }
  }

  /// 释放资源。
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    AppLogger.log('AudioPlayback', '释放播放服务: path=$_currentFilePath');
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }
    _currentFilePath = null;
    if (!_playCompleter.isCompleted) {
      _playCompleter.complete();
    }
    await _isPlayingController.close();
  }

  /// 懒初始化播放器。
  Future<AudioPlayer> _ensurePlayer() async {
    if (_isDisposed) {
      throw StateError('AudioPlaybackService has been disposed');
    }
    if (_player != null) return _player!;

    final player = AudioPlayer();
    _player = player;
    _playerStateSub = player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        AppLogger.log('AudioPlayback', '播放完成: path=$_currentFilePath');
        _currentFilePath = null;
        _isPlayingController.add(false);
        if (!_playCompleter.isCompleted) {
          _playCompleter.complete();
        }
      }
    });
    return player;
  }
}
