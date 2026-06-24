import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/services/background_audio_handler.dart';

/// just_audio 播放器的最小 mock：仅满足 [EchoLoopAudioHandler] 构造与
/// `_broadcastState` 读取的接口，不做真实播放。
class _MockAudioPlayer extends Mock implements ja.AudioPlayer {}

void main() {
  late _MockAudioPlayer player;
  late EchoLoopAudioHandler handler;

  setUp(() {
    player = _MockAudioPlayer();
    // 构造函数订阅这两个流，给空流即可。
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<ja.PlaybackEvent>.empty());
    when(
      () => player.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    // _broadcastState 读取的瞬时状态。
    when(() => player.playing).thenReturn(false);
    when(() => player.processingState).thenReturn(ja.ProcessingState.idle);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.speed).thenReturn(1.0);
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    handler = EchoLoopAudioHandler(player: player);
  });

  group('skip 回调', () {
    test('未注册时 skipToNext/skipToPrevious 为 no-op，且控制列表不含切句', () async {
      await handler.skipToNext();
      await handler.skipToPrevious();

      // 触发一次广播后读取 controls（未注册回调 → 仅播放/停止）。
      handler.setSkipHandlers(onPrevious: null, onNext: null);
      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls.contains(MediaControl.skipToPrevious), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });

    test('注册后 skipToNext/skipToPrevious 触发对应回调', () async {
      var nextCalls = 0;
      var prevCalls = 0;
      handler.setSkipHandlers(
        onPrevious: () async => prevCalls++,
        onNext: () async => nextCalls++,
      );

      await handler.skipToNext();
      await handler.skipToPrevious();

      expect(nextCalls, 1);
      expect(prevCalls, 1);
    });

    test('注册后控制列表与 systemActions 包含切句', () {
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToPrevious), isTrue);
      expect(state.controls.contains(MediaControl.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToPrevious), isTrue);
    });

    test('清空回调后控制列表恢复为播放/停止', () {
      handler.setSkipHandlers(onPrevious: () async {}, onNext: () async {});
      handler.setSkipHandlers(onPrevious: null, onNext: null);

      final state = handler.playbackState.value;
      expect(state.controls.contains(MediaControl.skipToNext), isFalse);
      expect(state.controls, contains(MediaControl.stop));
    });
  });

  group('play/pause 命令路由', () {
    test('未注册时 play/pause 直接驱动底层播放器', () async {
      await handler.play();
      await handler.pause();

      verify(() => player.play()).called(1);
      verify(() => player.pause()).called(1);
    });

    test('注册后 play/pause 转交业务回调，不直接碰播放器', () async {
      var playCalls = 0;
      var pauseCalls = 0;
      handler.setTransportHandlers(
        onPlay: () async => playCalls++,
        onPause: () async => pauseCalls++,
      );

      await handler.play();
      await handler.pause();

      expect(playCalls, 1);
      expect(pauseCalls, 1);
      verifyNever(() => player.play());
      verifyNever(() => player.pause());
    });

    test('playPlayer/pausePlayer 始终直接驱动播放器（不经回调）', () async {
      handler.setTransportHandlers(onPlay: () async {}, onPause: () async {});

      await handler.playPlayer();
      await handler.pausePlayer();

      verify(() => player.play()).called(1);
      verify(() => player.pause()).called(1);
    });
  });
}
