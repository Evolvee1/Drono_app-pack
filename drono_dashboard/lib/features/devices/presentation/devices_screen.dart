import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/services/device_service.dart';
import '../../../features/monitoring/presentation/widgets/batch_operations_widget.dart';

final deviceServiceProvider = Provider((ref) => DeviceService());

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  StreamSubscription? _deviceSubscription;
  bool _isLoading = false;
  String? _error;
  bool _isExecutingCommand = false;
  String? _commandStatus;
  // Set to track selected device IDs
  Set<String> _selectedDeviceIds = {};

  @override
  void initState() {
    super.initState();
    _setupDeviceStream();
    _loadDevices();
  }

  void _setupDeviceStream() {
    final deviceService = ref.read(deviceServiceProvider);
    _deviceSubscription = deviceService.deviceStream.listen(
      (devices) {
        setState(() {
          _error = null;
        });
      },
      onError: (error) {
        setState(() {
          _error = error.toString();
        });
      },
    );
  }

  Future<void> _loadDevices() async {
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

  Future<void> _scanDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceService = ref.read(deviceServiceProvider);
      await deviceService.scanDevices();
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

  Future<void> _executeCommand(String deviceId, String command, Map<String, dynamic> params) async {
    // Don't execute if already executing a command
    if (_isExecutingCommand) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command execution in progress. Please wait.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Show configuration dialog for start command
    if (command == 'start') {
      final result = await _showStartCommandDialog(deviceId);
      if (result == null) {
        // User cancelled
        return;
      }
      // Use the parameters from the dialog
      params = result;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
      _isExecutingCommand = true;
      _commandStatus = 'Executing $command on device $deviceId...';
    });

    try {
      final deviceService = ref.read(deviceServiceProvider);
      final result = await deviceService.executeCommand(deviceId, command, params);
      
      if (mounted) {
        if (result['success'] == false) {
          throw Exception(result['error'] ?? 'Unknown error');
        }
        
        // Check if this was a simulated success
        final bool isSimulated = result['simulated'] == true;
        final String message = isSimulated 
            ? 'Command sent, but server response was unavailable' 
            : 'Command $command executed successfully';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isSimulated ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _commandStatus = message;
          
          // If there was an error message, store it but don't show an error UI
          if (result['error_message'] != null) {
            _error = 'Warning: ${result['error_message']}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _commandStatus = 'Command execution failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isExecutingCommand = false;
        });
        
        // Refresh device list after command execution
        _loadDevices();
      }
    }
  }

  Future<Map<String, dynamic>?> _showStartCommandDialog(String deviceId) async {
    final TextEditingController urlController = TextEditingController(text: 'https://example.com');
    final TextEditingController iterationsController = TextEditingController(text: '100');
    final TextEditingController minIntervalController = TextEditingController(text: '1');
    final TextEditingController maxIntervalController = TextEditingController(text: '3');
    bool dismissRestore = true;
    bool webviewMode = false;
    bool rotateIp = true;
    
    // Function to update the command preview
    String getCommandPreview() {
      String cmd = './drono_control.sh -settings';
      if (dismissRestore) cmd += ' dismiss_restore';
      if (urlController.text.isNotEmpty) cmd += ' url ${urlController.text}';
      if (iterationsController.text.isNotEmpty) cmd += ' iterations ${iterationsController.text}';
      if (minIntervalController.text.isNotEmpty) cmd += ' min_interval ${minIntervalController.text}';
      if (maxIntervalController.text.isNotEmpty) cmd += ' max_interval ${maxIntervalController.text}';
      if (webviewMode) cmd += ' toggle webview_mode true';
      if (rotateIp) cmd += ' toggle rotate_ip true';
      cmd += ' start';
      return cmd;
    }
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Configure Start Command'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7, // Limit to 70% of screen height
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'Enter URL to load',
                    ),
                    onChanged: (_) => setState(() {}), // Update preview
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: iterationsController,
                    decoration: const InputDecoration(
                      labelText: 'Iterations',
                      hintText: 'Number of iterations',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}), // Update preview
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minIntervalController,
                          decoration: const InputDecoration(
                            labelText: 'Min Interval',
                            hintText: 'Min seconds',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}), // Update preview
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxIntervalController,
                          decoration: const InputDecoration(
                            labelText: 'Max Interval',
                            hintText: 'Max seconds',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}), // Update preview
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Dismiss Restore'),
                    subtitle: const Text('Skip session recovery'),
                    value: dismissRestore,
                    onChanged: (value) {
                      setState(() => dismissRestore = value ?? true);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('WebView Mode'),
                    subtitle: const Text('Use WebView instead of native app'),
                    value: webviewMode,
                    onChanged: (value) {
                      setState(() => webviewMode = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Rotate IP'),
                    subtitle: const Text('Enable IP rotation'),
                    value: rotateIp,
                    onChanged: (value) {
                      setState(() => rotateIp = value ?? true);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Command Preview:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      getCommandPreview(),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Parse values and validate
                int? iterations = int.tryParse(iterationsController.text);
                double? minInterval = double.tryParse(minIntervalController.text);
                double? maxInterval = double.tryParse(maxIntervalController.text);
                
                if (urlController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL is required')),
                  );
                  return;
                }
                
                if (iterations == null || iterations <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Iterations must be a positive number')),
                  );
                  return;
                }
                
                if (minInterval == null || minInterval < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Min interval must be a non-negative number')),
                  );
                  return;
                }
                
                if (maxInterval == null || maxInterval < minInterval) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Max interval must be greater than min interval')),
                  );
                  return;
                }
                
                Navigator.of(context).pop({
                  'url': urlController.text,
                  'iterations': iterations,
                  'min_interval': minInterval,
                  'max_interval': maxInterval,
                  'dismiss_restore': dismissRestore,
                  'webview_mode': webviewMode,
                  'rotate_ip': rotateIp,
                });
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
    
    // Clean up controllers
    urlController.dispose();
    iterationsController.dispose();
    minIntervalController.dispose();
    maxIntervalController.dispose();
    
    return result;
  }

  void _showDeviceSettings(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Check Status'),
              onTap: () {
                _executeCommand(deviceId, 'status', {});
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Update Firmware'),
              onTap: () {
                _executeCommand(deviceId, 'update_firmware', {});
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Factory Reset'),
              onTap: () {
                _executeCommand(deviceId, 'factory_reset', {});
                Navigator.pop(context);
              },
            ),
          ],
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

  // Execute batch command on selected devices
  Future<void> _executeBatchCommand(List<String> deviceIds, String command, Map<String, dynamic> params, String sessionName) async {
    if (deviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices selected')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
      _isExecutingCommand = true;
      _commandStatus = 'Executing $command on ${deviceIds.length} devices...';
    });

    try {
      final deviceService = ref.read(deviceServiceProvider);
      final result = await deviceService.executeBatchCommand(deviceIds, command, params);
      
      if (mounted) {
        if (result['success'] == false) {
          throw Exception(result['error'] ?? 'Unknown error');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Command $command executed on ${deviceIds.length} devices'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _commandStatus = 'Command executed successfully on ${deviceIds.length} devices';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _commandStatus = 'Command execution failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isExecutingCommand = false;
        });
        
        // Refresh device list after command execution
        _loadDevices();
      }
    }
  }
  
  // Show batch start command dialog for selected devices
  void _showBatchStartCommandDialog() async {
    if (_selectedDeviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices selected')),
      );
      return;
    }

    // Use the same dialog as single-device start, but for all selected devices
    final TextEditingController urlController = TextEditingController(text: 'https://example.com');
    final TextEditingController iterationsController = TextEditingController(text: '100');
    final TextEditingController minIntervalController = TextEditingController(text: '1');
    final TextEditingController maxIntervalController = TextEditingController(text: '3');
    bool dismissRestore = true;
    bool webviewMode = false;
    bool rotateIp = true;
    final TextEditingController sessionNameController = TextEditingController();

    String getCommandPreview() {
      String url = urlController.text;
      if (!url.startsWith('"')) url = '"' + url;
      if (!url.endsWith('"')) url = url + '"';
      String cmd = './drono_control.sh -settings';
      if (dismissRestore) cmd += ' dismiss_restore';
      if (urlController.text.isNotEmpty) cmd += ' url ' + url;
      if (iterationsController.text.isNotEmpty) cmd += ' iterations ${iterationsController.text}';
      if (minIntervalController.text.isNotEmpty) cmd += ' min_interval ${minIntervalController.text}';
      if (maxIntervalController.text.isNotEmpty) cmd += ' max_interval ${maxIntervalController.text}';
      if (webviewMode) cmd += ' toggle webview_mode true';
      if (rotateIp) cmd += ' toggle rotate_ip true';
      cmd += ' start';
      return cmd;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Configure Start Command for Selected Devices'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'Enter URL to load',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: iterationsController,
                    decoration: const InputDecoration(
                      labelText: 'Iterations',
                      hintText: 'Number of iterations',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minIntervalController,
                          decoration: const InputDecoration(
                            labelText: 'Min Interval',
                            hintText: 'Min seconds',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxIntervalController,
                          decoration: const InputDecoration(
                            labelText: 'Max Interval',
                            hintText: 'Max seconds',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sessionNameController,
                    decoration: const InputDecoration(
                      labelText: 'Session Name (optional)',
                      hintText: 'Enter a name for this session',
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Dismiss Restore'),
                    subtitle: const Text('Skip session recovery'),
                    value: dismissRestore,
                    onChanged: (value) {
                      setState(() => dismissRestore = value ?? true);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('WebView Mode'),
                    subtitle: const Text('Use WebView instead of native app'),
                    value: webviewMode,
                    onChanged: (value) {
                      setState(() => webviewMode = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Rotate IP'),
                    subtitle: const Text('Enable IP rotation'),
                    value: rotateIp,
                    onChanged: (value) {
                      setState(() => rotateIp = value ?? true);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Command Preview:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      getCommandPreview(),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                int? iterations = int.tryParse(iterationsController.text);
                double? minInterval = double.tryParse(minIntervalController.text);
                double? maxInterval = double.tryParse(maxIntervalController.text);
                if (urlController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL is required')),
                  );
                  return;
                }
                if (iterations == null || iterations <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Iterations must be a positive number')),
                  );
                  return;
                }
                if (minInterval == null || minInterval < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Min interval must be a non-negative number')),
                  );
                  return;
                }
                if (maxInterval == null || maxInterval < minInterval) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Max interval must be greater than min interval')),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'url': urlController.text,
                  'iterations': iterations,
                  'min_interval': minInterval,
                  'max_interval': maxInterval,
                  'dismiss_restore': dismissRestore,
                  'webview_mode': webviewMode,
                  'rotate_ip': rotateIp,
                  'session_name': sessionNameController.text,
                });
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
    urlController.dispose();
    iterationsController.dispose();
    minIntervalController.dispose();
    maxIntervalController.dispose();
    sessionNameController.dispose();
    if (result != null) {
      // Use the same params for all selected devices
      _executeBatchCommand(
        _selectedDeviceIds.toList(),
        'start',
        result,
        result['session_name'] ?? '',
      );
    }
  }

  // Toggle selection of a device
  void _toggleDeviceSelection(String deviceId, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _selectedDeviceIds.add(deviceId);
      } else {
        _selectedDeviceIds.remove(deviceId);
      }
    });
  }
  
  // Select all online devices
  void _selectAllOnlineDevices() {
    final deviceService = ref.read(deviceServiceProvider);
    setState(() {
      _selectedDeviceIds = deviceService.currentDevices
          .where((device) => device['status'] == 'online')
          .map((device) => device['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    });
  }
  
  // Clear all selections
  void _clearAllSelections() {
    setState(() {
      _selectedDeviceIds.clear();
    });
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = ref.watch(deviceServiceProvider);
    final devices = deviceService.currentDevices;
    
    // Count online devices for button labels
    final onlineDeviceCount = devices.where((device) => device['status'] == 'online').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _scanDevices,
            tooltip: 'Scan for devices',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (_commandStatus != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_commandStatus!),
                    ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDevices,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : devices.isEmpty
                  ? const Center(
                      child: Text('No devices found. Try scanning for devices.'),
                    )
                  : Column(
                      children: [
                        // Selection controls and batch command button
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.select_all),
                                    label: Text('Select All ($onlineDeviceCount)'),
                                    onPressed: onlineDeviceCount > 0 ? _selectAllOnlineDevices : null,
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.deselect),
                                    label: const Text('Clear'),
                                    onPressed: _selectedDeviceIds.isNotEmpty ? _clearAllSelections : null,
                                  ),
                                ],
                              ),
                              if (_selectedDeviceIds.isNotEmpty)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.send),
                                  label: Text('Run on ${_selectedDeviceIds.length} Device${_selectedDeviceIds.length > 1 ? 's' : ''}'),
                                  onPressed: _showBatchStartCommandDialog,
                                ),
                            ],
                          ),
                        ),
                        // Device list table with selection checkboxes
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Select')),
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Model')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Battery')),
                                DataColumn(label: Text('Last Seen')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: devices.map((device) {
                                final deviceId = device['id'] ?? '';
                                final isOnline = device['status'] == 'online';
                                
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: _selectedDeviceIds.contains(deviceId),
                                        onChanged: isOnline 
                                          ? (value) => _toggleDeviceSelection(deviceId, value)
                                          : null,
                                      ),
                                    ),
                                    DataCell(Text(deviceId)),
                                    DataCell(Text(device['name'] ?? 'Unknown')),
                                    DataCell(Text(device['model'] ?? 'Unknown')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.green : Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          device['status'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(device['battery'] != null 
                                      ? device['battery']
                                      : 'Unknown')),
                                    DataCell(Text(device['lastSeen'] != null 
                                      ? _formatDateTime(device['lastSeen'])
                                      : device['last_seen'] != null 
                                        ? _formatDateTime(device['last_seen'])
                                        : 'Unknown')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: 'Start',
                                            child: IconButton(
                                              icon: const Icon(Icons.play_arrow, color: Colors.green),
                                              onPressed: _isExecutingCommand || !isOnline
                                                ? null 
                                                : () => _executeCommand(deviceId, 'start', {}),
                                            ),
                                          ),
                                          Tooltip(
                                            message: 'Pause',
                                            child: IconButton(
                                              icon: const Icon(Icons.pause, color: Colors.orange),
                                              onPressed: _isExecutingCommand || !isOnline
                                                ? null 
                                                : () => _executeCommand(deviceId, 'pause', {}),
                                            ),
                                          ),
                                          Tooltip(
                                            message: 'Stop',
                                            child: IconButton(
                                              icon: const Icon(Icons.stop, color: Colors.red),
                                              onPressed: _isExecutingCommand || !isOnline
                                                ? null 
                                                : () => _executeCommand(deviceId, 'stop', {}),
                                            ),
                                          ),
                                          Tooltip(
                                            message: 'Settings',
                                            child: IconButton(
                                              icon: const Icon(Icons.settings),
                                              onPressed: _isExecutingCommand || !isOnline
                                                ? null 
                                                : () => _showDeviceSettings(deviceId),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
  
  // Helper method to format datetime strings
  String _formatDateTime(String? dateTimeStr) {
    // Handle null or empty strings
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return 'Unknown';
    }
    
    try {
      // Parse the ISO date string
      final dateTime = DateTime.parse(dateTimeStr);
      
      // Get just the time portion if it's today
      final now = DateTime.now();
      if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      }
      
      // Otherwise show date and time
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // Just return the original string if we can't parse it
      // This avoids any substring operations that could cause RangeErrors
      return dateTimeStr;
    }
  }
} 
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Model')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Battery')),
                          DataColumn(label: Text('Last Seen')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: devices.map((device) {
                          return DataRow(
                            cells: [
                              DataCell(Text(device['id'] ?? 'Unknown')),
                              DataCell(Text(device['name'] ?? 'Unknown')),
                              DataCell(Text(device['model'] ?? 'Unknown')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (device['status'] == 'online') ? Colors.green : Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    device['status'] ?? 'Unknown',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              DataCell(Text(device['battery'] != null 
                                  ? device['battery']
                                  : 'Unknown')),
                              DataCell(Text(device['lastSeen'] != null 
                                  ? device['lastSeen'] 
                                  : device['last_seen'] != null 
                                      ? device['last_seen']
                                      : 'Unknown')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Start',
                                      child: IconButton(
                                        icon: const Icon(Icons.play_arrow, color: Colors.green),
                                        onPressed: _isExecutingCommand 
                                          ? null 
                                          : () => _executeCommand(device['id'], 'start', {}),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Pause',
                                      child: IconButton(
                                        icon: const Icon(Icons.pause, color: Colors.orange),
                                        onPressed: _isExecutingCommand 
                                          ? null 
                                          : () => _executeCommand(device['id'], 'pause', {}),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Stop',
                                      child: IconButton(
                                        icon: const Icon(Icons.stop, color: Colors.red),
                                        onPressed: _isExecutingCommand 
                                          ? null 
                                          : () => _executeCommand(device['id'], 'stop', {}),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Settings',
                                      child: IconButton(
                                        icon: const Icon(Icons.settings),
                                        onPressed: _isExecutingCommand 
                                          ? null 
                                          : () => _showDeviceSettings(device['id']),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
} 