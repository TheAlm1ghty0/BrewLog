import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../models/drink_entry.dart';

// --- Default Drink Data ---
final Map<String, double> defaultVolumes = {
  'Pint': 568, 'Half Pint': 284, 'Wine Glass': 175, 'Can': 330, 'Shot': 25,
  'Martini Glass': 180, 'Margarita Glass': 300, 'Hurricane Glass': 600,
};
final Map<String, double> defaultAbv = {
  'Pint': 5.0, 'Half Pint': 5.0, 'Wine Glass': 14, 'Can': 5.0, 'Shot': 40,
  'Martini Glass': 35.0, 'Margarita Glass': 25.0, 'Hurricane Glass': 20.0,
};

// Main screen widget
class ManualEntryScreen extends StatefulWidget {
  final String userName;
  final List<DrinkEntry> userDrinks;
  final Set<String> hiddenSignatures;
  final Function(DrinkEntry) onHideRecent;

  const ManualEntryScreen({
    super.key,
    required this.userName,
    required this.userDrinks,
    required this.hiddenSignatures,
    required this.onHideRecent,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  Key _formKey = UniqueKey();
  DrinkEntry? _initialDrink;
  late List<DrinkEntry> _recents;

  @override
  void initState() {
    super.initState();
    _buildRecentsList();
  }

  void _buildRecentsList() {
    final recentUniqueDrinks = <DrinkEntry>[];
    final uniqueSignatures = <String>{};

    for (var drink in widget.userDrinks) {
      final signature = '${drink.type}-${drink.volume}-${drink.abv}';
      final isDefault = defaultVolumes[drink.type] == drink.volume && defaultAbv[drink.type] == drink.abv;

      if (isDefault || widget.hiddenSignatures.contains(signature)) continue;

      if (!uniqueSignatures.contains(signature)) {
        uniqueSignatures.add(signature);
        recentUniqueDrinks.add(drink);
      }
      if (recentUniqueDrinks.length >= 5) break;
    }
    _recents = recentUniqueDrinks;
  }

  void _prefillFromRecent(DrinkEntry drink) {
    setState(() {
      _initialDrink = drink;
      _formKey = UniqueKey();
    });
  }

  void _handleHide(DrinkEntry drink) {
    widget.onHideRecent(drink);
    setState(() {
      _buildRecentsList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Manual Drink Entry")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_recents.isNotEmpty) ...[
              Text('Recents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _recents.map((drink) {
                  return GestureDetector(
                    onLongPress: () {
                      AwesomeDialog(
                        context: context,
                        animType: AnimType.bottomSlide,
                        title: 'Hide Recent',
                        desc: 'Would you like to hide this from your recents list for this session?',
                        dialogBackgroundColor: Theme.of(context).cardColor,
                        titleTextStyle: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
                        descTextStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        customHeader: Icon(
                          Icons.warning,
                          size: 60,
                          color: colorScheme.tertiary,
                        ),
                        btnCancelOnPress: () {},
                        btnOkText: 'Hide',
                        btnOkColor: colorScheme.tertiary,
                        btnOkOnPress: () {
                          _handleHide(drink);
                        },
                      ).show();
                    },
                    child: ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(
                          '${drink.type} (${drink.volume.toStringAsFixed(0)}ml, ${drink.abv.toStringAsFixed(1)}%)'),
                      onPressed: () => _prefillFromRecent(drink),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 32),
            ],
            _ManualEntryForm(
              key: _formKey,
              userName: widget.userName,
              initialDrink: _initialDrink,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualEntryForm extends StatefulWidget {
  final String userName;
  final DrinkEntry? initialDrink;

  const _ManualEntryForm({super.key, required this.userName, this.initialDrink});

  @override
  State<_ManualEntryForm> createState() => __ManualEntryFormState();
}

class __ManualEntryFormState extends State<_ManualEntryForm> {
  final _formKey = GlobalKey<FormState>();

  late String _drinkType;
  late TextEditingController _volumeController;
  late TextEditingController _abvController;
  final TextEditingController _locationController = TextEditingController();
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _drinkType = widget.initialDrink?.type ?? 'Pint';
    _volumeController = TextEditingController(text: widget.initialDrink?.volume.toStringAsFixed(0) ?? defaultVolumes[_drinkType]?.toString() ?? '0');
    _abvController = TextEditingController(text: widget.initialDrink?.abv.toStringAsFixed(1) ?? defaultAbv[_drinkType]?.toString() ?? '0');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _abvController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation) return;
    if (mounted) setState(() => _isFetchingLocation = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 5));
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');

      Position position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 10));
      if (!mounted) return;
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> locationParts = [];
        if (place.locality != null && place.locality!.isNotEmpty) {
          locationParts.add(place.locality!);
        } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) locationParts.add(place.subAdministrativeArea!);
        if (place.country != null && place.country!.isNotEmpty) locationParts.add(place.country!);
        if (mounted) setState(() => _locationController.text = locationParts.join(', '));
      }
    } on TimeoutException catch (_) {
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Could not get location: Timed out.', style: TextStyle(color: colorScheme.onTertiaryContainer)),
        backgroundColor: colorScheme.tertiaryContainer,
      ));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Could not get location: ${e.toString()}', style: TextStyle(color: colorScheme.onErrorContainer)),
        backgroundColor: colorScheme.errorContainer,
      ));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  double get _volume => double.tryParse(_volumeController.text) ?? 0;
  double get _abv => double.tryParse(_abvController.text) ?? 0;
  double get _units => (_volume * _abv) / 1000;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownMenu<String>(
            initialSelection: defaultVolumes.containsKey(_drinkType) ? _drinkType : null,
            label: const Text('Drink Type'),
            expandedInsets: EdgeInsets.zero,
            onSelected: (String? val) {
              if (val != null) {
                setState(() {
                  _drinkType = val;
                  _volumeController.text = defaultVolumes[val]!.toString();
                  _abvController.text = defaultAbv[val]!.toString();
                });
              }
            },
            dropdownMenuEntries: defaultVolumes.keys.map((String drink) {
              return DropdownMenuEntry<String>(value: drink, label: drink);
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _volumeController,
            decoration: const InputDecoration(
              labelText: "Volume (ml)",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _abvController,
            decoration: const InputDecoration(
              labelText: "ABV (%)",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: "Location (optional)",
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isFetchingLocation)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)),
                    )
                  else
                    IconButton(icon: const Icon(Icons.my_location), onPressed: _getCurrentLocation),
                  if (_locationController.text.isNotEmpty)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _locationController.clear())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text("Units: ${_units.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final now = DateTime.now(); // <-- YOUR TIMESTAMP CHANGE
                final entry = DrinkEntry(
                  // id is no longer required, so this is valid
                  timestamp: DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second), // <-- YOUR TIMESTAMP CHANGE
                  type: _drinkType,
                  volume: _volume,
                  abv: _abv,
                  units: _units,
                  userName: widget.userName,
                  location: _locationController.text.isNotEmpty ? _locationController.text : null,
                );
                Navigator.pop(context, entry);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}