import 'package:expense_tracker/features/auth/data/auth_runtime_config.dart';
import 'package:expense_tracker/core/firebase/firebase_bootstrap.dart';
import 'package:expense_tracker/features/auth/domain/exceptions/auth_exception.dart';
import 'package:expense_tracker/features/auth/domain/models/auth_user.dart';
import 'package:expense_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  bool _didInitializeGoogleSignIn = false;

  @override
  AuthUser? get currentUser {
    if (!FirebaseBootstrap.isSupportedPlatform) {
      return null;
    }

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    return _mapFirebaseUser(firebaseUser);
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    if (!FirebaseBootstrap.isSupportedPlatform) {
      return Stream<AuthUser?>.value(null);
    }

    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        return null;
      }

      return _mapFirebaseUser(firebaseUser);
    });
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    _ensureFirebaseIsSupported();

    try {
      await _ensureGoogleSignInInitialized();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthConfigurationException(
          'Google sign-in is not available on this platform.',
        );
      }

      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthConfigurationException(
          'Google sign-in did not return an ID token. Verify the Google provider, Android SHA certificates, and that your Google auth configuration includes a valid server client ID.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const AuthFailureException(
          'Google sign-in completed without creating a Firebase session.',
        );
      }

      return _mapFirebaseUser(firebaseUser);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }

      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw AuthConfigurationException(
          _googleConfigurationMessage(error.description),
        );
      }

      throw AuthFailureException(
        error.description ?? 'Unable to continue with Google right now.',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailureException(_firebaseAuthMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    _ensureFirebaseIsSupported();

    try {
      await _firebaseAuth.signOut();
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailureException(_firebaseAuthMessage(error));
    } on GoogleSignInException catch (error) {
      throw AuthFailureException(
        error.description ?? 'Unable to sign out cleanly right now.',
      );
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_didInitializeGoogleSignIn) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId: AuthRuntimeConfig.resolvedGoogleServerClientId,
    );
    _didInitializeGoogleSignIn = true;
  }

  void _ensureFirebaseIsSupported() {
    if (FirebaseBootstrap.isSupportedPlatform) {
      return;
    }

    throw const AuthConfigurationException(
      'Google authentication is currently configured for Android only in this project.',
    );
  }

  AuthUser _mapFirebaseUser(User user) {
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  String _googleConfigurationMessage(String? details) {
    final normalizedDetails = details?.trim();
    final suffix = normalizedDetails == null || normalizedDetails.isEmpty
        ? ''
        : ' Details: $normalizedDetails';

    return 'Google sign-in is not fully configured for this Android app. Make sure the Google provider is enabled in Firebase, the debug or release SHA certificate is registered for package com.bartolot.vero, and a valid web/server OAuth client ID is supplied to the Android sign-in flow.$suffix';
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'A network error interrupted authentication. Check the device connection and try again.';
      case 'account-exists-with-different-credential':
        return 'This Google account already exists with another sign-in method.';
      case 'invalid-credential':
        return 'Google returned an invalid credential. Refresh the Firebase Android config and try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase Authentication yet.';
      default:
        return error.message ?? 'Authentication failed unexpectedly.';
    }
  }
}
