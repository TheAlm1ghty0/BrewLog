import 'package:flutter/material.dart';
import 'models/drink_entry.dart'; // Ensures we use the one, correct DrinkEntry model

class ManualEntryScreen extends StatefulWidget {
  final String currentUserName; // Accepts the user's name automatically

  const ManualEntryScreen({super.key, required this.currentUserName});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final Map<String, double> _defaultVolumes = {
    'Pint': 568,
    'Half Pint': 284,
    'Wine Glass': 175,
    'Can': 330,
    'Shot': 25,
  };

  final Map<String, double> _defaultAbv = {
    'Pint': 5.0,
    'Half Pint': 5.0,
    'Wine Glass': 14,
    'Can': 5.0,
    'Shot': 40,
  };

  String _drinkType = 'Pint';
  late TextEditingController _volumeController;
  late TextEditingController _abvController;
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _volumeController =
        TextEditingController(text: _defaultVolumes[_drinkType]!.toString());
    _abvController =
        TextEditingController(text: _defaultAbv[_drinkType]!.toString());
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _abvController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  double get _volume => double.tryParse(_volumeController.text) ?? 0;
  double get _abv => double.tryParse(_abvController.text) ?? 0;
  double get _units => (_volume * _abv) / 1000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual Drink Entry")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _drinkType,
                items: _defaultVolumes.keys.map((drink) {
                  return DropdownMenuItem(value: drink, child: Text(drink));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    if (val != null) {
                      _drinkType = val;
                      _volumeController.text =
                          _defaultVolumes[_drinkType]?.toString() ?? '';
                      _abvController.text =
                          _defaultAbv[_drinkType]?.toString() ?? '';
                    }
                  });
                },
                decoration: const InputDecoration(labelText: "Drink Type"),
              ),
              TextFormField(
                controller: _volumeController,
                decoration: const InputDecoration(labelText: "Volume (ml)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              TextFormField(
                controller: _abvController,
                decoration: const InputDecoration(labelText: "ABV (%)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: "Location (optional)"),
              ),
              const SizedBox(height: 20),
              Text("Units: ${_units.toStringAsFixed(2)}"),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    final entry = DrinkEntry(
                      timestamp: DateTime.now(),
                      userName: widget.currentUserName, // Uses the passed-in username
                      type: _drinkType,
                      volume: _volume,
                      abv: _abv,
                      units: _units,
                      location: _locationController.text.isNotEmpty
                          ? _locationController.text
                          : null,
                    );
                    Navigator.pop(context, entry);
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

