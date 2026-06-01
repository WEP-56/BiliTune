import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../state/providers.dart';

const _biliWebLoginUrl = 'https://passport.bilibili.com/login';
const _biliCookieUrls = <String>[
  'https://www.bilibili.com/',
  'https://passport.bilibili.com/',
];

const _requiredCookieNames = <String>{
  'SESSDATA',
  'bili_jct',
  'DedeUserID',
  'DedeUserID__ckMd5',
  'ac_time_value',
};

class WebLoginDialog extends ConsumerStatefulWidget {
  const WebLoginDialog({super.key});

  @override
  ConsumerState<WebLoginDialog> createState() => _WebLoginDialogState();
}

class _WebLoginDialogState extends ConsumerState<WebLoginDialog> {
  final _cookieManager = CookieManager.instance();
  InAppWebViewController? _controller;
  bool _syncing = false;
  bool _loginCompleted = false;
  int _progress = 0;
  String _message = '正在打开 Bilibili 登录页';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = viewport.width >= AppLayout.desktopBreakpoint
        ? 760.0
        : viewport.width * 0.94;
    final dialogHeight = viewport.height * 0.88;

    return Dialog(
      backgroundColor: colors.bgElevated,
      insetPadding: const EdgeInsets.all(AppSpacing.s3),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight.clamp(560.0, 860.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '网页登录',
                    style: AppTypography.titleM.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '刷新',
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => _controller?.reload(),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                '在页面内使用短信验证码或账号密码登录，完成后会自动同步登录态。',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: Stack(
                    children: [
                      InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(_biliWebLoginUrl),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          thirdPartyCookiesEnabled: true,
                          useShouldOverrideUrlLoading: true,
                          transparentBackground: false,
                          supportZoom: false,
                        ),
                        onWebViewCreated: (controller) {
                          _controller = controller;
                        },
                        onProgressChanged: (_, progress) {
                          if (!mounted) return;
                          setState(() => _progress = progress);
                        },
                        onLoadStart: (_, _) {
                          if (!mounted || _loginCompleted) return;
                          setState(() => _message = '正在加载登录页');
                        },
                        onLoadStop: (_, url) async {
                          await _syncCookiesIfReady(url);
                        },
                        onUpdateVisitedHistory:
                            (_, url, androidIsReload) async {
                              await _syncCookiesIfReady(url);
                            },
                        shouldOverrideUrlLoading:
                            (controller, navigationAction) async {
                              return NavigationActionPolicy.ALLOW;
                            },
                        onReceivedError: (_, request, error) {
                          if (!mounted || request.isForMainFrame != true) {
                            return;
                          }
                          setState(
                            () => _message = error.description.isEmpty
                                ? '登录页加载失败'
                                : error.description,
                          );
                        },
                      ),
                      if (_progress > 0 && _progress < 100)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: LinearProgressIndicator(
                            value: _progress / 100,
                            minHeight: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                auth.errorMessage ?? _message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: auth.errorMessage == null
                      ? colors.textSecondary
                      : colors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _syncing
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_syncing ? '同步中' : '检测登录态'),
                      onPressed: _syncing
                          ? null
                          : () async => _syncCookiesIfReady(
                              await _controller?.getUrl(),
                              force: true,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncCookiesIfReady(WebUri? url, {bool force = false}) async {
    if (_syncing || _loginCompleted) return;
    final cookieHeader = await _readBiliCookieHeader(url);
    if (cookieHeader == null) {
      if (force && mounted) {
        setState(() => _message = '还没有检测到有效登录态，请完成网页登录后再试');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _syncing = true;
      _message = '已检测到登录态，正在同步账号';
    });

    await ref.read(authProvider.notifier).saveManualCookie(cookieHeader);
    if (!mounted) return;

    final signedIn = ref.read(authProvider).isSignedIn;
    if (signedIn) {
      _loginCompleted = true;
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _syncing = false;
      _message = '登录态同步失败，请重新登录或改用扫码登录';
    });
  }

  Future<String?> _readBiliCookieHeader(WebUri? currentUrl) async {
    final cookiesByName = <String, String>{};
    final targets = <WebUri>{
      for (final url in _biliCookieUrls) WebUri(url),
      if (currentUrl != null && currentUrl.scheme.startsWith('http'))
        currentUrl,
    };

    for (final target in targets) {
      try {
        final cookies = await _cookieManager.getCookies(url: target);
        for (final cookie in cookies) {
          final value = cookie.value?.toString() ?? '';
          if (value.isEmpty || !_requiredCookieNames.contains(cookie.name)) {
            continue;
          }
          cookiesByName[cookie.name] = value;
        }
      } catch (_) {}
    }

    if (!(cookiesByName['SESSDATA']?.isNotEmpty ?? false)) return null;
    return cookiesByName.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}
