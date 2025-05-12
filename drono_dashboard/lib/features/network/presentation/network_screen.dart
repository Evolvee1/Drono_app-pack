import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/services/device_service.dart';

final deviceServiceProvider = Provider((ref) => DeviceService());

class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  StreamSubscription? _deviceSubscription;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _devices = [];

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

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network'),
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
                      _buildNetworkStatusSection(),
                      const SizedBox(height: 24),
                      _buildDeviceConnectionsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNetworkStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    'Connected Devices',
                    _devices.length.toString(),
                    Icons.devices,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatusCard(
                    'Active Connections',
                    _devices.where((d) => d['status'] == 'online').length.toString(),
                    Icons.link,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceConnectionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Connections',
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
                  
                  // Handle both formats of last_seen field
                  String lastSeen = device['lastSeen'] != null
                      ? device['lastSeen']
                      : device['last_seen'] != null
                          ? device['last_seen']
                          : 'Unknown';
                  
                  return ListTile(
                    leading: Icon(
                      device['status'] == 'online'
                          ? Icons.check_circle
                          : Icons.error,
                      color: device['status'] == 'online'
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text(device['name'] ?? 'Unknown Device'),
                    subtitle: Text(device['model'] ?? 'Unknown Model'),
                    trailing: Text(lastSeen),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 