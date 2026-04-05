/// 收藏句子详情页面
///
/// 从收藏列表点击进入，展示单个句子的精听界面。
/// 包含解析/翻译/意群工具栏和单句播放按钮，不包含上下句导航。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart' as model;
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/tappable_wrapper.dart';
import '../widgets/practice/annotation_content_view.dart';

/// 收藏句子详情页面参数
class BookmarkSentenceDetailArgs {
  /// 书签数据
  final Bookmark bookmark;

  /// 音频 ID
  final String audioId;

  /// 音频名称（用于 AppBar 显示）
  final String audioName;

  const BookmarkSentenceDetailArgs({
    required this.bookmark,
    required this.audioId,
    required this.audioName,
  });
}

/// 收藏句子详情页面
class BookmarkSentenceDetailScreen extends ConsumerStatefulWidget {
  /// 页面参数
  final BookmarkSentenceDetailArgs args;

  const BookmarkSentenceDetailScreen({super.key, required this.args});

  @override
  ConsumerState<BookmarkSentenceDetailScreen> createState() =>
      _BookmarkSentenceDetailScreenState();
}

class _BookmarkSentenceDetailScreenState
    extends ConsumerState<BookmarkSentenceDetailScreen> {
  bool _isPlaying = false;

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 播放该句子的原声片段
  Future<void> _playSentence() async {
    final engine = ref.read(audioEngineProvider.notifier);

    if (_isPlaying) {
      engine.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final engineState = ref.read(audioEngineProvider);
      final bm = widget.args.bookmark;

      // 如果当前加载的不是同一音频，重新加载
      if (engineState.currentAudioId != widget.args.audioId) {
        final dao = ref.read(audioItemDaoProvider);
        final row = await dao.getById(widget.args.audioId);
        if (row == null || !mounted) {
          setState(() => _isPlaying = false);
          return;
        }

        final audioItem = model.AudioItem(
          id: row.id,
          name: row.name,
          audioPath: row.audioPath,
          transcriptPath: row.transcriptPath,
          addedDate: row.addedDate,
          totalDuration: row.totalDuration,
          sentenceCount: row.sentenceCount,
          wordCount: row.wordCount,
          isStarred: row.isStarred,
          transcriptSource: model.TranscriptSource.fromIndex(
            row.transcriptSource,
          ),
          audioSha256: row.audioSha256,
          transcriptLanguage: row.transcriptLanguage,
        );

        await engine.loadAudio(audioItem, 1.0);
      }

      if (!mounted) return;

      final sessionId = engine.newSession();
      final start = Duration(
        milliseconds: (bm.startTime * 1000).round(),
      );
      final end = Duration(
        milliseconds: (bm.endTime * 1000).round(),
      );
      await engine.playRangeOnce(start, end, sessionId);
    } catch (_) {
      // 忽略播放错误（音频文件不存在等）
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bm = widget.args.bookmark;

    final durationSec = bm.endTime - bm.startTime;
    final durationText = l10n.sentenceDuration(durationSec.toStringAsFixed(1));
    final timeRangeText =
        '${_formatTime(bm.startTime)} - ${_formatTime(bm.endTime)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.audioName),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(audioEngineProvider.notifier).stop();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          // 句子时间信息
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.l,
              right: AppSpacing.l,
              top: AppSpacing.s,
            ),
            child: Row(
              children: [
                Text(
                  timeRangeText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  durationText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 主体内容：解析/翻译/意群 + 句子文本
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: AnnotationContentView(
                text: bm.sentenceText,
                aiNotifier: ref.read(sentenceAiNotifierProvider),
                audioItemId: widget.args.audioId,
                sentenceIndex: bm.sentenceIndex,
                sentenceStartMs: (bm.startTime * 1000).round(),
                sentenceEndMs: (bm.endTime * 1000).round(),
                onStopMainPlayer: () {
                  if (_isPlaying) {
                    ref.read(audioEngineProvider.notifier).stop();
                    setState(() => _isPlaying = false);
                  }
                },
              ),
            ),
          ),

          // 底部播放按钮（与精听页面 footer 位置一致）
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.m,
              bottom: 64,
            ),
            child: _PlayButton(
              isPlaying: _isPlaying,
              onTap: _playSentence,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单句播放按钮
class _PlayButton extends StatelessWidget {
  /// 是否正在播放
  final bool isPlaying;

  /// 点击回调
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TappableWrapper(
      onTap: onTap,
      feedbackType: TapFeedback.scale,
      scaleDown: 0.92,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 28,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
