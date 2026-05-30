import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../state/providers.dart';
import '../../../shared/widgets/cover_image.dart';

/// Desktop "Now Playing" right panel (design doc §6.4): cover + actions and a
/// 歌词 / 队列 / 相关 tab switcher. Mock content for M0.
class NowPlayingPanel extends ConsumerStatefulWidget {
  const NowPlayingPanel({super.key});

  @override
  ConsumerState<NowPlayingPanel> createState() => _NowPlayingPanelState();
}

class _NowPlayingPanelState extends ConsumerState<NowPlayingPanel> {
  int _tab = 0;

  static const _mockLyrics = <String>[
    '夜的第七章 缓缓开始',
    '是谁躲在斑驳的剪影里',
    '月光下的歌声轻轻响起',
    '你的旋律划过我心底',
    '就让这首歌陪你到天明',
    '所有的故事都有了结局',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = ref.watch(playbackProvider).track;

    return Container(
      width: AppLayout.nowPlayingWidth,
      margin: const EdgeInsets.only(
          right: AppSpacing.s4, top: AppSpacing.s2, bottom: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: AppRadius.mdAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4, AppSpacing.s3, AppSpacing.s2, AppSpacing.s2),
            child: Row(
              children: [
                Text('正在播放',
                    style: AppTypography.titleS
                        .copyWith(color: colors.textPrimary)),
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
                      Text(track?.title ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleS
                              .copyWith(color: colors.textPrimary)),
                      Text(track?.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption
                              .copyWith(color: colors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.download_outlined,
                    color: colors.textSecondary, size: 22),
                const SizedBox(width: AppSpacing.s4),
                Icon(Icons.share_outlined,
                    color: colors.textSecondary, size: 22),
              ],
            ),
          ),
          _TabBar(
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const Divider(height: 1),
          Expanded(child: _tabBody(track, colors)),
        ],
      ),
    );
  }

  Widget _tabBody(Track? track, BiliColors colors) {
    switch (_tab) {
      case 0:
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.s4),
          itemCount: _mockLyrics.length,
          itemBuilder: (_, i) {
            final current = i == 2;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Text(
                _mockLyrics[i],
                style: (current ? AppTypography.titleS : AppTypography.body)
                    .copyWith(
                  color: current ? colors.brand : colors.textSecondary,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            );
          },
        );
      case 1:
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.s3),
          children: [
            for (final t in MockData.tracks.take(6))
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                leading: SizedBox(
                  width: 36,
                  height: 36,
                  child: CoverImage(gradientSeed: t.gradientSeed),
                ),
                title: Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body
                        .copyWith(color: colors.textPrimary)),
                subtitle: Text(t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: colors.textSecondary)),
              ),
          ],
        );
      default:
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            for (final c in MockData.shelves.first.items.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: Row(
                  children: [
                    SizedBox(
                        width: 48,
                        height: 48,
                        child: CoverImage(gradientSeed: c.gradientSeed)),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body
                                  .copyWith(color: colors.textPrimary)),
                          Text(c.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption
                                  .copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
    }
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
          horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
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
                      fontWeight:
                          i == index ? FontWeight.w700 : FontWeight.w400,
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
