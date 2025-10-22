import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class CreateLeaderboardScreen extends StatefulWidget {
  const CreateLeaderboardScreen({super.key});

  @override
  State<CreateLeaderboardScreen> createState() => _CreateLeaderboardScreenState();
}

class _CreateLeaderboardScreenState extends State<CreateLeaderboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _goalValueController = TextEditingController();
  DateTime? _startDate; // Truncated to current minute
  DateTime? _endDate;
  bool _isLoading = false;
  bool _setGoal = false;
  String? _goalCategory = 'drinks';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  Future<void> _pickDate(BuildContext context, {required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    final firstDate = isStartDate ? now.subtract(const Duration(days: 365)) : (_startDate ?? now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Please select a start date.', style: TextStyle(color: colorScheme.onErrorContainer)),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final apiService = ApiService();
      await apiService.createLeaderboard(
        name: _nameController.text,
        startDate: _startDate!,
        endDate: _endDate,
        goalCategory: _setGoal ? _goalCategory : null,
        goalValue: _setGoal ? double.tryParse(_goalValueController.text) : null,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Leaderboard created successfully!')),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to create leaderboard: $e', style: TextStyle(color: colorScheme.onError)),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Leaderboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Leaderboard Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a name.' : null,
              ),
              const SizedBox(height: 24),
              _buildDatePickerField(
                context: context,
                label: 'Start Date *',
                date: _startDate,
                onTap: () => _pickDate(context, isStartDate: true),
              ),
              const SizedBox(height: 16),
              _buildDatePickerField(
                context: context,
                label: 'End Date (Optional)',
                date: _endDate,
                onTap: () => _pickDate(context, isStartDate: false),
                onClear: () => setState(() => _endDate = null),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Set a Goal'),
                value: _setGoal,
                onChanged: (bool value) {
                  setState(() {
                    _setGoal = value;
                  });
                },
              ),
              if (_setGoal) ...[
                const SizedBox(height: 16),
                DropdownMenu<String>(
                  initialSelection: _goalCategory,
                  label: const Text('Goal Category'),
                  expandedInsets: EdgeInsets.zero,
                  onSelected: (String? newValue) {
                    setState(() {
                      _goalCategory = newValue;
                    });
                  },
                  dropdownMenuEntries: const <DropdownMenuEntry<String>>[
                    DropdownMenuEntry(value: 'drinks', label: 'Total Drinks'),
                    DropdownMenuEntry(value: 'volume', label: 'Total Volume (ml)'),
                    DropdownMenuEntry(value: 'units', label: 'Total Units'),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goalValueController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Target',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_setGoal) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a target value.';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number.';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Create Leaderboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear != null && date != null
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: onClear,
          )
              : const Icon(Icons.calendar_today),
        ),
        child: Text(
          date != null ? DateFormat('EEE, d MMM yyyy').format(date) : 'Select a date',
          style: TextStyle(
            color: date != null ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}