import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/core/firebase/firebase_bootstrap.dart';
import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('bootstrap'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    _logger.e(
      'Unhandled Flutter framework error.',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  try {
    await HiveStorage.initialize();
    _logger.i('Hive storage initialized.');
    await FirebaseBootstrap.initialize();
    runApp(const ProviderScope(child: ExpenseTrackerApp()));
  } catch (error, stackTrace) {
    _logger.e(
      'Failed to initialize application services.',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
