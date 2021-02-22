import 'dart:developer' as developer;
import 'package:logging/logging.dart';

const LOG_LEVEL = Level.WARNING;
const LOGGER_METHOD = consoleLogger;

consoleLogger(LogRecord record) {
  print('${record.loggerName}(${record.level.name}): ${record.message}');
}

developerLogger(LogRecord record) {
  developer.log(record.message, name: record.loggerName);
}
