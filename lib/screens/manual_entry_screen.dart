import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../models/drink_entry.dart';
import '../models/cocktail.dart'; // Import the new Cocktail model
import '../services/api_service.dart'; // Import ApiService

// --- New Preset Definitions ---
enum DrinkCategory { beer, cider, wine, shot, cocktail }

const Map<DrinkCategory, Map<String, Map<String, double>>> presetData = {
  DrinkCategory.beer: {
    'Pint': {'volume': 568, 'abv': 5.0},
    'Half Pint': {'volume': 284, 'abv': 5.0},
    'Can (330ml)': {'volume': 330, 'abv': 5.0},
    'Can (440ml)': {'volume': 440, 'abv': 5.2},
    'Bottle (330ml)': {'volume': 330, 'abv': 5.0},
    'Custom': {'volume': 568, 'abv': 5.0}, // Default for custom
  },
  DrinkCategory.cider: {
    'Pint': {'volume': 568, 'abv': 4.5},
    'Half Pint': {'volume': 284, 'abv': 4.5},
    'Can (500ml)': {'volume': 500, 'abv': 4.5},
    'Bottle (500ml)': {'volume': 500, 'abv': 4.5},
    'Custom': {'volume': 568, 'abv': 4.5},
  },
  DrinkCategory.wine: {
    'Small Glass (125ml)': {'volume': 125, 'abv': 13.0},
    'Medium Glass (175ml)': {'volume': 175, 'abv': 13.0},
    'Large Glass (250ml)': {'volume': 250, 'abv': 13.0},
    'Bottle (750ml)': {'volume': 750, 'abv': 13.0},
    'Custom': {'volume': 175, 'abv': 13.0},
  },
  DrinkCategory.shot: {
    'Single (25ml)': {'volume': 25, 'abv': 40.0},
    'Double (50ml)': {'volume': 50, 'abv': 40.0},
    'Custom': {'volume': 25, 'abv': 40.0},
  },
  DrinkCategory.cocktail: {
    // Custom will be handled separately
    'Custom': {'volume': 250, 'abv': 15.0}, // Default for custom cocktail
  }
};
// --- End Preset Definitions ---


// Main screen widget
class ManualEntryScreen extends StatefulWidget {
  final String userName;
  final List<DrinkEntry> userDrinks; // Passed for recents
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
  final ApiService _apiService = ApiService();
  Future<List<Cocktail>>? _cocktailsFuture;
  List<Cocktail> _cocktailList = []; // To store fetched cocktails

  Key _formKey = UniqueKey(); // Used to reset form state when prefilling
  DrinkEntry? _initialDrink; // Holds data for prefilling
  late List<DrinkEntry> _recents; // Holds the calculated recent drinks

  @override
  void initState() {
    super.initState();
    _buildRecentsList();
    _fetchCocktails();
  }

  void _fetchCocktails() {
    _cocktailsFuture = _apiService.getCocktails();
    // Pre-load the list for the dropdown
    _cocktailsFuture!.then((list) {
      if (mounted) {
        setState(() {
          _cocktailList = list;
        });
      }
    }).catchError((e) {
      // Handle error fetching cocktails, maybe show a snackbar
      print("Failed to fetch cocktails: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load cocktail list: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  // Calculates the list of unique, non-default recent drinks
  void _buildRecentsList() {
    final recentUniqueDrinks = <DrinkEntry>[];
    final uniqueSignatures = <String>{};

    for (var drink in widget.userDrinks) {
      // Use name if available, otherwise type for signature
      final primaryIdentifier = drink.name ?? drink.type;
      final signature = '$primaryIdentifier-${drink.volume}-${drink.abv}';

      // We don't check for defaults here, just show unique recent customs/named drinks
      // But for simplicity, let's just show recent drinks that have a 'name'
      if (drink.name != null && drink.name!.isNotEmpty) {
        if (!uniqueSignatures.contains(signature)) {
          uniqueSignatures.add(signature);
          recentUniqueDrinks.add(drink);
        }
      }
      if (recentUniqueDrinks.length >= 5) break;
    }
    _recents = recentUniqueDrinks;
  }

  // Sets the initial drink data and forces form rebuild
  void _prefillFromRecent(DrinkEntry drink) {
    setState(() {
      _initialDrink = drink;
      _formKey = UniqueKey(); // Change key to force form state reset
    });
  }

  // Hides a recent drink signature and rebuilds the recents list
  void _handleHide(DrinkEntry drink) {
    widget.onHideRecent(drink); // Call parent callback to update hidden set
    setState(() {
      _buildRecentsList(); // Rebuild the list displayed in this screen
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
            // --- Recents Section (Now shows named drinks) ---
            if (_recents.isNotEmpty) ...[
              Text('Recents (Long press to hide)', style: Theme.of(context).textTheme.titleMedium),
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
                        desc: 'Hide "${drink.name}" from recents for this session?',
                        dialogBackgroundColor: Theme.of(context).cardColor,
                        titleTextStyle: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
                        descTextStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        customHeader: Icon(
                          Icons.visibility_off_outlined,
                          size: 60,
                          color: colorScheme.secondary,
                        ),
                        btnCancelOnPress: () {},
                        btnOkText: 'Hide',
                        btnOkColor: colorScheme.secondary,
                        btnOkOnPress: () {
                          _handleHide(drink);
                        },
                      ).show();
                    },
                    child: ActionChip(
                      avatar: Icon(Icons.history, size: 18, color: colorScheme.onSecondaryContainer),
                      label: Text(
                        // Show name, volume, and abv
                        '${drink.name} (${drink.volume.toStringAsFixed(0)}ml, ${drink.abv.toStringAsFixed(1)}%)',
                        style: TextStyle(color: colorScheme.onSecondaryContainer),
                      ),
                      backgroundColor: colorScheme.secondaryContainer,
                      tooltip: 'Tap to prefill form',
                      onPressed: () => _prefillFromRecent(drink),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 32),
            ],
            // --- Form Section ---
            _ManualEntryForm(
              key: _formKey,
              userName: widget.userName,
              initialDrink: _initialDrink, // Pass prefill data
              cocktailList: _cocktailList, // Pass fetched cocktail list
              cocktailsLoading: _cocktailsFuture == null || (_cocktailList.isEmpty && !_apiService.client.toString().contains('Error')), // Simplified loading check
            ),
          ],
        ),
      ),
    );
  }
}


