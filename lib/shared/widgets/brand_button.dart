import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

enum BiliButtonVariant { primary, secondary, ghost }

/// Pill button in the three design-doc §8.6 variants. Primary is brand-filled,
/// secondary is outlined, ghost is text-only that brightens on hover.
class BrandButton extends StatefulWidget {
  const BrandButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.variant = BiliButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BiliButtonVariant variant;

  @override
  State<BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<BrandButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPrimary = widget.variant == BiliButtonVariant.primary;
    final isSecondary = widget.variant == BiliButtonVariant.secondary;

    final Color bg;
    final Color fg;
    final BoxBorder? border;
    switch (widget.variant) {
      case BiliButtonVariant.primary:
        bg = _hover ? colors.brandLight : colors.brand;
        fg = colors.onBrand;
        border = null;
      case BiliButtonVariant.secondary:
        bg = Colors.transparent;
        fg = colors.textPrimary;
        border = Border.all(
          color: _hover ? colors.textPrimary : colors.textSecondary,
        );
      case BiliButtonVariant.ghost:
        bg = Colors.transparent;
        fg = _hover ? colors.textPrimary : colors.textSecondary;
        border = null;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.normal,
          padding: EdgeInsets.symmetric(
            horizontal: isPrimary || isSecondary
                ? AppSpacing.s8
                : AppSpacing.s3,
            vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.s2),
              ],
              Text(
                widget.label,
                style: AppTypography.body.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
