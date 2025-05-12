import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../../../core/services/device_service.dart';
import '../presentation/widgets/performance_metrics_widget.dart';
import '../presentation/widgets/device_details_panel.dart';
import '../presentation/widgets/command_history_widget.dart';
import '../presentation/widgets/batch_operations_widget.dart';
import '../presentation/widgets/custom_workflow_widget.dart';
import '../presentation/widgets/system_alerts_widget.dart';
import '../presentation/widgets/session_history_widget.dart';

final deviceServiceProvider = Provider((ref) => DeviceService());

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  StreamSubscription? _deviceSubscription;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _commands = [];
  List<Map<String, dynamic>> _savedWorkflows = [];
  List<Map<String, dynamic>> _sessionHistory = []; // Store session history
  
  // Map to store device colors for sessions
  Map<String, Color> _deviceSessionColors = {};
  
  // Track selected devices in the devices list
  Set<String> _selectedDevices = {};

  // Historical data for performance metrics
  Map<String, List<double>> _historicalData = {
    'cpu': [],
    'memory': [],
    'uptime': [],
    'temperature': [],
    'network': [],
  };

  @override
  void initState() {
    super.initState();
    _setupDeviceStream();
    _loadData();
    
    // Initialize with mock data for demo purposes
    _initMockData();

    // Set up timer to simulate changing resource usage if no real data
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _updateMetricsData();
      }
    });
  }

  void _initMockData() {
    // Mock device data
    _devices = [
      {
        'id': 'XYZ123',
        'name': 'Samsung Galaxy S21',
        'model': 'SM-G991U',
        'status': 'online',
        'os_version': 'Android 12',
        'cpu_info': 'Snapdragon 888',
        'ram_size': '8 GB',
        'storage_size': '128 GB',
        'cpu_usage': 42,
        'memory_usage': 65,
        'battery': '78%',
        'uptime': 24.5, // 24.5 hours
        'temperature': 38,
        'network_usage': 125,
        'last_seen': DateTime.now().toIso8601String(),
        'serial': 'R58M42ABCDE',
        'sim_status': 'Active',
        'sim_provider': 'AT&T'
      },
      {
        'id': 'ABC456',
        'name': 'Google Pixel 6',
        'model': 'GR1YH',
        'status': 'online',
        'os_version': 'Android 13',
        'cpu_info': 'Google Tensor',
        'ram_size': '12 GB',
        'storage_size': '256 GB',
        'cpu_usage': 35,
        'memory_usage': 48,
        'battery': '45%',
        'uptime': 12.75, // 12.75 hours
        'temperature': 42,
        'network_usage': 87,
        'last_seen': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        'serial': 'PX6729FGHIJ',
        'sim_status': 'Active',
        'sim_provider': 'T-Mobile'
      },
      {
        'id': 'DEF789',
        'name': 'OnePlus 9 Pro',
        'model': 'LE2121',
        'status': 'offline',
        'os_version': 'Android 12',
        'cpu_info': 'Snapdragon 888',
        'ram_size': '12 GB',
        'storage_size': '256 GB',
        'cpu_usage': 0,
        'memory_usage': 0,
        'battery': '9%',
        'uptime': 48.2, // 48.2 hours
        'temperature': 25,
        'network_usage': 0,
        'last_seen': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'serial': 'OP9P15KLMNO',
        'sim_status': 'Inactive',
        'sim_provider': 'Verizon'
      }
    ];
    
    // Mock session history
    final now = DateTime.now();
    
    _sessionHistory = [
      {
        'id': 'session_1',
        'name': 'Veewoy Traffic Test',
        'command': 'start',
        'parameters': {
          'url': 'https://veewoy.com/ip-text',
          'iterations': '500',
          'delay': '2',
          'webview_mode': 'true',
          'rotate_ip': 'true'
        },
        'device_count': 2,
        'device_ids': ['XYZ123', 'ABC456'],
        'started_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
        'ended_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'duration_minutes': 120,
        'status': 'completed',
        'color': Colors.blue.shade100,
      },
      {
        'id': 'session_2',
        'name': 'Instagram Profile Views',
        'command': 'start',
        'parameters': {
          'url': 'https://instagram.com/some_profile',
          'iterations': '250',
          'delay': '3',
          'webview_mode': 'true',
          'aggressive_clearing': 'true'
        },
        'device_count': 1,
        'device_ids': ['DEF789'],
        'started_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'ended_at': now.subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(),
        'duration_minutes': 30,
        'status': 'completed',
        'color': Colors.green.shade100,
      },
      {
        'id': 'session_3',
        'name': 'Test Run - All Devices',
        'command': 'status',
        'parameters': {},
        'device_count': 3,
        'device_ids': ['XYZ123', 'ABC456', 'DEF789'],
        'started_at': now.subtract(const Duration(minutes: 15)).toIso8601String(),
        'ended_at': now.subtract(const Duration(minutes: 14)).toIso8601String(),
        'duration_minutes': 1,
        'status': 'completed',
        'color': Colors.purple.shade100,
      },
    ];
    
    // Set up device colors from session history
    _deviceSessionColors = {
      'XYZ123': Colors.blue.shade100,
      'ABC456': Colors.blue.shade100,
      'DEF789': Colors.green.shade100,
    };
    
    // Mock alerts
    _alerts = [
      {
        'id': 'alert_1',
        'title': 'Device Disconnected',
        'message': 'Device XYZ123 has disconnected unexpectedly.',
        'device_id': 'XYZ123',
        'severity': 'warning',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'muted': false,
      },
      {
        'id': 'alert_2',
        'title': 'High CPU Usage',
        'message': 'Device ABC456 is experiencing high CPU usage (92%).',
        'device_id': 'ABC456',
        'severity': 'error',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        'muted': true,
      },
      {
        'id': 'alert_3',
        'title': 'Low Battery',
        'message': 'Device DEF789 battery level is below 10%.',
        'device_id': 'DEF789',
        'severity': 'critical',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        'muted': false,
      },
    ];
    
    // Mock command history
    _commands = [
      {
        'id': 'cmd_1',
        'device_id': 'XYZ123',
        'type': 'start',
        'parameters': {'url': 'https://example.com', 'iterations': '10', 'delay': '2'},
        'status': 'completed',
        'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'completed_at': DateTime.now().subtract(const Duration(minutes: 50)).toIso8601String(),
        'result': {'success': true, 'sessions': 10},
      },
      {
        'id': 'cmd_2',
        'device_id': 'ABC456',
        'type': 'stop',
        'parameters': {},
        'status': 'completed',
        'created_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
        'completed_at': DateTime.now().subtract(const Duration(minutes: 29)).toIso8601String(),
        'result': {'success': true},
      },
      {
        'id': 'cmd_3',
        'device_id': 'DEF789',
        'type': 'status',
        'parameters': {},
        'status': 'failed',
        'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        'completed_at': DateTime.now().subtract(const Duration(minutes: 9)).toIso8601String(),
        'error': 'Device not responding',
      },
    ];
    
    // Mock saved workflows
    _savedWorkflows = [
      {
        'id': 'workflow_1',
        'name': 'Basic Traffic Simulation',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'steps': [
          {
            'command': 'status',
            'device_id': 'XYZ123',
            'parameters': {},
          },
          {
            'command': 'start',
            'device_id': 'XYZ123',
            'parameters': {'url': 'https://example.com', 'iterations': '5', 'delay': '2'},
          },
          {
            'command': 'wait',
            'parameters': {'seconds': '30'},
          },
          {
            'command': 'stop',
            'device_id': 'XYZ123',
            'parameters': {},
          },
        ],
      },
    ];
    
    // Initialize historical data with some values
    for (int i = 0; i < 20; i++) {
      _historicalData['cpu']!.add(25.0 + (i % 30));
      _historicalData['memory']!.add(40.0 + (i % 20));
      _historicalData['uptime']!.add(i * 5.0); // Uptime increasing over time
      _historicalData['temperature']!.add(30.0 + (i % 15));
      _historicalData['network']!.add(50.0 + (i * 5));
    }
  }

  void _updateMetricsData() {
    // Get current values or use random if unavailable
    double cpu = 0.0;
    double memory = 0.0;
    double uptime = 0.0;
    double temperature = 0.0;
    double network = 0.0;
    
    if (_devices.isNotEmpty) {
      final device = _devices[0];
      
      // Extract values from device data if available, otherwise simulate
      cpu = device['cpu_usage']?.toDouble() ?? (25.0 + (DateTime.now().second % 30));
      memory = device['memory_usage']?.toDouble() ?? (40.0 + (DateTime.now().second % 20));
      
      // Get uptime in hours from the device data
      uptime = device['uptime']?.toDouble() ?? 0.0;
      
      // If we have no uptime data, calculate a mock value based on the last seen timestamp
      if (uptime == 0.0 && device['last_seen'] != null) {
        try {
          final lastSeen = DateTime.parse(device['last_seen'].toString());
          final uptimeHours = DateTime.now().difference(lastSeen).inHours.toDouble();
          uptime = uptimeHours > 0 ? uptimeHours : 0.5; // At least 30 minutes
        } catch (e) {
          uptime = 24.0; // Default to 24 hours if parsing fails
        }
      }
      
      temperature = device['temperature']?.toDouble() ?? (30 + (DateTime.now().second % 10));
      network = device['network_usage']?.toDouble() ?? (100 + (DateTime.now().second % 100));
    } else {
      // Simulate data if no devices available
      cpu = 25.0 + (DateTime.now().second % 30);
      memory = 40.0 + (DateTime.now().second % 20);
      uptime = 24.0 + (DateTime.now().hour % 72); // 1-3 days of uptime
      temperature = 30 + (DateTime.now().second % 10);
      network = 100 + (DateTime.now().second % 100);
    }
    
    // Add a small random variation to make charts more dynamic
    cpu += (DateTime.now().millisecond % 10) - 5;
    memory += (DateTime.now().millisecond % 8) - 4;
    // Don't add variation to uptime as it should only increase
    temperature += (DateTime.now().millisecond % 6) - 3;
    network += (DateTime.now().millisecond % 20) - 10;
    
    // Ensure values stay in reasonable ranges
    cpu = cpu.clamp(0, 100);
    memory = memory.clamp(0, 100);
    uptime = uptime.clamp(0, 720); // Up to 30 days (720 hours)
    temperature = temperature.clamp(20, 60);
    network = network.clamp(0, 500);
    
    // Update historical data (keep only last 50 points)
    const maxHistoryPoints = 50;
    
    setState(() {
      _historicalData['cpu']!.add(cpu);
      if (_historicalData['cpu']!.length > maxHistoryPoints) {
        _historicalData['cpu']!.removeAt(0);
      }
      
      _historicalData['memory']!.add(memory);
      if (_historicalData['memory']!.length > maxHistoryPoints) {
        _historicalData['memory']!.removeAt(0);
      }
      
      // For uptime, make sure it's always increasing
      final lastUptime = _historicalData['uptime']!.isNotEmpty 
          ? _historicalData['uptime']!.last 
          : 0.0;
      _historicalData['uptime']!.add(uptime > lastUptime ? uptime : lastUptime + 0.1);
      if (_historicalData['uptime']!.length > maxHistoryPoints) {
        _historicalData['uptime']!.removeAt(0);
      }
      
      _historicalData['temperature']!.add(temperature);
      if (_historicalData['temperature']!.length > maxHistoryPoints) {
        _historicalData['temperature']!.removeAt(0);
      }
      
      _historicalData['network']!.add(network);
      if (_historicalData['network']!.length > maxHistoryPoints) {
        _historicalData['network']!.removeAt(0);
      }
    });
  }

  void _setupDeviceStream() {
    final deviceService = ref.read(deviceServiceProvider);
    _deviceSubscription = deviceService.deviceStream.listen(
      (devices) {
        setState(() {
          _devices = devices;
          
          // Always show a note about WebSocket - this is for demo purposes 
          // and to explain why data might be delayed
          _error = "Note: Using HTTP polling for updates. WebSocket may be disconnected.";
        });
      },
      onError: (error) {
        setState(() {
          _error = "Connection issue: $error\nFalling back to HTTP polling for updates.";
        });
        
        // If WebSocket fails, fall back to periodic polling
        Timer.periodic(const Duration(seconds: 10), (timer) {
          if (mounted) {
            _loadData();
          }
        });
      },
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceService = ref.read(deviceServiceProvider);
      await deviceService.getDevices();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onDismissAlert(String alertId) {
    setState(() {
      _alerts.removeWhere((alert) => alert['id'] == alertId);
    });
  }

  void _onMuteAlert(String alertId, bool mute) {
    setState(() {
      final alertIndex = _alerts.indexWhere((alert) => alert['id'] == alertId);
      if (alertIndex != -1) {
        _alerts[alertIndex] = {
          ..._alerts[alertIndex],
          'muted': mute,
        };
      }
    });
  }

  void _onDeviceSelected(String deviceId) {
    // Implementation for filtering by device
  }

  void _onCommandTypeSelected(String type) {
    // Implementation for filtering by command type
  }

  void _onStatusSelected(String status) {
    // Implementation for filtering by status
  }

  void _onExecuteBatchCommand(List<String> deviceIds, String command, Map<String, dynamic> parameters, String sessionName) {
    final newCommandId = 'cmd_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    
    // Use sessionName if provided, or generate one
    final effectiveSessionName = sessionName.isNotEmpty 
        ? sessionName 
        : 'Session ${DateFormat('yyyy-MM-dd HH:mm').format(now)}';
    
    // Create a new session record
    final sessionId = 'session_${now.millisecondsSinceEpoch}';
    final sessionColor = Colors.primaries[now.millisecondsSinceEpoch % Colors.primaries.length];
    
    final newSession = {
      'id': sessionId,
      'name': effectiveSessionName,
      'command': command,
      'parameters': parameters,
      'device_count': deviceIds.length,
      'device_ids': deviceIds,
      'started_at': nowIso,
      'ended_at': null,
      'duration_minutes': 0,
      'status': 'running',
      'color': sessionColor,
    };
    
    // Add session to history
    setState(() {
      _sessionHistory.add(newSession);
      
      // Update device colors for the UI
      for (final deviceId in deviceIds) {
        _deviceSessionColors[deviceId] = sessionColor;
      }
      
      // Add a new command for each device
      for (final deviceId in deviceIds) {
        _commands.add({
          'id': '${newCommandId}_$deviceId',
          'device_id': deviceId,
          'type': command,
          'parameters': parameters,
          'status': 'pending',
          'session_id': sessionId,
          'session_name': effectiveSessionName,
          'created_at': nowIso,
          'completed_at': null,
        });
      }
    });
    
    // Execute the batch command using the device service
    final deviceService = ref.read(deviceServiceProvider);
    
    // Execute batch command for all devices at once
    deviceService.executeBatchCommand(deviceIds, command, parameters).then((response) {
      // Update command status based on response
      setState(() {
        if (response['success'] == true) {
          // Update the UI with successful execution
          for (final deviceId in deviceIds) {
            final index = _commands.indexWhere((cmd) => 
              cmd['id'] == '${newCommandId}_$deviceId' && 
              cmd['device_id'] == deviceId);
            
            if (index >= 0) {
              _commands[index]['status'] = 'success';
              _commands[index]['completed_at'] = DateTime.now().toIso8601String();
            }
          }
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully executed $command on ${deviceIds.length} devices'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Update UI with failure status
          for (final deviceId in deviceIds) {
            final index = _commands.indexWhere((cmd) => 
              cmd['id'] == '${newCommandId}_$deviceId' && 
              cmd['device_id'] == deviceId);
            
            if (index >= 0) {
              _commands[index]['status'] = 'failed';
              _commands[index]['completed_at'] = DateTime.now().toIso8601String();
              _commands[index]['error'] = response['message'] ?? 'Unknown error';
            }
          }
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error executing commands: ${response['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        // Update session status
        final sessionIndex = _sessionHistory.indexWhere((s) => s['id'] == sessionId);
        if (sessionIndex >= 0) {
          _sessionHistory[sessionIndex]['status'] = response['success'] == true ? 'completed' : 'failed';
          _sessionHistory[sessionIndex]['ended_at'] = DateTime.now().toIso8601String();
          
          // Calculate duration
          final startTime = DateTime.parse(_sessionHistory[sessionIndex]['started_at']);
          final endTime = DateTime.now();
          final durationMinutes = endTime.difference(startTime).inMinutes;
          _sessionHistory[sessionIndex]['duration_minutes'] = durationMinutes;
        }
      });
    }).catchError((error) {
      // Handle any unexpected errors
      setState(() {
        // Mark all commands as failed
        for (final deviceId in deviceIds) {
          final index = _commands.indexWhere((cmd) => 
            cmd['id'] == '${newCommandId}_$deviceId' && 
            cmd['device_id'] == deviceId);
          
          if (index >= 0) {
            _commands[index]['status'] = 'failed';
            _commands[index]['completed_at'] = DateTime.now().toIso8601String();
            _commands[index]['error'] = error.toString();
          }
        }
        
        // Update session status
        final sessionIndex = _sessionHistory.indexWhere((s) => s['id'] == sessionId);
        if (sessionIndex >= 0) {
          _sessionHistory[sessionIndex]['status'] = 'failed';
          _sessionHistory[sessionIndex]['ended_at'] = DateTime.now().toIso8601String();
          
          // Calculate duration
          final startTime = DateTime.parse(_sessionHistory[sessionIndex]['started_at']);
          final endTime = DateTime.now();
          final durationMinutes = endTime.difference(startTime).inMinutes;
          _sessionHistory[sessionIndex]['duration_minutes'] = durationMinutes;
        }
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error executing commands: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _onSaveWorkflow(Map<String, dynamic> workflow) {
    setState(() {
      _savedWorkflows.add(workflow);
    });
  }

  void _onDeleteWorkflow(String workflowId) {
    setState(() {
      _savedWorkflows.removeWhere((w) => w['id'] == workflowId);
    });
  }

  void _onRunWorkflow(Map<String, dynamic> workflow) {
    // Implementation for running workflows
    final steps = workflow['steps'] as List?;
    if (steps == null || steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow has no steps to execute')),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Running workflow: ${workflow['name']}')),
    );
    
    // For demo purposes, just create a command for each step
    final now = DateTime.now();
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final commandType = step['command'];
      
      if (commandType == 'wait') {
        // Skip wait steps in the simulation
        continue;
      }
      
      final deviceId = step['device_id'];
      final parameters = step['parameters'] ?? {};
      
      // Add a new command with a slight delay for each step
      Future.delayed(Duration(seconds: i), () {
        setState(() {
          final newCommandId = 'workflow_cmd_${now.millisecondsSinceEpoch}_$i';
          _commands.add({
            'id': newCommandId,
            'device_id': deviceId,
            'type': commandType,
            'parameters': parameters,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
            'completed_at': null,
          });
          
          // Simulate command completion
          Future.delayed(const Duration(seconds: 1), () {
            setState(() {
              final index = _commands.indexWhere((cmd) => cmd['id'] == newCommandId);
              if (index != -1) {
                _commands[index] = {
                  ..._commands[index],
                  'status': 'completed',
                  'completed_at': DateTime.now().toIso8601String(),
                  'result': {'success': true},
                };
              }
            });
          });
        });
      });
    }
  }

  // New method to handle device selection
  void _onDeviceSelectionChanged(String deviceId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedDevices.add(deviceId);
      } else {
        _selectedDevices.remove(deviceId);
      }
    });
  }
  
  // Method to show command dialog for selected devices
  void _showCommandDialogForSelectedDevices() {
    if (_selectedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices selected')),
      );
      return;
    }
    
    // Get list of selected device objects
    final selectedDeviceList = _devices.where(
      (device) => _selectedDevices.contains(device['id']?.toString())
    ).toList();
    
    // Use the same dialog that's used in batch operations
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Run Command on ${_selectedDevices.length} Selected Devices'),
        content: SizedBox(
          width: double.maxFinite,
          child: BatchOperationsWidget(
            devices: selectedDeviceList,
            onExecuteBatchCommand: _onExecuteBatchCommand,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _error!.contains("Note:") ? Colors.blue.shade100 : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _error!.contains("Note:") ? Colors.blue.shade300 : Colors.amber.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _error!.contains("Note:") ? Icons.info : Icons.warning,
                                color: _error!.contains("Note:") ? Colors.blue : Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: _error!.contains("Note:") ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Real-time performance metrics (horizontal at the top)
                    PerformanceMetricsWidget(
                      devices: _devices,
                      historicalData: _historicalData,
                    ),
                    const SizedBox(height: 24),
                    
                    // System alerts
                    SystemAlertsWidget(
                      alerts: _alerts,
                      onDismissAlert: _onDismissAlert,
                      onMuteAlert: _onMuteAlert,
                    ),
                    const SizedBox(height: 24),
                    
                    // Device details section with selection controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Device Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_devices.isNotEmpty && _selectedDevices.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _showCommandDialogForSelectedDevices,
                            icon: const Icon(Icons.send),
                            label: Text('Run on ${_selectedDevices.length} Selected Devices'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_devices.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No devices available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final deviceId = device['id']?.toString() ?? '';
                          return DeviceDetailsPanel(
                            device: device,
                            isSelected: _selectedDevices.contains(deviceId),
                            onSelect: device['status'] == 'online' ? _onDeviceSelectionChanged : null,
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    
                    // Batch operations
                    BatchOperationsWidget(
                      devices: _devices,
                      onExecuteBatchCommand: _onExecuteBatchCommand,
                    ),
                    const SizedBox(height: 24),
                    
                    // Session History
                    SessionHistoryWidget(
                      sessions: _sessionHistory,
                      deviceColors: _deviceSessionColors,
                      devices: _devices,
                    ),
                    const SizedBox(height: 24),
                    
                    // Command history
                    CommandHistoryWidget(
                      commands: _commands,
                      onDeviceSelected: _onDeviceSelected,
                      onCommandTypeSelected: _onCommandTypeSelected,
                      onStatusSelected: _onStatusSelected,
                    ),
                    const SizedBox(height: 24),
                    
                    // Custom automation workflows
                    CustomWorkflowWidget(
                      devices: _devices,
                      savedWorkflows: _savedWorkflows,
                      onSaveWorkflow: _onSaveWorkflow,
                      onDeleteWorkflow: _onDeleteWorkflow,
                      onRunWorkflow: _onRunWorkflow,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
} 
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _error!.contains("Note:") ? Colors.blue.shade100 : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _error!.contains("Note:") ? Colors.blue.shade300 : Colors.amber.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _error!.contains("Note:") ? Icons.info : Icons.warning,
                                color: _error!.contains("Note:") ? Colors.blue : Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: _error!.contains("Note:") ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Real-time performance metrics (horizontal at the top)
                    PerformanceMetricsWidget(
                      devices: _devices,
                      historicalData: _historicalData,
                    ),
                    const SizedBox(height: 24),
                    
                    // System alerts
                    SystemAlertsWidget(
                      alerts: _alerts,
                      onDismissAlert: _onDismissAlert,
                      onMuteAlert: _onMuteAlert,
                    ),
                    const SizedBox(height: 24),
                    
                    // Device details section with selection controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Device Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_devices.isNotEmpty && _selectedDevices.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _showCommandDialogForSelectedDevices,
                            icon: const Icon(Icons.send),
                            label: Text('Run on ${_selectedDevices.length} Selected Devices'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_devices.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No devices available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final deviceId = device['id']?.toString() ?? '';
                          return DeviceDetailsPanel(
                            device: device,
                            isSelected: _selectedDevices.contains(deviceId),
                            onSelect: device['status'] == 'online' ? _onDeviceSelectionChanged : null,
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    
                    // Batch operations
                    BatchOperationsWidget(
                      devices: _devices,
                      onExecuteBatchCommand: _onExecuteBatchCommand,
                    ),
                    const SizedBox(height: 24),
                    
                    // Session History
                    SessionHistoryWidget(
                      sessions: _sessionHistory,
                      deviceColors: _deviceSessionColors,
                      devices: _devices,
                    ),
                    const SizedBox(height: 24),
                    
                    // Command history
                    CommandHistoryWidget(
                      commands: _commands,
                      onDeviceSelected: _onDeviceSelected,
                      onCommandTypeSelected: _onCommandTypeSelected,
                      onStatusSelected: _onStatusSelected,
                    ),
                    const SizedBox(height: 24),
                    
                    // Custom automation workflows
                    CustomWorkflowWidget(
                      devices: _devices,
                      savedWorkflows: _savedWorkflows,
                      onSaveWorkflow: _onSaveWorkflow,
                      onDeleteWorkflow: _onDeleteWorkflow,
                      onRunWorkflow: _onRunWorkflow,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }