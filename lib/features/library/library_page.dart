import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/mock/mock_data.dart';
import '../../state/providers.dart';
import '../../shared/widgets/content_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/track_row.dart';

/// Library page (design doc §6.3 / §14): the user's favorite folders as a grid,
/// plus a recently-played track list.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppLayout.desktopBreakpoint;
    final pad = isDesktop ? AppSpacing.s6 : AppSpacing.s4;

    final playback = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Text('我的音乐',
            style: AppTypography.titleL.copyWith(color: colors.textPrimary)),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            for (final f in const ['全部', '音频', '视频'])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s2),
                child: _FilterChip(label: f, selected: f == '全部'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        const SectionHeader(title: '收藏夹'),
        const SizedBox(height: AppSpacing.s4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MockData.libraryFolders.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: 256,
            crossAxisSpacing: AppSpacing.s4,
            mainAxisSpacing: AppSpacing.s4,
          ),
          itemBuilder: (_, i) {
            final folder = MockData.libraryFolders[i];
            return ContentCard(
              item: folder,
              width: 180,
              onPlay: () => notifier.playTrack(
                  MockData.tracks[folder.gradientSeed % MockData.tracks.length]),
            );
          },
        ),
        const SizedBox(height: AppSpacing.s8),
        const SectionHeader(title: '最近播放'),
        const SizedBox(height: AppSpacing.s2),
        for (int i = 0; i < MockData.tracks.length; i++)
          TrackRow(
            index: i,
            track: MockData.tracks[i],
            isCurrent: playback.track?.id == MockData.tracks[i].id,
            isPlaying: playback.isPlaying &&
                playback.track?.id == MockData.tracks[i].id,
            onTap: () => notifier.playTrack(MockData.tracks[i]),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: selected ? colors.brand : colors.bgHighlight,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: selected ? colors.onBrand : colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
