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
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/providers.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  int _heroIndex = 0;
  int _selectedRankIndex = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppLayout.desktopBreakpoint;
    final pad = isDesktop ? AppSpacing.s6 : AppSpacing.s4;
    final discover = ref.watch(discoverProvider);
    final playback = ref.read(playbackProvider.notifier);
    final search = ref.read(searchProvider.notifier);

    final featuredTracks = discover.featuredTracks.isEmpty
        ? <Track>[discover.featuredTrack ?? MockData.nowPlaying]
        : discover.featuredTracks;
    final heroIndex = featuredTracks.isEmpty
        ? 0
        : _heroIndex.clamp(0, featuredTracks.length - 1).toInt();
    final shelves = discover.shelves.isEmpty && !discover.isLoading
        ? MockData.shelves
        : discover.shelves;
    final selectedRankIndex = shelves.isEmpty
        ? 0
        : _selectedRankIndex.clamp(0, shelves.length - 1).toInt();
    final selectedShelf = shelves.isEmpty ? null : shelves[selectedRankIndex];

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        _HeroCarousel(
          tracks: featuredTracks,
          currentIndex: heroIndex,
          onSelected: (index) => setState(() => _heroIndex = index),
          onPlay: (track) => playback.playTrack(track, queue: featuredTracks),
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
        if (selectedShelf != null) ...[
          SectionHeader(
            title: '音乐排行榜',
            actionLabel: '查看全部',
            onAction: () {
              search.search(selectedShelf.title);
              context.go('/search');
            },
          ),
          const SizedBox(height: AppSpacing.s3),
          _RankSelector(
            shelves: shelves,
            selectedIndex: selectedRankIndex,
            onSelected: (index) => setState(() => _selectedRankIndex = index),
          ),
          const SizedBox(height: AppSpacing.s4),
          _Shelf(
            shelf: selectedShelf,
            isDesktop: isDesktop,
            onPlay: (item) => _playItem(item, playback),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ],
    );
  }

  void _playItem(CardItem item, PlaybackNotifier playback) {
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
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.tracks,
    required this.currentIndex,
    required this.onSelected,
    required this.onPlay,
  });

  final List<Track> tracks;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<Track> onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = tracks[currentIndex];
    final hue = (track.gradientSeed * 31) % 360;
    final accent = HSLColor.fromAHSL(1, hue.toDouble(), 0.62, 0.42).toColor();

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
            accent.withValues(alpha: 0.65),
            colors.bgElevated,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showCover = constraints.maxWidth >= 680;
          final titleStyle = AppTypography.hero.copyWith(
            color: Colors.white,
            fontSize: showCover ? 34 : 30,
            height: 1.08,
            letterSpacing: 0,
          );
          final artistStyle = AppTypography.titleM.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: showCover ? 18 : 16,
            height: 1.2,
          );

          return Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppDuration.normal,
                  child: Column(
                    key: ValueKey(track.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '今日推荐',
                            style: AppTypography.overline.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const Spacer(),
                          if (tracks.length > 1) ...[
                            _HeroArrowButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: () => _selectOffset(-1),
                            ),
                            const SizedBox(width: AppSpacing.s2),
                            _HeroArrowButton(
                              icon: Icons.chevron_right_rounded,
                              onTap: () => _selectOffset(1),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                              if (track.artist.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.s2),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: artistStyle,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Row(
                        children: [
                          BrandButton(
                            label: '立即播放',
                            icon: Icons.play_arrow_rounded,
                            onTap: () => onPlay(track),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          if (tracks.length > 1)
                            Flexible(
                              child: _HeroDots(
                                count: tracks.length,
                                currentIndex: currentIndex,
                                onSelected: onSelected,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (showCover) ...[
                const SizedBox(width: AppSpacing.s8),
                SizedBox(
                  width: 184,
                  height: 184,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: CoverImage(
                      url: track.coverUrl,
                      gradientSeed: track.gradientSeed,
                      radius: 8,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _selectOffset(int offset) {
    final next = (currentIndex + offset + tracks.length) % tracks.length;
    onSelected(next);
  }
}

class _HeroArrowButton extends StatelessWidget {
  const _HeroArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        borderRadius: AppRadius.pillAll,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({
    required this.count,
    required this.currentIndex,
    required this.onSelected,
  });

  final int count;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s2),
          child: Material(
            color: index == currentIndex
                ? Colors.white
                : Colors.white.withValues(alpha: 0.28),
            borderRadius: AppRadius.pillAll,
            child: InkWell(
              borderRadius: AppRadius.pillAll,
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: AppDuration.fast,
                width: index == currentIndex ? 22 : 8,
                height: 8,
                decoration: const BoxDecoration(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankSelector extends StatelessWidget {
  const _RankSelector({
    required this.shelves,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<Shelf> shelves;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shelves.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (_, index) => _RankChip(
          label: shelves[index].title,
          selected: index == selectedIndex,
          onTap: () => onSelected(index),
        ),
      ),
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.brand : colors.bgElevated,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        borderRadius: AppRadius.pillAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s2,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: selected ? colors.onBrand : colors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Shelf extends StatefulWidget {
  const _Shelf({
    required this.shelf,
    required this.isDesktop,
    required this.onPlay,
  });

  final Shelf shelf;
  final bool isDesktop;
  final void Function(CardItem item) onPlay;

  @override
  State<_Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<_Shelf> {
  final ScrollController _controller = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncButtons());
  }

  @override
  void didUpdateWidget(covariant _Shelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncButtons());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncButtons)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.isDesktop ? 160.0 : 150.0;
    return SizedBox(
      height: cardWidth + 76,
      child: Stack(
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: widget.shelf.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s4),
            itemBuilder: (_, i) {
              final item = widget.shelf.items[i];
              return ContentCard(
                item: item,
                width: cardWidth,
                onPlay: () => widget.onPlay(item),
              );
            },
          ),
          if (widget.isDesktop && _canScrollLeft)
            Positioned(
              left: 0,
              top: 58,
              child: _ShelfScrollButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _scrollBy(-360),
              ),
            ),
          if (widget.isDesktop && _canScrollRight)
            Positioned(
              right: 0,
              top: 58,
              child: _ShelfScrollButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _scrollBy(360),
              ),
            ),
        ],
      ),
    );
  }

  void _syncButtons() {
    if (!mounted || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final nextLeft = _controller.offset > 2;
    final nextRight = _controller.offset < max - 2;
    if (_canScrollLeft == nextLeft && _canScrollRight == nextRight) return;
    setState(() {
      _canScrollLeft = nextLeft;
      _canScrollRight = nextRight;
    });
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: AppDuration.page,
      curve: Curves.easeOutCubic,
    );
  }
}

class _ShelfScrollButton extends StatelessWidget {
  const _ShelfScrollButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.bgElevated.withValues(alpha: 0.88),
      elevation: 8,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        borderRadius: AppRadius.pillAll,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: colors.textPrimary, size: 24),
        ),
      ),
    );
  }
}
