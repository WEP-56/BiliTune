import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import 'cover_image.dart';
import 'play_button.dart';

/// The universal content card (design doc §8.1). One primitive, infinitely
/// reused: shape (rounded-square vs circle) distinguishes content from creator.
/// Background lifts to highlight on hover and the play button floats up.
class ContentCard extends StatefulWidget {
  const ContentCard({
    super.key,
    required this.item,
    this.onTap,
    this.onPlay,
    this.width = 160,
  });

  final CardItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final double width;

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCircle = widget.item.shape == CoverShape.circle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.normal,
          curve: Curves.ease,
          width: widget.width,
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: _hover ? colors.bgHighlight : colors.bgElevated,
            borderRadius: AppRadius.mdAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: CoverImage(
                      url: widget.item.coverUrl,
                      gradientSeed: widget.item.gradientSeed,
                      shape: widget.item.shape,
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.s2,
                    bottom: AppSpacing.s2,
                    child: AnimatedSlide(
                      offset: _hover ? Offset.zero : const Offset(0, 0.3),
                      duration: AppDuration.normal,
                      curve: Curves.ease,
                      child: AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: AppDuration.normal,
                        child: PlayButton(onTap: widget.onPlay ?? () {}),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: isCircle ? TextAlign.center : TextAlign.start,
                style: AppTypography.titleS.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s1),
              SizedBox(
                width: double.infinity,
                child: Text(
                  widget.item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isCircle ? TextAlign.center : TextAlign.start,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
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
