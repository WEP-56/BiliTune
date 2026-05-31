import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../state/providers.dart';

/// Desktop right-side playback details: cover, actions, lyrics, queue, related.
class NowPlayingPanel extends ConsumerStatefulWidget {
  const NowPlayingPanel({super.key});

  @override
  ConsumerState<NowPlayingPanel> createState() => _NowPlayingPanelState();
}

class _NowPlayingPanelState extends ConsumerState<NowPlayingPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final playback = ref.watch(playbackProvider);
    final track = playback.track;
    final downloadQueue = ref.read(downloadQueueProvider.notifier);

    return Container(
      width: AppLayout.nowPlayingWidth,
      margin: const EdgeInsets.only(
        right: AppSpacing.s4,
        top: AppSpacing.s2,
        bottom: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: AppRadius.mdAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s3,
              AppSpacing.s2,
              AppSpacing.s2,
            ),
            child: Row(
              children: [
                Text(
                  '正在播放',
                  style: AppTypography.titleS.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  iconSize: 20,
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  onPressed: () =>
                      ref.read(nowPlayingOpenProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: AspectRatio(
              aspectRatio: 1,
              child: CoverImage(
                url: track?.coverUrl,
                gradientSeed: track?.gradientSeed ?? 0,
                radius: AppRadius.md,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
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
                        style: AppTypography.titleS.copyWith(
                          color: colors.textPrimary,
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
                IconButton(
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.download_outlined,
                    color: colors.textSecondary,
                  ),
                  onPressed: track == null
                      ? null
                      : () => downloadQueue.enqueueTrack(track),
                ),
                const SizedBox(width: AppSpacing.s4),
                Icon(
                  Icons.share_outlined,
                  color: colors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
          _TabBar(index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const Divider(height: 1),
          Expanded(child: _tabBody(playback)),
        ],
      ),
    );
  }

  Widget _tabBody(PlaybackState playback) {
    switch (_tab) {
      case 0:
        return _LyricsPane(
          lyrics: ref.watch(nowPlayingLyricsProvider),
          position: playback.position,
        );
      case 1:
        return _QueuePane(
          playback: playback,
          onPlay: (track) => ref
              .read(playbackProvider.notifier)
              .playTrack(track, queue: playback.queue),
        );
      default:
        return _RelatedPane(
          related: ref.watch(nowPlayingRelatedProvider),
          onPlay: (track, queue) => ref
              .read(playbackProvider.notifier)
              .playTrack(track, queue: queue),
        );
    }
  }
}

class _LyricsPane extends StatelessWidget {
  const _LyricsPane({required this.lyrics, required this.position});

  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const _PanelMessage(title: '未找到歌词', subtitle: '当前曲目暂时没有匹配到可用歌词。'),
      data: (lines) {
        if (lines.isEmpty) {
          return const _PanelMessage(
            title: '未找到歌词',
            subtitle: '会优先用 B 站关联歌曲信息匹配 LRCLIB 歌词。',
          );
        }
        final currentIndex = _currentLyricIndex(lines, position);
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.s4),
          itemCount: lines.length,
          itemBuilder: (_, i) {
            final current = i == currentIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Text(
                lines[i].text,
                style: (current ? AppTypography.titleS : AppTypography.body)
                    .copyWith(
                      color: current ? colors.brand : colors.textSecondary,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            );
          },
        );
      },
    );
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
  const _QueuePane({required this.playback, required this.onPlay});

  final PlaybackState playback;
  final ValueChanged<Track> onPlay;

  @override
  Widget build(BuildContext context) {
    final queue = playback.queue;
    if (queue.isEmpty) {
      return const _PanelMessage(title: '队列为空', subtitle: '播放搜索结果或歌单后会形成队列。');
    }

    final currentIndex = queue.indexWhere(
      (item) => item.id == playback.track?.id,
    );
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s3),
      itemCount: queue.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          final suffix = currentIndex < 0 ? '' : ' · 第 ${currentIndex + 1} 首';
          return _PaneCaption('播放队列 · ${queue.length} 首$suffix');
        }
        final trackIndex = index - 1;
        final track = queue[trackIndex];
        return _TrackListTile(
          track: track,
          selected: track.id == playback.track?.id,
          leadingText: '${trackIndex + 1}',
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
          const _PanelMessage(title: '暂无相关推荐', subtitle: '当前曲目没有匹配到相似音乐内容。'),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const _PanelMessage(
            title: '暂无相关推荐',
            subtitle: '换一首带有明确标题和 UP 信息的音乐再试。',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.s3),
          itemCount: tracks.length + 1,
          itemBuilder: (_, index) {
            if (index == 0) return _PaneCaption('相关音乐 · ${tracks.length} 首');
            final track = tracks[index - 1];
            return _TrackListTile(
              track: track,
              onTap: () => onPlay(track, tracks),
            );
          },
        );
      },
    );
  }
}

class _TrackListTile extends StatelessWidget {
  const _TrackListTile({
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
                  width: 22,
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
                width: 40,
                height: 40,
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

class _PaneCaption extends StatelessWidget {
  const _PaneCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s2,
        AppSpacing.s1,
        AppSpacing.s2,
        AppSpacing.s3,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: context.colors.textTertiary,
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
        padding: const EdgeInsets.all(AppSpacing.s6),
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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['歌词', '队列', '相关'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: [
          for (int i = 0; i < _labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s5),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    _labels[i],
                    style: AppTypography.body.copyWith(
                      color: i == index
                          ? colors.textPrimary
                          : colors.textTertiary,
                      fontWeight: i == index
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
