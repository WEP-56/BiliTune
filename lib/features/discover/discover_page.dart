import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../state/providers.dart';
import '../../shared/widgets/brand_button.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/quick_card.dart';
import '../../shared/widgets/section_header.dart';

/// Discover page (design doc §6.3): hero banner → quick-pick grid → horizontal
/// shelves of recommendations / hot tracks / followed creators / rankings.
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppLayout.desktopBreakpoint;
    final pad = isDesktop ? AppSpacing.s6 : AppSpacing.s4;
    final notifier = ref.read(playbackProvider.notifier);

    void playSeed(int seed) =>
        notifier.playTrack(MockData.tracks[seed % MockData.tracks.length]);

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        _HeroBanner(onPlay: () => playSeed(2)),
        const SizedBox(height: AppSpacing.s8),
        _QuickGrid(isDesktop: isDesktop, onTap: playSeed),
        const SizedBox(height: AppSpacing.s8),
        for (final shelf in MockData.shelves) ...[
          SectionHeader(title: shelf.title, actionLabel: '查看全部'),
          const SizedBox(height: AppSpacing.s4),
          _Shelf(shelf: shelf, isDesktop: isDesktop, onPlay: playSeed),
          const SizedBox(height: AppSpacing.s8),
        ],
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onPlay});

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
          Text('晚上好',
              style: AppTypography.overline
                  .copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: AppSpacing.s2),
          Text('今夜由 BiliTune\n为你点亮旋律',
              style: AppTypography.hero.copyWith(color: Colors.white)),
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
  const _QuickGrid({required this.isDesktop, required this.onTap});

  final bool isDesktop;
  final void Function(int seed) onTap;

  @override
  Widget build(BuildContext context) {
    final columns = isDesktop ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: MockData.quickPicks.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 56,
        crossAxisSpacing: AppSpacing.s3,
        mainAxisSpacing: AppSpacing.s3,
      ),
      itemBuilder: (_, i) => QuickCard(
        label: MockData.quickPicks[i],
        gradientSeed: i + 40,
        onTap: () => onTap(i),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf(
      {required this.shelf, required this.isDesktop, required this.onPlay});

  final Shelf shelf;
  final bool isDesktop;
  final void Function(int seed) onPlay;

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
            onPlay: () => onPlay(item.gradientSeed),
          );
        },
      ),
    );
  }
}
