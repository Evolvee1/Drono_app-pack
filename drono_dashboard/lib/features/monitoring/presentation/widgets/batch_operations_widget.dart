import 'package:flutter/material.dart';

class BatchOperationsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final Function(List<String>, String, Map<String, dynamic>, String) onExecuteBatchCommand;
  
  const BatchOperationsWidget({
    Key? key,
    required this.devices,
    required this.onExecuteBatchCommand,
  }) : super(key: key);

  @override
  State<BatchOperationsWidget> createState() => _BatchOperationsWidgetState();
}

class _BatchOperationsWidgetState extends State<BatchOperationsWidget> {
  final List<String> _selectedDevices = [];
  String _selectedCommand = 'status';
  final Map<String, dynamic> _commandParameters = {};
  bool _isConfirmDialogOpen = false;
  final TextEditingController _sessionNameController = TextEditingController();
  String _commandPreview = '';
  
  // Feature toggles state
  final Map<String, bool> _featureToggles = {
    'rotate_ip': false,
    'webview_mode': false,
    'random_devices': false,
    'aggressive_clearing': false,
    'new_webview_per_request': false,
    'handle_redirects': false,
  };
  
  // Colors for different session groups
  final List<Color> _sessionColors = [
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
    Colors.teal.shade100,
    Colors.indigo.shade100,
    Colors.pink.shade100,
    Colors.amber.shade100,
  ];
  
