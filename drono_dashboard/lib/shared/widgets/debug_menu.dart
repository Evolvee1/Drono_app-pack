import 'package:flutter/material.dart';
import '../../utils/web_logger.dart';
import '../../utils/error_overlay.dart';

class DebugMenu extends StatelessWidget {
  const DebugMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.bug_report,
        color: Colors.grey.withOpacity(0.5),
      ),
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'download_logs',
          child: Row(
            children: [
              Icon(Icons.download),
              SizedBox(width: 8),
              Text('Download Error Logs'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'show_overlay',
          child: Row(
            children: [
              Icon(Icons.warning),
              SizedBox(width: 8),
              Text('Show Test Error Overlay'),
            ],
          ),
        ),
      ],
      onSelected: (String value) {
        switch (value) {
          case 'download_logs':
            WebLogger.downloadLogs();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logs downloaded to your downloads folder'),
                duration: Duration(seconds: 2),
              ),
            );
            break;
          case 'show_overlay':
            // Show the error overlay for testing instead of causing an actual error
            ErrorOverlayManager().show('This is a test error message. You can dismiss this overlay.');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Test error overlay displayed'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
            break;
        }
      },
    );
  }
} 