import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../state/providers.dart';

Future<void> showImmersivePlayer(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '沉浸播放器',
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, _) => const ImmersivePlayer(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class ImmersivePlayer extends ConsumerStatefulWidget {
  const ImmersivePlayer({super.key});

  @override
  ConsumerState<ImmersivePlayer> createState() => _ImmersivePlayerState();
}

class _ImmersivePlayerState extends ConsumerState<ImmersivePlayer> {
  bool _controlsVisible = true;
  bool _vinylMode = false;
  Color? _coverColor;
  String? _paletteKey;
  Timer? _hideControlsTimer;

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = BiliColors.dark;
    final track = ref.watch(playbackProvider.select((state) => state.track));
    _schedulePalette(track);

    final seedColor = _seedColor(track?.gradientSeed ?? 0);
    final baseColor = _coverColor ?? seedColor;
    final palette = _ImmersivePalette.from(baseColor, vinyl: _vinylMode);

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(extensions: const <ThemeExtension<dynamic>>[BiliColors.dark]),
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onHover: (event) => _handleHover(event.localPosition.dy),
          onExit: (_) => _setControlsVisible(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.primary, palette.secondary, colors.bgBase],
                stops: const [0, 0.52, 1],
              ),
            ),
            child: Stack(
              children: [
                _BlurredCoverBackdrop(track: track, vinyl: _vinylMode),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.45, -0.20),
                      radius: 1.2,
                      colors: [
                        palette.glow.withValues(alpha: 0.42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
                _AudioBars(
                  color: palette.glow,
                  vinyl: _vinylMode,
                  track: track,
                ),
                _ImmersiveBody(track: track, vinyl: _vinylMode),
                _TopControls(
                  visible: _controlsVisible,
                  vinyl: _vinylMode,
                  onClose: () => Navigator.of(context).pop(),
                  onToggleTheme: () => setState(() => _vinylMode = !_vinylMode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleHover(double y) {
    if (y < 112) {
      _setControlsVisible(true);
      _hideControlsTimer?.cancel();
      return;
    }
    _hideControlsTimer ??= Timer(
      const Duration(milliseconds: 900),
      () => _setControlsVisible(false),
    );
  }

  void _setControlsVisible(bool visible) {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
    if (_controlsVisible == visible) return;
    setState(() => _controlsVisible = visible);
  }

  void _schedulePalette(Track? track) {
    final key = '${track?.id ?? ''}:${track?.coverUrl ?? ''}';
    if (_paletteKey == key) return;
    _paletteKey = key;
    _coverColor = _seedColor(track?.gradientSeed ?? 0);
    unawaited(
      _extractDominantColor(track).then((color) {
        if (!mounted || _paletteKey != key) return;
        setState(() => _coverColor = color);
      }),
    );
  }

  Future<Color> _extractDominantColor(Track? track) async {
    final fallback = _seedColor(track?.gradientSeed ?? 0);
    final url = track?.coverUrl;
    if (url == null || url.isEmpty) return fallback;

    try {
      final provider = ResizeImage(NetworkImage(url), width: 64, height: 64);
      final image = await _loadImage(
        provider,
      ).timeout(const Duration(seconds: 4));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return fallback;

      final data = bytes.buffer.asUint8List();
      final pixelCount = image.width * image.height;
      final step = math.max(1, pixelCount ~/ 1800);
      var hueX = 0.0;
      var hueY = 0.0;
      var saturation = 0.0;
      var lightness = 0.0;
      var totalWeight = 0.0;

      for (var pixel = 0; pixel < pixelCount; pixel += step) {
        final offset = pixel * 4;
        if (offset + 3 >= data.length) break;
        final alpha = data[offset + 3];
        if (alpha < 220) continue;
        final color = Color.fromARGB(
          alpha,
          data[offset],
          data[offset + 1],
          data[offset + 2],
        );
        final hsl = HSLColor.fromColor(color);
        if (hsl.lightness < 0.08 ||
            hsl.lightness > 0.92 ||
            hsl.saturation < 0.08) {
          continue;
        }
        final weight =
            (hsl.saturation + 0.18) * (1 - (hsl.lightness - 0.5).abs());
        final radians = hsl.hue * math.pi / 180;
        hueX += math.cos(radians) * weight;
        hueY += math.sin(radians) * weight;
        saturation += hsl.saturation * weight;
        lightness += hsl.lightness * weight;
        totalWeight += weight;
      }

      if (totalWeight <= 0) return fallback;
      final hue = (math.atan2(hueY, hueX) * 180 / math.pi + 360) % 360;
      return HSLColor.fromAHSL(
        1,
        hue,
        (saturation / totalWeight).clamp(0.34, 0.82),
        (lightness / totalWeight).clamp(0.22, 0.48),
      ).toColor();
    } catch (_) {
      return fallback;
    }
  }

  Future<ui.Image> _loadImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(image.image);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

class _ImmersivePalette {
  const _ImmersivePalette({
    required this.primary,
    required this.secondary,
    required this.glow,
  });

  final Color primary;
  final Color secondary;
  final Color glow;

  factory _ImmersivePalette.from(Color color, {required bool vinyl}) {
    final hsl = HSLColor.fromColor(color);
    if (vinyl) {
      return _ImmersivePalette(
        primary: hsl
            .withSaturation((hsl.saturation * 0.62 + 0.20).clamp(0.24, 0.64))
            .withLightness(0.16)
            .toColor(),
        secondary: hsl
            .withHue((hsl.hue + 28) % 360)
            .withSaturation((hsl.saturation * 0.55 + 0.12).clamp(0.18, 0.54))
            .withLightness(0.08)
            .toColor(),
        glow: hsl
            .withHue((hsl.hue + 180) % 360)
            .withSaturation(0.34)
            .withLightness(0.22)
            .toColor(),
      );
    }
    return _ImmersivePalette(
      primary: hsl
          .withSaturation((hsl.saturation * 0.72 + 0.24).clamp(0.35, 0.82))
          .withLightness(0.30)
          .toColor(),
      secondary: hsl
          .withHue((hsl.hue + 36) % 360)
          .withSaturation((hsl.saturation * 0.65 + 0.18).clamp(0.30, 0.76))
          .withLightness(0.12)
          .toColor(),
      glow: hsl.withLightness(0.42).withSaturation(0.62).toColor(),
    );
  }
}

Color _seedColor(int seed) {
  final hue = (seed * 47) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.36).toColor();
}

class _AudioBars extends ConsumerStatefulWidget {
  const _AudioBars({
    required this.color,
    required this.vinyl,
    required this.track,
  });

  final Color color;
  final bool vinyl;
  final Track? track;

  @override
  ConsumerState<_AudioBars> createState() => _AudioBarsState();
}

class _AudioBarsState extends ConsumerState<_AudioBars>
    with SingleTickerProviderStateMixin {
  static const _barCount = 84;

  late final AnimationController _controller;
  late List<_AudioBarSeed> _seeds;
  late String _patternKey;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 37),
    )..repeat();
    _patternKey = _buildPatternKey();
    _seeds = _buildSeeds();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AudioBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    final patternKey = _buildPatternKey();
    if (oldWidget.vinyl != widget.vinyl || patternKey != _patternKey) {
      _patternKey = patternKey;
      _seeds = _buildSeeds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isBuffering: state.isBuffering,
          progress: state.progress,
          bufferProgress: state.bufferProgress,
          volume: state.volume,
          positionSeconds: state.position.inMilliseconds / 1000,
        ),
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 138,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: widget.vinyl ? 0.28 : 0.18),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AudioBarsPainter(
                  time:
                      (_controller.lastElapsedDuration?.inMilliseconds ?? 0) /
                      1000,
                  playbackSeconds: snapshot.positionSeconds,
                  progress: snapshot.progress,
                  bufferProgress: snapshot.bufferProgress,
                  volume: snapshot.volume,
                  seeds: _seeds,
                  color: widget.color,
                  isPlaying: snapshot.isPlaying,
                  isBuffering: snapshot.isBuffering,
                  vinyl: widget.vinyl,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _buildPatternKey() {
    final track = widget.track;
    return '${track?.id ?? ''}:${track?.title ?? ''}:${track?.gradientSeed ?? 0}:${widget.vinyl}';
  }

  List<_AudioBarSeed> _buildSeeds() {
    final random = math.Random(_stableHash(_buildPatternKey()));
    return List<_AudioBarSeed>.generate(_barCount, (index) {
      final lowBand = index < _barCount * 0.28;
      final highBand = index > _barCount * 0.72;
      return _AudioBarSeed(
        base: 0.24 + random.nextDouble() * 0.76,
        phase: random.nextDouble() * math.pi * 2,
        speed:
            (lowBand
                ? 0.62
                : highBand
                ? 1.45
                : 1.0) +
            random.nextDouble() * 0.72,
        pulse: 0.20 + random.nextDouble() * 0.52,
        bandBias: lowBand
            ? 1.18
            : highBand
            ? 0.76
            : 0.94 + random.nextDouble() * 0.28,
      );
    }, growable: false);
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _AudioBarSeed {
  const _AudioBarSeed({
    required this.base,
    required this.phase,
    required this.speed,
    required this.pulse,
    required this.bandBias,
  });

  final double base;
  final double phase;
  final double speed;
  final double pulse;
  final double bandBias;
}

class _AudioBarsPainter extends CustomPainter {
  const _AudioBarsPainter({
    required this.time,
    required this.playbackSeconds,
    required this.progress,
    required this.bufferProgress,
    required this.volume,
    required this.seeds,
    required this.color,
    required this.isPlaying,
    required this.isBuffering,
    required this.vinyl,
  });

  final double time;
  final double playbackSeconds;
  final double progress;
  final double bufferProgress;
  final double volume;
  final List<_AudioBarSeed> seeds;
  final Color color;
  final bool isPlaying;
  final bool isBuffering;
  final bool vinyl;

  @override
  void paint(Canvas canvas, Size size) {
    if (seeds.isEmpty || size.width <= 0 || size.height <= 0) return;

    final count = seeds.length;
    final gap = vinyl ? 7.0 : 6.0;
    final barWidth = math.max(3.0, (size.width - gap * (count - 1)) / count);
    final totalWidth = count * barWidth + (count - 1) * gap;
    final startX = (size.width - totalWidth) / 2;
    final baseline = size.height;
    final maxHeight = vinyl ? 82.0 : 68.0;
    final activeWidth = size.width * progress.clamp(0.0, 1.0);
    final bufferedWidth = size.width * bufferProgress.clamp(0.0, 1.0);
    final hsl = HSLColor.fromColor(color);
    final volumeLift = 0.36 + volume.clamp(0.0, 1.0) * 0.92;
    final playLift = isPlaying ? 1.0 : 0.24;
    final bufferLift = isBuffering ? 0.72 : 1.0;
    final drift = playbackSeconds * (vinyl ? 0.08 : 0.11);

    for (var i = 0; i < count; i++) {
      final x = startX + i * (barWidth + gap);
      final seed = seeds[i];
      final phase = time * seed.speed + seed.phase + drift;
      final slowEnvelope =
          0.58 + math.sin(time * 0.31 + seed.phase * 0.7) * 0.20;
      final waveA = math.sin(phase + i * 0.11);
      final waveB = math.sin(phase * 1.83 + i * 0.19);
      final waveC = math.sin(time * 0.47 + progress * math.pi * 4 + i * 0.05);
      final energy = isPlaying
          ? (0.20 +
                seed.base * 0.34 +
                waveA * seed.pulse * 0.18 +
                waveB * 0.11 +
                waveC * 0.07)
          : (0.08 + seed.base * 0.06);
      final centerWeight = 1 - ((i / (count - 1)) - 0.5).abs() * 0.72;
      final height =
          (maxHeight *
                  energy *
                  centerWeight *
                  seed.bandBias *
                  slowEnvelope *
                  volumeLift *
                  playLift *
                  bufferLift)
              .clamp(5.0, maxHeight);
      final isActive = x <= activeWidth;
      final isBuffered = x <= bufferedWidth;
      final barColor = hsl
          .withHue((hsl.hue + i * (vinyl ? 0.9 : 0.55)) % 360)
          .withSaturation(vinyl ? 0.32 : 0.56)
          .withLightness(isActive ? 0.64 : 0.38)
          .toColor()
          .withValues(
            alpha: isActive
                ? 0.46
                : isBuffered
                ? 0.27
                : 0.15,
          );
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseline - height, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, Paint()..color = barColor);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioBarsPainter oldDelegate) {
    return time != oldDelegate.time ||
        playbackSeconds != oldDelegate.playbackSeconds ||
        progress != oldDelegate.progress ||
        bufferProgress != oldDelegate.bufferProgress ||
        volume != oldDelegate.volume ||
        isPlaying != oldDelegate.isPlaying ||
        isBuffering != oldDelegate.isBuffering ||
        vinyl != oldDelegate.vinyl ||
        color != oldDelegate.color ||
        seeds != oldDelegate.seeds;
  }
}

class _BlurredCoverBackdrop extends StatelessWidget {
  const _BlurredCoverBackdrop({required this.track, required this.vinyl});

  final Track? track;
  final bool vinyl;

  @override
  Widget build(BuildContext context) {
    final url = track?.coverUrl;
    if (url == null || url.isEmpty) return const SizedBox.expand();
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: vinyl ? 0.18 : 0.28,
        duration: AppDuration.slow,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
          child: Transform.scale(
            scale: 1.16,
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _ImmersiveBody extends ConsumerWidget {
  const _ImmersiveBody({required this.track, required this.vinyl});

  final Track? track;
  final bool vinyl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.sizeOf(context);
    final coverExtent = math.min(media.width * 0.34, media.height * 0.62);

    return Padding(
      padding: const EdgeInsets.fromLTRB(84, 96, 84, 72),
      child: Row(
        children: [
          SizedBox(
            width: coverExtent.clamp(300.0, 460.0),
            child: _CoverColumn(track: track, vinyl: vinyl),
          ),
          const SizedBox(width: 72),
          Expanded(
            child: _ImmersiveLyrics(
              lyrics: ref.watch(nowPlayingLyricsProvider),
              position: ref.watch(
                playbackProvider.select((state) => state.position),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverColumn extends ConsumerWidget {
  const _CoverColumn({required this.track, required this.vinyl});

  final Track? track;
  final bool vinyl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const colors = BiliColors.dark;
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (
          position: state.position,
          duration: state.duration,
          progress: state.progress,
          bufferProgress: state.bufferProgress,
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: vinyl
                ? _VinylDeck(key: const ValueKey('vinyl'), track: track)
                : _SquareCover(key: const ValueKey('square'), track: track),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          track?.title ?? '—',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleL.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          track?.artist ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s6),
        BiliProgressBar(
          value: snapshot.progress,
          bufferValue: snapshot.bufferProgress,
          onChangeEnd: ref.read(playbackProvider.notifier).seekFraction,
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Format.duration(snapshot.position),
              style: AppTypography.caption.copyWith(color: colors.textTertiary),
            ),
            Text(
              Format.duration(snapshot.duration),
              style: AppTypography.caption.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

class _SquareCover extends StatelessWidget {
  const _SquareCover({super.key, required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 44,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: CoverImage(
        url: track?.coverUrl,
        gradientSeed: track?.gradientSeed ?? 0,
        radius: 20,
      ),
    );
  }
}

class _VinylDeck extends ConsumerStatefulWidget {
  const _VinylDeck({super.key, required this.track});

  final Track? track;

  @override
  ConsumerState<_VinylDeck> createState() => _VinylDeckState();
}

class _VinylDeckState extends ConsumerState<_VinylDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (ref.read(playbackProvider).isPlaying) _rotation.repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(
      playbackProvider.select((state) => state.isPlaying),
    );
    if (isPlaying && !_rotation.isAnimating) {
      _rotation.repeat();
    } else if (!isPlaying && _rotation.isAnimating) {
      _rotation.stop();
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.46),
                blurRadius: 52,
                offset: const Offset(0, 30),
              ),
            ],
          ),
          child: RotationTransition(
            turns: _rotation,
            child: CustomPaint(
              painter: _VinylPainter(),
              child: SizedBox.expand(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.38,
                    heightFactor: 0.38,
                    child: ClipOval(
                      child: CoverImage(
                        url: widget.track?.coverUrl,
                        gradientSeed: widget.track?.gradientSeed ?? 0,
                        shape: CoverShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -46,
          top: -4,
          width: 164,
          height: 236,
          child: AnimatedRotation(
            turns: isPlaying ? 0.010 : -0.018,
            duration: AppDuration.slow,
            curve: Curves.easeOutCubic,
            alignment: const Alignment(0.34, -0.76),
            child: CustomPaint(painter: _ToneArmPainter(isPlaying: isPlaying)),
          ),
        ),
      ],
    );
  }
}

class _ToneArmPainter extends CustomPainter {
  const _ToneArmPainter({required this.isPlaying});

  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.72, size.height * 0.16);
    final elbow = Offset(size.width * 0.54, size.height * 0.43);
    final head = Offset(size.width * 0.42, size.height * 0.72);
    final needle = Offset(size.width * 0.36, size.height * 0.80);

    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.28);
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(pivot, head, [
        Colors.white.withValues(alpha: 0.42),
        Colors.white.withValues(alpha: 0.16),
      ]);
    final joint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.28);

    final path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..quadraticBezierTo(elbow.dx, elbow.dy, head.dx, head.dy);
    canvas.drawPath(path.shift(const Offset(4, 5)), shadow);
    canvas.drawPath(path, arm);

    canvas.drawCircle(
      pivot,
      25,
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );
    canvas.drawCircle(
      pivot,
      20,
      Paint()
        ..shader = ui.Gradient.radial(
          pivot,
          20,
          [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.22),
          ],
          const [0.0, 0.58, 1.0],
        ),
    );
    canvas.drawCircle(
      pivot,
      7,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    canvas.drawLine(
      Offset(head.dx - 16, head.dy - 6),
      Offset(head.dx + 14, head.dy + 8),
      joint,
    );

    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(-0.34);
    final headshell = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, -11, 46, 24),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      headshell.shift(const Offset(3, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.26),
    );
    canvas.drawRRect(
      headshell,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-22, -10),
          const Offset(24, 12),
          [
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0.16),
          ],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 2, 16, 13),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );
    canvas.restore();

    canvas.drawLine(
      Offset(head.dx - 4, head.dy + 13),
      needle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: isPlaying ? 0.52 : 0.34),
    );
    canvas.drawCircle(
      needle,
      2.2,
      Paint()..color = Colors.white.withValues(alpha: 0.46),
    );
  }

  @override
  bool shouldRepaint(covariant _ToneArmPainter oldDelegate) {
    return isPlaying != oldDelegate.isPlaying;
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final base = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          const Color(0xFF303033),
          const Color(0xFF0B0B0D),
          const Color(0xFF050506),
        ],
        const [0.0, 0.54, 1.0],
      );
    canvas.drawCircle(center, radius, base);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.07);
    for (var factor = 0.30; factor <= 0.92; factor += 0.085) {
      canvas.drawCircle(center, radius * factor, ringPaint);
    }

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.78),
      -1.20,
      0.62,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ImmersiveLyrics extends StatefulWidget {
  const _ImmersiveLyrics({required this.lyrics, required this.position});

  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;

  @override
  State<_ImmersiveLyrics> createState() => _ImmersiveLyricsState();
}

class _ImmersiveLyricsState extends State<_ImmersiveLyrics> {
  final _controller = ScrollController();
  final _lineKeys = <GlobalKey>[];
  int? _lastCenteredIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = BiliColors.dark;
    return widget.lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const _LyricsMessage(title: '未找到歌词', subtitle: '当前曲目暂时没有可用歌词。'),
      data: (lines) {
        if (lines.isEmpty) {
          return const _LyricsMessage(
            title: '未找到歌词',
            subtitle: '当前曲目暂时没有匹配到歌词。',
          );
        }
        _syncLineKeys(lines.length);
        final currentIndex = _currentLyricIndex(lines, widget.position);
        _scheduleCenterCurrentLine(currentIndex);
        return LayoutBuilder(
          builder: (context, constraints) {
            return ListView.builder(
              controller: _controller,
              padding: EdgeInsets.symmetric(
                vertical: constraints.maxHeight * 0.38,
              ),
              itemCount: lines.length,
              itemBuilder: (_, index) {
                final current = index == currentIndex;
                return Padding(
                  key: _lineKeys[index],
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      style:
                          (current
                                  ? AppTypography.titleL
                                  : AppTypography.titleM)
                              .copyWith(
                                color: current
                                    ? colors.textPrimary
                                    : colors.textSecondary.withValues(
                                        alpha: 0.52,
                                      ),
                                fontWeight: current
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                      child: Text(
                        lines[index].text,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _syncLineKeys(int length) {
    if (_lineKeys.length == length) return;
    if (_lineKeys.length > length) {
      _lineKeys.removeRange(length, _lineKeys.length);
      return;
    }
    _lineKeys.addAll(
      List<GlobalKey>.generate(length - _lineKeys.length, (_) => GlobalKey()),
    );
  }

  void _scheduleCenterCurrentLine(int index) {
    if (index < 0 || _lastCenteredIndex == index) return;
    _lastCenteredIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _lineKeys.length) return;
      final context = _lineKeys[index].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.48,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _currentLyricIndex(List<LyricLine> lines, Duration position) {
    final timed = lines.any((line) => line.time > Duration.zero);
    if (!timed) return -1;
    var index = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time > position) break;
      index = i;
    }
    return index;
  }
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const colors = BiliColors.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleL.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TopControls extends ConsumerWidget {
  const _TopControls({
    required this.visible,
    required this.vinyl,
    required this.onClose,
    required this.onToggleTheme,
  });

  final bool visible;
  final bool vinyl;
  final VoidCallback onClose;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const colors = BiliColors.dark;
    final isPlaying = ref.watch(
      playbackProvider.select((state) => state.isPlaying),
    );
    final notifier = ref.read(playbackProvider.notifier);

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 88,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -0.25),
          duration: AppDuration.normal,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: AppDuration.normal,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                child: Row(
                  children: [
                    _TopIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      tooltip: '退出沉浸',
                      onPressed: onClose,
                    ),
                    Expanded(
                      child: Platform.isWindows
                          ? const ExcludeSemantics(
                              child: DragToMoveArea(child: SizedBox.expand()),
                            )
                          : const SizedBox.expand(),
                    ),
                    _TopControlCluster(
                      children: [
                        _TopIconButton(
                          icon: Icons.skip_previous_rounded,
                          tooltip: '上一首',
                          onPressed: notifier.previous,
                        ),
                        _TopIconButton(
                          icon: isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: isPlaying ? '暂停' : '播放',
                          emphasized: true,
                          onPressed: notifier.togglePlay,
                        ),
                        _TopIconButton(
                          icon: Icons.skip_next_rounded,
                          tooltip: '下一首',
                          onPressed: notifier.next,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: colors.textPrimary.withValues(alpha: 0.14),
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s1,
                          ),
                        ),
                        _TopIconButton(
                          icon: vinyl
                              ? Icons.album_rounded
                              : Icons.crop_square_rounded,
                          tooltip: '切换沉浸主题',
                          active: vinyl,
                          onPressed: onToggleTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopControlCluster extends StatelessWidget {
  const _TopControlCluster({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s1,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    const colors = BiliColors.dark;
    final color = active || emphasized
        ? colors.textPrimary
        : colors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: emphasized ? 26 : 22,
        style: IconButton.styleFrom(
          fixedSize: Size.square(emphasized ? 44 : 40),
          backgroundColor: emphasized
              ? colors.brand.withValues(alpha: 0.88)
              : active
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.transparent,
          foregroundColor: color,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
