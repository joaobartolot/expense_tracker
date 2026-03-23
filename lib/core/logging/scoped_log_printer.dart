import 'package:logger/logger.dart';

class ScopedLogPrinter extends LogPrinter {
  ScopedLogPrinter(this.scope)
    : _printer = PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 100,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      );

  final String scope;
  final PrettyPrinter _printer;

  @override
  List<String> log(LogEvent event) {
    final scopedEvent = LogEvent(
      event.level,
      '[$scope] ${event.message}',
      time: event.time,
      error: event.error,
      stackTrace: event.stackTrace,
    );

    return _printer.log(scopedEvent);
  }
}
