import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

void showAppToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  Color? accentColor,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  AppToast.show(
    context,
    message: message,
    icon: icon,
    accentColor: accentColor,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

class AppToast {
  AppToast._();

  static OverlayEntry? _currentEntry;

  static void dismissCurrent() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? accentColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismissCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _AppToastHost(
        message: message,
        icon: icon,
        accentColor: accentColor ?? overlayContext.colors.brand,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          entry.remove();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _AppToastHost extends StatefulWidget {
  const _AppToastHost({
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final IconData? icon;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<_AppToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.fast,
      reverseDuration: AppDuration.fast,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    try {
      await _controller.reverse();
    } finally {
      if (mounted) {
        widget.onDismissed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= AppLayout.desktopBreakpoint;
    final bottomOffset =
        media.padding.bottom +
        (isDesktop
            ? AppLayout.playBarHeight + AppSpacing.s3
            : AppLayout.miniPlayerHeight +
                  AppLayout.bottomNavHeight +
                  AppSpacing.s4);
    final horizontalPadding = isDesktop ? AppSpacing.s6 : AppSpacing.s4;
    final maxWidth = isDesktop
        ? 420.0
        : math.max(240.0, media.size.width - horizontalPadding * 2);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: bottomOffset,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _ToastBody(
                      message: widget.message,
                      icon: widget.icon,
                      accentColor: widget.accentColor,
                      actionLabel: widget.actionLabel,
                      onAction: widget.onAction == null
                          ? null
                          : () {
                              widget.onAction?.call();
                              _close();
                            },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final IconData? icon;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.bgSurface.withValues(alpha: 0.96),
      elevation: 0,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: colors.textPrimary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: AppSpacing.s3),
            ],
            Flexible(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.s3),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: colors.brand,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: AppSpacing.s1,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.body.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