// --- Form Widget ---
class _ManualEntryForm extends StatefulWidget {
  final String userName;
  final DrinkEntry? initialDrink; // Data passed from parent for prefilling
  final List<Cocktail> cocktailList; // List of cocktails from API
  final bool cocktailsLoading; // Flag if cocktails are still loading

  const _ManualEntryForm({
    super.key,
    required this.userName,
    this.initialDrink,
    required this.cocktailList,
    required this.cocktailsLoading,
  });

  @override
  State<_ManualEntryForm> createState() => __ManualEntryFormState();
}

class __ManualEntryFormState extends State<_ManualEntryForm> {
  final _formKey = GlobalKey<FormState>();

  // Form state variables
  late TextEditingController _nameController;
  late TextEditingController _volumeController;
  late TextEditingController _abvController;
  final TextEditingController _locationController = TextEditingController();
  bool _isFetchingLocation = false;

  DrinkCategory? _selectedCategory;
  String? _selectedPreset; // Can be a preset name or a cocktail name
  List<String> _presetOptions = []; // Options for Dropdown 2

  @override
  void initState() {
    super.initState();
    _initializeFormFields();
    // Fetch location after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _getCurrentLocation();
    });
  }

  // Sets initial form values based on initialDrink or defaults
  void _initializeFormFields() {
    if (widget.initialDrink != null) {
      // Prefilling from a recent drink
      _nameController = TextEditingController(text: widget.initialDrink!.name ?? '');
      _volumeController = TextEditingController(text: widget.initialDrink!.volume.toStringAsFixed(0));
      _abvController = TextEditingController(text: widget.initialDrink!.abv.toStringAsFixed(1));
      _locationController.text = widget.initialDrink!.location ?? '';

      // Try to match the category
      _selectedCategory = _getCategoryFromString(widget.initialDrink!.type);

      // Update preset options based on matched category
      _updatePresetOptions();

      // Try to match the preset
      // This is complex: was it a named cocktail, a preset, or custom?
      // For simplicity, if prefilling, we'll just set fields and not try to match dropdowns
      // Or, we can try:
      if (_selectedCategory == DrinkCategory.cocktail) {
        _selectedPreset = widget.cocktailList.any((c) => c.name == widget.initialDrink!.name)
            ? widget.initialDrink!.name
            : 'Custom';
      } else {
        // Check if it matches a preset in that category
        final presets = presetData[_selectedCategory]?.keys.toList() ?? [];
        _selectedPreset = presets.firstWhere(
              (p) => p != 'Custom' &&
              presetData[_selectedCategory]![p]!['volume'] == widget.initialDrink!.volume &&
              presetData[_selectedCategory]![p]!['abv'] == widget.initialDrink!.abv,
          orElse: () => 'Custom', // Default to custom if no preset matches
        );
      }

    } else {
      // Default state for a new drink
      _nameController = TextEditingController();
      _volumeController = TextEditingController();
      _abvController = TextEditingController();
      // Don't select a category by default
      _selectedCategory = null;
      _selectedPreset = null;
    }
  }

  DrinkCategory? _getCategoryFromString(String typeStr) {
    final type = typeStr.toLowerCase();
    if (type == 'beer') return DrinkCategory.beer;
    if (type == 'cider') return DrinkCategory.cider;
    if (type == 'wine') return DrinkCategory.wine;
    if (type == 'shot') return DrinkCategory.shot;
    if (type == 'cocktail') return DrinkCategory.cocktail;
    return null;
  }


  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    _abvController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- Location Fetching (unchanged from previous) ---
  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation) return;
    if (mounted) setState(() => _isFetchingLocation = true);
    final currentContext = context;
    if (!currentContext.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
    final colorScheme = Theme.of(currentContext).colorScheme;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 5));
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied, please enable in settings.');
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10));
      if (!currentContext.mounted) return;
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (!currentContext.mounted) return;
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> locationParts = [];
        if (place.locality != null && place.locality!.isNotEmpty) {
          locationParts.add(place.locality!);
        } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          locationParts.add(place.subAdministrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          locationParts.add(place.country!);
        }
        setState(() => _locationController.text = locationParts.join(', '));
      } else {
        if(currentContext.mounted) _showLocationError(scaffoldMessenger, colorScheme, 'Could not determine place name.');
      }
    } on TimeoutException catch (_) {
      if(currentContext.mounted) _showLocationError(scaffoldMessenger, colorScheme, 'Location timed out.');
    } catch (e) {
      if(currentContext.mounted) _showLocationError(scaffoldMessenger, colorScheme, 'Location error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }
  void _showLocationError(ScaffoldMessengerState messenger, ColorScheme colors, String message) {
    messenger.showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      backgroundColor: colors.errorContainer,
      duration: const Duration(seconds: 3),
    ));
  }
  // --- End Location Fetching ---


  // --- Form Input Getters & Calculations ---
  double get _volume => double.tryParse(_volumeController.text.replaceAll(',', '.')) ?? 0;
  double get _abv => double.tryParse(_abvController.text.replaceAll(',', '.')) ?? 0;
  double get _units => (_volume * _abv) / 1000;

  // --- New Dropdown Logic ---
  void _onCategoryChanged(DrinkCategory? newCategory) {
    setState(() {
      _selectedCategory = newCategory;
      _selectedPreset = null; // Reset preset
      _updatePresetOptions(); // Update options for Dropdown 2

      // Handle "Shot" category, which has no Dropdown 2
      if (newCategory == DrinkCategory.shot) {
        // Auto-select "Single (25ml)" and prefill
        _selectedPreset = 'Single (25ml)';
        _prefillFields(DrinkCategory.shot, 'Single (25ml)');
      }
      // Clear fields if category is cleared? Or keep? Let's clear.
      else if (newCategory == null) {
        _volumeController.clear();
        _abvController.clear();
      }
    });
  }

  void _updatePresetOptions() {
    if (_selectedCategory == null) {
      _presetOptions = [];
      return;
    }
    if (_selectedCategory == DrinkCategory.cocktail) {
      // Use fetched cocktail list + "Custom"
      _presetOptions = [
        ...widget.cocktailList.map((c) => c.name),
        'Custom'
      ];
    } else {
      // Use presetData map keys
      _presetOptions = presetData[_selectedCategory]?.keys.toList() ?? [];
    }
  }

  void _onPresetChanged(String? newPreset) {
    setState(() {
      _selectedPreset = newPreset;
      if (_selectedCategory != null && newPreset != null) {
        _prefillFields(_selectedCategory!, newPreset);
      }
    });
  }

  void _prefillFields(DrinkCategory category, String preset) {
    if (preset == 'Custom') {
      // Prefill with category's 'Custom' defaults
      final customData = presetData[category]?['Custom'];
      if (customData != null) {
        _volumeController.text = customData['volume']!.toStringAsFixed(0);
        _abvController.text = customData['abv']!.toStringAsFixed(1);
      }
      // Don't auto-fill name for custom
    }
    else if (category == DrinkCategory.cocktail) {
      // Find the cocktail in the fetched list
      final cocktail = widget.cocktailList.firstWhere(
            (c) => c.name == preset,
        orElse: () => Cocktail(id: 0, name: 'Custom', defaultVolume: 250, defaultAbv: 15.0), // Fallback
      );
      _volumeController.text = cocktail.defaultVolume.toStringAsFixed(0);
      _abvController.text = cocktail.defaultAbv.toStringAsFixed(1);
      // Auto-fill name field *only* if it's empty
      if (_nameController.text.isEmpty) {
        _nameController.text = cocktail.name;
      }
    }
    else {
      // It's a standard preset (Beer, Wine, Cider, Shot)
      final presetMap = presetData[category];
      if (presetMap != null && presetMap.containsKey(preset)) {
        final data = presetMap[preset]!;
        _volumeController.text = data['volume']!.toStringAsFixed(0);
        _abvController.text = data['abv']!.toStringAsFixed(1);
      }
    }
    // Trigger rebuild to update units display
    setState(() {});
  }
  // --- End New Dropdown Logic ---


  @override
  Widget build(BuildContext context) {
    final unitsString = "Units: ${_units.toStringAsFixed(2)}";

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Optional Drink Name ---
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Drink Name (Optional)",
              hintText: "e.g., Punk IPA, Mojito, Water...",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
            // No validator, it's optional
          ),
          const SizedBox(height: 16),

          // --- Dropdown 1: Category ---
          DropdownMenu<DrinkCategory>(
            initialSelection: _selectedCategory,
            label: const Text('Category *'),
            expandedInsets: EdgeInsets.zero,
            onSelected: _onCategoryChanged, // Use the new handler
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: DrinkCategory.beer, label: 'Beer'),
              DropdownMenuEntry(value: DrinkCategory.cider, label: 'Cider'),
              DropdownMenuEntry(value: DrinkCategory.wine, label: 'Wine'),
              DropdownMenuEntry(value: DrinkCategory.shot, label: 'Shot'),
              DropdownMenuEntry(value: DrinkCategory.cocktail, label: 'Cocktail'),
            ],
            // Simple validation
            // validator: (value) => value == null ? 'Please select a category.' : null, // Handled by save button
          ),
          const SizedBox(height: 16),

          // --- Dropdown 2: Preset (Conditional) ---
          Visibility(
            // Hide if no category selected or if category is "Shot"
            visible: _selectedCategory != null && _selectedCategory != DrinkCategory.shot,
            child: DropdownMenu<String>(
              key: ValueKey(_selectedCategory), // Rebuild when category changes
              initialSelection: _selectedPreset,
              label: Text(_selectedCategory == DrinkCategory.cocktail ? 'Cocktail Type *' : 'Preset Size *'),
              expandedInsets: EdgeInsets.zero,
              onSelected: _onPresetChanged,
              // Handle loading state for cocktails
              enabled: _selectedCategory == DrinkCategory.cocktail ? !widget.cocktailsLoading : true,
              dropdownMenuEntries: _presetOptions.map((String preset) {
                return DropdownMenuEntry<String>(value: preset, label: preset);
              }).toList(),
            ),
          ),
          // Add spacing only if the dropdown is visible
          if (_selectedCategory != null && _selectedCategory != DrinkCategory.shot)
            const SizedBox(height: 16),

          // --- Volume Input ---
          TextFormField(
            controller: _volumeController,
            decoration: const InputDecoration(
              labelText: "Volume (ml) *",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_drink_outlined),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter volume';
              final number = double.tryParse(value.replaceAll(',', '.'));
              if (number == null || number <= 0) return 'Enter valid positive volume';
              return null;
            },
            onChanged: (_) => setState(() {}), // Update units display
          ),
          const SizedBox(height: 16),

          // --- ABV Input ---
          TextFormField(
            controller: _abvController,
            decoration: const InputDecoration(
              labelText: "ABV (%) *",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.percent),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter ABV';
              final number = double.tryParse(value.replaceAll(',', '.'));
              if (number == null || number < 0 || number > 100) return 'Enter valid ABV (0-100)';
              return null;
            },
            onChanged: (_) => setState(() {}), // Update units display
          ),
          const SizedBox(height: 16),

          // --- Location Input ---
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: "Location (optional)",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isFetchingLocation)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)),
                    )
                  else
                    IconButton(
                        icon: const Icon(Icons.my_location),
                        tooltip: 'Get Current Location',
                        onPressed: _getCurrentLocation
                    ),
                  if (_locationController.text.isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear Location',
                        onPressed: () => setState(() => _locationController.clear())
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Units Display ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              unitsString,
              key: ValueKey<String>(unitsString),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // --- Save Button ---
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text("Save Drink"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate() && _selectedCategory != null) {
                final now = DateTime.now();
                final entry = DrinkEntry(
                  id: null, // ID is null for creation
                  // Truncate timestamp to seconds
                  timestamp: DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second),
                  // Use the category name (e.g., "Beer") as the type
                  type: _selectedCategory!.name,
                  // Use the text field content for the name
                  name: _nameController.text.isNotEmpty ? _nameController.text : null,
                  volume: _volume,
                  abv: _abv,
                  units: _units,
                  userName: widget.userName,
                  location: _locationController.text.isNotEmpty ? _locationController.text : null,
                );
                Navigator.pop(context, entry); // Pop screen and return new entry
              } else if (_selectedCategory == null) {
                // Show error if category not selected
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please select a drink category.', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}