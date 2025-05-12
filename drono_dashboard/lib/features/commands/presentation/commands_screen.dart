import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/services/device_service.dart';

final deviceServiceProvider = Provider((ref) => DeviceService());

class CommandsScreen extends ConsumerStatefulWidget {
  const CommandsScreen({super.key});

  @override
  ConsumerState<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends ConsumerState<CommandsScreen> {
  StreamSubscription? _deviceSubscription;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _commandHistory = [];

  @override
  void initState() {
    super.initState();
    _setupDeviceStream();
    _loadData();
  }

  void _setupDeviceStream() {
    final deviceService = ref.read(deviceServiceProvider);
    _deviceSubscription = deviceService.deviceStream.listen(
      (devices) {
        setState(() {
          _devices = devices;
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

  Future<void> _executeCommand(String deviceId, String command, Map<String, dynamic> params) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceService = ref.read(deviceServiceProvider);
      await deviceService.executeCommand(deviceId, command, params);
      
      if (mounted) {
        setState(() {
          _commandHistory.insert(0, {
            'deviceId': deviceId,
            'command': command,
            'params': params,
            'timestamp': DateTime.now().toString(),
            'status': 'success',
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _commandHistory.insert(0, {
            'deviceId': deviceId,
            'command': command,
            'params': params,
            'timestamp': DateTime.now().toString(),
            'status': 'error',
            'error': e.toString(),
          });
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

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commands'),
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
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommandHistorySection(),
                      const SizedBox(height: 24),
                      _buildDeviceCommandsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCommandHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Command History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_commandHistory.isEmpty)
              const Center(
                child: Text('No commands executed yet'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _commandHistory.length,
                itemBuilder: (context, index) {
                  final command = _commandHistory[index];
                  return ListTile(
                    leading: Icon(
                      command['status'] == 'success'
                          ? Icons.check_circle
                          : Icons.error,
                      color: command['status'] == 'success'
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text('${command['command']} on ${command['deviceId']}'),
                    subtitle: Text(command['timestamp']),
                    trailing: Text(command['status']),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCommandsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Commands',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_devices.isEmpty)
              const Center(
                child: Text('No devices connected'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['name'] ?? 'Unknown Device',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                              onPressed: () => _executeCommand(
                                device['id'],
                                'start',
                                {},
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause'),
                              onPressed: () => _executeCommand(
                                device['id'],
                                'pause',
                                {},
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              onPressed: () => _executeCommand(
                                device['id'],
                                'stop',
                                {},
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
} 