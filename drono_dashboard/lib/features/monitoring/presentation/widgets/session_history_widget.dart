import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionHistoryWidget extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final Map<String, Color> deviceColors;
  final List<Map<String, dynamic>> devices;
  
  const SessionHistoryWidget({
    Key? key,
    required this.sessions,
    required this.deviceColors,
    required this.devices,
  }) : super(key: key);

  @override
  State<SessionHistoryWidget> createState() => _SessionHistoryWidgetState();
}

class _SessionHistoryWidgetState extends State<SessionHistoryWidget> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  Set<String> _expandedSessions = {};
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (widget.sessions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No session history available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.sessions.length,
                itemBuilder: (context, index) {
                  // Display sessions in reverse chronological order (newest first)
                  final session = widget.sessions[widget.sessions.length - 1 - index];
                  final isExpanded = _expandedSessions.contains(session['id']);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: session['color'] ?? Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          // Session header
                          ListTile(
                            title: Text(
                              session['name'] ?? 'Unnamed Session',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Started: ${_formatDate(session['started_at'])} | Status: ${_formatStatus(session['status'])}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text('${session['device_count']} device${session['device_count'] == 1 ? '' : 's'}'),
                                  backgroundColor: session['color'] ?? Colors.grey.shade200,
                                ),
                                IconButton(
                                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedSessions.remove(session['id']);
                                      } else {
                                        _expandedSessions.add(session['id']);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // Expanded session details
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  
                                  // Session statistics
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatCard(
                                          'Command',
                                          session['command'] ?? 'Unknown',
                                          Icons.code,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildStatCard(
                                          'Duration',
                                          session['duration_minutes'] != null 
                                            ? '${session['duration_minutes']} min'
                                            : 'Running...',
                                          Icons.timer,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildStatCard(
                                          'Ended',
                                          session['ended_at'] != null
                                            ? _formatDate(session['ended_at'])
                                            : 'Not completed',
                                          Icons.event_available,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Devices used
                                  const Text(
                                    'Devices:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (session['device_ids'] as List).map((deviceId) {
                                      final device = widget.devices.firstWhere(
                                        (d) => d['id'].toString() == deviceId.toString(),
                                        orElse: () => {'name': 'Unknown Device', 'model': 'Unknown'},
                                      );
                                      
                                      return Chip(
                                        avatar: Icon(
                                          Icons.phone_android,
                                          size: 16,
                                          color: device['status'] == 'online' ? Colors.green : Colors.red,
                                        ),
                                        label: Text('${device['name']} (${device['model']})'),
                                        backgroundColor: session['color'] ?? Colors.grey.shade200,
                                      );
                                    }).toList(),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Parameters (expandable)
                                  ExpansionTile(
                                    title: const Text(
                                      'Parameters',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.grey.shade50,
                                        width: double.infinity,
                                        child: session['parameters'] != null && 
                                               (session['parameters'] as Map).isNotEmpty
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: (session['parameters'] as Map).entries.map<Widget>((entry) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${entry.key}: ',
                                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                      Expanded(
                                                        child: Text(entry.value.toString()),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            )
                                          : const Text('No parameters'),
                                      ),
                                    ],
                                  ),
                                  
                                  // Show executed command if available
                                  if (session['shell_command'] != null) ...[
                                    const SizedBox(height: 16),
                                    ExpansionTile(
                                      title: const Text(
                                        'Executed Command',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          color: Colors.grey.shade50,
                                          width: double.infinity,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Shell command:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  session['shell_command'],
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Show error message if there was one
                                              if (session['error'] != null) ...[
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'Error:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withOpacity(0.05),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.red.shade300),
                                                  ),
                                                  child: Text(
                                                    session['error'],
                                                    style: TextStyle(
                                                      color: Colors.red.shade800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    
    try {
      if (date is String) {
        final dateTime = DateTime.parse(date);
        return _dateFormat.format(dateTime);
      } else {
        return date.toString();
      }
    } catch (e) {
      return date.toString();
    }
  }
  
  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    
    switch (status.toLowerCase()) {
      case 'running':
        return 'Running';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
} 
import 'package:intl/intl.dart';

class SessionHistoryWidget extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final Map<String, Color> deviceColors;
  final List<Map<String, dynamic>> devices;
  
  const SessionHistoryWidget({
    Key? key,
    required this.sessions,
    required this.deviceColors,
    required this.devices,
  }) : super(key: key);

  @override
  State<SessionHistoryWidget> createState() => _SessionHistoryWidgetState();
}

class _SessionHistoryWidgetState extends State<SessionHistoryWidget> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  Set<String> _expandedSessions = {};
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (widget.sessions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No session history available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.sessions.length,
                itemBuilder: (context, index) {
                  // Display sessions in reverse chronological order (newest first)
                  final session = widget.sessions[widget.sessions.length - 1 - index];
                  final isExpanded = _expandedSessions.contains(session['id']);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: session['color'] ?? Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          // Session header
                          ListTile(
                            title: Text(
                              session['name'] ?? 'Unnamed Session',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Started: ${_formatDate(session['started_at'])} | Status: ${_formatStatus(session['status'])}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text('${session['device_count']} device${session['device_count'] == 1 ? '' : 's'}'),
                                  backgroundColor: session['color'] ?? Colors.grey.shade200,
                                ),
                                IconButton(
                                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedSessions.remove(session['id']);
                                      } else {
                                        _expandedSessions.add(session['id']);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // Expanded session details
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  
                                  // Session statistics
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatCard(
                                          'Command',
                                          session['command'] ?? 'Unknown',
                                          Icons.code,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildStatCard(
                                          'Duration',
                                          session['duration_minutes'] != null 
                                            ? '${session['duration_minutes']} min'
                                            : 'Running...',
                                          Icons.timer,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildStatCard(
                                          'Ended',
                                          session['ended_at'] != null
                                            ? _formatDate(session['ended_at'])
                                            : 'Not completed',
                                          Icons.event_available,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Devices used
                                  const Text(
                                    'Devices:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (session['device_ids'] as List).map((deviceId) {
                                      final device = widget.devices.firstWhere(
                                        (d) => d['id'].toString() == deviceId.toString(),
                                        orElse: () => {'name': 'Unknown Device', 'model': 'Unknown'},
                                      );
                                      
                                      return Chip(
                                        avatar: Icon(
                                          Icons.phone_android,
                                          size: 16,
                                          color: device['status'] == 'online' ? Colors.green : Colors.red,
                                        ),
                                        label: Text('${device['name']} (${device['model']})'),
                                        backgroundColor: session['color'] ?? Colors.grey.shade200,
                                      );
                                    }).toList(),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Parameters (expandable)
                                  ExpansionTile(
                                    title: const Text(
                                      'Parameters',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.grey.shade50,
                                        width: double.infinity,
                                        child: session['parameters'] != null && 
                                               (session['parameters'] as Map).isNotEmpty
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: (session['parameters'] as Map).entries.map<Widget>((entry) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${entry.key}: ',
                                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                      Expanded(
                                                        child: Text(entry.value.toString()),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            )
                                          : const Text('No parameters'),
                                      ),
                                    ],
                                  ),
                                  
                                  // Show executed command if available
                                  if (session['shell_command'] != null) ...[
                                    const SizedBox(height: 16),
                                    ExpansionTile(
                                      title: const Text(
                                        'Executed Command',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          color: Colors.grey.shade50,
                                          width: double.infinity,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Shell command:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  session['shell_command'],
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Show error message if there was one
                                              if (session['error'] != null) ...[
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'Error:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withOpacity(0.05),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.red.shade300),
                                                  ),
                                                  child: Text(
                                                    session['error'],
                                                    style: TextStyle(
                                                      color: Colors.red.shade800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    
    try {
      if (date is String) {
        final dateTime = DateTime.parse(date);
        return _dateFormat.format(dateTime);
      } else {
        return date.toString();
      }
    } catch (e) {
      return date.toString();
    }
  }
  
  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    
    switch (status.toLowerCase()) {
      case 'running':
        return 'Running';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
} 