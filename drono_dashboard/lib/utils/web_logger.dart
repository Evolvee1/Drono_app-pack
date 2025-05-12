import 'dart:html' as html;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// A simplified web logger for capturing and storing errors in the browser
class WebLogger {
  static final List<Map<String, dynamic>> _logs = [];
  static bool _initialized = false;
  static Timer? _saveTimer;

  /// Initialize the web logger system
  static void initialize() {
    if (!kIsWeb || _initialized) return;
    
    try {
      debugPrint('Initializing WebLogger');
      
      // Set up error handler for Flutter errors
      FlutterError.onError = (details) {
        _logError(
          'Flutter Error',
          details.exception.toString(),
          details.stack.toString()
        );
      };
      
      // Set up window error handler for JavaScript errors
      html.window.onError.listen((event) {
        final message = event is html.ErrorEvent 
            ? '${event.message} at ${event.filename}:${event.lineno}:${event.colno}'
            : 'Unknown error';
            
        _logError('JavaScript Error', message);
      });
      
      // Set up autosave timer
      _saveTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _saveToLocalStorage();
      });
      
      _initialized = true;
      debugPrint('WebLogger initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize WebLogger: $e');
    }
  }

  /// Log a specific range error
  static void logRangeError(RangeError error, StackTrace stackTrace) {
    String details = 'Invalid value: ${error.invalidValue}';
    if (error.start != null) details += ', Start: ${error.start}';
    if (error.end != null) details += ', End: ${error.end}';
    
    _logError(
      'Range Error', 
      error.message ?? error.toString(),
      stackTrace.toString(),
      details
    );
  }

  /// Log a general error
  static void logError(String type, String message, String stackTrace) {
    _logError(type, message, stackTrace);
  }

  /// Internal method to log an error
  static void _logError(String type, String message, [String? stackTrace, String? details]) {
    debugPrint('[$type] $message');
    if (details != null) debugPrint('Details: $details');
    
    _logs.add({
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'message': message,
      'stackTrace': stackTrace,
      'details': details
    });
    
    // Save immediately if this is a critical error
    if (type.contains('Error')) {
      _saveToLocalStorage();
    }
  }

  /// Save logs to local storage
  static void _saveToLocalStorage() {
    if (!kIsWeb || _logs.isEmpty) return;
    
    try {
      // Get existing logs
      final existingLogsJson = html.window.localStorage['drono_error_logs'] ?? '[]';
      List<dynamic> allLogs;
      
      try {
        allLogs = jsonDecode(existingLogsJson);
      } catch (_) {
        allLogs = [];
      }
      
      // Add new logs and limit to 100 entries to prevent storage issues
      allLogs.addAll(_logs);
      if (allLogs.length > 100) {
        allLogs = allLogs.sublist(allLogs.length - 100);
      }
      
      // Save back to localStorage
      html.window.localStorage['drono_error_logs'] = jsonEncode(allLogs);
      _logs.clear();
    } catch (e) {
      debugPrint('Error saving logs: $e');
    }
  }

  /// Download logs as a JSON file
  static void downloadLogs() {
    if (!kIsWeb) return;
    
    try {
      // Save any pending logs first
      _saveToLocalStorage();
      
      // Get all logs from storage
      final logs = html.window.localStorage['drono_error_logs'] ?? '[]';
      
      // Create blob for download
      final blob = html.Blob([logs], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create download link
      final anchor = html.AnchorElement()
        ..href = url
        ..download = 'drono_logs_${DateTime.now().millisecondsSinceEpoch}.json'
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      
      // Cleanup
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Error downloading logs: $e');
    }
  }

  /// Clear all stored logs
  static void clearLogs() {
    if (!kIsWeb) return;
    
    try {
      html.window.localStorage.remove('drono_error_logs');
      _logs.clear();
      debugPrint('Logs cleared');
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
  }

  /// Cleanup resources
  static void dispose() {
    _saveTimer?.cancel();
    _logs.clear();
    _initialized = false;
  }