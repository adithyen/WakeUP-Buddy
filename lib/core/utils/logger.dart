/// Simple logger utility for WakeUp Buddy
// ignore_for_file: avoid_print
class Logger {
  static const String _prefix = '🎯 [WakeUp Buddy]';

  static void info(String message) {
    print('$_prefix ℹ️ $message');
  }

  static void debug(String message) {
    print('$_prefix 🐛 $message');
  }

  static void warning(String message) {
    print('$_prefix ⚠️ $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('$_prefix ❌ $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('StackTrace: $stackTrace');
  }

  static void success(String message) {
    print('$_prefix ✅ $message');
  }
}
