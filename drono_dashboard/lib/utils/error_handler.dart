import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logger.dart';

class AppErrorHandler {
  static void initialize() {
    // Set up global exception handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _reportError(details.exception, details.stack, errorDetails: details.toString());
    };

    // Handle errors in the current zone
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportError(error, stack);
      return true;
    };

    // Handle errors from the framework
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Log the error
      _reportError(details.exception, details.stack, errorDetails: details.toString());
      
      // In debug mode, show the error details
      if (kDebugMode) {
        return ErrorWidget(details.exception);
      }
      
      // In production, show a friendly error message
      return Container(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Something went wrong. Please try again later.',
            style: TextStyle(color: Colors.red[300]),
          ),
        ),
      );
    };
  }

  // Run the app with error catching
  static Future<void> runWithCatching(Widget app) async {
    await runZonedGuarded(
      () async {
        runApp(app);
      },
      (error, stackTrace) {
        _reportError(error, stackTrace);
      },
    );
  }

  // Report error to logger and potentially to a remote service
  static void _reportError(Object error, StackTrace? stackTrace, {String? errorDetails}) {
    try {
      final String errorStr = error.toString();
      final String message = 'Uncaught error: ${errorDetails ?? errorStr}';
      
      log.error(message, error, stackTrace);
      
      // Here you could send the error to a remote service like Firebase Crashlytics
      // or your own error reporting service
      
      debugPrint('Error reported: $message');
    } catch (e) {
      debugPrint('Failed to report error: $e');
    }
  }
} 