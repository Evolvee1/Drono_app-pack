import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomWorkflowWidget extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> savedWorkflows;
  final Function(Map<String, dynamic>) onSaveWorkflow;
  final Function(String) onDeleteWorkflow;
  final Function(Map<String, dynamic>) onRunWorkflow;
  
  const CustomWorkflowWidget({
    Key? key,
    required this.devices,
    required this.savedWorkflows,
    required this.onSaveWorkflow,
    required this.onDeleteWorkflow,
    required this.onRunWorkflow,
  }) : super(key: key);

  @override
  State<CustomWorkflowWidget> createState() => _CustomWorkflowWidgetState();
}

class _CustomWorkflowWidgetState extends State<CustomWorkflowWidget> {
  final _workflowNameController = TextEditingController();
  final _workflowFormKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _workflowSteps = [];
  
  bool _isCreatingWorkflow = false;
  String? _selectedWorkflow;
  
  // Define available commands for steps
  final List<Map<String, dynamic>> _availableCommands = [
    {
      'type': 'status',
      'name': 'Get Status',
      'description': 'Check device status',
      'parameters': [],
      'icon': Icons.info,
      'color': Colors.blue,
    },
    {
      'type': 'start',
      'name': 'Start Simulation',
      'description': 'Start a simulation with specified parameters',
      'parameters': ['url', 'iterations', 'delay'],
      'icon': Icons.play_arrow,
      'color': Colors.green,
    },
    {
      'type': 'stop',
      'name': 'Stop Simulation',
      'description': 'Stop any running simulation',
      'parameters': [],
      'icon': Icons.stop,
      'color': Colors.red,
    },
    {
      'type': 'pause',
      'name': 'Pause Simulation',
      'description': 'Pause a running simulation',
      'parameters': [],
      'icon': Icons.pause,
      'color': Colors.orange,
    },
    {
      'type': 'resume',
      'name': 'Resume Simulation',
      'description': 'Resume a paused simulation',
      'parameters': [],
      'icon': Icons.play_arrow,
      'color': Colors.blue,
    },
    {
      'type': 'wait',
      'name': 'Wait',
      'description': 'Wait for a specified duration',
      'parameters': ['seconds'],
      'icon': Icons.timelapse,
      'color': Colors.purple,
    },
  ];

