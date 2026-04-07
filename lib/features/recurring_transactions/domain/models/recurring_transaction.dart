import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

enum RecurringExecutionMode { automatic, manual }

enum RecurringFrequencyPreset { daily, weekly, monthly, yearly, custom }

enum RecurringIntervalUnit { day, week, month, year }

class RecurringTransaction {
  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.startDate,
    required this.type,
    required this.executionMode,
    required this.frequencyPreset,
    required this.intervalUnit,
    this.interval = 1,
    this.categoryId,
    this.accountId,
    this.sourceAccountId,
    this.destinationAccountId,
    this.lastProcessedOccurrenceDate,
    this.isPaused = false,
  }) : assert(interval > 0, 'Recurring interval must be greater than zero.'),
       assert(
         _isValidConfiguration(
           type: type,
           categoryId: categoryId,
           accountId: accountId,
           sourceAccountId: sourceAccountId,
           destinationAccountId: destinationAccountId,
         ),
         'Recurring transaction configuration does not match its type.',
       );

  final String id;
  final String title;
  final double amount;
  final String currencyCode;
  final DateTime startDate;
  final TransactionType type;
  final String? categoryId;
  final String? accountId;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final RecurringExecutionMode executionMode;
  final RecurringFrequencyPreset frequencyPreset;
  final RecurringIntervalUnit intervalUnit;
  final int interval;
  final DateTime? lastProcessedOccurrenceDate;
  final bool isPaused;

  bool get isTransfer => type == TransactionType.transfer;

  bool get isAutomatic => executionMode == RecurringExecutionMode.automatic;

  bool get isManual => executionMode == RecurringExecutionMode.manual;

  String get frequencyLabel {
    switch (frequencyPreset) {
      case RecurringFrequencyPreset.daily:
        return 'Daily';
      case RecurringFrequencyPreset.weekly:
        return 'Weekly';
      case RecurringFrequencyPreset.monthly:
        return 'Monthly';
      case RecurringFrequencyPreset.yearly:
        return 'Yearly';
      case RecurringFrequencyPreset.custom:
        final unitLabel = switch (intervalUnit) {
          RecurringIntervalUnit.day => interval == 1 ? 'day' : 'days',
          RecurringIntervalUnit.week => interval == 1 ? 'week' : 'weeks',
          RecurringIntervalUnit.month => interval == 1 ? 'month' : 'months',
          RecurringIntervalUnit.year => interval == 1 ? 'year' : 'years',
        };
        return 'Every $interval $unitLabel';
    }
  }

  String get executionModeLabel => switch (executionMode) {
    RecurringExecutionMode.automatic => 'Automatic',
    RecurringExecutionMode.manual => 'Manual',
  };

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'currencyCode': currencyCode,
      'startDate': startDate.toIso8601String(),
      'type': type.name,
      'categoryId': categoryId,
      'accountId': accountId,
      'sourceAccountId': sourceAccountId,
      'destinationAccountId': destinationAccountId,
      'executionMode': executionMode.name,
      'frequencyPreset': frequencyPreset.name,
      'intervalUnit': intervalUnit.name,
      'interval': interval,
      'lastProcessedOccurrenceDate': lastProcessedOccurrenceDate
          ?.toIso8601String(),
      'isPaused': isPaused,
    };
  }

  factory RecurringTransaction.fromMap(Map<dynamic, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: map['currencyCode'] as String? ?? 'EUR',
      startDate:
          DateTime.tryParse(map['startDate'] as String? ?? '') ??
          DateTime.now(),
      type: _transactionTypeFromName(map['type'] as String?),
      categoryId: _optionalString(map['categoryId']),
      accountId: _optionalString(map['accountId']),
      sourceAccountId: _optionalString(map['sourceAccountId']),
      destinationAccountId: _optionalString(map['destinationAccountId']),
      executionMode: _executionModeFromName(map['executionMode'] as String?),
      frequencyPreset: _frequencyPresetFromName(
        map['frequencyPreset'] as String?,
      ),
      intervalUnit: _intervalUnitFromName(map['intervalUnit'] as String?),
      interval: map['interval'] as int? ?? 1,
      lastProcessedOccurrenceDate: DateTime.tryParse(
        map['lastProcessedOccurrenceDate'] as String? ?? '',
      ),
      isPaused: map['isPaused'] as bool? ?? false,
    );
  }

  RecurringTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? currencyCode,
    DateTime? startDate,
    TransactionType? type,
    String? categoryId,
    bool clearCategoryId = false,
    String? accountId,
    bool clearAccountId = false,
    String? sourceAccountId,
    bool clearSourceAccountId = false,
    String? destinationAccountId,
    bool clearDestinationAccountId = false,
    RecurringExecutionMode? executionMode,
    RecurringFrequencyPreset? frequencyPreset,
    RecurringIntervalUnit? intervalUnit,
    int? interval,
    DateTime? lastProcessedOccurrenceDate,
    bool clearLastProcessedOccurrenceDate = false,
    bool? isPaused,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      startDate: startDate ?? this.startDate,
      type: type ?? this.type,
      categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
      sourceAccountId: clearSourceAccountId
          ? null
          : sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: clearDestinationAccountId
          ? null
          : destinationAccountId ?? this.destinationAccountId,
      executionMode: executionMode ?? this.executionMode,
      frequencyPreset: frequencyPreset ?? this.frequencyPreset,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      interval: interval ?? this.interval,
      lastProcessedOccurrenceDate: clearLastProcessedOccurrenceDate
          ? null
          : lastProcessedOccurrenceDate ?? this.lastProcessedOccurrenceDate,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  static bool _isValidConfiguration({
    required TransactionType type,
    required String? categoryId,
    required String? accountId,
    required String? sourceAccountId,
    required String? destinationAccountId,
  }) {
    if (type == TransactionType.transfer) {
      return !_hasValue(categoryId) &&
          !_hasValue(accountId) &&
          _hasValue(sourceAccountId) &&
          _hasValue(destinationAccountId);
    }

    return _hasValue(categoryId) &&
        _hasValue(accountId) &&
        !_hasValue(sourceAccountId) &&
        !_hasValue(destinationAccountId);
  }

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;

  static String? _optionalString(Object? value) {
    final stringValue = value as String?;
    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  static TransactionType _transactionTypeFromName(String? value) {
    return TransactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TransactionType.expense,
    );
  }

  static RecurringExecutionMode _executionModeFromName(String? value) {
    return RecurringExecutionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => RecurringExecutionMode.manual,
    );
  }

  static RecurringFrequencyPreset _frequencyPresetFromName(String? value) {
    return RecurringFrequencyPreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => RecurringFrequencyPreset.monthly,
    );
  }

  static RecurringIntervalUnit _intervalUnitFromName(String? value) {
    return RecurringIntervalUnit.values.firstWhere(
      (unit) => unit.name == value,
      orElse: () => RecurringIntervalUnit.month,
    );
  }
}
