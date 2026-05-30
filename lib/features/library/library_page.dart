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
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/track_row.dart';
import '../../state/providers.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppLayout.desktopBreakpoint;
    final pad = isDesktop ? AppSpacing.s6 : AppSpacing.s4;

    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);
    final playback = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);
    final libraryNotifier = ref.read(libraryProvider.notifier);

    final folders = library.folders.isEmpty
        ? MockData.libraryFolders
              .map(
                (item) => BiliFavoriteFolder(
                  mediaId: int.tryParse(item.id) ?? item.gradientSeed,
                  fid: int.tryParse(item.id) ?? item.gradientSeed,
                  mid: auth.credential?.mid ?? auth.account?.mid ?? 0,
                  title: item.title,
                  mediaCount:
                      int.tryParse(
                        item.subtitle.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0,
                  gradientSeed: item.gradientSeed,
                  coverUrl: item.coverUrl,
                ),
              )
              .toList(growable: false)
        : library.folders;

    final history = library.recentHistory.isEmpty
        ? MockData.tracks
        : library.recentHistory;
    final selectedTracks = library.selectedFolderTracks.isEmpty
        ? MockData.tracks.take(6).toList(growable: false)
        : library.selectedFolderTracks;

    if (!auth.isSignedIn) {
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
        children: [
          Text(
            '我的音乐',
            style: AppTypography.titleL.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '登录后可同步收藏夹和播放历史',
                  style: AppTypography.titleS.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  '收藏夹、历史记录和下载任务都会绑定到当前账号。',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                BrandButton(
                  label: '去登录',
                  icon: Icons.login_rounded,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Text(
          '我的音乐',
          style: AppTypography.titleL.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.s2),
        if (library.isLoading) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppSpacing.s4),
        ],
        if (library.errorMessage != null) ...[
          Text(
            library.errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
        SectionHeader(title: '收藏夹'),
        const SizedBox(height: AppSpacing.s4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: folders.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: 256,
            crossAxisSpacing: AppSpacing.s4,
            mainAxisSpacing: AppSpacing.s4,
          ),
          itemBuilder: (_, i) {
            final folder = folders[i];
            return ContentCard(
              item: folder.toCardItem(),
              width: 180,
              onTap: () => libraryNotifier.selectFolder(folder.mediaId),
              onPlay: () {
                if (selectedTracks.isNotEmpty) {
                  notifier.playTrack(
                    selectedTracks.first,
                    queue: selectedTracks,
                  );
                }
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.s8),
        SectionHeader(title: library.selectedFolder?.title ?? '收藏夹内容'),
        const SizedBox(height: AppSpacing.s2),
        for (int i = 0; i < selectedTracks.length; i++)
          TrackRow(
            index: i,
            track: selectedTracks[i],
            isCurrent: playback.track?.id == selectedTracks[i].id,
            isPlaying:
                playback.isPlaying &&
                playback.track?.id == selectedTracks[i].id,
            onTap: () =>
                notifier.playTrack(selectedTracks[i], queue: selectedTracks),
          ),
        const SizedBox(height: AppSpacing.s8),
        SectionHeader(title: '最近播放'),
        const SizedBox(height: AppSpacing.s2),
        for (int i = 0; i < history.length; i++)
          TrackRow(
            index: i,
            track: history[i],
            isCurrent: playback.track?.id == history[i].id,
            isPlaying:
                playback.isPlaying && playback.track?.id == history[i].id,
            onTap: () => notifier.playTrack(history[i], queue: history),
          ),
      ],
    );
  }
}
