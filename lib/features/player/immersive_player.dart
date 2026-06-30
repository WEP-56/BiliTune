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

enum _ImmersiveThemeMode {
  standard,
  vinyl,
  tilt,
  fume,
  partita;

  bool get isVinyl => this == _ImmersiveThemeMode.vinyl;
  bool get isTilt => this == _ImmersiveThemeMode.tilt;
  bool get isFume => this == _ImmersiveThemeMode.fume;
  bool get isPartita => this == _ImmersiveThemeMode.partita;

  IconData get icon => switch (this) {
    _ImmersiveThemeMode.standard => Icons.crop_square_rounded,
    _ImmersiveThemeMode.vinyl => Icons.album_rounded,
    _ImmersiveThemeMode.tilt => Icons.auto_awesome_rounded,
    _ImmersiveThemeMode.fume => Icons.article_rounded,
    _ImmersiveThemeMode.partita => Icons.stairs_rounded,
  };
}

_ImmersiveThemeMode _themeModeFromPreference(
  ImmersiveThemePreference preference,
) {
  return switch (preference) {
    ImmersiveThemePreference.standard => _ImmersiveThemeMode.standard,
    ImmersiveThemePreference.vinyl => _ImmersiveThemeMode.vinyl,
    ImmersiveThemePreference.tilt => _ImmersiveThemeMode.tilt,
    ImmersiveThemePreference.fume => _ImmersiveThemeMode.fume,
    ImmersiveThemePreference.partita => _ImmersiveThemeMode.partita,
  };
}

class _ImmersivePlayerState extends ConsumerState<ImmersivePlayer> {
  bool _controlsVisible = true;
  _ImmersiveThemeMode _themeMode = _ImmersiveThemeMode.standard;
  bool _themeManuallyChanged = false;
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
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 720;
    final defaultTheme = ref.watch(
      playbackSettingsProvider.select((state) => state.immersiveDefaultTheme),
    );
    if (!_themeManuallyChanged) {
      _themeMode = _themeModeFromPreference(defaultTheme);
    }
    final track = ref.watch(playbackProvider.select((state) => state.track));
    _schedulePalette(track);

