import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:flutter/material.dart';
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
    runApp(const ExpenseTrackerApp());
  } catch (error, stackTrace) {
    _logger.e(
      'Failed to initialize application storage.',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
