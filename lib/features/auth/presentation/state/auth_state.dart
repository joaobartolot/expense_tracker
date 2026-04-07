import 'package:expense_tracker/features/auth/domain/models/auth_user.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    required this.isBusy,
    required this.user,
    required this.errorMessage,
  });

  const AuthState.checking()
    : status = AuthStatus.checking,
      isBusy = false,
      user = null,
      errorMessage = null;

  const AuthState.unauthenticated({this.isBusy = false, this.errorMessage})
    : status = AuthStatus.unauthenticated,
      user = null;

  const AuthState.authenticated(
    AuthUser this.user, {
    this.isBusy = false,
    this.errorMessage,
  }) : status = AuthStatus.authenticated;

  final AuthStatus status;
  final bool isBusy;
  final AuthUser? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    bool? isBusy,
    Object? user = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return AuthState(
      status: status ?? this.status,
      isBusy: isBusy ?? this.isBusy,
      user: identical(user, _sentinel) ? this.user : user as AuthUser?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();
