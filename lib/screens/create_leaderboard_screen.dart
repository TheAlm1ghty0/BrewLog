import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/leaderboard.dart'; // Import Leaderboard model

class CreateLeaderboardScreen extends StatefulWidget {
  const CreateLeaderboardScreen({super.key});

  @override
  State<CreateLeaderboardScreen> createState() => _CreateLeaderboardScreenState();
}

class _CreateLeaderboardScreenState extends State<CreateLeaderboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _goalValueController = TextEditingController();
  // Re-added _startDate
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _setGoal = false;
  String? _goalCategory = 'drinks'; // Default goal category

  @override
  void initState() {
    super.initState();
    // Set default start date to now, truncated to seconds
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
  }

  // Re-added start date picking logic
  Future<void> _pickDate(BuildContext context, {required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);
    // Allow picking past dates for start, but only from today onwards for end (relative to start)
    final firstDate = isStartDate ? DateTime(2020) : (_startDate ?? now);
    // Allow picking time as well
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        final finalDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute
        ).copyWith(second: 0, millisecond: 0, microsecond: 0); // Truncate to minute initially

        setState(() {
          if (isStartDate) {
            // Truncate start date to seconds
            _startDate = finalDateTime.copyWith(second: 0); // Corrected: Use copyWith(second: 0) for second truncation
            // If end date is now before new start date, clear it
            if (_endDate != null && _endDate!.isBefore(_startDate!)) {
              _endDate = null;
            }
          } else {
            // Set end date to the END of the selected minute for inclusiveness? Or keep precise?
            // Let's keep it precise for now, can adjust later if needed.
            // Ensure end date is not before start date
            if (_startDate != null && finalDateTime.isBefore(_startDate!)) {
              _endDate = _startDate; // Or show error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('End date cannot be before start date.'), backgroundColor: Theme.of(context).colorScheme.error),
              );
            } else {
              _endDate = finalDateTime.copyWith(second: 59); // Set to end of minute
            }
          }
        });
      }
    }
  }


  Future<void> _submitForm() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Check _startDate again
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

      // --- CRITICAL: Convert dates to UTC before sending ---
      final utcStartDate = _startDate!.toUtc();
      final utcEndDate = _endDate?.toUtc();
      // --- End UTC Conversion ---

      // Re-added startDate parameter, passing the UTC version
      // --- MODIFICATION: Store the returned leaderboard ---
      final newLeaderboard = await apiService.createLeaderboard(
        name: _nameController.text,
        startDate: utcStartDate, // Send UTC time
        endDate: utcEndDate, // Send UTC time (or null)
        goalCategory: _setGoal ? _goalCategory : null,
        goalValue: _setGoal ? double.tryParse(_goalValueController.text) : null,
      );
      // --- END MODIFICATION ---

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Leaderboard created successfully!')),
        );
        // --- MODIFICATION: Pop with the new leaderboard object ---
        navigator.pop(newLeaderboard); // Pop and signal success
        // --- END MODIFICATION ---
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
                  labelText: 'Leaderboard Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.rsvp),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a name.' : null,
              ),
              const SizedBox(height: 24), // Increased spacing
              // Re-added Start Date Picker Field
              _buildDateTimePickerField( // Use new DateTime picker
                context: context,
                label: 'Start Date & Time *',
                dateTime: _startDate,
                onTap: () => _pickDate(context, isStartDate: true),
              ),
              const SizedBox(height: 16),
              _buildDateTimePickerField( // Use new DateTime picker
                context: context,
                label: 'End Date & Time (Optional)',
                dateTime: _endDate,
                onTap: () => _pickDate(context, isStartDate: false), // Use specific end date picker
                onClear: () => setState(() => _endDate = null),
              ),
              const SizedBox(height: 24),
              // --- Goal Setting Section ---
              Card( // Wrap goal settings in a Card for visual grouping
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leaderboard Goal (Optional)', style: Theme.of(context).textTheme.titleMedium),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Set a Goal'),
                        value: _setGoal,
                        onChanged: (bool value) {
                          setState(() {
                            _setGoal = value;
                            // Clear goal value if goal is turned off
                            if (!_setGoal) _goalValueController.clear();
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
                            prefixIcon: Icon(Icons.track_changes),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true), // Allow decimals
                          validator: (value) {
                            if (_setGoal) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a target value.';
                              }
                              final number = double.tryParse(value);
                              if (number == null) {
                                return 'Please enter a valid number.';
                              }
                              if (number <= 0) {
                                return 'Goal must be positive.';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // --- End Goal Setting Section ---
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon( // Use icon button
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Leaderboard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Renamed and updated: Reusable DateTime Picker Field Widget
  Widget _buildDateTimePickerField({
    required BuildContext context,
    required String label,
    required DateTime? dateTime, // Changed from date to dateTime
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    // Format including time
    final String displayFormat = 'EEE, d MMM yyyy HH:mm';
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today), // Added prefix icon
          suffixIcon: onClear != null && dateTime != null
              ? IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Date', // Added tooltip
            onPressed: onClear,
          )
              : null, // Don't show suffix if no clear action
        ),
        child: Text(
          dateTime != null ? DateFormat(displayFormat).format(dateTime) : 'Select date & time', // Updated text
          style: TextStyle(
            color: dateTime != null ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}