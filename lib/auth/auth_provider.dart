import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/em_user.dart';
import 'auth_service.dart';
import 'auth_state.dart';

final authServiceProvider = Provider<IAuthService>((ref) {
  return AuthService();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final IAuthService authService;

  AuthNotifier({required this.authService}) : super(const AuthState()) {
    checkAuthSession();
  }

  Future<void> checkAuthSession() async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final user = await authService.checkAuthSession();
      final token = await authService.getAuthToken();
      if (user != null && token != null && token.isNotEmpty) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          token: token,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          token: null,
          errorMessage: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<SendUserCodeResult> sendUserCode({
    required String email,
    String? firstName,
    String? lastName,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      email: email.trim().toLowerCase(),
      errorMessage: null,
    );

    try {
      final result = await authService.sendUserCode(
        email: email,
        firstName: firstName,
        lastName: lastName,
      );

      if (result.isSuccess) {
        state = state.copyWith(
          status: AuthStatus.codeSent,
          email: result.email ?? email,
          errorMessage: null,
        );
      } else if (result.isNoUser) {
        state = state.copyWith(
          status: AuthStatus.needRegistration,
          email: result.email ?? email,
          allowGuestRegistration: result.allowGuestRegistration,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.errorMessage ?? 'Failed to send verification code',
        );
      }
      return result;
    } catch (e) {
      final err = e.toString();
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: err,
      );
      return SendUserCodeResult(
        status: SendUserCodeStatus.error,
        errorMessage: err,
      );
    }
  }

  Future<SendUserCodeResult> registerAndSendCode({
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    return sendUserCode(
      email: email,
      firstName: firstName,
      lastName: lastName,
    );
  }

  Future<LoginResult> loginWithCode({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );

    try {
      final result = await authService.loginWithCode(
        email: email,
        code: code,
      );

      if (result.isSuccess && result.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          token: result.token,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.errorMessage ?? 'Invalid verification code',
        );
      }
      return result;
    } catch (e) {
      final err = e.toString();
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: err,
      );
      return LoginResult(
        isSuccess: false,
        errorMessage: err,
      );
    }
  }

  Future<void> logout() async {
    await authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void resetFlow() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      errorMessage: null,
    );
  }

  void updateUser(EmUser user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService: authService);
});

final currentUserProvider = Provider<EmUser?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
