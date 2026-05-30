import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// The brand-pink circular play/pause button (design doc §8.2). Lifts and
/// scales slightly on hover; carries the only shadow the design permits.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.onTap,
    this.isPlaying = false,
    this.size = 44,
    this.elevated = true,
  });

  final VoidCallback onTap;
  final bool isPlaying;
  final double size;
  final bool elevated;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
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
        child: AnimatedScale(
          scale: _hover ? 1.06 : 1.0,
          duration: AppDuration.normal,
          curve: Curves.ease,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _hover ? colors.brandLight : colors.brand,
              shape: BoxShape.circle,
              boxShadow: widget.elevated
                  ? const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: colors.onBrand,
              size: widget.size * 0.56,
            ),
          ),
        ),
      ),
    );
  }
}