  // Map device IDs to colors (will be assigned when executing commands)
  final Map<String, Color> _deviceColors = {};
  
  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }
  
  // Define available commands
  final List<Map<String, dynamic>> _availableCommands = [
    {
      'type': 'status',
      'name': 'Get Status',
      'description': 'Check device status',
      'parameters': [],
      'icon': Icons.info,
      'color': Colors.blue,
      'shell_cmd': './drono_control.sh status',
      'category': 'functional',
    },
    {
      'type': 'start',
      'name': 'Start Simulation',
      'description': 'Start a simulation with specified parameters',
      'parameters': ['url', 'iterations', 'min_interval', 'max_interval', 'delay'],
      'icon': Icons.play_arrow,
      'color': Colors.green,
      'shell_cmd': './drono_control.sh start',
      'category': 'functional',
    },
    {
      'type': 'stop',
      'name': 'Stop Simulation',
      'description': 'Stop any running simulation',
      'parameters': [],
      'icon': Icons.stop,
      'color': Colors.red,
      'shell_cmd': './drono_control.sh stop',
      'category': 'functional',
    },
    {
      'type': 'pause',
      'name': 'Pause Simulation',
      'description': 'Pause a running simulation',
      'parameters': [],
      'icon': Icons.pause,
      'color': Colors.orange,
      'shell_cmd': './drono_control.sh pause',
      'category': 'functional',
    },
    {
      'type': 'resume',
      'name': 'Resume Simulation',
      'description': 'Resume a paused simulation',
      'parameters': [],
      'icon': Icons.play_arrow,
      'color': Colors.blue,
      'shell_cmd': './drono_control.sh resume',
      'category': 'functional',
    },
    {
      'type': 'preset',
      'name': 'Apply Preset',
      'description': 'Apply a predefined configuration preset',
      'parameters': ['preset_name'],
      'icon': Icons.settings,
      'color': Colors.purple,
      'options': {
        'preset_name': ['veewoy', 'performance', 'stealth', 'balanced']
      },
      'shell_cmd': './drono_control.sh preset',
      'category': 'preset',
    },
    {
      'type': 'restart',
      'name': 'Restart App',
      'description': 'Restart the app on selected devices',
      'parameters': [],
      'icon': Icons.refresh,
      'color': Colors.deepPurple,
      'shell_cmd': './drono_control.sh restart',
      'category': 'functional',
    },
  ];
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Batch Operations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Help'),
                    onPressed: _showHelpDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Session name field
              TextField(
                controller: _sessionNameController,
                decoration: const InputDecoration(
                  labelText: 'Session Name',
                  hintText: 'Enter a name for this session (optional)',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateCommandPreview(),
              ),
              const SizedBox(height: 16),
              
              // Device selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Devices',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _selectAllDevices,
                            child: const Text('Select All'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearSelection,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Device checkboxes - show in a grid
                  widget.devices.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No devices available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 0,
                        children: widget.devices.map((device) {
                          final deviceId = device['id']?.toString() ?? '';
                          final isOnline = device['status'] == 'online';
                          final deviceColor = _deviceColors[deviceId] ?? Colors.transparent;
                          
                          return SizedBox(
                            width: 200,
                            child: Card(
                              color: _selectedDevices.contains(deviceId) ? deviceColor : null,
                              child: CheckboxListTile(
                                value: _selectedDevices.contains(deviceId),
                                onChanged: isOnline ? (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      if (!_selectedDevices.contains(deviceId)) {
                                        _selectedDevices.add(deviceId);
                                        _updateCommandPreview();
                                      }
                                    } else {
                                      _selectedDevices.remove(deviceId);
                                      _updateCommandPreview();
                                    }
                                  });
                                } : null,
                                title: Text(
                                  device['name'] ?? 'Unknown',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  device['model'] ?? 'Unknown Model',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: Icon(
                                  Icons.phone_android,
                                  color: isOnline ? Colors.green : Colors.red,
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                enabled: isOnline,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Command selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Function Commands',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Command radio buttons - only show functional commands
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableCommands
                        .where((cmd) => cmd['category'] == 'functional' || cmd['category'] == 'preset')
                        .map((command) {
                          return ChoiceChip(
                            label: Text(command['name']),
                            selected: _selectedCommand == command['type'],
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCommand = command['type'];
                                  // Don't clear parameters when changing commands to allow reuse
                                  // Only clear if explicitly requested
                                  _updateCommandPreview();
                                });
                              }
                            },
                            avatar: Icon(
                              command['icon'],
                              color: _selectedCommand == command['type'] 
                                ? Colors.white 
                                : command['color'],
                              size: 16,
                            ),
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: command['color'],
                            labelStyle: TextStyle(
                              color: _selectedCommand == command['type'] 
                                ? Colors.white 
                                : Colors.black,
                            ),
                          );
                        }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Parameter inputs (if any)
                    _buildParameterInputs(),
                    
                    // Command preview
                    if (_commandPreview.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Command Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          _commandPreview,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Execute button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _selectedDevices.isNotEmpty
                          ? _showConfirmDialog
                          : null,
                        icon: const Icon(Icons.send),
                        label: Text(
                          'Execute on ${_selectedDevices.length} Device${_selectedDevices.length == 1 ? '' : 's'}',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Feature Toggles Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feature Toggles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toggle features immediately on selected devices. These settings will apply immediately.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Toggle switches for features
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildFeatureToggle(
                          'rotate_ip',
                          'IP Rotation',
                          Icons.swap_horiz,
                          Colors.teal,
                        ),
                        _buildFeatureToggle(
                          'webview_mode',
                          'WebView Mode',
                          Icons.public,
                          Colors.indigo,
                        ),
                        _buildFeatureToggle(
                          'random_devices',
                          'Random Devices',
                          Icons.devices,
                          Colors.amber,
                        ),
                        _buildFeatureToggle(
                          'aggressive_clearing',
                          'Aggressive Clearing',
                          Icons.cleaning_services,
                          Colors.brown,
                        ),
                        _buildFeatureToggle(
                          'new_webview_per_request',
                          'New WebView Per Request',
                          Icons.tab,
                          Colors.pink,
                        ),
                        _buildFeatureToggle(
                          'handle_redirects',
                          'Handle Redirects',
                          Icons.alt_route,
                          Colors.deepOrange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureToggle(String feature, String label, IconData icon, Color color) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(label),
            Switch(
              value: _featureToggles[feature] ?? false,
              activeColor: color,
              onChanged: (value) {
                setState(() {
                  _featureToggles[feature] = value;
                  _updateCommandPreview();
                  
                  // Send the toggle command immediately
                  if (_selectedDevices.isNotEmpty) {
                    final params = {'enabled': value.toString()};
                    widget.onExecuteBatchCommand(
                      _selectedDevices,
                      'toggle_$feature',
                      params,
                      _sessionNameController.text.isEmpty 
                        ? 'Toggle $label' 
                        : '${_sessionNameController.text} - Toggle $label',
                    );
                  } else {
                    // Show a warning if no devices are selected
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No devices selected. Toggle will be applied when you select devices.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _updateCommandPreview() {
    final selectedCommand = _availableCommands.firstWhere(
      (cmd) => cmd['type'] == _selectedCommand,
      orElse: () => {'shell_cmd': '', 'type': ''},
    );
    
    List<String> cmdParts = [];
    
    // Base script path
    cmdParts.add('./drono_control.sh');
    
    // Handle preset command differently
    if (_selectedCommand == 'preset' && _commandParameters.containsKey('preset_name')) {
      cmdParts.add('preset');
      cmdParts.add(_commandParameters['preset_name']);
    } else {
      // Add parameters first
      _commandParameters.forEach((key, value) {
        if (value.toString().isNotEmpty && !key.startsWith('toggle_')) {
          cmdParts.add(key);
          cmdParts.add(value);
        }
      });
      
      // Add the actual command at the end
      if (_selectedCommand != 'preset') {
        cmdParts.add(_selectedCommand);
      }
    }
    
    // Add feature toggles that are enabled - only for preview, not for actual command execution
    // since toggle commands are sent separately via the switch controls
    String togglePart = '';
    _featureToggles.forEach((feature, isEnabled) {
      if (isEnabled) {
        togglePart += '\n# Toggle: $feature is enabled';
      }
    });
    
    setState(() {
      _commandPreview = cmdParts.join(' ') + togglePart;
    });
  }
  
  Widget _buildParameterInputs() {
    // Find the selected command to get its parameters
    final selectedCommand = _availableCommands.firstWhere(
      (cmd) => cmd['type'] == _selectedCommand,
      orElse: () => {'parameters': [], 'options': {}},
    );
    
    final parameters = selectedCommand['parameters'] as List;
    final options = selectedCommand['options'] as Map<String, dynamic>? ?? {};
    
    if (parameters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Command Parameters',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        
        // Parameter fields - either dropdown or text input
        ...parameters.map((param) {
          // Check if this parameter has predefined options
          final paramOptions = options[param] as List<String>?;
          
          if (paramOptions != null && paramOptions.isNotEmpty) {
            // Use dropdown for parameters with options
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _formatParameterName(param),
                  border: const OutlineInputBorder(),
                ),
                value: _commandParameters[param] as String?,
                items: paramOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      _commandParameters[param] = value;
                      _updateCommandPreview();
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a value';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            );
          } else {
            // Use text field for parameters without predefined options
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: _formatParameterName(param),
                  hintText: 'Enter ${_formatParameterName(param)}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _commandParameters[param] = value;
                    _updateCommandPreview();
                  });
                },
              ),
            );
          }
        }).toList(),
      ],
    );
  }
  
  String _formatParameterName(String param) {
    // Convert snake_case or camelCase to Title Case with spaces
    return param
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
  
  void _selectAllDevices() {
    setState(() {
      _selectedDevices.clear();
      for (final device in widget.devices) {
        if (device['status'] == 'online') {
          final deviceId = device['id']?.toString();
          if (deviceId != null) {
            _selectedDevices.add(deviceId);
          }
        }
      }
    });
  }
  
  void _clearSelection() {
    setState(() {
      _selectedDevices.clear();
    });
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Operations Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This feature allows you to execute commands on multiple devices simultaneously.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('How to use:'),
              const SizedBox(height: 8),
              ...const [
                '1. Select the devices you want to control',
                '2. Choose the command to execute',
                '3. Fill in any required parameters',
                '4. Click "Execute" to send the command to all selected devices',
              ].map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(step),
              )),
              const SizedBox(height: 16),
              const Text('Available Commands:'),
              const SizedBox(height: 8),
              ..._availableCommands.map((command) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(command['icon'], color: command['color'], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            command['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            command['description'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showConfirmDialog() {
    // Prevent multiple dialogs
    if (_isConfirmDialogOpen) return;
    
    setState(() {
      _isConfirmDialogOpen = true;
    });
    
    final selectedCommand = _availableCommands.firstWhere(
      (cmd) => cmd['type'] == _selectedCommand,
      orElse: () => {'name': 'Unknown Command', 'type': _selectedCommand},
    );
    
    // Assign consistent colors to the devices for this session
    // Use the session name as seed if provided, otherwise use current timestamp
    final sessionColor = _sessionColors[(_sessionNameController.text.isNotEmpty ? 
        _sessionNameController.text.hashCode : 
        DateTime.now().millisecondsSinceEpoch) % _sessionColors.length];
    
    for (final deviceId in _selectedDevices) {
      _deviceColors[deviceId] = sessionColor;
    }
    
    // Format session name for display
    final sessionNameText = _sessionNameController.text.isNotEmpty 
        ? '"${_sessionNameController.text}"' 
        : 'Unnamed session';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Batch Operation'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Execute "${selectedCommand['name']}" on ${_selectedDevices.length} device${_selectedDevices.length == 1 ? '' : 's'}?',
              ),
              const SizedBox(height: 16),
              Text('Session: $sessionNameText'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sessionColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected Devices:'),
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: ListView(
                        shrinkWrap: true,
                        children: _selectedDevices.map((deviceId) {
                          final device = widget.devices.firstWhere(
                            (d) => d['id']?.toString() == deviceId,
                            orElse: () => {'name': 'Unknown Device'},
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• ${device['name'] ?? deviceId}'),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_commandParameters.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Parameters:'),
                const SizedBox(height: 4),
                ..._commandParameters.entries.map((entry) => Text('• ${_formatParameterName(entry.key)}: ${entry.value}')),
              ],
              
              if (_commandPreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Command to execute:'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _commandPreview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isConfirmDialogOpen = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Collect all parameters including feature toggles
              final Map<String, dynamic> allParams = Map.from(_commandParameters);
              
              // Don't add feature toggles to parameters for execution since they are handled separately
              // and sent immediately when toggled
              
              widget.onExecuteBatchCommand(
                _selectedDevices,
                _selectedCommand,
                allParams,
                _sessionNameController.text,
              );
              setState(() {
                _isConfirmDialogOpen = false;
                // Don't clear session name or selections to allow for repeated commands with the same config
              });
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    ).then((_) {
      // In case the dialog is dismissed in another way
      if (_isConfirmDialogOpen) {
        setState(() {
          _isConfirmDialogOpen = false;
        });
      }
    });
  }
} 
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• ${device['name'] ?? deviceId}'),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_commandParameters.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Parameters:'),
                const SizedBox(height: 4),
                ..._commandParameters.entries.map((entry) => Text('• ${_formatParameterName(entry.key)}: ${entry.value}')),
              ],
              
              if (_commandPreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Command to execute:'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _commandPreview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isConfirmDialogOpen = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Collect all parameters including feature toggles
              final Map<String, dynamic> allParams = Map.from(_commandParameters);
              
              // Don't add feature toggles to parameters for execution since they are handled separately
              // and sent immediately when toggled
              
              widget.onExecuteBatchCommand(
                _selectedDevices,
                _selectedCommand,
                allParams,
                _sessionNameController.text,
              );
              setState(() {
                _isConfirmDialogOpen = false;
                // Don't clear session name or selections to allow for repeated commands with the same config
              });
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    ).then((_) {
      // In case the dialog is dismissed in another way
      if (_isConfirmDialogOpen) {
        setState(() {
          _isConfirmDialogOpen = false;
        });
      }
    });
  }