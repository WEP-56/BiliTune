import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/favorite_folder_dialogs.dart';
import '../../shared/widgets/play_button.dart';
import '../../shared/widgets/progress_bar.dart';

class FullScreenPlayer extends ConsumerStatefulWidget {
  const FullScreenPlayer({super.key});

  @override
  ConsumerState<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends ConsumerState<FullScreenPlayer> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = ref.watch(playbackProvider.select((state) => state.track));
    final media = MediaQuery.of(context);
    final topInset = media.viewPadding.top + AppSpacing.s3;
    final bottomInset = media.padding.bottom + AppSpacing.s3;
    final hue = ((track?.gradientSeed ?? 0) * 47) % 360;
    final topColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.30).toColor();
    final coverSize = math.min(
      media.size.width - AppSpacing.s12,
      media.size.height * 0.34,
    );

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
      },
      child: Container(
        height: media.size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, colors.bgBase],
            stops: const [0.0, 0.55],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s6,
            topInset,
            AppSpacing.s6,
            bottomInset,
          ),
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                width: coverSize,
                height: coverSize,
                child: CoverImage(
                  url: track?.coverUrl,
                  gradientSeed: track?.gradientSeed ?? 0,
                  radius: AppRadius.lg,
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              const _TrackTitleActions(),
              const SizedBox(height: AppSpacing.s4),
              const _FullScreenProgressControls(),
              const SizedBox(height: AppSpacing.s3),
              const _FullScreenTransportControls(),
              const SizedBox(height: AppSpacing.s4),
              _MobilePlayerTabs(
                index: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
              const SizedBox(height: AppSpacing.s2),
              Expanded(child: _tabBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody() {
    return switch (_tab) {
      0 => const _LyricsPaneHost(),
      1 => const _QueuePaneHost(),
      _ => const _RelatedPaneHost(),
    };
  }
}

class _TrackTitleActions extends ConsumerWidget {
  const _TrackTitleActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (track: state.track, liked: state.liked),
      ),
    );
    final track = snapshot.track;
    final notifier = ref.read(playbackProvider.notifier);
    final downloadQueue = ref.read(downloadQueueProvider.notifier);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                track?.title ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleL.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                track?.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          iconSize: 28,
          icon: Icon(
            snapshot.liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: snapshot.liked ? colors.brand : colors.textPrimary,
          ),
          onPressed: track == null
              ? null
              : () async {
                  final added = await showAddToFavoriteDialog(context, track);
                  if (added == true) notifier.setLiked(true);
                },
        ),
        IconButton(
          iconSize: 24,
          icon: Icon(Icons.download_outlined, color: colors.textSecondary),
          onPressed: track == null
              ? null
              : () => downloadQueue.enqueueTrack(track),
        ),
      ],
    );
  }
}

class _FullScreenProgressControls extends ConsumerWidget {
  const _FullScreenProgressControls();

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

    return Column(
      children: [
        BiliProgressBar(
          value: snapshot.progress,
          bufferValue: snapshot.bufferProgress,
          onChangeEnd: ref.read(playbackProvider.notifier).seekFraction,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Format.duration(snapshot.position),
              style: AppTypography.caption.copyWith(color: colors.textTertiary),
            ),
            Text(
              Format.duration(snapshot.duration),
              style: AppTypography.caption.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

class _FullScreenTransportControls extends ConsumerWidget {
  const _FullScreenTransportControls();

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TransportIcon(
          icon: Icons.shuffle_rounded,
          active: snapshot.shuffle,
          onPressed: notifier.toggleShuffle,
        ),
        _TransportIcon(
          icon: Icons.skip_previous_rounded,
          size: 40,
          onPressed: notifier.previous,
        ),
        PlayButton(
          isPlaying: snapshot.isPlaying,
          size: 64,
          onTap: notifier.togglePlay,
        ),
        _TransportIcon(
          icon: Icons.skip_next_rounded,
          size: 40,
          onPressed: notifier.next,
        ),
        _TransportIcon(
          icon: snapshot.repeat == PlayRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: snapshot.repeat != PlayRepeatMode.off,
          onPressed: notifier.cycleRepeat,
        ),
      ],
    );
  }
}

class _LyricsPaneHost extends ConsumerWidget {
  const _LyricsPaneHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LyricsPane(
      lyrics: ref.watch(nowPlayingLyricsProvider),
      position: ref.watch(playbackProvider.select((state) => state.position)),
    );
  }
}

class _QueuePaneHost extends ConsumerWidget {
  const _QueuePaneHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (queue: state.queue, currentTrackId: state.track?.id),
      ),
    );
    return _QueuePane(
      queue: snapshot.queue,
      currentTrackId: snapshot.currentTrackId,
      onPlay: (track) => ref
          .read(playbackProvider.notifier)
          .playTrack(track, queue: snapshot.queue),
    );
  }
}

class _RelatedPaneHost extends ConsumerWidget {
  const _RelatedPaneHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RelatedPane(
      related: ref.watch(nowPlayingRelatedProvider),
      onPlay: (track, queue) =>
          ref.read(playbackProvider.notifier).playTrack(track, queue: queue),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.textPrimary,
              size: 30,
            ),
            onPressed: onClose,
          ),
          const Spacer(),
          Text(
            '正在播放',
            style: AppTypography.overline.copyWith(color: colors.textSecondary),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: colors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.size = 26,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      iconSize: size,
      icon: Icon(icon, color: active ? colors.brand : colors.textSecondary),
      onPressed: onPressed,
    );
  }
}

