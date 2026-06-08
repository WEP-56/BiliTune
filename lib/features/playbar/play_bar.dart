import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../player/immersive_player.dart';
import '../../state/providers.dart';
import '../../shared/widgets/favorite_folder_dialogs.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/play_button.dart';
import '../../shared/widgets/progress_bar.dart';

/// Desktop bottom play bar (design doc §6.5): left = track info, center =
/// transport + scrubber, right = queue / now-playing / volume.
class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
          const Expanded(flex: 3, child: _TrackInfoSection()),
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const _CenterControls(),
            ),
          ),
          const Expanded(flex: 3, child: _RightControls()),
        ],
      ),
    );
  }
}

class _TrackInfoSection extends ConsumerWidget {
  const _TrackInfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (track: state.track, liked: state.liked),
      ),
    );
    final track = snapshot.track;

    return Row(
      children: [
        GestureDetector(
          onTap: () => ref.read(nowPlayingOpenProvider.notifier).toggle(),
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
            snapshot.liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: snapshot.liked ? colors.brand : colors.textSecondary,
          ),
          onPressed: track == null
              ? null
              : () async {
                  final added = await showAddToFavoriteDialog(context, track);
                  if (added == true) {
                    ref.read(playbackProvider.notifier).setLiked(true);
                  }
                },
        ),
      ],
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportControls(),
        SizedBox(height: AppSpacing.s1),
        _PlaybackProgressControls(),
      ],
    );
  }
}

class _TransportControls extends ConsumerWidget {
  const _TransportControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          shuffle: state.shuffle,
          repeat: state.repeat,
        ),
      ),
    );
    final notifier = ref.read(playbackProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportIcon(
          icon: Icons.shuffle_rounded,
          active: snapshot.shuffle,
          onTap: notifier.toggleShuffle,
        ),
        const SizedBox(width: AppSpacing.s4),
        _TransportIcon(
          icon: Icons.skip_previous_rounded,
          onTap: notifier.previous,
        ),
        const SizedBox(width: AppSpacing.s4),
        PlayButton(
          isPlaying: snapshot.isPlaying,
          elevated: false,
          size: 40,
          onTap: notifier.togglePlay,
        ),
        const SizedBox(width: AppSpacing.s4),
        _TransportIcon(icon: Icons.skip_next_rounded, onTap: notifier.next),
        const SizedBox(width: AppSpacing.s4),
        _TransportIcon(
          icon: snapshot.repeat == PlayRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: snapshot.repeat != PlayRepeatMode.off,
          onTap: notifier.cycleRepeat,
        ),
      ],
    );
  }
}

class _PlaybackProgressControls extends ConsumerWidget {
  const _PlaybackProgressControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (
          position: state.position,
          duration: state.duration,
          progress: state.progress,
          bufferProgress: state.bufferProgress,
        ),
      ),
    );

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            Format.duration(snapshot.position),
            textAlign: TextAlign.right,
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: BiliProgressBar(
            value: snapshot.progress,
            bufferValue: snapshot.bufferProgress,
            onChangeEnd: ref.read(playbackProvider.notifier).seekFraction,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        SizedBox(
          width: 40,
          child: Text(
            Format.duration(snapshot.duration),
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _RightControls extends StatelessWidget {
  const _RightControls();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _QueueButton(),
        SizedBox(width: AppSpacing.s3),
        _NowPlayingButton(),
        SizedBox(width: AppSpacing.s3),
        _VolumeControls(),
      ],
    );
  }
}

class _QueueButton extends StatelessWidget {
  const _QueueButton();

  @override
  Widget build(BuildContext context) {
    return _ImmersiveButton();
  }
}

class _ImmersiveButton extends ConsumerWidget {
  const _ImmersiveButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(
      playbackProvider.select((state) => state.track != null),
    );
    final enabled = defaultTargetPlatform == TargetPlatform.windows && hasTrack;

    return _TransportIcon(
      icon: Icons.queue_music_rounded,
      onTap: enabled ? () => showImmersivePlayer(context) : null,
    );
  }
}

class _NowPlayingButton extends ConsumerWidget {
  const _NowPlayingButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(nowPlayingOpenProvider);
    return _TransportIcon(
      icon: Icons.picture_in_picture_alt_rounded,
      active: open,
      onTap: () => ref.read(nowPlayingOpenProvider.notifier).toggle(),
    );
  }
}

class _VolumeControls extends ConsumerWidget {
  const _VolumeControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final volume = ref.watch(playbackProvider.select((state) => state.volume));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          size: 20,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.s2),
        SizedBox(
          width: 96,
          child: BiliProgressBar(
            value: volume,
            onChanged: ref.read(playbackProvider.notifier).setVolume,
          ),
        ),
      ],
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
  final VoidCallback? onTap;
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
