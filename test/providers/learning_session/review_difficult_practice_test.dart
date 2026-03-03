// ReviewDifficultPracticeState 单元测试
//
// 测试状态类的 copyWith 和初始值行为。
// Provider 的播放逻辑依赖 SentencePlaybackEngine，
// 集成测试在 integration_test 中覆盖。
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';

void main() {
  group('ReviewDifficultPracticeState', () {
    test('初始状态 — 默认值正确', () {
      const state = ReviewDifficultPracticeState();

      expect(state.currentSentenceIndex, 0);
      expect(state.totalSentences, 0);
      expect(state.currentPlayCount, 1);
      expect(state.isPlaying, false);
      expect(state.isPauseBetweenPlays, false);
      expect(state.isPauseBetweenSentences, false);
      expect(state.pauseRemaining, Duration.zero);
      expect(state.pauseDuration, Duration.zero);
      expect(state.isAnnotationMode, false);
      expect(state.isAnnotationReplay, false);
      expect(state.isTextRevealed, false);
      expect(state.isCompleted, false);
    });

    test('copyWith — 更新单个字段', () {
      const state = ReviewDifficultPracticeState();
      final updated = state.copyWith(
        currentSentenceIndex: 2,
        totalSentences: 5,
      );

      expect(updated.currentSentenceIndex, 2);
      expect(updated.totalSentences, 5);
      // 未修改字段保持不变
      expect(updated.isPlaying, false);
      expect(updated.isAnnotationMode, false);
    });

    test('copyWith — 进入标注模式', () {
      const state = ReviewDifficultPracticeState(
        totalSentences: 3,
        isPlaying: true,
      );
      final annotation = state.copyWith(
        isAnnotationMode: true,
        isPlaying: false,
        isPauseBetweenPlays: false,
      );

      expect(annotation.isAnnotationMode, true);
      expect(annotation.isPlaying, false);
      expect(annotation.totalSentences, 3);
    });

    test('copyWith — 进入标注重播', () {
      const state = ReviewDifficultPracticeState(
        isAnnotationMode: true,
        totalSentences: 5,
      );
      final replay = state.copyWith(
        isAnnotationMode: false,
        isAnnotationReplay: true,
        isPlaying: true,
      );

      expect(replay.isAnnotationMode, false);
      expect(replay.isAnnotationReplay, true);
      expect(replay.isPlaying, true);
    });

    test('copyWith — 偷看字幕', () {
      const state = ReviewDifficultPracticeState();
      final peeked = state.copyWith(isTextRevealed: true);

      expect(peeked.isTextRevealed, true);
      // 偷看不影响播放状态
      expect(peeked.isPlaying, false);
      expect(peeked.isAnnotationMode, false);
    });

    test('copyWith — 标记完成', () {
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 4,
        totalSentences: 5,
        isPlaying: true,
      );
      final completed = state.copyWith(
        isCompleted: true,
        isPlaying: false,
      );

      expect(completed.isCompleted, true);
      expect(completed.isPlaying, false);
      expect(completed.currentSentenceIndex, 4);
    });

    test('copyWith — 句间停顿状态', () {
      const state = ReviewDifficultPracticeState(totalSentences: 3);
      final pausing = state.copyWith(
        isPauseBetweenPlays: true,
        isPauseBetweenSentences: true,
        isPlaying: false,
        pauseDuration: const Duration(seconds: 2),
        pauseRemaining: const Duration(seconds: 2),
      );

      expect(pausing.isPauseBetweenPlays, true);
      expect(pausing.isPauseBetweenSentences, true);
      expect(pausing.pauseDuration, const Duration(seconds: 2));
      expect(pausing.pauseRemaining, const Duration(seconds: 2));

      // 模拟停顿 tick
      final ticked = pausing.copyWith(
        pauseRemaining: const Duration(seconds: 1),
      );
      expect(ticked.pauseRemaining, const Duration(seconds: 1));
      expect(ticked.pauseDuration, const Duration(seconds: 2));
    });

    test('copyWith — 切句时重置标注/偷看状态', () {
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 1,
        totalSentences: 5,
        isAnnotationMode: true,
        isTextRevealed: true,
      );
      final nextSentence = state.copyWith(
        currentSentenceIndex: 2,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        currentPlayCount: 1,
      );

      expect(nextSentence.currentSentenceIndex, 2);
      expect(nextSentence.isAnnotationMode, false);
      expect(nextSentence.isAnnotationReplay, false);
      expect(nextSentence.isTextRevealed, false);
    });
  });
}
