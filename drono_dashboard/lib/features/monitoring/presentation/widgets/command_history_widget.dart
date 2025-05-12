import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommandHistoryWidget extends StatefulWidget {
  final List<Map<String, dynamic>> commands;
  final Function(String) onDeviceSelected;
  final Function(String) onCommandTypeSelected;
  final Function(String) onStatusSelected;
  
  const CommandHistoryWidget({
    Key? key,
    required this.commands,
    required this.onDeviceSelected,
    required this.onCommandTypeSelected,
    required this.onStatusSelected,
  }) : super(key: key);

  @override
  State<CommandHistoryWidget> createState() => _CommandHistoryWidgetState();
}

class _CommandHistoryWidgetState extends State<CommandHistoryWidget> {
  String? _selectedDevice;
  String? _selectedCommandType;
  String? _selectedStatus;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  
  @override
  Widget build(BuildContext context) {
    // Extract unique values for filters
    final devices = <String>{'All'};
    final commandTypes = <String>{'All'};
    final statuses = <String>{'All'};
    
    for (final command in widget.commands) {
      if (command['device_id'] != null) {
        devices.add(command['device_id'].toString());
      }
      if (command['type'] != null) {
        commandTypes.add(command['type'].toString());
      }
      if (command['status'] != null) {
        statuses.add(command['status'].toString());
      }
    }
    
    // Apply filters to commands
    final filteredCommands = widget.commands.where((command) {
      bool matchesDevice = _selectedDevice == null || _selectedDevice == 'All' || 
          command['device_id']?.toString() == _selectedDevice;
          
      bool matchesType = _selectedCommandType == null || _selectedCommandType == 'All' || 
          command['type']?.toString() == _selectedCommandType;
          
      bool matchesStatus = _selectedStatus == null || _selectedStatus == 'All' || 
          command['status']?.toString() == _selectedStatus;
          
      return matchesDevice && matchesType && matchesStatus;
    }).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            
            // Filters
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Device',
                    value: _selectedDevice,
                    items: devices.toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDevice = value;
                      });
                      widget.onDeviceSelected(value ?? 'All');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Command Type',
                    value: _selectedCommandType,
                    items: commandTypes.toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCommandType = value;
                      });
                      widget.onCommandTypeSelected(value ?? 'All');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Status',
                    value: _selectedStatus,
                    items: statuses.toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      widget.onStatusSelected(value ?? 'All');
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Commands table
            if (filteredCommands.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No command history available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Command ID')),
                    DataColumn(label: Text('Device')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Parameters')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Completed')),
                    DataColumn(label: Text('Result')),
                  ],
                  rows: filteredCommands.map((command) {
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          command['id'] != null && command['id'].toString().length >= 8
                              ? command['id'].toString().substring(0, 8)
                              : (command['id']?.toString() ?? 'Unknown'), 
                          style: const TextStyle(fontFamily: 'monospace')
                        )),
                        DataCell(Text(command['device_id']?.toString() ?? 'Unknown')),
                        DataCell(_buildCommandTypeChip(command['type']?.toString() ?? 'unknown')),
                        DataCell(_buildParametersTooltip(command['parameters'])),
                        DataCell(_buildStatusChip(command['status']?.toString() ?? 'unknown')),
                        DataCell(Text(_formatDate(command['created_at']))),
                        DataCell(Text(_formatDate(command['completed_at']))),
                        DataCell(_buildResultTooltip(command['result'], command['error'])),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: const Text('All'),
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item == 'All' ? null : item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildCommandTypeChip(String type) {
    Color color;
    IconData icon;
    
    switch (type.toLowerCase()) {
      case 'start':
        color = Colors.green;
        icon = Icons.play_arrow;
        break;
      case 'stop':
        color = Colors.red;
        icon = Icons.stop;
        break;
      case 'pause':
        color = Colors.orange;
        icon = Icons.pause;
        break;
      case 'resume':
        color = Colors.blue;
        icon = Icons.play_arrow;
        break;
      case 'status':
        color = Colors.purple;
        icon = Icons.info;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        break;
    }
    
    return Chip(
      label: Text(
        type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
      avatar: Icon(icon, color: Colors.white, size: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.blue;
        icon = Icons.pending;
        break;
      case 'running':
        color = Colors.orange;
        icon = Icons.timelapse;
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check;
        break;
      case 'failed':
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        break;
    }
    
    return Chip(
      label: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
      avatar: Icon(icon, color: Colors.white, size: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
  
  Widget _buildParametersTooltip(dynamic parameters) {
    if (parameters == null) {
      return const Text('None');
    }
    
    String displayText;
    
    if (parameters is Map) {
      // Get first few keys for display
      final keys = parameters.keys.take(2).toList();
      if (keys.isNotEmpty) {
        displayText = keys.map((k) => '$k: ${_truncate(parameters[k].toString())}').join(', ');
        if (parameters.length > 2) {
          displayText += '...';
        }
      } else {
        displayText = 'Empty';
      }
    } else {
      displayText = parameters.toString();
    }
    
    return Tooltip(
      message: parameters.toString(),
      child: Text(displayText),
    );
  }
  
  Widget _buildResultTooltip(dynamic result, dynamic error) {
    if (error != null) {
      return Tooltip(
        message: error.toString(),
        child: Text(
          'Error',
          style: TextStyle(color: Colors.red.shade700),
        ),
      );
    }
    
    if (result == null) {
      return const Text('N/A');
    }
    
    String displayText;
    
    if (result is Map) {
      // Get first few keys for display
      final keys = result.keys.take(2).toList();
      if (keys.isNotEmpty) {
        displayText = keys.map((k) => '$k: ${_truncate(result[k].toString())}').join(', ');
        if (result.length > 2) {
          displayText += '...';
        }
      } else {
        displayText = 'Empty';
      }
    } else {
      displayText = result.toString();
    }
    
    return Tooltip(
      message: result.toString(),
      child: Text(displayText),
    );
  }
  
  String _truncate(String str) {
    if (str.length <= 12) {
      return str;
    }
    return '${str.substring(0, 12)}...';
  }
  
  String _formatDate(dynamic date) {
    if (date == null) {
      return 'N/A';
    }
    
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