import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../data/mock/mock_data.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/section_header.dart';

/// Download manager (design doc §6.3 / §14): storage summary + task list. Mock
/// data only; the real download engine lands in M6.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final pad =
        width >= AppLayout.desktopBreakpoint ? AppSpacing.s6 : AppSpacing.s4;
    final items = MockData.downloads;
    final doneCount = items.where((e) => e.done).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Text('下载管理',
            style: AppTypography.titleL.copyWith(color: colors.textPrimary)),
        const SizedBox(height: AppSpacing.s6),
        const _StorageCard(usedFraction: 0.42),
        const SizedBox(height: AppSpacing.s8),
        SectionHeader(title: '下载任务（$doneCount/${items.length} 已完成）'),
        const SizedBox(height: AppSpacing.s4),
        for (final item in items)
          _DownloadRow(
            title: item.track.title,
            artist: item.track.artist,
            seed: item.track.gradientSeed,
            duration: item.track.duration,
            progress: item.progress,
            done: item.done,
          ),
      ],
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.usedFraction});

  final double usedFraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('存储空间',
                  style: AppTypography.titleS
                      .copyWith(color: colors.textPrimary)),
              Text('26.9 GB / 64 GB',
                  style: AppTypography.caption
                      .copyWith(color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedFraction,
              minHeight: 8,
              backgroundColor: colors.bgActive,
              valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              _Legend(color: colors.brand, label: '已下载 26.9 GB'),
              const SizedBox(width: AppSpacing.s4),
              _Legend(color: colors.bgActive, label: '可用 37.1 GB'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(label,
            style: AppTypography.caption
                .copyWith(color: context.colors.textSecondary)),
      ],
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.title,
    required this.artist,
    required this.seed,
    required this.duration,
    required this.progress,
    required this.done,
  });

  final String title;
  final String artist;
  final int seed;
  final Duration duration;
  final double progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Row(
        children: [
          SizedBox(width: 44, height: 44, child: CoverImage(gradientSeed: seed)),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (done)
                  Text('$artist · ${Format.duration(duration)} · FLAC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: colors.textSecondary))
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colors.bgActive,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          if (done)
            Icon(Icons.check_circle_rounded, color: colors.success, size: 22)
          else
            Row(
              children: [
                Text('${(progress * 100).round()}%',
                    style: AppTypography.caption
                        .copyWith(color: colors.textSecondary)),
                const SizedBox(width: AppSpacing.s2),
                Icon(Icons.pause_circle_outline_rounded,
                    color: colors.textSecondary, size: 22),
              ],
            ),
        ],
      ),
    );
  }
}
