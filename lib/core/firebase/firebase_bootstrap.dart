import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('firebase_bootstrap'));

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<void> initialize() async {
    if (!isSupportedPlatform) {
      _logger.i(
        'Skipping Firebase initialization because this platform is not configured yet.',
      );
      return;
    }

    if (Firebase.apps.isNotEmpty) {
      return;
    }

    await Firebase.initializeApp();
    _logger.i('Firebase initialized.');
  }
}
