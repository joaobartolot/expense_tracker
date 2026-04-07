import 'dart:async';

import 'package:expense_tracker/features/auth/data/firebase_auth_repository.dart';
import 'package:expense_tracker/features/auth/domain/exceptions/auth_exception.dart';
import 'package:expense_tracker/features/auth/domain/models/auth_user.dart';
import 'package:expense_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _authRepository;

  StreamSubscription<AuthUser?>? _authStateSubscription;
  bool _didBindAuthStateStream = false;

  @override
  AuthState build() {
    _authRepository = ref.read(authRepositoryProvider);

    if (!_didBindAuthStateStream) {
      _bindAuthStateStream();
      _didBindAuthStateStream = true;
    }

    final currentUser = _authRepository.currentUser;
    if (currentUser != null) {
      return AuthState.authenticated(currentUser);
    }

    return const AuthState.checking();
  }

  Future<void> signInWithGoogle() async {
    if (state.isBusy) {
      return;
    }

    state = state.copyWith(isBusy: true, errorMessage: null);

    try {
      final user = await _authRepository.signInWithGoogle();
      state = AuthState.authenticated(user);
    } on AuthCancelledException {
      state = const AuthState.unauthenticated();
    } on AuthException catch (error) {
      state = AuthState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      state = const AuthState.unauthenticated(
        errorMessage: 'Authentication failed unexpectedly.',
      );
    }
  }

  Future<void> signOut() async {
    if (state.isBusy) {
      return;
    }

    final currentUser = state.user;
    state = state.copyWith(isBusy: true, errorMessage: null);

    try {
      await _authRepository.signOut();
      state = const AuthState.unauthenticated();
    } on AuthException catch (error) {
      if (currentUser == null) {
        state = AuthState.unauthenticated(errorMessage: error.message);
        return;
      }

      state = AuthState.authenticated(currentUser, errorMessage: error.message);
    } catch (_) {
      if (currentUser == null) {
        state = const AuthState.unauthenticated(
          errorMessage: 'Sign-out failed unexpectedly.',
        );
        return;
      }

      state = const AuthState.unauthenticated(
        errorMessage: 'Sign-out failed unexpectedly.',
      );
    }
  }

  void _bindAuthStateStream() {
    _authStateSubscription = _authRepository.authStateChanges().listen(
      (user) {
        if (user == null) {
          state = const AuthState.unauthenticated();
          return;
        }

        state = AuthState.authenticated(user);
      },
      onError: (Object error) {
        final message = error is AuthException
            ? error.message
            : 'Authentication state could not be refreshed.';
        state = AuthState.unauthenticated(errorMessage: message);
      },
    );

    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });
  }
}
