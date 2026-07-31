import 'dart:developer' as developer;

enum LogLevel { info, warning, error }

class LoggerService {
  static final LoggerService _instance = LoggerService._();
  factory LoggerService() => _instance;
  LoggerService._();

  void log(String message, {LogLevel level = LogLevel.info, String? tag}) {
    final timestamp = DateTime.now().toString().substring(0, 19);
    final prefix = _prefix(level);
    final tagStr = tag != null ? ' [$tag]' : '';
    final formatted = '$timestamp $prefix$tagStr $message';
    developer.log(formatted, name: 'POS');
  }

  void info(String message, {String? tag}) => log(message, level: LogLevel.info, tag: tag);
  void warning(String message, {String? tag}) => log(message, level: LogLevel.warning, tag: tag);
  void error(String message, {String? tag}) => log(message, level: LogLevel.error, tag: tag);

  String _prefix(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERR]';
    }
  }
}