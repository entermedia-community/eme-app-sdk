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
      final user = await authService.getCurrentUser();
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
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
    try {
      final user = await authService.loginWithCredentials(
        username: username,
        password: password,
      );
      final token = await authService.getAuthToken();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        token: token,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
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
