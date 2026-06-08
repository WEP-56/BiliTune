part of '../providers.dart';

@immutable
class WindowsStartupState {
  const WindowsStartupState({
    this.enabled = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool enabled;
  final bool isLoading;
  final String? errorMessage;

  WindowsStartupState copyWith({
    bool? enabled,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return WindowsStartupState(
      enabled: enabled ?? this.enabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class WindowsStartupNotifier extends Notifier<WindowsStartupState> {
  bool _bootstrapped = false;

  @override
  WindowsStartupState build() {
    if (!Platform.isWindows) {
      return const WindowsStartupState(enabled: false, isLoading: false);
    }
    if (!_bootstrapped) {
      _bootstrapped = true;
      unawaited(Future<void>.microtask(_load));
    }
    return const WindowsStartupState(isLoading: true);
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final enabled = await WindowsStartupManager.isEnabled();
      state = WindowsStartupState(enabled: enabled, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await WindowsStartupManager.setEnabled(value);
      state = WindowsStartupState(enabled: value, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }
}

final windowsStartupProvider =
    NotifierProvider<WindowsStartupNotifier, WindowsStartupState>(
      WindowsStartupNotifier.new,
    );

final playbackBootstrapProvider = Provider<PlaybackState?>((ref) => null);

final windowsHotkeyBootstrapProvider = Provider<List<WindowsHotkeyBinding>>(
  (ref) => const <WindowsHotkeyBinding>[],
);

class WindowsHotkeyNotifier extends Notifier<List<WindowsHotkeyBinding>> {
  bool _hydrated = false;

  @override
  List<WindowsHotkeyBinding> build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_load());
    }
    return ref.read(windowsHotkeyBootstrapProvider);
  }

  Future<void> setBinding(WindowsHotkeyBinding binding) async {
    if (!binding.isSet) {
      await clearBinding(binding.action);
      return;
    }

    final next = <WindowsHotkeyBinding>[
      for (final existing in state)
        if (existing.action != binding.action &&
            existing.signature != binding.signature)
          existing,
      binding,
    ];
    state = next;
    await _persist(next);
  }

  Future<void> clearBinding(WindowsHotkeyAction action) async {
    final next = state
        .where((binding) => binding.action != action)
        .toList(growable: false);
    state = next;
    await _persist(next);
  }

  Future<void> clearAll() async {
    state = const <WindowsHotkeyBinding>[];
    await _persist(state);
  }

  Future<void> _persist(List<WindowsHotkeyBinding> bindings) {
    return ref
        .read(appLocalStoreProvider)
        .saveWindowsHotkeys(
          bindings.map((binding) => binding.toJson()).toList(growable: false),
        );
  }

  Future<void> _load() async {
    try {
      final bindings = await ref
          .read(appLocalStoreProvider)
          .readWindowsHotkeys();
      final parsed = bindings
          .map((item) {
            try {
              return WindowsHotkeyBinding.fromJson(item);
            } catch (_) {
              return null;
            }
          })
          .whereType<WindowsHotkeyBinding>()
          .where((binding) => binding.isSet)
          .toList(growable: false);
      if (state.isEmpty && parsed.isNotEmpty) {
        state = parsed;
      }
    } catch (_) {}
  }
}

final windowsHotkeysProvider =
    NotifierProvider<WindowsHotkeyNotifier, List<WindowsHotkeyBinding>>(
      WindowsHotkeyNotifier.new,
    );

@immutable
class AppUpdateState {
  const AppUpdateState({
    this.isChecking = false,
    this.latestRelease,
    this.hasUpdate,
    this.errorMessage,
  });

  final bool isChecking;
  final GithubReleaseInfo? latestRelease;
  final bool? hasUpdate;
  final String? errorMessage;

  String get label {
    if (isChecking) return '检查中...';
    if (errorMessage != null) return '检查失败';
    if (latestRelease == null) return '手动检查';
    return hasUpdate == true ? '有更新' : '已是最新';
  }

  AppUpdateState copyWith({
    bool? isChecking,
    Object? latestRelease = _unset,
    Object? hasUpdate = _unset,
    Object? errorMessage = _unset,
  }) {
    return AppUpdateState(
      isChecking: isChecking ?? this.isChecking,
      latestRelease: identical(latestRelease, _unset)
          ? this.latestRelease
          : latestRelease as GithubReleaseInfo?,
      hasUpdate: identical(hasUpdate, _unset)
          ? this.hasUpdate
          : hasUpdate as bool?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestRelease,
    required this.hasUpdate,
    required this.installerAsset,
  });

  final PackageInfo currentVersion;
  final GithubReleaseInfo latestRelease;
  final bool hasUpdate;
  final GithubReleaseAsset? installerAsset;
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState();

  Future<UpdateCheckResult?> checkForUpdate() async {
    if (state.isChecking) return null;
    state = state.copyWith(isChecking: true, errorMessage: null);
    try {
      final packageInfo = await ref.read(packageInfoProvider.future);
      final updateService = ref.read(githubUpdateServiceProvider);
      final release = await updateService.fetchLatestRelease();
      final hasUpdate = isRemoteReleaseNewer(
        currentVersion: packageInfo.version,
        remoteTag: release.tagName,
      );
      final installerAsset = updateService.selectInstallerAsset(release);
      state = AppUpdateState(
        isChecking: false,
        latestRelease: release,
        hasUpdate: hasUpdate,
      );
      return UpdateCheckResult(
        currentVersion: packageInfo,
        latestRelease: release,
        hasUpdate: hasUpdate,
        installerAsset: installerAsset,
      );
    } catch (error) {
      state = state.copyWith(isChecking: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<File> downloadInstaller(GithubReleaseInfo release) async {
    final asset = ref
        .read(githubUpdateServiceProvider)
        .selectInstallerAsset(release);
    if (asset == null) {
      throw StateError('当前版本没有可用的安装包。');
    }
    return ref.read(githubUpdateServiceProvider).downloadInstallerAsset(asset);
  }

  Future<bool> canInstallApk() => AppInstaller.canInstallApk();

  Future<void> openInstallSettings() => AppInstaller.openInstallSettings();

  Future<bool> launchInstaller(String path) =>
      AppInstaller.launchInstaller(path);
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

class NowPlayingOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final nowPlayingOpenProvider = NotifierProvider<NowPlayingOpenNotifier, bool>(
  NowPlayingOpenNotifier.new,
);
