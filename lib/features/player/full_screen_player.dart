import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../state/providers.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/play_button.dart';
import '../../shared/widgets/progress_bar.dart';

/// Mobile full-screen player (design doc §7.4). Big cover, transport, scrubber,
/// and a lyric preview, over a gradient pulled toward the cover's hue. Shown as
/// a draggable full-height sheet; the chevron / down-drag dismisses it.
class FullScreenPlayer extends ConsumerWidget {
  const FullScreenPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);
    final track = state.track;
    final hue = ((track?.gradientSeed ?? 0) * 47) % 360;
    final topColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.30).toColor();

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
      },
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, colors.bgBase],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.textPrimary,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      '正在播放',
                      style: AppTypography.overline.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: colors.textPrimary,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const Spacer(),
                // Cover
                AspectRatio(
                  aspectRatio: 1,
                  child: CoverImage(
                    url: track?.coverUrl,
                    gradientSeed: track?.gradientSeed ?? 0,
                    radius: AppRadius.lg,
                  ),
                ),
                const Spacer(),
                // Title + like
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track?.title ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleL.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          Text(
                            track?.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 28,
                      icon: Icon(
                        state.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: state.liked ? colors.brand : colors.textPrimary,
                      ),
                      onPressed: notifier.toggleLike,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                // Scrubber
                BiliProgressBar(
                  value: state.progress,
                  onChangeEnd: notifier.seekFraction,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Format.duration(state.position),
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    Text(
                      Format.duration(state.duration),
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                // Transport
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      iconSize: 26,
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: state.shuffle
                            ? colors.brand
                            : colors.textSecondary,
                      ),
                      onPressed: notifier.toggleShuffle,
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: colors.textPrimary,
                      ),
                      onPressed: notifier.previous,
                    ),
                    PlayButton(
                      isPlaying: state.isPlaying,
                      size: 64,
                      onTap: notifier.togglePlay,
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: colors.textPrimary,
                      ),
                      onPressed: notifier.next,
                    ),
                    IconButton(
                      iconSize: 26,
                      icon: Icon(
                        state.repeat == PlayRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: state.repeat != PlayRepeatMode.off
                            ? colors.brand
                            : colors.textSecondary,
                      ),
                      onPressed: notifier.cycleRepeat,
                    ),
                  ],
                ),
                const Spacer(),
                // Lyric preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.06),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '月光下的歌声轻轻响起',
                        style: AppTypography.titleS.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        '你的旋律划过我心底',
                        style: AppTypography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                // Secondary actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      color: colors.textSecondary,
                    ),
                    Icon(Icons.lyrics_outlined, color: colors.textSecondary),
                    Icon(Icons.download_outlined, color: colors.textSecondary),
                    Icon(Icons.share_outlined, color: colors.textSecondary),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