class _MobilePlayerTabs extends StatelessWidget {
  const _MobilePlayerTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _tabs = <({String label, IconData icon})>[
    (label: '歌词', icon: Icons.lyrics_outlined),
    (label: '队列', icon: Icons.queue_music_rounded),
    (label: '相关', icon: Icons.travel_explore_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: 0.78),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: AppRadius.smAll,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i == index ? colors.bgHighlight : Colors.transparent,
                    borderRadius: AppRadius.smAll,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _tabs[i].icon,
                        size: 18,
                        color: i == index
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.s1),
                      Text(
                        _tabs[i].label,
                        style: AppTypography.caption.copyWith(
                          color: i == index
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontWeight: i == index
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LyricsPane extends StatefulWidget {
  const _LyricsPane({required this.lyrics, required this.position});

  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;

  @override
  State<_LyricsPane> createState() => _LyricsPaneState();
}

class _LyricsPaneState extends State<_LyricsPane> {
  final _controller = ScrollController();
  final _lineKeys = <GlobalKey>[];
  int? _lastCenteredIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return widget.lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const _PanelMessage(title: '未找到歌词', subtitle: '当前曲目暂时没有匹配到可用歌词。'),
      data: (lines) {
        if (lines.isEmpty) {
          return const _PanelMessage(
            title: '未找到歌词',
            subtitle: '会优先使用 B 站字幕，再尝试匹配 LRCLIB 歌词。',
          );
        }
        _syncLineKeys(lines.length);
        final currentIndex = _currentLyricIndex(lines, widget.position);
        _scheduleCenterCurrentLine(currentIndex);
        final timed = currentIndex >= 0;

        return ListView.builder(
          controller: _controller,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s1,
            vertical: timed ? AppSpacing.s8 : AppSpacing.s3,
          ),
          itemCount: lines.length,
          itemBuilder: (_, i) {
            final current = i == currentIndex;
            return Padding(
              key: _lineKeys[i],
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: AnimatedDefaultTextStyle(
                duration: AppDuration.fast,
                curve: Curves.easeOut,
                style: (current ? AppTypography.titleS : AppTypography.body)
                    .copyWith(
                      color: current ? colors.brand : colors.textSecondary,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    ),
                child: Text(
                  lines[i].text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _syncLineKeys(int length) {
    if (_lineKeys.length == length) return;
    if (_lineKeys.length > length) {
      _lineKeys.removeRange(length, _lineKeys.length);
      return;
    }
    _lineKeys.addAll(
      List<GlobalKey>.generate(length - _lineKeys.length, (_) => GlobalKey()),
    );
  }

  void _scheduleCenterCurrentLine(int index) {
    if (index < 0 || _lastCenteredIndex == index) return;
    _lastCenteredIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _lineKeys.length) return;
      final context = _lineKeys[index].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.45,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _currentLyricIndex(List<LyricLine> lines, Duration position) {
    final timed = lines.any((line) => line.time > Duration.zero);
    if (!timed) return -1;
    var index = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time > position) break;
      index = i;
    }
    return index;
  }
}

class _QueuePane extends StatelessWidget {
  const _QueuePane({
    required this.queue,
    required this.currentTrackId,
    required this.onPlay,
  });

  final List<Track> queue;
  final String? currentTrackId;
  final ValueChanged<Track> onPlay;

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return const _PanelMessage(title: '队列为空', subtitle: '播放搜索结果或歌单后会形成播放队列。');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      itemCount: queue.length,
      itemBuilder: (_, index) {
        final track = queue[index];
        return _TrackTile(
          track: track,
          selected: track.id == currentTrackId,
          leadingText: '${index + 1}',
          onTap: () => onPlay(track),
        );
      },
    );
  }
}

class _RelatedPane extends StatelessWidget {
  const _RelatedPane({required this.related, required this.onPlay});

  final AsyncValue<List<Track>> related;
  final void Function(Track track, List<Track> queue) onPlay;

  @override
  Widget build(BuildContext context) {
    return related.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const _PanelMessage(title: '暂无相关音乐', subtitle: '当前曲目没有匹配到相似音乐内容。'),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const _PanelMessage(
            title: '暂无相关音乐',
            subtitle: '换一首带有明确标题和 UP 信息的音乐再试。',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.s2),
          itemCount: tracks.length,
          itemBuilder: (_, index) {
            final track = tracks[index];
            return _TrackTile(track: track, onTap: () => onPlay(track, tracks));
          },
        );
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    this.selected = false,
    this.leadingText,
    this.onTap,
  });

  final Track track;
  final bool selected;
  final String? leadingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.bgHighlight : Colors.transparent,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s2,
            vertical: AppSpacing.s2,
          ),
          child: Row(
            children: [
              if (leadingText != null) ...[
                SizedBox(
                  width: 24,
                  child: Text(
                    leadingText!,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: selected ? colors.brand : colors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              SizedBox(
                width: 44,
                height: 44,
                child: CoverImage(
                  url: track.coverUrl,
                  gradientSeed: track.gradientSeed,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: selected ? colors.brand : colors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleS.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
