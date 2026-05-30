import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import 'cover_image.dart';

/// A song-list row (design doc §8.5). On hover the row lifts to highlight and
/// the track number swaps for a play glyph; the current track shows in brand
/// pink. Type icon (🎵/🎬) distinguishes audio-area vs video content.
class TrackRow extends StatefulWidget {
  const TrackRow({
    super.key,
    required this.index,
    required this.track,
    this.isCurrent = false,
    this.isPlaying = false,
    this.liked = false,
    this.onTap,
    this.onLike,
  });

  final int index;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool liked;
  final VoidCallback? onTap;
  final VoidCallback? onLike;

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titleColor = widget.isCurrent ? colors.brand : colors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: _hover ? colors.bgHighlight : Colors.transparent,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: [
              // Index / play glyph
              SizedBox(
                width: 28,
                child: Center(
                  child: _hover || widget.isCurrent
                      ? Icon(
                          widget.isPlaying
                              ? Icons.volume_up_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                          color: titleColor,
                        )
                      : Text(
                          '${widget.index + 1}',
                          style: AppTypography.body.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              // Cover
              SizedBox(
                width: 40,
                height: 40,
                child: CoverImage(
                  url: widget.track.coverUrl,
                  gradientSeed: widget.track.gradientSeed,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              // Title + artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.track.artist,
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
              // Type badge
              Icon(
                widget.track.type == ContentType.audio
                    ? Icons.music_note_rounded
                    : Icons.smart_display_rounded,
                size: 16,
                color: colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.s4),
              // Like (on hover)
              SizedBox(
                width: 28,
                child: (_hover || widget.liked)
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 18,
                        icon: Icon(
                          widget.liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: widget.liked
                              ? colors.brand
                              : colors.textSecondary,
                        ),
                        onPressed: widget.onLike,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: AppSpacing.s2),
              // Duration
              SizedBox(
                width: 44,
                child: Text(
                  Format.duration(widget.track.duration),
                  textAlign: TextAlign.right,
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
