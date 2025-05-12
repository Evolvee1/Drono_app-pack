import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SystemAlertsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> alerts;
  final Function(String) onDismissAlert;
  final Function(String, bool) onMuteAlert;
  
  const SystemAlertsWidget({
    Key? key,
    required this.alerts,
    required this.onDismissAlert,
    required this.onMuteAlert,
  }) : super(key: key);

  @override
  State<SystemAlertsWidget> createState() => _SystemAlertsWidgetState();
}

class _SystemAlertsWidgetState extends State<SystemAlertsWidget> {
  String _selectedSeverity = 'all';
  String _selectedDeviceId = 'all';
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  
  @override
  Widget build(BuildContext context) {
    // Extract all devices and ensure 'all' is an option
    final Set<String> devices = {'all'};
    for (final alert in widget.alerts) {
      if (alert['device_id'] != null) {
        devices.add(alert['device_id'].toString());
      }
    }
    
    // Filter alerts based on selection
    final filteredAlerts = widget.alerts.where((alert) {
      final matchesSeverity = _selectedSeverity == 'all' || 
          alert['severity']?.toString().toLowerCase() == _selectedSeverity;
          
      final matchesDevice = _selectedDeviceId == 'all' || 
          alert['device_id']?.toString() == _selectedDeviceId;
          
      return matchesSeverity && matchesDevice;
    }).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'System Alerts & Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildAlertCountBadge(filteredAlerts),
              ],
            ),
            const SizedBox(height: 16),
            
            // Filters
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Severity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedSeverity,
                        isExpanded: true,
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedSeverity = value;
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Severities')),
                          DropdownMenuItem(value: 'info', child: Text('Info')),
                          DropdownMenuItem(value: 'warning', child: Text('Warning')),
                          DropdownMenuItem(value: 'error', child: Text('Error')),
                          DropdownMenuItem(value: 'critical', child: Text('Critical')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Device:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedDeviceId,
                        isExpanded: true,
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedDeviceId = value;
                            });
                          }
                        },
                        items: devices.map((device) => DropdownMenuItem(
                          value: device,
                          child: Text(device == 'all' ? 'All Devices' : device),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Alerts list
            if (filteredAlerts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 48, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No alerts match your current filters',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = filteredAlerts[index];
                  return _buildAlertCard(alert);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlertCountBadge(List<Map<String, dynamic>> alerts) {
    final criticalCount = alerts.where((a) => a['severity']?.toString().toLowerCase() == 'critical').length;
    final errorCount = alerts.where((a) => a['severity']?.toString().toLowerCase() == 'error').length;
    final warningCount = alerts.where((a) => a['severity']?.toString().toLowerCase() == 'warning').length;
    final infoCount = alerts.where((a) => a['severity']?.toString().toLowerCase() == 'info').length;
    
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'All Clear',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    return Row(
      children: [
        if (criticalCount > 0)
          _buildCountBadge(criticalCount, Colors.red),
        if (errorCount > 0)
          _buildCountBadge(errorCount, Colors.deepOrange),
        if (warningCount > 0)
          _buildCountBadge(warningCount, Colors.amber),
        if (infoCount > 0)
          _buildCountBadge(infoCount, Colors.blue),
      ],
    );
  }
  
  Widget _buildCountBadge(int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final Color borderColor = _getSeverityColor(alert['severity']);
    final IconData icon = _getSeverityIcon(alert['severity']);
    final timestamp = alert['timestamp'] != null ? 
      _dateFormat.format(DateTime.parse(alert['timestamp'].toString())) : 
      'Unknown';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: borderColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert['title'] ?? 'Untitled Alert',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  timestamp,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert['message'] ?? 'No details provided'),
            if (alert['device_id'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Device: ${alert['device_id']}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(
                    alert['muted'] == true ? Icons.volume_off : Icons.volume_up,
                    size: 16,
                  ),
                  label: Text(alert['muted'] == true ? 'Unmute' : 'Mute'),
                  onPressed: () {
                    widget.onMuteAlert(
                      alert['id'].toString(),
                      !(alert['muted'] == true),
                    );
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Dismiss'),
                  onPressed: () {
                    widget.onDismissAlert(alert['id'].toString());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getSeverityColor(dynamic severity) {
    if (severity == null) return Colors.grey;
    
    final String severityStr = severity.toString().toLowerCase();
    switch (severityStr) {
      case 'critical':
        return Colors.red;
      case 'error':
        return Colors.deepOrange;
      case 'warning':
        return Colors.amber;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getSeverityIcon(dynamic severity) {
    if (severity == null) return Icons.info;
    
    final String severityStr = severity.toString().toLowerCase();
    switch (severityStr) {
      case 'critical':
        return Icons.error;
      case 'error':
        return Icons.report_problem;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.help;
    }
  }
} 