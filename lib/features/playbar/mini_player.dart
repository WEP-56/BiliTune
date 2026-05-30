import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../state/providers.dart';
import '../../shared/widgets/cover_image.dart';

/// Mobile floating mini player (design doc §7.3): a 2px brand progress line on
/// top, compact track info, and quick controls. Tapping opens the full-screen
/// player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);
    final track = state.track;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppLayout.miniPlayerHeight,
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: AppRadius.mdAll,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top progress line
            LinearProgressIndicator(
              value: state.progress,
              minHeight: 2,
              backgroundColor: colors.bgActive,
              valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CoverImage(
                        url: track?.coverUrl,
                        gradientSeed: track?.gradientSeed ?? 0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track?.title ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          Text(track?.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption
                                  .copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 22,
                      icon: Icon(
                        state.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: state.liked
                            ? colors.brand
                            : colors.textSecondary,
                      ),
                      onPressed: notifier.toggleLike,
                    ),
                    IconButton(
                      iconSize: 26,
                      icon: Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: colors.textPrimary,
                      ),
                      onPressed: notifier.togglePlay,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
