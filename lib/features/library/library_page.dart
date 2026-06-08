import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/brand_button.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/favorite_folder_dialogs.dart';
import '../../shared/widgets/track_row.dart';
import '../../state/providers.dart';

String _downloadedTracksKey(DownloadQueueState state) {
  return state.completedTasks
      .map(
        (task) => [
          task.id,
          task.title,
          task.artist,
          task.type.name,
          task.gradientSeed,
          task.coverUrl ?? '',
          task.bvid ?? '',
          task.aid ?? '',
          task.cid ?? '',
          task.audioId ?? '',
          task.savePath ?? '',
          task.downloadedBytes,
        ].join('\u001e'),
      )
      .join('\u001f');
}

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _trackSearchController = TextEditingController();
  Timer? _trackSearchDebounce;

  @override
  void dispose() {
    _trackSearchDebounce?.cancel();
    _trackSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppLayout.desktopBreakpoint;
    final pad = isDesktop ? AppSpacing.s6 : AppSpacing.s4;

    final auth = ref.watch(authProvider);
    final library = ref.watch(libraryProvider);
    ref.watch(downloadQueueProvider.select(_downloadedTracksKey));
    final downloadedTracks = ref.read(downloadQueueProvider).downloadedTracks;
    final playback = ref.watch(
      playbackProvider.select(
        (state) => (trackId: state.track?.id, isPlaying: state.isPlaying),
      ),
    );
    final playbackNotifier = ref.read(playbackProvider.notifier);
    final libraryNotifier = ref.read(libraryProvider.notifier);

    final recentTracks = library.recentHistory;
    final playlists = <_PlaylistViewData>[
      _PlaylistViewData.recent(recentTracks.length),
      _PlaylistViewData.downloads(downloadedTracks.length),
      ...library.folders.map(_PlaylistViewData.folder),
    ];
    final selected = _selectedPlaylist(playlists, library.selectedFolderId);
    final selectedTracks = switch (selected.kind) {
      _PlaylistKind.recent => _filterTracks(recentTracks, library.trackKeyword),
      _PlaylistKind.downloads => _filterTracks(
        downloadedTracks,
        library.trackKeyword,
      ),
      _PlaylistKind.folder => library.selectedFolderTracks,
    };

    final content = isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: _PlaylistList(
                  playlists: playlists,
                  selectedId: selected.id,
                  isLoading: library.isLoading,
                  canCreate: auth.isSignedIn,
                  onCreate: auth.isSignedIn
                      ? () => showCreateFavoriteFolderDialog(context)
                      : () => context.go('/settings'),
                  onSelect: _selectPlaylist,
                  onHideFolder: (playlist) => _hidePlaylist(context, playlist),
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: _PlaylistDetail(
                  playlist: selected,
                  tracks: selectedTracks,
                  trackKeyword: library.trackKeyword,
                  isLoadingTracks:
                      library.isLoading &&
                      selected.kind == _PlaylistKind.folder,
                  searchController: _trackSearchController,
                  currentTrackId: playback.trackId,
                  isCurrentTrackPlaying: playback.isPlaying,
                  onSearchChanged: _scheduleTrackSearch,
                  onPlayTrack: (track) =>
                      playbackNotifier.playTrack(track, queue: selectedTracks),
                  onPlayAll: selectedTracks.isEmpty
                      ? null
                      : () => playbackNotifier.playTrack(
                          selectedTracks.first,
                          queue: selectedTracks,
                        ),
                  onRemoveTrack: selected.kind == _PlaylistKind.folder
                      ? (track) =>
                            libraryNotifier.removeTrackFromFavoriteFolder(
                              track,
                              selected.mediaId!,
                            )
                      : null,
                ),
              ),
            ],
          )
        : Column(
            children: [
              _PlaylistList(
                playlists: playlists,
                selectedId: selected.id,
                isLoading: library.isLoading,
                canCreate: auth.isSignedIn,
                onCreate: auth.isSignedIn
                    ? () => showCreateFavoriteFolderDialog(context)
                    : () => context.go('/settings'),
                onSelect: _selectPlaylist,
                onHideFolder: (playlist) => _hidePlaylist(context, playlist),
              ),
              const SizedBox(height: AppSpacing.s6),
              _PlaylistDetail(
                playlist: selected,
                tracks: selectedTracks,
                trackKeyword: library.trackKeyword,
                isLoadingTracks:
                    library.isLoading && selected.kind == _PlaylistKind.folder,
                searchController: _trackSearchController,
                currentTrackId: playback.trackId,
                isCurrentTrackPlaying: playback.isPlaying,
                onSearchChanged: _scheduleTrackSearch,
                onPlayTrack: (track) =>
                    playbackNotifier.playTrack(track, queue: selectedTracks),
                onPlayAll: selectedTracks.isEmpty
                    ? null
                    : () => playbackNotifier.playTrack(
                        selectedTracks.first,
                        queue: selectedTracks,
                      ),
                onRemoveTrack: selected.kind == _PlaylistKind.folder
                    ? (track) => libraryNotifier.removeTrackFromFavoriteFolder(
                        track,
                        selected.mediaId!,
                      )
                    : null,
              ),
            ],
          );

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '我的歌单',
                style: AppTypography.titleL.copyWith(color: colors.textPrimary),
              ),
            ),
            BrandButton(
              label: auth.isSignedIn ? '新建歌单' : '登录同步',
              icon: auth.isSignedIn ? Icons.add_rounded : Icons.login_rounded,
              variant: BiliButtonVariant.secondary,
              onTap: auth.isSignedIn
                  ? () => showCreateFavoriteFolderDialog(context)
                  : () => context.go('/settings'),
            ),
          ],
        ),
        if (!auth.isSignedIn) ...[
          const SizedBox(height: AppSpacing.s3),
          Text(
            '登录后可同步 B 站收藏夹；最近播放和我的下载可直接使用。',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.s5),
        if (library.errorMessage != null) ...[
          Text(
            library.errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
        content,
      ],
    );
  }

  List<Track> _filterTracks(List<Track> tracks, String query) {
    if (query.isEmpty) return tracks;
    final lower = query.toLowerCase();
    return tracks
        .where(
          (track) =>
              track.title.toLowerCase().contains(lower) ||
              track.artist.toLowerCase().contains(lower),
        )
        .toList(growable: false);
  }

  _PlaylistViewData _selectedPlaylist(
    List<_PlaylistViewData> playlists,
    int? selectedFolderId,
  ) {
    if (selectedFolderId == null) return playlists.first;
    for (final playlist in playlists) {
      if (playlist.mediaId == selectedFolderId) return playlist;
    }
    return playlists.first;
  }

  void _selectPlaylist(_PlaylistViewData playlist) {
    _trackSearchDebounce?.cancel();
    _trackSearchController.clear();
    final notifier = ref.read(libraryProvider.notifier);
    switch (playlist.kind) {
      case _PlaylistKind.recent:
        notifier.selectRecent();
      case _PlaylistKind.downloads:
        notifier.selectDownloads();
      case _PlaylistKind.folder:
        notifier.selectFolder(playlist.mediaId!);
    }
  }

  Future<void> _hidePlaylist(
    BuildContext context,
    _PlaylistViewData playlist,
  ) async {
    final mediaId = playlist.mediaId;
    if (playlist.kind != _PlaylistKind.folder || mediaId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        return AlertDialog(
          backgroundColor: colors.bgElevated,
          title: Text(
            '隐藏歌单',
            style: AppTypography.titleM.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            '只会在 BiliTune 中隐藏「${playlist.title}」，不会删除 B 站账号里的收藏夹。',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('隐藏'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    _trackSearchDebounce?.cancel();
    _trackSearchController.clear();
    await ref.read(libraryProvider.notifier).hideFavoriteFolder(mediaId);
    if (!context.mounted) return;
    final colors = context.colors;
    showAppToast(
      context,
      message: '已在 BiliTune 中隐藏「${playlist.title}」',
      icon: Icons.visibility_off_rounded,
      accentColor: colors.info,
      actionLabel: '撤销',
      onAction: () => unawaited(
        ref.read(libraryProvider.notifier).unhideFavoriteFolder(mediaId),
      ),
    );
  }

  void _scheduleTrackSearch(String value) {
    _trackSearchDebounce?.cancel();
    _trackSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(libraryProvider.notifier).searchSelectedTracks(value);
    });
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({
    required this.playlists,
    required this.selectedId,
    required this.isLoading,
    required this.canCreate,
    required this.onCreate,
    required this.onSelect,
    required this.onHideFolder,
  });

  final List<_PlaylistViewData> playlists;
  final String selectedId;
  final bool isLoading;
  final bool canCreate;
  final VoidCallback onCreate;
  final void Function(_PlaylistViewData playlist) onSelect;
  final void Function(_PlaylistViewData playlist) onHideFolder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '歌单',
                    style: AppTypography.titleS.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: canCreate ? '新建歌单' : '登录同步收藏夹',
                  onPressed: onCreate,
                  icon: Icon(
                    canCreate ? Icons.add_rounded : Icons.login_rounded,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          for (final playlist in playlists)
            _PlaylistListTile(
              playlist: playlist,
              selected: playlist.id == selectedId,
              onTap: () => onSelect(playlist),
              onHide: playlist.kind == _PlaylistKind.folder
                  ? () => onHideFolder(playlist)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _TrackSearchField extends StatelessWidget {
  const _TrackSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.bgHighlight,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '搜索当前歌单的歌曲',
                hintStyle: AppTypography.body.copyWith(
                  color: colors.textTertiary,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistListTile extends StatefulWidget {
  const _PlaylistListTile({
    required this.playlist,
    required this.selected,
    required this.onTap,
    required this.onHide,
  });

  final _PlaylistViewData playlist;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onHide;

  @override
  State<_PlaylistListTile> createState() => _PlaylistListTileState();
}

class _PlaylistListTileState extends State<_PlaylistListTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.bgActive
                : (_hover ? colors.bgHighlight : Colors.transparent),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CoverImage(
                  url: widget.playlist.coverUrl,
                  gradientSeed: widget.playlist.gradientSeed,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.playlist.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.playlist.trailingIcon,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                  if (widget.onHide != null && (_hover || widget.selected)) ...[
                    const SizedBox(width: AppSpacing.s1),
                    Tooltip(
                      message: '在 BiliTune 中隐藏',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: Icon(
                          Icons.visibility_off_outlined,
                          color: colors.textTertiary,
                        ),
                        onPressed: widget.onHide,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetail extends StatelessWidget {
  const _PlaylistDetail({
    required this.playlist,
    required this.tracks,
    required this.trackKeyword,
    required this.isLoadingTracks,
    required this.searchController,
    required this.currentTrackId,
    required this.isCurrentTrackPlaying,
    required this.onSearchChanged,
    required this.onPlayTrack,
    required this.onPlayAll,
    required this.onRemoveTrack,
  });

  final _PlaylistViewData playlist;
  final List<Track> tracks;
  final String trackKeyword;
  final bool isLoadingTracks;
  final TextEditingController searchController;
  final String? currentTrackId;
  final bool isCurrentTrackPlaying;
  final ValueChanged<String> onSearchChanged;
  final void Function(Track track) onPlayTrack;
  final VoidCallback? onPlayAll;
  final void Function(Track track)? onRemoveTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s5),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.brand.withValues(alpha: 0.7),
                colors.accent.withValues(alpha: 0.35),
                colors.bgElevated,
              ],
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CoverImage(
                  url: playlist.coverUrl,
                  gradientSeed: playlist.gradientSeed,
                ),
              ),
              const SizedBox(width: AppSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.badge,
                      style: AppTypography.overline.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      playlist.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleL.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      playlist.intro?.isNotEmpty ?? false
                          ? playlist.intro!
                          : playlist.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    FilledButton.icon(
                      onPressed: onPlayAll,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('播放'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        Row(
          children: [
            Expanded(
              child: _TrackSearchField(
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ),
            if (trackKeyword.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.s2),
              IconButton(
                tooltip: '清空搜索',
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              ),
            ],
          ],
        ),
        if (isLoadingTracks) ...[
          const SizedBox(height: AppSpacing.s3),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: AppSpacing.s4),
        if (tracks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: AppRadius.mdAll,
            ),
            child: Text(
              trackKeyword.isNotEmpty ? '没有找到匹配的歌曲' : playlist.emptyText,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          )
        else
          for (int i = 0; i < tracks.length; i++)
            TrackRow(
              index: i,
              track: tracks[i],
              isCurrent: currentTrackId == tracks[i].id,
              isPlaying:
                  isCurrentTrackPlaying && currentTrackId == tracks[i].id,
              liked: playlist.kind == _PlaylistKind.folder,
              onLike: onRemoveTrack == null
                  ? null
                  : () => onRemoveTrack!(tracks[i]),
              onTap: () => onPlayTrack(tracks[i]),
            ),
      ],
    );
  }
}

enum _PlaylistKind { recent, downloads, folder }

class _PlaylistViewData {
  const _PlaylistViewData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gradientSeed,
    required this.kind,
    this.mediaId,
    this.coverUrl,
    this.intro,
    this.isPrivate = false,
  });

  factory _PlaylistViewData.recent(int count) {
    return _PlaylistViewData(
      id: 'recent',
      title: '最近播放',
      subtitle: '$count 首',
      gradientSeed: 12,
      kind: _PlaylistKind.recent,
    );
  }

  factory _PlaylistViewData.downloads(int count) {
    return _PlaylistViewData(
      id: 'downloads',
      mediaId: libraryDownloadsPlaylistId,
      title: '我的下载',
      subtitle: '$count 首',
      gradientSeed: 18,
      kind: _PlaylistKind.downloads,
    );
  }

  factory _PlaylistViewData.folder(BiliFavoriteFolder folder) {
    return _PlaylistViewData(
      id: 'folder-${folder.mediaId}',
      mediaId: folder.mediaId,
      title: folder.title,
      subtitle: '${folder.mediaCount} 首',
      gradientSeed: folder.gradientSeed,
      coverUrl: folder.coverUrl,
      intro: folder.intro,
      isPrivate: !folder.isPublic,
      kind: _PlaylistKind.folder,
    );
  }

  final String id;
  final int? mediaId;
  final String title;
  final String subtitle;
  final int gradientSeed;
  final _PlaylistKind kind;
  final String? coverUrl;
  final String? intro;
  final bool isPrivate;

  String get badge => switch (kind) {
    _PlaylistKind.recent => '自动歌单',
    _PlaylistKind.downloads => '本地歌单',
    _PlaylistKind.folder => 'B 站收藏夹',
  };

  String get emptyText => switch (kind) {
    _PlaylistKind.recent => '还没有最近播放记录',
    _PlaylistKind.downloads => '还没有已下载歌曲',
    _PlaylistKind.folder => '这个歌单还没有内容',
  };

  IconData get trailingIcon {
    if (isPrivate) return Icons.lock_outline_rounded;
    return switch (kind) {
      _PlaylistKind.recent => Icons.history_rounded,
      _PlaylistKind.downloads => Icons.download_done_rounded,
      _PlaylistKind.folder => Icons.chevron_right_rounded,
    };
  }
}
