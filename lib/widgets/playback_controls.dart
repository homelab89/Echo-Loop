import 'package:flutter/material.dart';
import '../providers/player_provider.dart';

class PlaybackControls extends StatelessWidget {
  final PlayerProvider player;

  const PlaybackControls({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 单句模式开关
          _buildToggleButton(
            context,
            icon: player.settings.singleSentenceMode
                ? Icons.format_quote
                : Icons.article,
            isActive: player.settings.singleSentenceMode,
            onPressed: () {
              player.updateSettings(
                player.settings.copyWith(
                  singleSentenceMode: !player.settings.singleSentenceMode,
                ),
              );
            },
            tooltip: 'Single Sentence Mode',
          ),
          const SizedBox(width: 8),
          // 显示字幕开关
          _buildToggleButton(
            context,
            icon: player.settings.showTranscript
                ? Icons.visibility
                : Icons.visibility_off,
            isActive: player.settings.showTranscript,
            onPressed: () {
              player.updateSettings(
                player.settings.copyWith(
                  showTranscript: !player.settings.showTranscript,
                ),
              );
            },
            tooltip: 'Show Transcript',
          ),
          const SizedBox(width: 16),
          // 上一句
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 32,
            onPressed: player.hasSentences
                ? () => player.previousSentence()
                : null,
            tooltip: 'Previous Sentence',
          ),
          const SizedBox(width: 8),
          // 播放/暂停按钮（中间位置）
          _buildPlayPauseButton(context),
          const SizedBox(width: 8),
          // 下一句
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 32,
            onPressed: player.hasSentences ? () => player.nextSentence() : null,
            tooltip: 'Next Sentence',
          ),
          const SizedBox(width: 16),
          // 播放速度
          _buildSpeedButton(context),
          const SizedBox(width: 8),
          // 句子循环开关
          _buildToggleButton(
            context,
            icon: Icons.repeat_one,
            isActive: player.settings.loopEnabled,
            onPressed: () {
              player.updateSettings(
                player.settings.copyWith(
                  loopEnabled: !player.settings.loopEnabled,
                ),
              );
            },
            tooltip: 'Sentence Repeat',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    print('isMainPlaybackPlaying: ${player.isMainPlaybackPlaying}');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          player.isMainPlaybackPlaying ? Icons.pause : Icons.play_arrow,
        ),
        iconSize: 40,
        color: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          if (player.isMainPlaybackPlaying) {
            player.pause();
          } else {
            player.mainPlay();
          }
        },
        tooltip: player.isMainPlaybackPlaying ? 'Pause' : 'Play',
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 24,
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }

  Widget _buildSpeedButton(BuildContext context) {
    return PopupMenuButton<double>(
      icon: Text(
        '${player.settings.playbackSpeed}x',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      tooltip: 'Playback Speed',
      itemBuilder: (context) {
        return [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
          return PopupMenuItem<double>(
            value: speed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${speed}x'),
                if (speed == player.settings.playbackSpeed)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (speed) {
        player.updateSettings(player.settings.copyWith(playbackSpeed: speed));
      },
    );
  }
}
