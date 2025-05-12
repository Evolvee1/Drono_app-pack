import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  static AppLogger get instance => _instance;

  late Logger _logger;
  String? _logFilePath;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  // Create a singleton instance
  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: Level.debug,
    );
    _initLogFile();
  }

  Future<void> _initLogFile() async {
    try {
      if (!kIsWeb) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String logDirPath = '${appDocDir.path}/logs';
        final Directory logDir = Directory(logDirPath);
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _logFilePath = '$logDirPath/drono_dashboard_$today.log';
        debugPrint('Log file initialized at: $_logFilePath');
      }
    } catch (e) {
      debugPrint('Failed to initialize log file: $e');
    }
  }

  Future<void> _writeToLogFile(String level, String message) async {
    if (_logFilePath != null && !kIsWeb) {
      try {
        final File logFile = File(_logFilePath!);
        final String timestamp = _dateFormat.format(DateTime.now());
        final String logEntry = '[$timestamp] [$level] $message\n';
        await logFile.writeAsString(logEntry, mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    }
  }

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('DEBUG', message + (error != null ? ' - ERROR: $error' : ''));
    developer.log(message, name: 'DEBUG', error: error, stackTrace: stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('INFO', message + (error != null ? ' - ERROR: $error' : ''));
    developer.log(message, name: 'INFO', error: error, stackTrace: stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('WARNING', message + (error != null ? ' - ERROR: $error' : ''));
    developer.log(message, name: 'WARNING', error: error, stackTrace: stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('ERROR', message + (error != null ? ' - ERROR: $error' : ''));
    developer.log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
  }

  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('FATAL', message + (error != null ? ' - ERROR: $error' : ''));
    developer.log(message, name: 'FATAL', error: error, stackTrace: stackTrace);
  }
}

// Global logger instance for easy access
final log = AppLogger.instance; 