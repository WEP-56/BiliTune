import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/brand_button.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/providers.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= AppLayout.desktopBreakpoint
        ? AppSpacing.s6
        : AppSpacing.s4;

    final playback = ref.watch(playbackProvider);
    final downloadState = ref.watch(downloadQueueProvider);
    final downloadNotifier = ref.read(downloadQueueProvider.notifier);
    final playbackNotifier = ref.read(playbackProvider.notifier);
    final completedTasks = downloadState.completedTasks;
    final downloadedTracks = downloadState.downloadedTracks;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '下载管理',
                style: AppTypography.titleL.copyWith(color: colors.textPrimary),
              ),
            ),
            if (playback.track != null) ...[
              BrandButton(
                label: '添加当前播放',
                icon: Icons.add_rounded,
                onTap: () => downloadNotifier.enqueueTrack(playback.track!),
              ),
              const SizedBox(width: AppSpacing.s3),
            ],
            IconButton(
              tooltip: '清空任务',
              onPressed: downloadState.tasks.isEmpty
                  ? null
                  : () => downloadNotifier.clear(),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        if (downloadState.isLoading) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppSpacing.s4),
        ],
        if (downloadState.errorMessage != null) ...[
          Text(
            downloadState.errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
        SectionHeader(
          title:
              '下载任务 (${downloadState.completedCount}/${downloadState.tasks.length})',
        ),
        const SizedBox(height: AppSpacing.s4),
        if (downloadState.tasks.isEmpty)
          const _EmptyState(
            title: '还没有下载任务',
            subtitle: '播放任意搜索结果后，可把当前播放内容加入下载队列。',
          )
        else
          for (final task in downloadState.tasks)
            _DownloadRow(
              task: task,
              onPause: () => downloadNotifier.pauseTask(task.id),
              onResume: () => downloadNotifier.resumeTask(task.id),
              onDelete: () => downloadNotifier.removeTask(task.id),
              onOpenFolder: () => _openInFolder(context, task.savePath),
            ),
        const SizedBox(height: AppSpacing.s8),
        SectionHeader(title: '我的下载 (${completedTasks.length})'),
        const SizedBox(height: AppSpacing.s4),
        if (completedTasks.isEmpty)
          const _EmptyState(
            title: '还没有已下载歌曲',
            subtitle: '下载完成后会显示在这里，也会出现在“我的下载”固定歌单。',
          )
        else
          for (int i = 0; i < completedTasks.length; i++)
            _DownloadedTrackRow(
              task: completedTasks[i],
              track: downloadedTracks[i],
              isCurrent: playback.track?.id == downloadedTracks[i].id,
              isPlaying:
                  playback.isPlaying &&
                  playback.track?.id == downloadedTracks[i].id,
              onPlay: () => playbackNotifier.playTrack(
                downloadedTracks[i],
                queue: downloadedTracks,
              ),
              onOpenFolder: () =>
                  _openInFolder(context, completedTasks[i].savePath),
              onDelete: () => downloadNotifier.removeTask(completedTasks[i].id),
            ),
      ],
    );
  }

  Future<void> _openInFolder(BuildContext context, String? savePath) async {
    if (savePath == null || savePath.isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,$savePath']);
        return;
      }
      final directory = File(savePath).parent.path;
      if (Platform.isMacOS) {
        await Process.start('open', [directory]);
        return;
      }
      if (Platform.isLinux) {
        await Process.start('xdg-open', [directory]);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前平台暂不支持打开文件夹')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开文件夹：$error')));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s6),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleS.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            subtitle,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
    required this.onOpenFolder,
  });

  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quality = _qualityLabel(task);
    final statusLabel = switch (task.status) {
      DownloadTaskStatus.queued => '等待中',
      DownloadTaskStatus.downloading => '下载中',
      DownloadTaskStatus.paused => '已暂停',
      DownloadTaskStatus.completed => '已完成',
      DownloadTaskStatus.failed => '失败',
      DownloadTaskStatus.cancelled => '已取消',
    };
    final canControl =
        task.status != DownloadTaskStatus.completed &&
        task.status != DownloadTaskStatus.cancelled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CoverImage(
                url: task.coverUrl,
                gradientSeed: task.gradientSeed,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.artist} · $statusLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 4,
                      backgroundColor: colors.bgActive,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.status == DownloadTaskStatus.failed
                            ? colors.error
                            : colors.accent,
                      ),
                    ),
                  ),
                  if (quality.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      quality,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Column(
              children: [
                Text(
                  '${(task.progress * 100).round()}%',
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: task.status == DownloadTaskStatus.failed
                          ? '重试'
                          : task.status == DownloadTaskStatus.paused
                          ? '继续'
                          : '暂停',
                      onPressed: !canControl
                          ? null
                          : (task.status == DownloadTaskStatus.paused ||
                                task.status == DownloadTaskStatus.failed)
                          ? onResume
                          : onPause,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        task.status == DownloadTaskStatus.failed
                            ? Icons.refresh_rounded
                            : task.status == DownloadTaskStatus.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: '在文件夹中显示',
                      onPressed: task.savePath == null ? null : onOpenFolder,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.folder_open_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: '删除任务',
                      onPressed: onDelete,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _qualityLabel(DownloadTask task) {
    if (task.outputFileType == 'video') {
      return task.videoResolution == null
          ? ''
          : '${task.videoResolution}${task.videoFrameRate == null ? '' : '@${task.videoFrameRate}'}';
    }
    if (task.audioCodecs == 'flac') return 'FLAC';
    if (task.audioCodecs?.contains('ec-3') ?? false) return 'Dolby';
    if (task.audioBandwidth != null) {
      return '${(task.audioBandwidth! / 1000).round()} kbps';
    }
    return task.outputFileType == 'audio' ? '音频任务' : '';
  }
}

class _DownloadedTrackRow extends StatelessWidget {
  const _DownloadedTrackRow({
    required this.task,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onPlay,
    required this.onOpenFolder,
    required this.onDelete,
  });

  final DownloadTask task;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onOpenFolder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: isCurrent ? colors.bgActive : colors.bgElevated,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CoverImage(
                url: task.coverUrl,
                gradientSeed: task.gradientSeed,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.artist} · ${_sizeLabel(task.downloadedBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            IconButton(
              tooltip: isPlaying ? '正在播放' : '播放',
              onPressed: onPlay,
              icon: Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                color: isCurrent ? colors.brand : colors.textSecondary,
              ),
            ),
            IconButton(
              tooltip: '在文件夹中显示',
              onPressed: onOpenFolder,
              icon: Icon(
                Icons.folder_open_rounded,
                color: colors.textSecondary,
              ),
            ),
            IconButton(
              tooltip: '删除记录',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes <= 0) return '本地文件';
    final mb = bytes / 1024 / 1024;
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).round()} KB';
  }
}
