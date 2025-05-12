import 'package:flutter/material.dart';
import 'logger.dart';

/// Controls a red error overlay that can be displayed over the app
/// when critical errors occur
class ErrorOverlayManager {
  // Singleton pattern
  static final ErrorOverlayManager _instance = ErrorOverlayManager._internal();
  factory ErrorOverlayManager() => _instance;
  ErrorOverlayManager._internal();
  
  // State variables
  bool _visible = false;
  String _errorMessage = '';
  
  // Global key for the overlay
  final GlobalKey<ErrorOverlayState> _overlayKey = GlobalKey<ErrorOverlayState>();
  
  // Methods to show/hide the overlay
  void show(String message) {
    log.error('Showing error overlay: $message');
    _errorMessage = message;
    _visible = true;
    _updateOverlay();
  }
  
  void hide() {
    _visible = false;
    _updateOverlay();
  }
  
  void _updateOverlay() {
    try {
      if (_overlayKey.currentState != null && _overlayKey.currentContext != null) {
        _overlayKey.currentState!.updateOverlay(_visible, _errorMessage);
      }
    } catch (e) {
      // Log but don't crash if there's an issue with the overlay
      log.error('Error updating overlay: $e');
    }
  }
  
  // Getter for the overlay key
  GlobalKey<ErrorOverlayState> get overlayKey => _overlayKey;
  
  // Getter for visibility state
  bool get isVisible => _visible;
}

/// The actual error overlay widget that displays the red background
/// and error message
class ErrorOverlay extends StatefulWidget {
  final Widget child;
  
  const ErrorOverlay({
    super.key,
    required this.child,
  });
  
  @override
  ErrorOverlayState createState() => ErrorOverlayState();
}

class ErrorOverlayState extends State<ErrorOverlay> {
  bool _visible = false;
  String _errorMessage = '';
  
  void updateOverlay(bool visible, String message) {
    // Only update state if it's actually changed and if the widget is still mounted
    if (mounted && (_visible != visible || _errorMessage != message)) {
      try {
        setState(() {
          _visible = visible;
          _errorMessage = message;
        });
      } catch (e) {
        // Log the error but don't crash the app
        log.error('Error updating overlay state: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Colors.red.withOpacity(0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Critical Error',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) => ElevatedButton(
                            onPressed: () {
                              try {
                                ErrorOverlayManager().hide();
                              } catch (e) {
                                log.error('Error hiding overlay: $e');
                              }
                            },
                            child: const Text('Dismiss'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Extension to help with FocusManager and keyboard dismissal
extension KeyboardDismissalExtension on Widget {
  /// Wraps the widget with a GestureDetector to dismiss keyboard when tapped
  Widget dismissKeyboardOnTap(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: this,
    );
  }
} 
                                ErrorOverlayManager().hide();
                              } catch (e) {
                                log.error('Error hiding overlay: $e');
                              }
                            },
                            child: const Text('Dismiss'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }