import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/services/speech_practice_platform.dart';

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  _FakeSpeechPracticeBackend({
    this.permissions = const SpeechPracticePermissionState(
      microphone: SpeechPracticePermissionStatus.granted,
      speech: SpeechPracticePermissionStatus.granted,
    ),
    this.autoEmitFinalOnStop = true,
  });

  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  SpeechPracticePermissionState permissions;
  String nextFinalTranscript = '';
  int deleteCallCount = 0;
  int permissionCheckCount = 0;
  int _counter = 0;
  String? _activePromptId;
  SpeechPracticePlatformException? permissionError;
  SpeechPracticePlatformException? startSessionError;
  bool autoEmitFinalOnStop;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    permissionCheckCount += 1;
    if (permissionError != null) {
      throw permissionError!;
    }
    return permissions;
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions() async {
    return permissions;
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    if (startSessionError != null) {
      throw startSessionError!;
    }
    _counter += 1;
    _activePromptId = promptId;
    return '/tmp/$promptId-$_counter.caf';
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    final promptId = _activePromptId;
    if (promptId != null && autoEmitFinalOnStop) {
      scheduleMicrotask(() {
        _controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: promptId,
            transcript: nextFinalTranscript,
          ),
        );
      });
    }
    return SpeechPracticeStopResult(
      filePath: '/tmp/${promptId ?? 'prompt'}-$_counter.caf',
    );
  }

  @override
  Future<void> cancelSession() async {
    _activePromptId = null;
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    deleteCallCount += 1;
  }

  void emitFinalEvent(String promptId, String transcript) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.finalTranscriptReady,
        promptId: promptId,
        transcript: transcript,
      ),
    );
  }

  void emitSpeechStarted(String promptId) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.speechStarted,
        promptId: promptId,
      ),
    );
  }

  void emitSilenceProgress(String promptId, Duration silenceDuration) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.silenceProgress,
        promptId: promptId,
        silenceDuration: silenceDuration,
      ),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechPracticeSession', () {
    test('开始和结束录音后生成通过结果', () async {
      final backend = _FakeSpeechPracticeBackend()
        ..nextFinalTranscript = 'test sentence number one';
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);
      await notifier.startRecording(promptId: 'prompt');
      final attempt = await notifier.stopRecordingAndEvaluate(
        promptId: 'prompt',
        referenceText: 'Test sentence number one',
      );

      expect(attempt, isNotNull);
      expect(attempt!.status, SpeechPracticeAttemptStatus.passed);
      expect(attempt.finalTranscript, 'test sentence number one');
      expect(
        container.read(speechPracticeSessionProvider).recordingPromptId,
        isNull,
      );
      expect(
        container.read(speechPracticeSessionProvider).awaitingFinalPromptId,
        isNull,
      );
    });

    test('停止后先等待 final transcript 再更新最终状态', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinalOnStop: false);
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);
      await notifier.startRecording(promptId: 'prompt');

      final future = notifier.stopRecordingAndEvaluate(
        promptId: 'prompt',
        referenceText: 'Test sentence number one',
      );

      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(speechPracticeSessionProvider).awaitingFinalPromptId,
        'prompt',
      );

      backend.emitFinalEvent('prompt', 'test sentence number one');
      final attempt = await future;
      expect(attempt?.status, SpeechPracticeAttemptStatus.passed);
    });

    test('权限拒绝时直接进入 permissionDenied', () async {
      final backend = _FakeSpeechPracticeBackend(
        permissions: const SpeechPracticePermissionState(
          microphone: SpeechPracticePermissionStatus.denied,
          speech: SpeechPracticePermissionStatus.denied,
        ),
      );
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);
      await notifier.startRecording(promptId: 'prompt');

      expect(
        container
            .read(speechPracticeSessionProvider)
            .attempts['prompt']
            ?.status,
        SpeechPracticeAttemptStatus.permissionDenied,
      );
    });

    test('disposeSession 会删除临时录音', () async {
      final backend = _FakeSpeechPracticeBackend()
        ..nextFinalTranscript = 'test sentence';
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);
      await notifier.startRecording(promptId: 'prompt');
      await notifier.stopRecordingAndEvaluate(
        promptId: 'prompt',
        referenceText: 'test sentence',
      );
      await notifier.disposeSession();

      expect(backend.deleteCallCount, greaterThanOrEqualTo(1));
      expect(container.read(speechPracticeSessionProvider).attempts, isEmpty);
    });

    test('平台不可用时不会抛未处理异常，并写入 unavailable 状态', () async {
      final backend = _FakeSpeechPracticeBackend()
        ..permissionError = const SpeechPracticePlatformException(
          'notAvailable',
          'plugin missing',
        );
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);
      await notifier.startRecording(promptId: 'prompt');

      expect(
        container
            .read(speechPracticeSessionProvider)
            .attempts['prompt']
            ?.status,
        SpeechPracticeAttemptStatus.unavailable,
      );
    });

    test('收到 speechStarted 和 silenceProgress 时更新录音中的检测状态', () async {
      final backend = _FakeSpeechPracticeBackend();
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);
      await notifier.startRecording(promptId: 'prompt');

      backend.emitSpeechStarted('prompt');
      backend.emitSilenceProgress('prompt', const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);

      final attempt = container
          .read(speechPracticeSessionProvider)
          .attempts['prompt'];
      expect(attempt?.hasDetectedSpeech, isTrue);
      expect(attempt?.silenceDuration, const Duration(seconds: 2));
    });

    test('已缓存 granted 时第二次录音跳过权限检查', () async {
      final backend = _FakeSpeechPracticeBackend()
        ..nextFinalTranscript = 'hello';
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);

      // 第一次录音：需要查权限。
      await notifier.startRecording(promptId: 'p1');
      await notifier.stopRecordingAndEvaluate(
        promptId: 'p1',
        referenceText: 'hello',
      );
      final checksAfterFirst = backend.permissionCheckCount;
      expect(checksAfterFirst, greaterThan(0));

      // 第二次录音：缓存已 granted，不再查权限。
      await notifier.startRecording(promptId: 'p2');
      expect(backend.permissionCheckCount, checksAfterFirst);
    });

    test('startSession 权限失败时异步刷新缓存', () async {
      final backend = _FakeSpeechPracticeBackend();
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        container.dispose();
        await backend.dispose();
      });

      final notifier = container.read(speechPracticeSessionProvider.notifier);

      // 第一次正常录音，缓存 granted。
      await notifier.startRecording(promptId: 'p1');
      await notifier.cancelActiveRecording();
      final checksBeforeError = backend.permissionCheckCount;

      // 模拟 startSession 返回权限错误。
      backend.startSessionError = const SpeechPracticePlatformException(
        'permissionDenied',
        'permission revoked',
      );
      await notifier.startRecording(promptId: 'p2');

      // 应异步刷新权限缓存。
      await Future<void>.delayed(Duration.zero);
      expect(backend.permissionCheckCount, greaterThan(checksBeforeError));
      expect(
        container
            .read(speechPracticeSessionProvider)
            .attempts['p2']
            ?.status,
        SpeechPracticeAttemptStatus.permissionDenied,
      );
    });
  });
}
