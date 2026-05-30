import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Compact horizontal entry for the discover page's 2-column quick-pick grid
/// (design doc §8.1 "快捷卡片"): a 56px cover flush-left + a bold label.
class QuickCard extends StatefulWidget {
  const QuickCard({
    super.key,
    required this.label,
    required this.gradientSeed,
    this.onTap,
  });

  final String label;
  final int gradientSeed;
  final VoidCallback? onTap;

  @override
  State<QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<QuickCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hue = (widget.gradientSeed * 47) % 360;
    final c1 = HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.42).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 35) % 360, 0.55, 0.26).toColor();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.normal,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _hover ? colors.bgActive : colors.bgHighlight,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c1, c2],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
            ],
          ),
        ),
      ),
    );
  }
}
