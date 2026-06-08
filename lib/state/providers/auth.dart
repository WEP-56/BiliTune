part of '../providers.dart';

@immutable
class AuthState {
  const AuthState({
    this.credential,
    this.account,
    this.qrSession,
    this.qrStatus,
    this.isLoading = false,
    this.errorMessage,
  });

  final BiliCredential? credential;
  final BiliAccount? account;
  final QrLoginSession? qrSession;
  final QrLoginStatus? qrStatus;
  final bool isLoading;
  final String? errorMessage;

  bool get isSignedIn => credential?.isSignedIn ?? false;

  AuthState copyWith({
    Object? credential = _unset,
    Object? account = _unset,
    Object? qrSession = _unset,
    Object? qrStatus = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      credential: identical(credential, _unset)
          ? this.credential
          : credential as BiliCredential?,
      account: identical(account, _unset)
          ? this.account
          : account as BiliAccount?,
      qrSession: identical(qrSession, _unset)
          ? this.qrSession
          : qrSession as QrLoginSession?,
      qrStatus: identical(qrStatus, _unset)
          ? this.qrStatus
          : qrStatus as QrLoginStatus?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  bool _hydrated = false;

  @override
  AuthState build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_restore());
    }
    return const AuthState();
  }

  Future<void> _restore() async {
    final repository = ref.read(biliAuthRepositoryProvider);
    final credential = await repository.restoreSession();
    state = state.copyWith(credential: credential);
    if (credential?.isSignedIn ?? false) {
      await refreshAccount();
    }
  }

  Future<void> refreshAccount() async {
    try {
      final account = await ref
          .read(biliAuthRepositoryProvider)
          .currentAccount();
      if (account == null) {
        await ref.read(biliAuthRepositoryProvider).logout();
        state = state.copyWith(
          account: null,
          credential: null,
          errorMessage: null,
        );
        return;
      }
      final credential = await ref
          .read(biliAuthRepositoryProvider)
          .restoreSession();
      state = state.copyWith(
        account: account,
        credential: credential ?? state.credential,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> createQrLoginSession() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await ref
          .read(biliAuthRepositoryProvider)
          .createQrLoginSession();
      state = state.copyWith(
        qrSession: session,
        qrStatus: QrLoginStatus.waiting,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> pollQrLogin() async {
    final session = state.qrSession;
    if (session == null) return;

    try {
      final result = await ref
          .read(biliAuthRepositoryProvider)
          .pollQrLogin(session);
      state = state.copyWith(
        qrStatus: result.status,
        credential: result.credential ?? state.credential,
        errorMessage: result.status == QrLoginStatus.failed
            ? (result.message ?? 'QR login failed')
            : null,
      );
      if (result.status == QrLoginStatus.confirmed) {
        await refreshAccount();
      }
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> saveManualCookie(String cookieHeader) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(biliAuthRepositoryProvider);
      await repository.saveManualCookie(cookieHeader);
      final account = await repository.currentAccount();
      if (account == null) {
        await repository.logout();
        throw StateError('Cookie 无效或已过期');
      }
      final credential = await repository.restoreSession();
      state = state.copyWith(
        credential: credential,
        account: account,
        isLoading: false,
        qrSession: null,
        qrStatus: null,
      );
    } catch (error) {
      state = state.copyWith(
        credential: null,
        account: null,
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> logout() async {
    await ref.read(biliAuthRepositoryProvider).logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
