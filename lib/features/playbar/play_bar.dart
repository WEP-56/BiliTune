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

/// Desktop bottom play bar (design doc §6.5): left = track info, center =
/// transport + scrubber, right = queue / now-playing / volume.
class PlayBar extends ConsumerWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);
    final track = state.track;

    return Container(
      height: AppLayout.playBarHeight,
      decoration: BoxDecoration(
        color: colors.bgBase,
        border: Border(
          top: BorderSide(color: colors.textPrimary.withValues(alpha: 0.06)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          // Left: track info
          Expanded(
            flex: 3,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ref.read(nowPlayingOpenProvider.notifier).toggle(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: CoverImage(
                        url: track?.coverUrl,
                        gradientSeed: track?.gradientSeed ?? 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        track?.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                IconButton(
                  iconSize: 20,
                  icon: Icon(
                    state.liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: state.liked ? colors.brand : colors.textSecondary,
                  ),
                  onPressed: notifier.toggleLike,
                ),
              ],
            ),
          ),
          // Center: transport + scrubber
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TransportIcon(
                        icon: Icons.shuffle_rounded,
                        active: state.shuffle,
                        onTap: notifier.toggleShuffle,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      _TransportIcon(
                        icon: Icons.skip_previous_rounded,
                        onTap: notifier.previous,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      PlayButton(
                        isPlaying: state.isPlaying,
                        elevated: false,
                        size: 40,
                        onTap: notifier.togglePlay,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      _TransportIcon(
                        icon: Icons.skip_next_rounded,
                        onTap: notifier.next,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      _TransportIcon(
                        icon: state.repeat == PlayRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        active: state.repeat != PlayRepeatMode.off,
                        onTap: notifier.cycleRepeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          Format.duration(state.position),
                          textAlign: TextAlign.right,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: BiliProgressBar(
                          value: state.progress,
                          onChangeEnd: notifier.seekFraction,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      SizedBox(
                        width: 40,
                        child: Text(
                          Format.duration(state.duration),
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Right: queue / now-playing / volume
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TransportIcon(icon: Icons.queue_music_rounded, onTap: () {}),
                const SizedBox(width: AppSpacing.s3),
                _TransportIcon(
                  icon: Icons.picture_in_picture_alt_rounded,
                  active: ref.watch(nowPlayingOpenProvider),
                  onTap: () =>
                      ref.read(nowPlayingOpenProvider.notifier).toggle(),
                ),
                const SizedBox(width: AppSpacing.s3),
                Icon(
                  state.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s2),
                SizedBox(
                  width: 96,
                  child: BiliProgressBar(
                    value: state.volume,
                    onChanged: notifier.setVolume,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      onPressed: onTap,
      iconSize: 22,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: active ? colors.brand : colors.textSecondary),
    );
  }
}
