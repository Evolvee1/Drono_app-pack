import 'package:flutter/material.dart';

class DeviceDetailsPanel extends StatefulWidget {
  final Map<String, dynamic> device;
  final bool isSelected;
  final Function(String, bool)? onSelect;
  
  const DeviceDetailsPanel({
    Key? key,
    required this.device,
    this.isSelected = false,
    this.onSelect,
  }) : super(key: key);

  @override
  State<DeviceDetailsPanel> createState() => _DeviceDetailsPanelState();
}

class _DeviceDetailsPanelState extends State<DeviceDetailsPanel> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    final bool isOnline = widget.device['status'] == 'online';
    final String deviceId = widget.device['id']?.toString() ?? '';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Header with device info and expand/collapse button
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOnline)
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: (value) {
                      if (widget.onSelect != null) {
                        widget.onSelect!(deviceId, value ?? false);
                      }
                    },
                  ),
                Icon(
                  Icons.phone_android,
                  color: isOnline ? Colors.green : Colors.red,
                  size: 36,
                ),
              ],
            ),
            title: Text(
              widget.device['name'] ?? 'Unknown Device',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              widget.device['model'] ?? 'Unknown Model',
              style: const TextStyle(fontSize: 14),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.device['status'] == 'online' 
                      ? Colors.green 
                      : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.device['status'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Expanded details section
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Device details in a simple layout rather than a grid
                  Wrap(
                    spacing: 16.0,
                    runSpacing: 8.0,
                    children: [
                      _buildDetailItem(
                        icon: Icons.sd_storage, 
                        title: 'ID', 
                        value: widget.device['id'] ?? 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.battery_full, 
                        title: 'Battery', 
                        value: widget.device['battery'] ?? 'Unknown',
                        valueColor: _getBatteryValueColor(widget.device['battery']),
                      ),
                      _buildDetailItem(
                        icon: Icons.access_time, 
                        title: 'Last Seen',
                        value: _formatLastSeen(widget.device['lastSeen'] ?? widget.device['last_seen']),
                      ),
                      _buildDetailItem(
                        icon: Icons.system_update, 
                        title: 'OS Version',
                        value: widget.device['os_version'] ?? 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.memory, 
                        title: 'CPU',
                        value: widget.device['cpu_info'] ?? 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.storage, 
                        title: 'RAM',
                        value: _formatStorage(widget.device['ram_size']),
                      ),
                      _buildDetailItem(
                        icon: Icons.sd_storage, 
                        title: 'Storage',
                        value: _formatStorage(widget.device['storage_size']),
                      ),
                      _buildDetailItem(
                        icon: Icons.speed, 
                        title: 'CPU Usage',
                        value: widget.device['cpu_usage'] != null 
                          ? '${widget.device['cpu_usage'].toString()}%' 
                          : 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.dns, 
                        title: 'Memory Usage',
                        value: widget.device['memory_usage'] != null 
                          ? '${widget.device['memory_usage'].toString()}%' 
                          : 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.thermostat, 
                        title: 'Temperature',
                        value: widget.device['temperature'] != null 
                          ? '${widget.device['temperature'].toString()}°C' 
                          : 'Unknown',
                        valueColor: _getTemperatureValueColor(widget.device['temperature']),
                      ),
                      _buildDetailItem(
                        icon: Icons.devices, 
                        title: 'Serial Number',
                        value: widget.device['serial'] ?? 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.sim_card, 
                        title: 'SIM Status',
                        value: widget.device['sim_status'] ?? 'Unknown',
                      ),
                      _buildDetailItem(
                        icon: Icons.sim_card, 
                        title: 'SIM Provider',
                        value: widget.device['sim_provider'] ?? 'Unknown',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Installed Apps Section (if available)
                  if (widget.device['installed_apps'] != null) ...[
                    Row(
                      children: const [
                        Icon(Icons.apps, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Installed Apps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (widget.device['installed_apps'] as List)
                          .map((app) => Chip(
                                avatar: const Icon(Icons.android, size: 16),
                                label: Text(app.toString()),
                                backgroundColor: Colors.grey.shade200,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Unknown';
    
    // Try to handle both string timestamps and DateTime objects
    try {
      if (lastSeen is String) {
        // Assuming the format is either ISO 8601 or a simple date string
        if (lastSeen.contains('T')) {
          // ISO format likely
          final dateTime = DateTime.parse(lastSeen);
          return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        } else {
          // Already formatted
          return lastSeen;
        }
      } else {
        return 'Unknown format';
      }
    } catch (e) {
      return lastSeen.toString();
    }
  }

  String _formatStorage(dynamic size) {
    if (size == null) return 'Unknown';
    
    // Convert to string and handle different formats
    final sizeStr = size.toString();
    
    // If already has units like GB or MB, return as is
    if (sizeStr.contains('GB') || sizeStr.contains('MB')) {
      return sizeStr;
    }
    
    // Try to parse as number and format
    try {
      final sizeNum = double.parse(sizeStr);
      if (sizeNum > 1024) {
        return '${(sizeNum / 1024).toStringAsFixed(1)} GB';
      } else {
        return '$sizeStr MB';
      }
    } catch (e) {
      return sizeStr;
    }
  }
  
  Color? _getBatteryValueColor(dynamic battery) {
    if (battery == null) return null;
    
    try {
      final batteryStr = battery.toString().replaceAll('%', '').trim();
      final batteryLevel = double.tryParse(batteryStr);
      if (batteryLevel == null) return null;
      
      if (batteryLevel < 20) return Colors.red;
      if (batteryLevel < 50) return Colors.orange;
      return Colors.green;
    } catch (e) {
      return null;
    }
  }
  
  Color? _getTemperatureValueColor(dynamic temperature) {
    if (temperature == null) return null;
    
    try {
      final tempValue = double.tryParse(temperature.toString());
      if (tempValue == null) return null;
      
      if (tempValue > 45) return Colors.red;
      if (tempValue > 35) return Colors.orange;
      return Colors.blue;
    } catch (e) {
      return null;
    }
  }