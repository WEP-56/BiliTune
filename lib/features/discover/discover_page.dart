import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/brand_button.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/quick_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/providers.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppLayout.desktopBreakpoint;
    final pad = isDesktop ? AppSpacing.s6 : AppSpacing.s4;
    final discover = ref.watch(discoverProvider);
    final playback = ref.read(playbackProvider.notifier);
    final search = ref.read(searchProvider.notifier);

    final featuredTrack = discover.featuredTrack ?? MockData.nowPlaying;
    final shelves = discover.shelves.isEmpty
        ? MockData.shelves
        : discover.shelves;
    final quickPicks = discover.quickPicks.isEmpty
        ? MockData.quickPicks
        : discover.quickPicks;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        _HeroBanner(
          track: featuredTrack,
          onPlay: () =>
              playback.playTrack(featuredTrack, queue: [featuredTrack]),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (discover.isLoading) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppSpacing.s6),
        ],
        if (discover.errorMessage != null) ...[
          Text(
            discover.errorMessage!,
            style: AppTypography.caption.copyWith(color: context.colors.error),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
        SectionHeader(
          title: '历史',
          actionLabel: '查看全部',
          onAction: () => context.go('/search'),
        ),
        const SizedBox(height: AppSpacing.s4),
        _QuickGrid(
          isDesktop: isDesktop,
          items: quickPicks,
          onTap: (label) {
            search.search(label);
            context.go('/search');
          },
        ),
        const SizedBox(height: AppSpacing.s8),
        for (final shelf in shelves) ...[
          SectionHeader(
            title: shelf.title,
            actionLabel: '查看全部',
            onAction: () {
              search.search(shelf.title);
              context.go('/search');
            },
          ),
          const SizedBox(height: AppSpacing.s4),
          _Shelf(
            shelf: shelf,
            isDesktop: isDesktop,
            onPlay: (item) {
              if (item.bvid == null &&
                  item.aid == null &&
                  item.cid == null &&
                  item.audioId == null) {
                playback.playTrack(
                  MockData.tracks[item.gradientSeed % MockData.tracks.length],
                  queue: MockData.tracks,
                );
                return;
              }

              final track = Track(
                id: item.id,
                title: item.title,
                artist: item.artist ?? item.subtitle,
                duration: item.duration ?? Duration.zero,
                type: item.type ?? ContentType.video,
                gradientSeed: item.gradientSeed,
                coverUrl: item.coverUrl,
                playCount: item.playCount,
                bvid: item.bvid,
                aid: item.aid,
                cid: item.cid,
                audioId: item.audioId,
                webUrl: item.bvid == null
                    ? null
                    : Uri.parse('https://www.bilibili.com/video/${item.bvid}'),
              );
              playback.playTrack(track, queue: [track]);
            },
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.track, required this.onPlay});

  final Track track;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 280,
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.brand.withValues(alpha: 0.85),
            colors.accent.withValues(alpha: 0.55),
            colors.bgElevated,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '今日推荐',
            style: AppTypography.overline.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '${track.title}\n${track.artist}',
            style: AppTypography.hero.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.s4),
          BrandButton(
            label: '立即播放',
            icon: Icons.play_arrow_rounded,
            onTap: onPlay,
          ),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({
    required this.isDesktop,
    required this.items,
    required this.onTap,
  });

  final bool isDesktop;
  final List<String> items;
  final void Function(String label) onTap;

  @override
  Widget build(BuildContext context) {
    final columns = isDesktop ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 56,
        crossAxisSpacing: AppSpacing.s3,
        mainAxisSpacing: AppSpacing.s3,
      ),
      itemBuilder: (_, i) => QuickCard(
        label: items[i],
        gradientSeed: i + 40,
        onTap: () => onTap(items[i]),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.shelf,
    required this.isDesktop,
    required this.onPlay,
  });

  final Shelf shelf;
  final bool isDesktop;
  final void Function(CardItem item) onPlay;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isDesktop ? 160.0 : 150.0;
    return SizedBox(
      height: cardWidth + 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shelf.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s4),
        itemBuilder: (_, i) {
          final item = shelf.items[i];
          return ContentCard(
            item: item,
            width: cardWidth,
            onPlay: () => onPlay(item),
          );
        },
      ),
    );
  }
}
