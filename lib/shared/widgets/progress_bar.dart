import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Spotify-style scrubber (design doc §8.3): 4px track that thickens to 6px on
/// hover, fill turns brand-pink on hover, and a thumb scales in. Click or drag
/// to seek. [onChanged] fires while scrubbing; [onChangeEnd] on release.
class BiliProgressBar extends StatefulWidget {
  const BiliProgressBar({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.alwaysActive = false,
  });

  final double value; // 0..1
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Mobile mini-player uses a thin always-brand bar with no thumb.
  final bool alwaysActive;

  @override
  State<BiliProgressBar> createState() => _BiliProgressBarState();
}

class _BiliProgressBarState extends State<BiliProgressBar> {
  bool _hover = false;
  double? _dragValue;

  double get _display => _dragValue ?? widget.value.clamp(0.0, 1.0);

  void _emit(double v, BoxConstraints c, {bool end = false}) {
    final frac = (v / c.maxWidth).clamp(0.0, 1.0);
    setState(() => _dragValue = frac);
    widget.onChanged?.call(frac);
    if (end) {
      widget.onChangeEnd?.call(frac);
      setState(() => _dragValue = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = _hover || _dragValue != null;
    final showThumb = active && !widget.alwaysActive;
    final fillColor =
        (active || widget.alwaysActive) ? colors.brand : colors.textPrimary;
    final trackHeight = active && !widget.alwaysActive ? 6.0 : 4.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _emit(d.localPosition.dx, constraints, end: true),
            onHorizontalDragUpdate: (d) =>
                _emit(d.localPosition.dx, constraints),
            onHorizontalDragEnd: (_) {
              final v = _dragValue;
              if (v != null) {
                widget.onChangeEnd?.call(v);
                setState(() => _dragValue = null);
              }
            },
            child: SizedBox(
              height: 16,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  AnimatedContainer(
                    duration: AppDuration.fast,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: colors.bgActive,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                  // Fill
                  FractionallySizedBox(
                    widthFactor: _display,
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                      ),
                    ),
                  ),
                  // Thumb
                  Align(
                    alignment: Alignment(_display * 2 - 1, 0),
                    child: AnimatedScale(
                      scale: showThumb ? 1 : 0,
                      duration: AppDuration.fast,
                      curve: Curves.ease,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