  @override
  void dispose() {
    _workflowNameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
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
                  'Custom Automation Workflows',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(_isCreatingWorkflow ? Icons.close : Icons.add),
                  label: Text(_isCreatingWorkflow ? 'Cancel' : 'Create New'),
                  onPressed: () {
                    setState(() {
                      _isCreatingWorkflow = !_isCreatingWorkflow;
                      if (!_isCreatingWorkflow) {
                        _workflowNameController.text = '';
                        _workflowSteps.clear();
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Create workflow form
            if (_isCreatingWorkflow)
              _buildWorkflowCreationForm()
            else
              _buildSavedWorkflowsList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWorkflowCreationForm() {
    return Form(
      key: _workflowFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workflow name input
          TextFormField(
            controller: _workflowNameController,
            decoration: const InputDecoration(
              labelText: 'Workflow Name',
              hintText: 'Enter a name for this workflow',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a workflow name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Steps list
          const Text(
            'Workflow Steps',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          
          // Show existing steps
          if (_workflowSteps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No steps added yet. Click "Add Step" to start building your workflow.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _workflowSteps.length,
              itemBuilder: (context, index) => Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getCommandColor(_workflowSteps[index]['command']),
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(_getCommandName(_workflowSteps[index]['command'])),
                  subtitle: _buildStepDetails(_workflowSteps[index]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editStep(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _workflowSteps.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Add step button
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Step'),
              onPressed: _addStep,
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // Save workflow button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isCreatingWorkflow = false;
                    _workflowNameController.text = '';
                    _workflowSteps.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Workflow'),
                onPressed: _workflowSteps.isEmpty ? null : _saveWorkflow,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSavedWorkflowsList() {
    if (widget.savedWorkflows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No saved workflows. Click "Create New" to create your first automation workflow.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved Workflows',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.savedWorkflows.length,
          itemBuilder: (context, index) {
            final workflow = widget.savedWorkflows[index];
            final steps = workflow['steps'] as List?;
            final created = workflow['created_at'] != null ? 
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(workflow['created_at'])) : 
              'Unknown';
            
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  title: Text(workflow['name'] ?? 'Unnamed Workflow'),
                  subtitle: Text('Created: $created, ${steps?.length ?? 0} steps'),
                  leading: Radio<String>(
                    value: workflow['id'],
                    groupValue: _selectedWorkflow,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedWorkflow = value;
                      });
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteWorkflow(workflow['id']),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run'),
                        onPressed: () => widget.onRunWorkflow(workflow),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Steps:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...(steps ?? []).asMap().entries.map((entry) {
                            final index = entry.key;
                            final step = entry.value;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _getCommandColor(step['command']),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getCommandName(step['command']),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (step['device_id'] != null)
                                          Text(
                                            'Device: ${_getDeviceName(step['device_id'])}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        if (step['parameters'] != null && 
                                            step['parameters'] is Map &&
                                            (step['parameters'] as Map).isNotEmpty)
                                          Text(
                                            'Parameters: ${_formatParameters(step['parameters'])}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Run selected workflow button
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Selected Workflow'),
            onPressed: _selectedWorkflow != null ? () {
              final workflow = widget.savedWorkflows.firstWhere(
                (w) => w['id'] == _selectedWorkflow,
                orElse: () => {},
              );
              if (workflow.isNotEmpty) {
                widget.onRunWorkflow(workflow);
              }
            } : null,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStepDetails(Map<String, dynamic> step) {
    final List<String> details = [];
    
    if (step['device_id'] != null) {
      details.add('Device: ${_getDeviceName(step['device_id'])}');
    }
    
    if (step['parameters'] != null && step['parameters'] is Map && step['parameters'].isNotEmpty) {
      details.add('Parameters: ${_formatParameters(step['parameters'])}');
    }
    
    return Text(details.join(', '));
  }
  
  String _formatParameters(Map<String, dynamic> parameters) {
    if (parameters.isEmpty) return 'None';
    
    return parameters.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
  
  String _getDeviceName(String deviceId) {
    final device = widget.devices.firstWhere(
      (d) => d['id']?.toString() == deviceId,
      orElse: () => {'name': 'Unknown Device'},
    );
    
    return device['name'] ?? deviceId;
  }
  
  String _getCommandName(String commandType) {
    final command = _availableCommands.firstWhere(
      (cmd) => cmd['type'] == commandType,
      orElse: () => {'name': commandType},
    );
    
    return command['name'];
  }
  
  Color _getCommandColor(String commandType) {
    final command = _availableCommands.firstWhere(
      (cmd) => cmd['type'] == commandType,
      orElse: () => {'color': Colors.grey},
    );
    
    return command['color'];
  }
  
  void _addStep() {
    _showStepDialog();
  }
  
  void _editStep(int index) {
    _showStepDialog(existingStep: _workflowSteps[index], stepIndex: index);
  }
  
  void _showStepDialog({Map<String, dynamic>? existingStep, int? stepIndex}) {
    String selectedCommand = existingStep?['command'] ?? 'status';
    String? selectedDeviceId = existingStep?['device_id'];
    final Map<String, dynamic> parameters = Map.from(existingStep?['parameters'] ?? {});
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Get the parameters for the selected command
            final selectedCommandInfo = _availableCommands.firstWhere(
              (cmd) => cmd['type'] == selectedCommand,
              orElse: () => {'parameters': []},
            );
            final commandParameters = selectedCommandInfo['parameters'] as List;
            
            return AlertDialog(
              title: Text(existingStep != null ? 'Edit Step' : 'Add Step'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Command selection
                    const Text('Command:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableCommands.map((command) {
                        return ChoiceChip(
                          label: Text(command['name']),
                          selected: selectedCommand == command['type'],
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedCommand = command['type'];
                                parameters.clear();
                              });
                            }
                          },
                          avatar: Icon(
                            command['icon'],
                            color: selectedCommand == command['type'] 
                              ? Colors.white 
                              : command['color'],
                            size: 16,
                          ),
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: command['color'],
                          labelStyle: TextStyle(
                            color: selectedCommand == command['type'] 
                              ? Colors.white 
                              : Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Device selection (if not "wait" command)
                    if (selectedCommand != 'wait') ...[
                      const Text('Device:'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedDeviceId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        hint: const Text('Select a device'),
                        items: widget.devices
                            .where((d) => d['status'] == 'online')
                            .map((device) {
                          return DropdownMenuItem(
                            value: device['id']?.toString(),
                            child: Text('${device['name']} (${device['model']})'),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            selectedDeviceId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a device';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Parameter inputs
                    if (commandParameters.isNotEmpty) ...[
                      const Text('Parameters:'),
                      const SizedBox(height: 8),
                      ...commandParameters.map((param) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: _formatParameterName(param),
                              hintText: 'Enter $param value',
                              border: const OutlineInputBorder(),
                            ),
                            controller: TextEditingController(
                              text: parameters[param]?.toString() ?? '',
                            ),
                            onChanged: (value) {
                              parameters[param] = value;
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedCommand != 'wait' && (selectedDeviceId == null || selectedDeviceId!.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a device')),
                      );
                      return;
                    }
                    
                    final step = {
                      'command': selectedCommand,
                      if (selectedCommand != 'wait') 'device_id': selectedDeviceId,
                      'parameters': parameters,
                    };
                    
                    // Update or add the step
                    this.setState(() {
                      if (stepIndex != null) {
                        _workflowSteps[stepIndex] = step;
                      } else {
                        _workflowSteps.add(step);
                      }
                    });
                    
                    Navigator.of(context).pop();
                  },
                  child: Text(existingStep != null ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _saveWorkflow() {
    if (!_workflowFormKey.currentState!.validate()) {
      return;
    }
    
    if (_workflowSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one step to the workflow')),
      );
      return;
    }
    
    final workflow = {
      'id': 'workflow_${DateTime.now().millisecondsSinceEpoch}',
      'name': _workflowNameController.text,
      'steps': _workflowSteps,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    widget.onSaveWorkflow(workflow);
    
    setState(() {
      _isCreatingWorkflow = false;
      _workflowNameController.text = '';
      _workflowSteps.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workflow saved successfully')),
    );
  }
  
  void _deleteWorkflow(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workflow'),
        content: const Text('Are you sure you want to delete this workflow? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDeleteWorkflow(id);
              if (_selectedWorkflow == id) {
                setState(() {
                  _selectedWorkflow = null;
                });
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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
} 