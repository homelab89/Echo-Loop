import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/providers/listen_and_repeat_turn_controller_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/services/speech_practice_platform.dart';

import '../helpers/mock_providers.dart';

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  bool autoEmitFinal;
  String? activePromptId;
  int counter = 0;

  _FakeSpeechPracticeBackend({this.autoEmitFinal = true});

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    return const SpeechPracticePermissionState(
      microphone: SpeechPracticePermissionStatus.granted,
      speech: SpeechPracticePermissionStatus.granted,
    );
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions() {
    return getPermissionStatus();
  }

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    activePromptId = promptId;
    counter += 1;
    return '/tmp/$promptId-$counter.caf';
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    final promptId = activePromptId ?? 'shadowing:a1:0';
    if (autoEmitFinal) {
      scheduleMicrotask(() {
        _controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: promptId,
            transcript: 'done',
          ),
        );
      });
    }
    return SpeechPracticeStopResult(filePath: '/tmp/$promptId-$counter.caf');
  }

  @override
  Future<void> cancelSession() async {}

  @override
  Future<void> deleteRecording(String filePath) async {}

  void emitPartial(String transcript) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.partialTranscriptUpdated,
        promptId: activePromptId ?? 'shadowing:a1:0',
        transcript: transcript,
      ),
    );
  }

  void emitSpeechStarted() {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.speechStarted,
        promptId: activePromptId ?? 'shadowing:a1:0',
      ),
    );
  }

  void emitSilence(Duration duration) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.silenceProgress,
        promptId: activePromptId ?? 'shadowing:a1:0',
        silenceDuration: duration,
      ),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  group('SpeechPracticeCompletionHeuristic', () {
    const heuristic = SpeechPracticeCompletionHeuristic();

    test('句尾命中且整体分数足够时判定已说完', () {
      final result = heuristic.isLikelyComplete(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'I noticed your name on the door',
      );

      expect(result, isTrue);
    });

    test('整体分数不足时即使有句尾也不判定已说完', () {
      final result = heuristic.isLikelyComplete(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'name on the door',
      );

      expect(result, isFalse);
    });

    test('没有命中句尾词时不判定已说完', () {
      final result = heuristic.isLikelyComplete(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'Anyhow I noticed your name',
      );

      expect(result, isFalse);
    });
  });

  group('ListenAndRepeatTurnController', () {
    test('静音 1 秒且内容看起来已说完时自动进入 processing', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureAutoTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      backend.emitPartial('I noticed your name on the door');
      backend.emitSpeechStarted();
      backend.emitSilence(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final turnState = container.read(listenAndRepeatTurnControllerProvider);
      final speechState = container.read(speechPracticeSessionProvider);
      expect(turnState.phase, ListenAndRepeatTurnPhase.processing);
      expect(speechState.awaitingFinalPromptId, 'shadowing:a1:0');
    });

    test('review 倒计时在回放录音时重置为完整 5 秒', () async {
      final backend = _FakeSpeechPracticeBackend();
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
        allowAutoFallback: false,
      );
      controller.activateReviewCountdown(promptId: 'shadowing:a1:0');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      controller.resetReviewCountdownOnPlayback();
      final pausedState = container.read(listenAndRepeatTurnControllerProvider);
      expect(pausedState.isReviewCountdownPaused, isTrue);
      expect(pausedState.reviewCountdownRemaining, const Duration(seconds: 5));

      controller.resumeReviewCountdown();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final resumedState = container.read(
        listenAndRepeatTurnControllerProvider,
      );
      expect(
        resumedState.reviewCountdownRemaining,
        lessThan(const Duration(seconds: 5)),
      );
    });

    test(
      '15 秒无声 manualFallback 后调用 startManualRecording 能重新进入 awaitingSpeech',
      () {
        fakeAsync((async) {
          final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
          final container = ProviderContainer(
            overrides: [
              speechPracticeBackendProvider.overrideWithValue(backend),
              listenAndRepeatPlayerProvider.overrideWith(
                () => TestListenAndRepeatPlayer(
                  const ListenAndRepeatPlayerState(
                    currentSentenceIndex: 0,
                    totalSentences: 1,
                    currentPlayCount: 1,
                    isPauseBetweenPlays: true,
                  ),
                  createTestSentences(count: 1),
                ),
              ),
            ],
          );

          final controller = container.read(
            listenAndRepeatTurnControllerProvider.notifier,
          );
          controller.ensureAutoTurn(
            promptId: 'shadowing:a1:0',
            referenceText: 'Hello world',
          );
          async.flushMicrotasks();

          // 15 秒后进入 manualFallback
          async.elapse(const Duration(seconds: 15));
          final fallbackState = container.read(
            listenAndRepeatTurnControllerProvider,
          );
          expect(fallbackState.phase, ListenAndRepeatTurnPhase.manualFallback);

          // 用户再点录音按钮
          controller.startManualRecording(
            promptId: 'shadowing:a1:0',
            referenceText: 'Hello world',
          );
          async.flushMicrotasks();

          final retriedState = container.read(
            listenAndRepeatTurnControllerProvider,
          );
          expect(retriedState.phase, ListenAndRepeatTurnPhase.awaitingSpeech);

          backend.dispose();
          container.dispose();
        });
      },
    );

    test(
      '识别失败（noEnglishDetected）时回退为 manualFallback 而非 reviewCountdown',
      () async {
        // autoEmitFinal: false，手动控制 final transcript 时机
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );
        addTearDown(() async {
          await backend.dispose();
          container.dispose();
        });

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        await controller.ensureAutoTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
        );

        // 手动停止录音 → session 进入 awaitingFinal → turn 进入 processing
        // handleManualStop 内部调用 stopRecordingAndEvaluate，
        // 返回的 Future 在 final transcript 到达后才 complete
        final stopFuture = controller.handleManualStop();

        // 发送空 final transcript → matcher 判定 noEnglishDetected
        await Future<void>.delayed(const Duration(milliseconds: 10));
        backend._controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: 'shadowing:a1:0',
            transcript: '',
          ),
        );
        await stopFuture;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final turnState = container.read(listenAndRepeatTurnControllerProvider);
        expect(turnState.phase, ListenAndRepeatTurnPhase.manualFallback);
      },
    );
  });
}
