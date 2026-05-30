import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

/// Renders a cover for content (rounded-square) or a creator (circle).
///
/// When [url] is null (M0 mock data) it paints a deterministic gradient seeded
/// by [gradientSeed] with a faint type glyph, so placeholders look intentional.
/// When a URL is present it loads via [CachedNetworkImage] (the path used once
/// real Bilibili covers are wired in, M4).
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.url,
    required this.gradientSeed,
    this.shape = CoverShape.square,
    this.radius = 4,
  });

  final String? url;
  final int gradientSeed;
  final CoverShape shape;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == CoverShape.circle;
    final borderRadius =
        isCircle ? null : BorderRadius.circular(radius);

    Widget content = url == null
        ? _Placeholder(seed: gradientSeed, isCircle: isCircle)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                _Placeholder(seed: gradientSeed, isCircle: isCircle),
            errorWidget: (_, _, _) =>
                _Placeholder(seed: gradientSeed, isCircle: isCircle),
          );

    if (isCircle) {
      return ClipOval(child: content);
    }
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.seed, required this.isCircle});

  final int seed;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final hue = (seed * 47) % 360;
    final c1 = HSLColor.fromAHSL(1, hue.toDouble(), 0.50, 0.42).toColor();
    final c2 =
        HSLColor.fromAHSL(1, (hue + 35) % 360, 0.55, 0.26).toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Center(
        child: Icon(
          isCircle ? Icons.person_rounded : Icons.music_note_rounded,
          color: context.colors.onBrand.withValues(alpha: 0.55),
          size: 28,
        ),
      ),
    );
  }
}
