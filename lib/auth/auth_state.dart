import '../models/em_user.dart';

enum SendUserCodeStatus {
  ok,
  error,
  nouser;

  static SendUserCodeStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'ok':
      case 'success':
        return SendUserCodeStatus.ok;
      case 'nouser':
      case 'no_user':
        return SendUserCodeStatus.nouser;
      case 'error':
      default:
        return SendUserCodeStatus.error;
    }
  }
}

class SendUserCodeResult {
  final SendUserCodeStatus status;
  final String? email;
  final String? errorMessage;
  final bool allowGuestRegistration;

  const SendUserCodeResult({
    required this.status,
    this.email,
    this.errorMessage,
    this.allowGuestRegistration = false,
  });

  bool get isSuccess => status == SendUserCodeStatus.ok;
  bool get isNoUser => status == SendUserCodeStatus.nouser;
  bool get isError => status == SendUserCodeStatus.error;

  factory SendUserCodeResult.fromJson(Map<String, dynamic> json) {
    final response = json['response'] is Map<String, dynamic>
        ? json['response'] as Map<String, dynamic>
        : json;

    final rawStatus = response['status']?.toString();
    final status = SendUserCodeStatus.fromString(rawStatus);
    final email = response['email']?.toString();
    final rawError = response['error']?.toString() ?? json['error']?.toString();
    final allowGuest = response['allowguestregistration'] == true ||
        response['allowguestregistration'] == 'true' ||
        json['allowguestregistration'] == true ||
        json['allowguestregistration'] == 'true';

    return SendUserCodeResult(
      status: status,
      email: email,
      errorMessage: rawError,
      allowGuestRegistration: allowGuest,
    );
  }
}

class LoginResult {
  final bool isSuccess;
  final EmUser? user;
  final String? token;
  final String? errorMessage;

  const LoginResult({
    required this.isSuccess,
    this.user,
    this.token,
    this.errorMessage,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final response = json['response'] is Map<String, dynamic>
        ? json['response'] as Map<String, dynamic>
        : json;

    final status = response['status']?.toString().toLowerCase();
    final rawError = response['error']?.toString() ?? json['error']?.toString();
    final token = json['entermediakey']?.toString() ??
        response['entermediakey']?.toString() ??
        json['token']?.toString();

    EmUser? user;
    if (json['user'] is Map<String, dynamic>) {
      user = EmUser.fromJson(json['user'] as Map<String, dynamic>);
      if (token != null && token.isNotEmpty) {
        user = user.copyWith(entermediakey: token);
      }
    } else if (status == 'ok' && token != null) {
      final userId = (response['user'] ?? json['user'] ?? '').toString();
      user = EmUser(userid: userId, entermediakey: token);
    }

    final isOk = (status == 'ok' || token != null) && (rawError == null || rawError.isEmpty);

    return LoginResult(
      isSuccess: isOk,
      user: user,
      token: token,
      errorMessage: isOk ? null : (rawError ?? 'Authentication failed'),
    );
  }
}

enum AuthStatus {
  initial,
  unauthenticated,
  needRegistration,
  codeSent,
  authenticating,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final EmUser? user;
  final String? token;
  final String? email;
  final bool allowGuestRegistration;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.email,
    this.allowGuestRegistration = false,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.authenticating;
  bool get isCodeSent => status == AuthStatus.codeSent;
  bool get isNeedRegistration => status == AuthStatus.needRegistration;

  AuthState copyWith({
    AuthStatus? status,
    EmUser? user,
    String? token,
    String? email,
    bool? allowGuestRegistration,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      email: email ?? this.email,
      allowGuestRegistration:
          allowGuestRegistration ?? this.allowGuestRegistration,
      errorMessage: errorMessage,
    );
  }
}