    final seedColor = _seedColor(track?.gradientSeed ?? 0);
    final baseColor = _coverColor ?? seedColor;
    final palette = _ImmersivePalette.from(baseColor, mode: _themeMode);

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
                _BlurredCoverBackdrop(track: track, vinyl: _themeMode.isVinyl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: _themeMode.isTilt
                          ? const Alignment(0.18, -0.10)
                          : _themeMode.isFume
                          ? const Alignment(-0.08, -0.18)
                          : _themeMode.isPartita
                          ? const Alignment(0.04, -0.26)
                          : const Alignment(-0.45, -0.20),
                      radius:
                          _themeMode.isTilt ||
                              _themeMode.isFume ||
                              _themeMode.isPartita
                          ? 1.45
                          : 1.2,
                      colors: [
                        palette.glow.withValues(
                          alpha: _themeMode.isTilt
                              ? 0.58
                              : _themeMode.isFume
                              ? 0.34
                              : _themeMode.isPartita
                              ? 0.42
                              : 0.42,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
                _AudioBars(
                  color: palette.glow,
                  vinyl: _themeMode.isVinyl,
                  track: track,
                ),
                _ImmersiveBody(
                  track: track,
                  mode: _themeMode,
                  palette: palette,
                  compact: compact,
                ),
                _TopControls(
                  visible: _controlsVisible,
                  mode: _themeMode,
                  compact: compact,
                  onClose: () => Navigator.of(context).pop(),
                  onToggleTheme: _cycleTheme,
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

  void _cycleTheme() {
    setState(() {
      _themeManuallyChanged = true;
      _themeMode = switch (_themeMode) {
        _ImmersiveThemeMode.standard => _ImmersiveThemeMode.vinyl,
        _ImmersiveThemeMode.vinyl => _ImmersiveThemeMode.tilt,
        _ImmersiveThemeMode.tilt => _ImmersiveThemeMode.fume,
        _ImmersiveThemeMode.fume => _ImmersiveThemeMode.partita,
        _ImmersiveThemeMode.partita => _ImmersiveThemeMode.standard,
      };
    });
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

  factory _ImmersivePalette.from(
    Color color, {
    required _ImmersiveThemeMode mode,
  }) {
    final hsl = HSLColor.fromColor(color);
    if (mode.isVinyl) {
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
    if (mode.isTilt) {
      return _ImmersivePalette(
        primary: hsl
            .withSaturation((hsl.saturation * 0.44 + 0.10).clamp(0.16, 0.42))
            .withLightness(0.13)
            .toColor(),
        secondary: hsl
            .withHue((hsl.hue + 22) % 360)
            .withSaturation((hsl.saturation * 0.34 + 0.08).clamp(0.12, 0.34))
            .withLightness(0.055)
            .toColor(),
        glow: hsl
            .withSaturation((hsl.saturation * 0.46 + 0.16).clamp(0.22, 0.48))
            .withLightness(0.44)
            .toColor(),
      );
    }
    if (mode.isFume) {
      return _ImmersivePalette(
        primary: hsl
            .withHue((hsl.hue + 10) % 360)
            .withSaturation((hsl.saturation * 0.30 + 0.08).clamp(0.10, 0.30))
            .withLightness(0.10)
            .toColor(),
        secondary: hsl
            .withHue((hsl.hue + 54) % 360)
            .withSaturation((hsl.saturation * 0.24 + 0.06).clamp(0.08, 0.24))
            .withLightness(0.045)
            .toColor(),
        glow: hsl
            .withHue((hsl.hue + 190) % 360)
            .withSaturation((hsl.saturation * 0.28 + 0.12).clamp(0.16, 0.34))
            .withLightness(0.36)
            .toColor(),
      );
    }
    if (mode.isPartita) {
      return _ImmersivePalette(
        primary: hsl
            .withHue((hsl.hue + 346) % 360)
            .withSaturation((hsl.saturation * 0.38 + 0.12).clamp(0.18, 0.46))
            .withLightness(0.12)
            .toColor(),
        secondary: hsl
            .withHue((hsl.hue + 76) % 360)
            .withSaturation((hsl.saturation * 0.30 + 0.10).clamp(0.14, 0.36))
            .withLightness(0.055)
            .toColor(),
        glow: hsl
            .withHue((hsl.hue + 152) % 360)
            .withSaturation((hsl.saturation * 0.42 + 0.20).clamp(0.24, 0.54))
            .withLightness(0.42)
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

double _durationProgress(Duration elapsed, Duration duration) {
  final total = duration.inMilliseconds;
  if (total <= 0) return 0;
  return (elapsed.inMilliseconds / total).clamp(0.0, 1.0);
}

double _easeOutCubic(double value) {
  final normalized = value.clamp(0.0, 1.0);
  return 1 - math.pow(1 - normalized, 3).toDouble();
}

List<String> _graphemes(String text) {
  return text.runes.map(String.fromCharCode).toList(growable: false);
}

List<String> _splitTiltSegments(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return const <String>[''];
  final words = normalized.split(' ');
  if (words.length >= 5) {
    final targetCount = words.length >= 10 ? 3 : 2;
    final segments = <String>[];
    for (var i = 0; i < targetCount; i++) {
      final start = (words.length * i / targetCount).floor();
      final end = (words.length * (i + 1) / targetCount).floor();
      segments.add(words.sublist(start, end).join(' '));
    }
    return segments.where((segment) => segment.isNotEmpty).toList();
  }

  final chars = _graphemes(normalized);
  if (chars.length <= 12) return <String>[normalized];
  final targetCount = chars.length > 26 ? 3 : 2;
  final breakChars = RegExp(r'[，。！？、,.!?;；:：]');
  final segments = <String>[];
  var start = 0;
  for (var i = 1; i <= targetCount; i++) {
    var end = (chars.length * i / targetCount).round();
    if (i < targetCount) {
      final searchStart = math.max(start + 2, end - 4);
      final searchEnd = math.min(chars.length - 1, end + 5);
      for (var j = searchStart; j <= searchEnd; j++) {
        if (breakChars.hasMatch(chars[j])) {
          end = j + 1;
          break;
        }
      }
    } else {
      end = chars.length;
    }
    final segment = chars.sublist(start, end).join().trim();
    if (segment.isNotEmpty) segments.add(segment);
    start = end;
  }
  return segments.isEmpty ? <String>[normalized] : segments;
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
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
  const _ImmersiveBody({
    required this.track,
    required this.mode,
    required this.palette,
    required this.compact,
  });

  final Track? track;
  final _ImmersiveThemeMode mode;
  final _ImmersivePalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.sizeOf(context);
    final coverExtent = math.min(media.width * 0.34, media.height * 0.62);
    final lyrics = ref.watch(nowPlayingLyricsProvider);
    final playback = ref.watch(
      playbackProvider.select(
        (state) => (
          position: state.position,
          duration: state.duration,
          progress: state.progress,
          bufferProgress: state.bufferProgress,
        ),
      ),
    );

    if (mode.isTilt) {
      return _TiltImmersiveStage(
        track: track,
        lyrics: lyrics,
        position: playback.position,
        duration: playback.duration,
        progress: playback.progress,
        bufferProgress: playback.bufferProgress,
        palette: palette,
        compact: compact,
      );
    }
    if (mode.isFume) {
      return _FumeImmersiveStage(
        track: track,
        lyrics: lyrics,
        position: playback.position,
        duration: playback.duration,
        progress: playback.progress,
        bufferProgress: playback.bufferProgress,
        palette: palette,
        compact: compact,
      );
    }
    if (mode.isPartita) {
      return _PartitaImmersiveStage(
        track: track,
        lyrics: lyrics,
        position: playback.position,
        duration: playback.duration,
        progress: playback.progress,
        bufferProgress: playback.bufferProgress,
        palette: palette,
        compact: compact,
      );
    }
    if (compact) {
      return _MobileDeckImmersiveBody(
        track: track,
        vinyl: mode.isVinyl,
        lyrics: lyrics,
        position: playback.position,
        duration: playback.duration,
        progress: playback.progress,
        bufferProgress: playback.bufferProgress,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(84, 96, 84, 72),
      child: Row(
        children: [
          SizedBox(
            width: coverExtent.clamp(300.0, 460.0),
            child: _CoverColumn(track: track, vinyl: mode.isVinyl),
          ),
          const SizedBox(width: 72),
          Expanded(
            child: _ImmersiveLyrics(
              lyrics: lyrics,
              position: playback.position,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDeckImmersiveBody extends ConsumerWidget {
  const _MobileDeckImmersiveBody({
    required this.track,
    required this.vinyl,
    required this.lyrics,
    required this.position,
    required this.duration,
    required this.progress,
    required this.bufferProgress,
  });

  final Track? track;
  final bool vinyl;
  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;
  final Duration duration;
  final double progress;
  final double bufferProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const colors = BiliColors.dark;
    final media = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final coverSize = math.min(media.width * (vinyl ? 0.70 : 0.64), 300.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset + 82, 24, bottomInset + 18),
        child: Column(
          children: [
            SizedBox(
              width: coverSize,
              height: coverSize,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: vinyl
                    ? _VinylDeck(
                        key: const ValueKey('mobile-vinyl'),
                        track: track,
                      )
                    : _SquareCover(
                        key: const ValueKey('mobile-square'),
                        track: track,
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              track?.title ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.titleM.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              track?.artist ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: _ImmersiveLyrics(lyrics: lyrics, position: position),
            ),
            const SizedBox(height: AppSpacing.s3),
            BiliProgressBar(
              value: progress,
              bufferValue: bufferProgress,
              onChangeEnd: ref.read(playbackProvider.notifier).seekFraction,
            ),
            const SizedBox(height: AppSpacing.s1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Format.duration(position),
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                Text(
                  Format.duration(duration),
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            const _MobileImmersiveTransportControls(),
          ],
        ),
      ),
    );
  }
}

class _MobileImmersiveTransportControls extends ConsumerWidget {
  const _MobileImmersiveTransportControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const colors = BiliColors.dark;
    final snapshot = ref.watch(
      playbackProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          shuffle: state.shuffle,
          repeat: state.repeat,
        ),
      ),
    );
    final notifier = ref.read(playbackProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: snapshot.shuffle ? colors.brand : colors.textSecondary,
          ),
          onPressed: notifier.toggleShuffle,
        ),
        IconButton(
          iconSize: 34,
          icon: Icon(Icons.skip_previous_rounded, color: colors.textPrimary),
          onPressed: notifier.previous,
        ),
        IconButton(
          iconSize: 42,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(58),
            backgroundColor: colors.brand.withValues(alpha: 0.88),
            foregroundColor: colors.textPrimary,
            shape: const CircleBorder(),
          ),
          icon: Icon(
            snapshot.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          onPressed: notifier.togglePlay,
        ),
        IconButton(
          iconSize: 34,
          icon: Icon(Icons.skip_next_rounded, color: colors.textPrimary),
          onPressed: notifier.next,
        ),
        IconButton(
          icon: Icon(
            snapshot.repeat == PlayRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: snapshot.repeat != PlayRepeatMode.off
                ? colors.brand
                : colors.textSecondary,
          ),
          onPressed: notifier.cycleRepeat,
        ),
      ],
    );
  }
}

class _FumeImmersiveStage extends ConsumerStatefulWidget {
  const _FumeImmersiveStage({
    required this.track,
    required this.lyrics,
    required this.position,
    required this.duration,
    required this.progress,
    required this.bufferProgress,
    required this.palette,
    required this.compact,
  });

  final Track? track;
  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;
  final Duration duration;
  final double progress;
  final double bufferProgress;
  final _ImmersivePalette palette;
  final bool compact;

  @override
  ConsumerState<_FumeImmersiveStage> createState() =>
      _FumeImmersiveStageState();
}

class _FumeImmersiveStageState extends ConsumerState<_FumeImmersiveStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: widget.lyrics.when(
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

          final currentIndex = _currentLyricIndex(lines, widget.position);
          final nextLine = currentIndex + 1 < lines.length
              ? lines[currentIndex + 1]
              : null;
          final lineStart = currentIndex >= 0
              ? lines[currentIndex].time
              : Duration.zero;
          final lineEnd =
              nextLine?.time ??
              (widget.duration > lineStart
                  ? widget.duration
                  : lineStart + const Duration(seconds: 4));
          final lineProgress = _durationProgress(
            widget.position - lineStart,
            lineEnd - lineStart,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewport = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final blocks = _buildFumeBlocks(
                      lines,
                      viewport,
                      compact: widget.compact,
                    );
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        end: currentIndex < 0 ? 0 : currentIndex.toDouble(),
                      ),
                      duration: const Duration(milliseconds: 560),
                      curve: Curves.easeOutCubic,
                      builder: (context, cameraIndex, _) {
                        return AnimatedBuilder(
                          animation: _ambient,
                          builder: (context, _) {
                            return CustomPaint(
                              isComplex: true,
                              willChange: true,
                              painter: _FumeMapPainter(
                                blocks: blocks,
                                cameraIndex: cameraIndex,
                                currentIndex: currentIndex,
                                lineProgress: lineProgress,
                                phase: _ambient.value,
                                palette: widget.palette,
                                compact: widget.compact,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              Positioned(
                left: widget.compact ? 22 : 80,
                right: widget.compact ? 22 : 80,
                bottom: widget.compact
                    ? MediaQuery.paddingOf(context).bottom + 22
                    : 48,
                child: _TiltStageMeta(
                  track: widget.track,
                  progress: widget.progress,
                  bufferProgress: widget.bufferProgress,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FumeLyricBlock {
  const _FumeLyricBlock({
    required this.lineIndex,
    required this.text,
    required this.center,
    required this.width,
    required this.fontSize,
    required this.rotation,
    required this.hero,
    required this.column,
  });

  final int lineIndex;
  final String text;
  final Offset center;
  final double width;
  final double fontSize;
  final double rotation;
  final bool hero;
  final int column;
}

List<_FumeLyricBlock> _buildFumeBlocks(
  List<LyricLine> lines,
  Size viewport, {
  required bool compact,
}) {
  final paperWidth = compact
      ? math.max(viewport.width * 1.04, 380.0)
      : math.max(viewport.width * 1.34, 820.0).clamp(820.0, 1240.0);
  final columns = compact
      ? 1
      : paperWidth >= 1060
      ? 2
      : 2;
  final gap = compact ? 10.0 : (paperWidth * 0.018).clamp(14.0, 24.0);
  final columnWidth = (paperWidth - gap * (columns - 1)) / columns;
  final left = viewport.width * 0.5 - paperWidth * 0.5;
  var y = math.max(viewport.height * (compact ? 0.38 : 0.45), 190.0);
  final blocks = <_FumeLyricBlock>[];

  for (var i = 0; i < lines.length; i++) {
    final text = lines[i].text.trim();
    if (text.isEmpty) continue;
    final hash = _stableHash('$i:$text');
    final unitA = ((hash & 0xff) / 255.0) - 0.5;
    final unitB = (((hash >> 8) & 0xff) / 255.0) - 0.5;
    final charCount = _graphemes(text.replaceAll(RegExp(r'\s+'), '')).length;
    final hero = i % 9 == 4 || (charCount <= 7 && i % 6 == 2);
    final fontSize = compact
        ? (hero ? 23.0 : 15.5 + (hash % 3))
        : (hero ? 28.0 : 18.0 + (hash % 4));
    final rotation = (unitB * (compact ? 0.026 : 0.034)).clamp(-0.026, 0.026);
    final targetColumn = compact ? 0 : i % columns;
    final serpentineColumn = !compact && ((i ~/ columns).isOdd)
        ? columns - 1 - targetColumn
        : targetColumn;
    final effectiveWidth = columnWidth * (hero ? 0.92 : 0.82);

    final maxLines = hero ? 3 : 2;
    final lineCount = math.min(
      maxLines,
      math.max(1, (charCount / (effectiveWidth / (fontSize * 0.72))).ceil()),
    );
    final blockHeight =
        fontSize * (hero ? 1.10 : 1.18) * lineCount +
        (hero ? (compact ? 14.0 : 18.0) : (compact ? 8.0 : 10.0));
    final x =
        left +
        serpentineColumn * (columnWidth + gap) +
        columnWidth * 0.5 +
        unitA * columnWidth * (compact ? 0.035 : 0.052);

    blocks.add(
      _FumeLyricBlock(
        lineIndex: i,
        text: text,
        center: Offset(x, y + blockHeight * 0.5),
        width: effectiveWidth,
        fontSize: fontSize,
        rotation: rotation,
        hero: hero,
        column: serpentineColumn,
      ),
    );
    if (compact || targetColumn == columns - 1) {
      y +=
          blockHeight +
          (hero ? (compact ? 18.0 : 24.0) : (compact ? 10.0 : 14.0));
    }
  }

  return blocks;
}

class _FumeMapPainter extends CustomPainter {
  const _FumeMapPainter({
    required this.blocks,
    required this.cameraIndex,
    required this.currentIndex,
    required this.lineProgress,
    required this.phase,
    required this.palette,
    required this.compact,
  });

  final List<_FumeLyricBlock> blocks;
  final double cameraIndex;
  final int currentIndex;
  final double lineProgress;
  final double phase;
  final _ImmersivePalette palette;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || blocks.isEmpty) return;
    final camera = _cameraCenter();
    final cameraScale =
        (compact ? 1.0 : 1.03) + math.sin(phase * math.pi * 2) * 0.012;
    final origin = Offset(
      size.width / 2,
      size.height * (compact ? 0.42 : 0.47),
    );

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(cameraScale);
    canvas.translate(-camera.dx, -camera.dy);

    _paintPaper(canvas, size);
    _paintArtifacts(canvas);
    _paintPath(canvas);
    for (final block in blocks) {
      final distance = (block.lineIndex - cameraIndex).abs();
      if (distance > (compact ? 12 : 18)) continue;
      _paintBlock(canvas, block, distance);
    }
    canvas.restore();

    _paintViewVignette(canvas, size);
  }

  Offset _cameraCenter() {
    if (currentIndex < 0) return blocks.first.center;
    final chronological = blocks.toList()
      ..sort((left, right) => left.lineIndex.compareTo(right.lineIndex));
    var lower = chronological.first;
    var upper = chronological.last;
    for (final block in chronological) {
      if (block.lineIndex <= cameraIndex) {
        lower = block;
      }
      if (block.lineIndex >= cameraIndex) {
        upper = block;
        break;
      }
    }
    final span = math.max(upper.lineIndex - lower.lineIndex, 1);
    final t = ((cameraIndex - lower.lineIndex) / span).clamp(0.0, 1.0);
    final focus = Offset(
      ui.lerpDouble(lower.center.dx, upper.center.dx, t)!,
      ui.lerpDouble(lower.center.dy, upper.center.dy, t)!,
    );
    final paperCenterX =
        blocks.map((block) => block.center.dx).reduce((a, b) => a + b) /
        blocks.length;
    _FumeLyricBlock? active;
    for (final block in chronological) {
      if (block.lineIndex == currentIndex) {
        active = block;
        break;
      }
    }
    final dampedFocus = Offset(
      ui.lerpDouble(paperCenterX, focus.dx, compact ? 0.34 : 0.26)!,
      focus.dy,
    );
    if (active == null || active.text.length <= 10) return dampedFocus;
    final printed = _easeOutCubic(lineProgress);
    final drift = (printed - 0.5) * active.width * (compact ? 0.12 : 0.16);
    return Offset(dampedFocus.dx + drift, dampedFocus.dy);
  }

  void _paintPaper(Canvas canvas, Size viewport) {
    final left =
        blocks
            .map((block) => block.center.dx - block.width / 2)
            .reduce(math.min) -
        80;
    final right =
        blocks
            .map((block) => block.center.dx + block.width / 2)
            .reduce(math.max) +
        80;
    final top =
        blocks
            .map((block) => block.center.dy - block.fontSize * 1.8)
            .reduce(math.min) -
        viewport.height * 0.30;
    final bottom =
        blocks
            .map((block) => block.center.dy + block.fontSize * 2.1)
            .reduce(math.max) +
        viewport.height * 0.34;
    final rect = Rect.fromLTRB(left, top, right, bottom);
    final radius = Radius.circular(
      math.min(compact ? 24 : 36, viewport.width * 0.05),
    );
    final paper = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(
      paper,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            Colors.white.withValues(alpha: 0.045),
            palette.glow.withValues(alpha: 0.035),
            Colors.black.withValues(alpha: 0.02),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawRRect(
      paper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.055),
    );
  }

  void _paintArtifacts(Canvas canvas) {
    if (blocks.isEmpty) return;
    final left = blocks
        .map((block) => block.center.dx - block.width / 2)
        .reduce(math.min);
    final right = blocks
        .map((block) => block.center.dx + block.width / 2)
        .reduce(math.max);
    final top = blocks.map((block) => block.center.dy).reduce(math.min);
    final bottom = blocks.map((block) => block.center.dy).reduce(math.max);
    final worldWidth = math.max(right - left, 1.0);
    final worldHeight = math.max(bottom - top, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < (compact ? 22 : 38); i++) {
      final hash = _stableHash('fume-bg-$i-${blocks.length}');
      final x = left + ((hash & 0xff) / 255.0) * worldWidth;
      final y = top + (((hash >> 8) & 0xff) / 255.0) * worldHeight;
      final pulse = 0.5 + math.sin(phase * math.pi * 2 + i * 0.73) * 0.5;
      final radius = 5.0 + (((hash >> 16) & 0xff) / 255.0) * 16.0;
      final alpha = (0.035 + pulse * 0.045) * (compact ? 0.76 : 1.0);
      paint.color = (i.isEven ? palette.glow : Colors.white).withValues(
        alpha: alpha,
      );
      final center = Offset(x, y);
      switch (i % 4) {
        case 0:
          canvas.drawCircle(center, radius, paint);
        case 1:
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate((((hash >> 12) & 0xff) / 255.0 - 0.5) * 0.8);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * 1.6,
              height: radius * 1.6,
            ),
            paint,
          );
          canvas.restore();
        case 2:
          canvas.drawLine(
            center.translate(-radius, 0),
            center.translate(radius, 0),
            paint,
          );
          canvas.drawLine(
            center.translate(0, -radius),
            center.translate(0, radius),
            paint,
          );
        default:
          canvas.drawCircle(
            center,
            1.4 + pulse * 1.6,
            paint..style = PaintingStyle.fill,
          );
          paint.style = PaintingStyle.stroke;
      }
    }
  }

  void _paintPath(Canvas canvas) {
    if (blocks.length < 2) return;
    final chronological = blocks.toList()
      ..sort((left, right) => left.lineIndex.compareTo(right.lineIndex));
    final path = Path()
      ..moveTo(chronological.first.center.dx, chronological.first.center.dy);
    for (var i = 1; i < chronological.length; i++) {
      final previous = chronological[i - 1].center;
      final current = chronological[i].center;
      final control = Offset(
        (previous.dx + current.dx) / 2,
        previous.dy + (current.dy - previous.dy) * 0.42,
      );
      path.quadraticBezierTo(control.dx, control.dy, current.dx, current.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.glow.withValues(alpha: 0.08),
    );
  }

  void _paintBlock(Canvas canvas, _FumeLyricBlock block, double distance) {
    final active = block.lineIndex == currentIndex;
    final passed = block.lineIndex < cameraIndex;
    final baseOpacity = active
        ? 1.0
        : passed
        ? (0.26 - distance * 0.018).clamp(0.08, 0.26)
        : (0.32 - distance * 0.022).clamp(0.08, 0.32);
    final entered = active ? _easeOutCubic(lineProgress) : 1.0;
    final visibleText = active
        ? _visiblePrefix(block.text, entered)
        : block.text;
    final color = active
        ? Colors.white.withValues(alpha: 0.96)
        : passed
        ? Colors.white.withValues(alpha: baseOpacity)
        : Colors.white.withValues(alpha: baseOpacity * 0.82);
    final style = TextStyle(
      color: color,
      fontSize: block.fontSize * (active ? 1.18 : 1.0),
      height: 1.16,
      fontWeight: active || block.hero ? FontWeight.w800 : FontWeight.w600,
      letterSpacing: 0,
      shadows: active
          ? [
              Shadow(
                color: palette.glow.withValues(alpha: 0.36),
                blurRadius: 28,
              ),
            ]
          : null,
    );
    final painter = TextPainter(
      text: TextSpan(text: visibleText, style: style),
      textAlign: block.hero ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: block.hero ? 3 : 2,
      ellipsis: '',
    )..layout(maxWidth: block.width);
    final topLeft = Offset(
      block.center.dx - painter.width / 2,
      block.center.dy - painter.height / 2,
    );

    canvas.save();
    canvas.translate(block.center.dx, block.center.dy);
    canvas.rotate(block.rotation);
    if (active) {
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: painter.width + 54,
        height: painter.height + 34,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        Paint()
          ..color = palette.glow.withValues(alpha: 0.075)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawLine(
        Offset(-painter.width / 2, painter.height / 2 + 12),
        Offset(
          -painter.width / 2 + painter.width * entered,
          painter.height / 2 + 12,
        ),
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = palette.glow.withValues(alpha: 0.46),
      );
    }
    painter.paint(
      canvas,
      Offset(topLeft.dx - block.center.dx, topLeft.dy - block.center.dy),
    );
    canvas.restore();
  }

  String _visiblePrefix(String text, double progress) {
    final chars = _graphemes(text);
    if (chars.isEmpty) return text;
    final count = (chars.length * progress).ceil().clamp(1, chars.length);
    return chars.take(count).join();
  }

  void _paintViewVignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          math.max(size.width, size.height) * 0.72,
          [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
          const [0.52, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _FumeMapPainter oldDelegate) {
    return blocks != oldDelegate.blocks ||
        cameraIndex != oldDelegate.cameraIndex ||
        currentIndex != oldDelegate.currentIndex ||
        lineProgress != oldDelegate.lineProgress ||
        phase != oldDelegate.phase ||
        palette != oldDelegate.palette ||
        compact != oldDelegate.compact;
  }
}

class _PartitaImmersiveStage extends ConsumerStatefulWidget {
  const _PartitaImmersiveStage({
    required this.track,
    required this.lyrics,
    required this.position,
    required this.duration,
    required this.progress,
    required this.bufferProgress,
    required this.palette,
    required this.compact,
  });

  final Track? track;
  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;
  final Duration duration;
  final double progress;
  final double bufferProgress;
  final _ImmersivePalette palette;
  final bool compact;

  @override
  ConsumerState<_PartitaImmersiveStage> createState() =>
      _PartitaImmersiveStageState();
}

class _PartitaImmersiveStageState extends ConsumerState<_PartitaImmersiveStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: widget.lyrics.when(
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

          final currentIndex = _currentLyricIndex(lines, widget.position);
          final activeIndex = currentIndex < 0 ? 0 : currentIndex;
          final activeLine = lines[activeIndex];
          final previousLine = activeIndex > 0 ? lines[activeIndex - 1] : null;
          final nextLine = activeIndex + 1 < lines.length
              ? lines[activeIndex + 1]
              : null;
          final lineStart = currentIndex >= 0 ? activeLine.time : Duration.zero;
          final lineEnd =
              nextLine?.time ??
              (widget.duration > lineStart
                  ? widget.duration
                  : lineStart + const Duration(seconds: 4));
          final lineProgress = currentIndex < 0
              ? 1.0
              : _durationProgress(
                  widget.position - lineStart,
                  lineEnd - lineStart,
                );

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) {
                    return CustomPaint(
                      isComplex: true,
                      willChange: true,
                      painter: _PartitaStagePainter(
                        activeText: activeLine.text.trim(),
                        previousText: previousLine?.text.trim(),
                        nextText: nextLine?.text.trim(),
                        lineProgress: lineProgress,
                        playbackProgress: widget.progress,
                        bufferProgress: widget.bufferProgress,
                        phase: _ambient.value,
                        palette: widget.palette,
                        compact: widget.compact,
                        seed: _stableHash('$activeIndex:${activeLine.text}'),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: widget.compact ? 22 : 80,
                right: widget.compact ? 22 : 80,
                bottom: widget.compact
                    ? MediaQuery.paddingOf(context).bottom + 22
                    : 48,
                child: _TiltStageMeta(
                  track: widget.track,
                  progress: widget.progress,
                  bufferProgress: widget.bufferProgress,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PartitaChunk {
  const _PartitaChunk({
    required this.text,
    required this.row,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  final String text;
  final int row;
  final double x;
  final double y;
  final double scale;
  final double rotation;
}

List<_PartitaChunk> _buildPartitaChunks(
  String text,
  Size size, {
  required bool compact,
  required int seed,
}) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return const <_PartitaChunk>[];
  final words = normalized.contains(' ')
      ? normalized.split(' ').where((word) => word.isNotEmpty).toList()
      : _graphemes(normalized);
  final totalGraphemes = _graphemes(normalized.replaceAll(' ', '')).length;
  final targetRows = math.min(
    words.length,
    totalGraphemes <= 6
        ? 1
        : totalGraphemes <= 12
        ? 2
        : totalGraphemes <= 20
        ? 3
        : compact
        ? 4
        : 5,
  );
  final chunks = <String>[];
  var remainingWords = words.length;
  var remainingRows = math.max(targetRows, 1);
  var cursor = 0;
  var localSeed = seed;
  double random() {
    final value = math.sin(localSeed++ * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  for (var row = 0; row < targetRows; row++) {
    final last = row == targetRows - 1;
    final average = remainingWords / remainingRows;
    var take = last
        ? remainingWords
        : math.max(1, (average + (random() - 0.5) * average).round());
    take = math.min(take, remainingWords - (remainingRows - 1));
    chunks.add(
      words
          .sublist(cursor, cursor + take)
          .join(normalized.contains(' ') ? ' ' : ''),
    );
    cursor += take;
    remainingWords -= take;
    remainingRows -= 1;
  }

  final width = size.width;
  final stepX = compact ? width * 0.105 : width * 0.085;
  final stepY = compact ? 54.0 : 68.0;
  final startY = -(chunks.length - 1) * stepY * 0.5;
  return [
    for (var row = 0; row < chunks.length; row++)
      _PartitaChunk(
        text: chunks[row],
        row: row,
        x:
            (row - (chunks.length - 1) / 2) *
            stepX *
            (row.isEven ? -0.72 : 0.82),
        y: startY + row * stepY,
        scale: 1.0 + (random() - 0.5) * (compact ? 0.08 : 0.13),
        rotation: (row.isEven ? -1 : 1) * (0.012 + random() * 0.025),
      ),
  ];
}

class _PartitaStagePainter extends CustomPainter {
  const _PartitaStagePainter({
    required this.activeText,
    required this.previousText,
    required this.nextText,
    required this.lineProgress,
    required this.playbackProgress,
    required this.bufferProgress,
    required this.phase,
    required this.palette,
    required this.compact,
    required this.seed,
  });

  final String activeText;
  final String? previousText;
  final String? nextText;
  final double lineProgress;
  final double playbackProgress;
  final double bufferProgress;
  final double phase;
  final _ImmersivePalette palette;
  final bool compact;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(
      size.width / 2,
      size.height * (compact ? 0.43 : 0.47),
    );
    _paintRails(canvas, size, center);
    _paintBeatLadder(canvas, size, center);
    _paintAudioCurve(canvas, size);
    _paintGhostLine(
      canvas,
      previousText,
      center.translate(0, compact ? -170 : -210),
      -1,
    );
    _paintGhostLine(
      canvas,
      nextText,
      center.translate(0, compact ? 168 : 210),
      1,
    );

    final chunks = _buildPartitaChunks(
      activeText.isEmpty ? '纯音乐' : activeText,
      size,
      compact: compact,
      seed: seed,
    );
    if (chunks.isEmpty) return;

    for (final chunk in chunks) {
      final rowDelay = chunk.row * (compact ? 0.085 : 0.075);
      final rowProgress = ((lineProgress - rowDelay) / 0.52).clamp(0.0, 1.0);
      final entered = _easeOutCubic(rowProgress);
      final active =
          lineProgress >= rowDelay && lineProgress <= rowDelay + 0.58;
      _paintChunk(canvas, chunk, center, entered, active, chunks.length);
    }
    _paintStepLabel(canvas, size, chunks.length);
  }

  void _paintRails(Canvas canvas, Size size, Offset center) {
    final railPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = palette.glow.withValues(alpha: 0.10);
    final count = compact ? 7 : 9;
    for (var i = 0; i < count; i++) {
      final y = center.dy + (i - (count - 1) / 2) * (compact ? 48 : 58);
      final inset = size.width * (compact ? 0.16 : 0.20) + i * 3;
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y),
        railPaint,
      );
      final sweep = (phase + i * 0.11) % 1.0;
      final startX = ui.lerpDouble(inset, size.width - inset, sweep)!;
      canvas.drawLine(
        Offset(startX - 38, y),
        Offset(startX + 18, y),
        pulsePaint,
      );
    }
  }

  void _paintBeatLadder(Canvas canvas, Size size, Offset center) {
    final left = size.width * (compact ? 0.105 : 0.145);
    final top = center.dy - (compact ? 170 : 230);
    final step = compact ? 28.0 : 34.0;
    final count = compact ? 10 : 13;
    final activeIndex = (lineProgress * count).floor().clamp(0, count - 1);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.11);
    canvas.drawLine(
      Offset(left, top - 10),
      Offset(left, top + step * (count - 1) + 10),
      linePaint,
    );
    for (var i = 0; i < count; i++) {
      final y = top + i * step;
      final active = i <= activeIndex;
      final pulse = math.sin(phase * math.pi * 2 + i * 0.64) * 0.5 + 0.5;
      final radius = active ? 3.4 + pulse * 1.4 : 2.1;
      canvas.drawCircle(
        Offset(left, y),
        radius,
        Paint()
          ..color = (active ? palette.glow : Colors.white).withValues(
            alpha: active ? 0.48 : 0.16,
          ),
      );
      canvas.drawLine(
        Offset(left + 10, y),
        Offset(left + (active ? 42 : 26), y),
        Paint()
          ..strokeWidth = active ? 1.6 : 1.0
          ..strokeCap = StrokeCap.round
          ..color = (active ? palette.glow : Colors.white).withValues(
            alpha: active ? 0.38 : 0.12,
          ),
      );
    }
  }

  void _paintAudioCurve(Canvas canvas, Size size) {
    final height = compact ? 54.0 : 66.0;
    final left = size.width * (compact ? 0.13 : 0.21);
    final right = size.width * (compact ? 0.87 : 0.79);
    final bottom = size.height - (compact ? 92.0 : 108.0);
    final width = right - left;
    if (width <= 0) return;
    final baseY = bottom;
    final points = <Offset>[];
    const count = 36;
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final envelope = math.sin(t * math.pi);
      final wave =
          math.sin(i * 0.44 + phase * math.pi * 2.5) * 0.5 +
          math.sin(i * 0.18 + playbackProgress * math.pi * 8) * 0.5;
      final amp = (0.14 + wave * 0.15 + lineProgress * 0.10) * envelope;
      points.add(Offset(left + width * t, baseY - height * amp));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    final fillPath = Path.from(path)
      ..lineTo(right, baseY + height * 0.22)
      ..lineTo(left, baseY + height * 0.22)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(left, baseY - height),
          Offset(left, baseY + height * 0.24),
          [palette.glow.withValues(alpha: 0.16), Colors.transparent],
        ),
    );
    canvas.drawLine(
      Offset(left, baseY + 12),
      Offset(left + width * bufferProgress.clamp(0.0, 1.0), baseY + 12),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.drawLine(
      Offset(left, baseY + 12),
      Offset(left + width * playbackProgress.clamp(0.0, 1.0), baseY + 12),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = palette.glow.withValues(alpha: 0.42),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = palette.glow.withValues(alpha: 0.52),
    );
  }

  void _paintGhostLine(
    Canvas canvas,
    String? text,
    Offset center,
    int direction,
  ) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return;
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.12),
      fontSize: compact ? 16 : 19,
      height: 1.16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: compact ? 260 : 560);
    final drift = math.sin(phase * math.pi * 2 + direction) * 10;
    painter.paint(
      canvas,
      Offset(
        center.dx - painter.width / 2 + drift,
        center.dy - painter.height / 2,
      ),
    );
  }

  void _paintChunk(
    Canvas canvas,
    _PartitaChunk chunk,
    Offset center,
    double entered,
    bool active,
    int totalRows,
  ) {
    final baseFont = compact ? 34.0 : 50.0;
    final fontSize = baseFont * chunk.scale * (active ? 1.04 : 0.98);
    final baseStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.22 + entered * 0.42),
      fontSize: fontSize,
      height: 1.10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      shadows: [
        Shadow(
          color: palette.glow.withValues(alpha: 0.16 + entered * 0.20),
          blurRadius: active ? 30 : 18,
        ),
      ],
    );
    final painter = TextPainter(
      text: TextSpan(text: chunk.text, style: baseStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: compact ? 2 : 1,
      ellipsis: '',
    )..layout(maxWidth: compact ? 310 : 720);
    final position = center.translate(
      chunk.x * (0.48 + entered * 0.52),
      chunk.y + (1 - entered) * 34,
    );

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(chunk.rotation * entered);
    final guideWidth = math.max(painter.width + 28, compact ? 120.0 : 180.0);
    final guideLeft = chunk.row.isEven;
    final bracketPaint = Paint()
      ..strokeWidth = active ? 1.8 : 1.1
      ..strokeCap = StrokeCap.round
      ..color = palette.glow.withValues(alpha: active ? 0.42 : 0.20);
    final bracketX = guideLeft ? -guideWidth / 2 - 12 : guideWidth / 2 + 12;
    canvas.drawLine(
      Offset(bracketX, -painter.height * 0.52),
      Offset(bracketX, painter.height * 0.52),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(bracketX, painter.height * 0.52),
      Offset(
        bracketX + (guideLeft ? 24 : -24) * entered,
        painter.height * 0.52,
      ),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(-guideWidth / 2, painter.height / 2 + 12),
      Offset(-guideWidth / 2 + guideWidth * entered, painter.height / 2 + 12),
      Paint()
        ..strokeWidth = active ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round
        ..color = palette.glow.withValues(alpha: active ? 0.46 : 0.20),
    );
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));

    final sweep = (lineProgress * 1.18 - chunk.row * 0.08).clamp(0.0, 1.0);
    if (sweep > 0) {
      final overlayStyle = baseStyle.copyWith(
        color: Colors.white.withValues(alpha: active ? 0.96 : 0.70),
        shadows: [
          Shadow(
            color: palette.glow.withValues(alpha: active ? 0.58 : 0.32),
            blurRadius: active ? 34 : 22,
          ),
        ],
      );
      final overlayPainter = TextPainter(
        text: TextSpan(text: chunk.text, style: overlayStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: compact ? 2 : 1,
        ellipsis: '',
      )..layout(maxWidth: compact ? 310 : 720);
      final rect = Rect.fromLTWH(
        -overlayPainter.width / 2 - 10,
        -overlayPainter.height / 2 - 8,
        (overlayPainter.width + 20) * sweep,
        overlayPainter.height + 20,
      );
      canvas.save();
      canvas.clipRect(rect);
      overlayPainter.paint(
        canvas,
        Offset(-overlayPainter.width / 2, -overlayPainter.height / 2),
      );
      canvas.restore();
    }
    final tickProgress = ((lineProgress * totalRows) - chunk.row).clamp(
      0.0,
      1.0,
    );
    canvas.drawCircle(
      Offset(
        guideLeft ? -guideWidth / 2 - 12 : guideWidth / 2 + 12,
        painter.height / 2 + 12,
      ),
      2.0 + _easeOutCubic(tickProgress) * 2.2,
      Paint()
        ..color = palette.glow.withValues(alpha: 0.18 + tickProgress * 0.34),
    );
    canvas.restore();
  }

  void _paintStepLabel(Canvas canvas, Size size, int rows) {
    final label = 'PARTITA  ${rows.toString().padLeft(2, '0')}';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.18),
          fontSize: compact ? 11 : 12,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        size.width - painter.width - (compact ? 22 : 42),
        compact ? 116 : 126,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PartitaStagePainter oldDelegate) {
    return activeText != oldDelegate.activeText ||
        previousText != oldDelegate.previousText ||
        nextText != oldDelegate.nextText ||
        lineProgress != oldDelegate.lineProgress ||
        playbackProgress != oldDelegate.playbackProgress ||
        bufferProgress != oldDelegate.bufferProgress ||
        phase != oldDelegate.phase ||
        palette != oldDelegate.palette ||
        compact != oldDelegate.compact ||
        seed != oldDelegate.seed;
  }
}

class _TiltImmersiveStage extends ConsumerStatefulWidget {
  const _TiltImmersiveStage({
    required this.track,
    required this.lyrics,
    required this.position,
    required this.duration,
    required this.progress,
    required this.bufferProgress,
    required this.palette,
    required this.compact,
  });

  final Track? track;
  final AsyncValue<List<LyricLine>> lyrics;
  final Duration position;
  final Duration duration;
  final double progress;
  final double bufferProgress;
  final _ImmersivePalette palette;
  final bool compact;

  @override
  ConsumerState<_TiltImmersiveStage> createState() =>
      _TiltImmersiveStageState();
}

class _TiltImmersiveStageState extends ConsumerState<_TiltImmersiveStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = BiliColors.dark;
    return SizedBox.expand(
      child: widget.lyrics.when(
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

          final currentIndex = _currentLyricIndex(lines, widget.position);
          final activeLine = currentIndex >= 0 ? lines[currentIndex] : null;
          final nextLine = currentIndex + 1 < lines.length
              ? lines[currentIndex + 1]
              : null;
          final previousLine = currentIndex > 0
              ? lines[currentIndex - 1]
              : null;
          final lineStart = activeLine?.time ?? Duration.zero;
          final lineEnd =
              nextLine?.time ??
              (widget.duration > lineStart
                  ? widget.duration
                  : lineStart + const Duration(seconds: 4));
          final lineProgress = _durationProgress(
            widget.position - lineStart,
            lineEnd - lineStart,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _TiltBackdropPainter(
                        lines: lines,
                        currentIndex: currentIndex,
                        phase: _ambient.value,
                        color: widget.palette.glow,
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) {
                    final drift = math.sin(_ambient.value * math.pi * 2) * 7;
                    return Transform.translate(
                      offset: Offset(0, drift),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.compact ? 22 : 72,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 520),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.96,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: activeLine == null
                                ? Text(
                                    'Waiting for music',
                                    key: const ValueKey('tilt-empty'),
                                    style: AppTypography.titleL.copyWith(
                                      color: colors.textSecondary.withValues(
                                        alpha: 0.46,
                                      ),
                                    ),
                                  )
                                : _TiltPhrase(
                                    key: ValueKey(
                                      'tilt-$currentIndex-${activeLine.text}',
                                    ),
                                    text: activeLine.text,
                                    nextText: nextLine?.text,
                                    previousText: previousLine?.text,
                                    color: colors.textPrimary,
                                    glowColor: widget.palette.glow,
                                    lineProgress: lineProgress,
                                    phase: _ambient.value,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: widget.compact ? 22 : 80,
                right: widget.compact ? 22 : 80,
                bottom: widget.compact
                    ? MediaQuery.paddingOf(context).bottom + 22
                    : 48,
                child: _TiltStageMeta(
                  track: widget.track,
                  progress: widget.progress,
                  bufferProgress: widget.bufferProgress,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TiltPhrase extends StatefulWidget {
  const _TiltPhrase({
    super.key,
    required this.text,
    required this.nextText,
    required this.previousText,
    required this.color,
    required this.glowColor,
    required this.lineProgress,
    required this.phase,
  });

  final String text;
  final String? nextText;
  final String? previousText;
  final Color color;
  final Color glowColor;
  final double lineProgress;
  final double phase;

  @override
  State<_TiltPhrase> createState() => _TiltPhraseState();
}

class _TiltPhraseState extends State<_TiltPhrase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _TiltPhrase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segments = _splitTiltSegments(widget.text);
        final baseSize = math
            .min(
              constraints.maxWidth * 0.085,
              constraints.maxHeight * (segments.length <= 1 ? 0.20 : 0.15),
            )
            .clamp(42.0, 92.0);
        final tiltIndex = _stableHash(widget.text) % segments.length;

        return AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((widget.previousText ?? '').isNotEmpty)
                  _TiltGhostLine(
                    text: widget.previousText!,
                    opacity: 0.14,
                    color: widget.color,
                  ),
                for (var i = 0; i < segments.length; i++)
                  _TiltSegmentLine(
                    text: segments[i],
                    segmentIndex: i,
                    reveal: _reveal.value,
                    phase: widget.phase,
                    lineProgress: widget.lineProgress,
                    fontSize: baseSize,
                    color: widget.color,
                    glowColor: widget.glowColor,
                    tilt: i == tiltIndex,
                  ),
                if ((widget.nextText ?? '').isNotEmpty)
                  _TiltGhostLine(
                    text: widget.nextText!,
                    opacity: 0.18,
                    color: widget.color,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TiltSegmentLine extends StatelessWidget {
  const _TiltSegmentLine({
    required this.text,
    required this.segmentIndex,
    required this.reveal,
    required this.phase,
    required this.lineProgress,
    required this.fontSize,
    required this.color,
    required this.glowColor,
    required this.tilt,
  });

  final String text;
  final int segmentIndex;
  final double reveal;
  final double phase;
  final double lineProgress;
  final double fontSize;
  final Color color;
  final Color glowColor;
  final bool tilt;

  @override
  Widget build(BuildContext context) {
    final chars = _graphemes(text);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tilt ? 2 : 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = fontSize * (tilt ? 1.62 : 1.34) + 36;
          return SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: CustomPaint(
              isComplex: true,
              willChange: true,
              painter: _TiltSegmentPainter(
                chars: chars,
                segmentIndex: segmentIndex,
                reveal: reveal,
                phase: phase,
                lineProgress: lineProgress,
                fontSize: fontSize,
                color: color,
                glowColor: glowColor,
                tilt: tilt,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TiltSegmentPainter extends CustomPainter {
  const _TiltSegmentPainter({
    required this.chars,
    required this.segmentIndex,
    required this.reveal,
    required this.phase,
    required this.lineProgress,
    required this.fontSize,
    required this.color,
    required this.glowColor,
    required this.tilt,
  });

  final List<String> chars;
  final int segmentIndex;
  final double reveal;
  final double phase;
  final double lineProgress;
  final double fontSize;
  final Color color;
  final Color glowColor;
  final bool tilt;

  @override
  void paint(Canvas canvas, Size size) {
    if (chars.isEmpty || size.isEmpty) return;

    final glyphFontSize = fontSize * (tilt ? 1.05 : 0.92);
    final textStyle = TextStyle(
      fontSize: glyphFontSize,
      height: 1.08,
      fontStyle: tilt ? FontStyle.italic : FontStyle.normal,
      fontWeight: tilt ? FontWeight.w300 : FontWeight.w700,
    );
    final glyphs = <_TiltGlyphLayout>[];
    var visualIndex = 0;
    var totalWidth = 0.0;

    for (final char in chars) {
      final isSpace = char.trim().isEmpty;
      final charIndex = visualIndex;
      if (!isSpace) visualIndex += 1;
      final width = isSpace
          ? glyphFontSize * 0.32
          : _measureGlyph(char, textStyle).width + 3.2;
      glyphs.add(
        _TiltGlyphLayout(
          char: char,
          charIndex: charIndex,
          width: width,
          isSpace: isSpace,
        ),
      );
      totalWidth += width;
    }

    final scaleToFit = totalWidth > size.width && totalWidth > 0
        ? (size.width / totalWidth).clamp(0.62, 1.0)
        : 1.0;
    final originX = (size.width - totalWidth * scaleToFit) / 2;
    final baselineY = size.height * 0.52;
    var cursorX = 0.0;

    canvas.save();
    canvas.translate(originX, 0);
    canvas.scale(scaleToFit);

    for (final glyph in glyphs) {
      if (!glyph.isSpace) {
        final start = segmentIndex * 0.10 + glyph.charIndex * 0.018;
        final entered = _easeOutCubic(
          ((reveal - start) / 0.36).clamp(0.0, 1.0),
        );
        final wave =
            math.sin(phase * math.pi * 2 + glyph.charIndex * 0.72) * 0.5 + 0.5;
        final pulse = math.sin(lineProgress * math.pi).clamp(0.0, 1.0);
        final stagger = tilt
            ? (glyph.charIndex.isEven ? -1.0 : 1.0) * fontSize * 0.12
            : 0.0;
        final y = (1 - entered) * 18 + stagger * entered;
        final glyphScale = 0.94 + entered * (0.06 + wave * pulse * 0.035);
        final alpha = entered.clamp(0.0, 1.0);
        final painter = _buildGlyphPainter(
          glyph.char,
          textStyle.copyWith(
            color: color.withValues(alpha: alpha),
            shadows: [
              Shadow(
                color: glowColor.withValues(
                  alpha: alpha * (tilt ? 0.40 : 0.24),
                ),
                blurRadius: tilt ? 24 : 16,
              ),
            ],
          ),
        );
        final x = cursorX + (glyph.width - painter.width) / 2;
        final top = baselineY - painter.height / 2 + y;

        canvas.save();
        canvas.translate(x + painter.width / 2, top + painter.height / 2);
        canvas.scale(glyphScale);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
      cursorX += glyph.width;
    }

    canvas.restore();
  }

  Size _measureGlyph(String char, TextStyle style) {
    final painter = _buildGlyphPainter(char, style);
    return Size(painter.width, painter.height);
  }

  TextPainter _buildGlyphPainter(String char, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: char, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _TiltSegmentPainter oldDelegate) {
    return chars != oldDelegate.chars ||
        segmentIndex != oldDelegate.segmentIndex ||
        reveal != oldDelegate.reveal ||
        phase != oldDelegate.phase ||
        lineProgress != oldDelegate.lineProgress ||
        fontSize != oldDelegate.fontSize ||
        color != oldDelegate.color ||
        glowColor != oldDelegate.glowColor ||
        tilt != oldDelegate.tilt;
  }
}

class _TiltGlyphLayout {
  const _TiltGlyphLayout({
    required this.char,
    required this.charIndex,
    required this.width,
    required this.isSpace,
  });

  final String char;
  final int charIndex;
  final double width;
  final bool isSpace;
}

class _TiltGhostLine extends StatelessWidget {
  const _TiltGhostLine({
    required this.text,
    required this.opacity,
    required this.color,
  });

  final String text;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTypography.titleM.copyWith(
          color: color.withValues(alpha: opacity),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TiltStageMeta extends ConsumerWidget {
  const _TiltStageMeta({
    required this.track,
    required this.progress,
    required this.bufferProgress,
  });

  final Track? track;
  final double progress;
  final double bufferProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const colors = BiliColors.dark;
    final position = ref.watch(
      playbackProvider.select((state) => state.position),
    );
    final duration = ref.watch(
      playbackProvider.select((state) => state.duration),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track?.title ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleS.copyWith(
                  color: colors.textPrimary.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                track?.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary.withValues(alpha: 0.70),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: BiliProgressBar(
                  value: progress,
                  bufferValue: bufferProgress,
                  onChangeEnd: ref.read(playbackProvider.notifier).seekFraction,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s5),
        Text(
          '${Format.duration(position)} / ${Format.duration(duration)}',
          style: AppTypography.caption.copyWith(
            color: colors.textTertiary.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _TiltBackdropPainter extends CustomPainter {
  const _TiltBackdropPainter({
    required this.lines,
    required this.currentIndex,
    required this.phase,
    required this.color,
  });

  final List<LyricLine> lines;
  final int currentIndex;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || lines.isEmpty || currentIndex < 0) return;
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final paintColor = color.withValues(alpha: 0.055);
    final offsets = <int>[-5, -3, -1, 2, 4, 6];

    for (var i = 0; i < offsets.length; i++) {
      final lineIndex = currentIndex + offsets[i];
      if (lineIndex < 0 || lineIndex >= lines.length) continue;
      final text = lines[lineIndex].text.trim();
      if (text.isEmpty) continue;
      final xWave = math.sin(phase * math.pi * 2 + i * 1.7);
      final yWave = math.cos(phase * math.pi * 2 + i * 1.1);
      final fontSize = size.width * (i.isEven ? 0.052 : 0.043);
      painter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: paintColor,
          fontSize: fontSize.clamp(34.0, 72.0),
          fontWeight: FontWeight.w800,
        ),
      );
      painter.layout(maxWidth: size.width * 0.85);
      final dx = size.width * (0.08 + (i % 3) * 0.26) + xWave * 26;
      final dy = size.height * (0.12 + i * 0.13) + yWave * 18;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate((i.isEven ? -1 : 1) * 0.045);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TiltBackdropPainter oldDelegate) {
    return lines != oldDelegate.lines ||
        currentIndex != oldDelegate.currentIndex ||
        phase != oldDelegate.phase ||
        color != oldDelegate.color;
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
    required this.mode,
    required this.compact,
    required this.onClose,
    required this.onToggleTheme,
  });

  final bool visible;
  final _ImmersiveThemeMode mode;
  final bool compact;
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
      height: compact ? 78 + MediaQuery.paddingOf(context).top : 88,
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
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 24,
                  compact ? MediaQuery.paddingOf(context).top + 8 : 14,
                  compact ? 14 : 24,
                  compact ? 10 : 18,
                ),
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
                          icon: mode.icon,
                          tooltip: '切换沉浸主题',
                          active: mode != _ImmersiveThemeMode.standard,
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
