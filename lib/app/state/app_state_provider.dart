import 'package:expense_tracker/app/state/app_state_notifier.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:expense_tracker/app/state/app_state_exceptions.dart';

final appStateProvider = NotifierProvider<AppStateNotifier, AppStateSnapshot>(
  AppStateNotifier.new,
);
