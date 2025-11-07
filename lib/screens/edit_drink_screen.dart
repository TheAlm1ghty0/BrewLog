import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:provider/provider.dart'; // Import Provider
import '../models/drink_entry.dart';
import '../models/cocktail.dart'; // Import the Cocktail model
import '../services/api_service.dart'; // Import ApiService
import '../providers/auth_provider.dart'; // Import AuthProvider for session/error handling

// --- Preset Definitions (Copied from manual_entry_screen) ---
enum DrinkCategory { beer, cider, wine, shot, cocktail }
// ... (presetData map remains the same) ...
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
    'Custom': {'volume': 250, 'abv': 15.0}, // Default for custom cocktail
  }
};
// --- End Preset Definitions ---


// Main screen widget
class EditDrinkScreen extends StatefulWidget {
  final DrinkEntry drinkToEdit; // The drink we are editing

  const EditDrinkScreen({
    super.key,
    required this.drinkToEdit,
  });

  @override
  State<EditDrinkScreen> createState() => _EditDrinkScreenState();
}

class _EditDrinkScreenState extends State<EditDrinkScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Cocktail>>? _cocktailsFuture;
  List<Cocktail> _cocktailList = []; // To store fetched cocktails
  bool _isLoading = false; // Loading state for save operation
  bool _cocktailsLoading = false;

  // Form state variables
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _volumeController;
  late TextEditingController _abvController;
  late TextEditingController _locationController;
  bool _isFetchingLocation = false;

  DrinkCategory? _selectedCategory;
  String? _selectedPreset;
  List<String> _presetOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchCocktails();
    _initializeFormFields(); // Initialize form with drink data
    // Fetch location after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _locationController.text.isEmpty) _getCurrentLocation();
    });
  }

  void _fetchCocktails() {
    // Only fetch if not already fetched/loading
    if (_cocktailsFuture == null) {
      setState(() {
        _cocktailsLoading = true;
      });
      _cocktailsFuture = _apiService.getCocktails();
      _cocktailsFuture!.then((list) {
        if (mounted) {
          setState(() {
            _cocktailList = list;
            _cocktailsLoading = false;
            // Re-update preset options if cocktail was selected before list loaded
            if (_selectedCategory == DrinkCategory.cocktail) {
              _updatePresetOptions();
              // Try to re-select preset if it's a known cocktail
              final knownCocktail = _cocktailList.any((c) => c.name == widget.drinkToEdit.name);
              if (knownCocktail) {
                setState(() {
                  _selectedPreset = widget.drinkToEdit.name;
                });
              }
              // --- MODIFICATION ---
              // If it's not a known cocktail, _selectedPreset will remain null
              // --- END MODIFICATION ---
            }
          });
        }
      }).catchError((e) {
        print("Failed to fetch cocktails: $e");
        if (mounted) {
          setState(() {
            _cocktailsLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load cocktail list: $e'), backgroundColor: Colors.red),
          );
        }
      });
    }
  }

  // Helper to set initial form values based on widget.drinkToEdit
  void _initializeFormFields() {
    // Pre-fill from the drink being edited
    _nameController = TextEditingController(text: widget.drinkToEdit.name ?? '');
    _volumeController = TextEditingController(text: widget.drinkToEdit.volume.toStringAsFixed(0));
    _abvController = TextEditingController(text: widget.drinkToEdit.abv.toStringAsFixed(1));
    _locationController = TextEditingController(text: widget.drinkToEdit.location ?? '');

    // Try to match the category
    _selectedCategory = _getCategoryFromString(widget.drinkToEdit.type);

    // Update preset options based on matched category
    _updatePresetOptions();

    // --- MODIFICATION: Set preset to null if no match ---
    _selectedPreset = null; // Default to null (blank)

    if (_selectedCategory == DrinkCategory.cocktail) {
      // If cocktail list is already loaded, check against it
      if (_cocktailList.isNotEmpty) {
        if (_cocktailList.any((c) => c.name == widget.drinkToEdit.name)) {
          _selectedPreset = widget.drinkToEdit.name;
        }
        // If no match, _selectedPreset stays null (blank)
      }
      // If list isn't loaded, _selectedPreset stays null, will be checked later in _fetchCocktails
    } else if (_selectedCategory != null) {
      // Check if it matches a standard preset
      final presets = presetData[_selectedCategory]?.keys.toList() ?? [];
      // Find the preset, or return null if no match
      _selectedPreset = presets.firstWhere(
            (p) => p != 'Custom' &&
            presetData[_selectedCategory]![p]!['volume'] == widget.drinkToEdit.volume &&
            presetData[_selectedCategory]![p]!['abv'] == widget.drinkToEdit.abv,
        orElse: () => "", // Set to null if no preset matches
      );
    }
    // --- END MODIFICATION ---
  }

  DrinkCategory? _getCategoryFromString(String typeStr) {
    final type = typeStr.toLowerCase();
    if (type == 'beer') return DrinkCategory.beer;
    if (type == 'cider') return DrinkCategory.cider;
    if (type == 'wine') return DrinkCategory.wine;
    if (type == 'shot') return DrinkCategory.shot;
    if (type == 'cocktail') return DrinkCategory.cocktail;
    return null; // Fallback
  }


  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    _abvController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- Location Fetching (Copied from Manual Entry) ---
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
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)));
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

  // --- Dropdown Logic (Copied from Manual Entry) ---
  void _onCategoryChanged(DrinkCategory? newCategory) {
    setState(() {
      _selectedCategory = newCategory;
      _selectedPreset = null; // Reset preset
      _updatePresetOptions(); // Update options for Dropdown 2

      if (newCategory == DrinkCategory.shot) {
        _selectedPreset = 'Single (25ml)';
        _prefillFields(DrinkCategory.shot, 'Single (25ml)');
      } else if (newCategory != null) {
        // --- ADDED: Clear fields when category changes ---
        // This forces user to pick a new preset or enter custom values,
        // preventing saving (e.g.) a "Wine" with "Pint" values.
        _volumeController.clear();
        _abvController.clear();
        // --- END ADDED ---
      } else {
        // Category was cleared
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
      _presetOptions = [
        // --- FIX: Use _cocktailList (state variable) ---
        ..._cocktailList.map((c) => c.name),
        // --- END FIX ---
        'Custom'
      ];
    } else {
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
      final customData = presetData[category]?['Custom'];
      if (customData != null) {
        _volumeController.text = customData['volume']!.toStringAsFixed(0);
        _abvController.text = customData['abv']!.toStringAsFixed(1);
      }
    }
    else if (category == DrinkCategory.cocktail) {
      // --- FIX: Use _cocktailList (state variable) ---
      final cocktail = _cocktailList.firstWhere(
        // --- END FIX ---
            (c) => c.name == preset,
        orElse: () => Cocktail(id: 0, name: 'Custom', defaultVolume: 250, defaultAbv: 15.0),
      );
      _volumeController.text = cocktail.defaultVolume.toStringAsFixed(0);
      _abvController.text = cocktail.defaultAbv.toStringAsFixed(1);
      if (_nameController.text.isEmpty) {
        _nameController.text = cocktail.name;
      }
    }
    else {
      final presetMap = presetData[category];
      if (presetMap != null && presetMap.containsKey(preset)) {
        final data = presetMap[preset]!;
        _volumeController.text = data['volume']!.toStringAsFixed(0);
        _abvController.text = data['abv']!.toStringAsFixed(1);
      }
    }
    setState(() {}); // Trigger rebuild to update units display
  }
  // --- End Dropdown Logic ---

  // --- Save Logic ---
  Future<void> _submitForm() async {
    final currentContext = context; // Capture context
    if (!currentContext.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
    final navigator = Navigator.of(currentContext);
    final colorScheme = Theme.of(currentContext).colorScheme;

    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      if (_selectedCategory == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Please select a drink category.', style: TextStyle(color: colorScheme.onErrorContainer)),
            backgroundColor: colorScheme.errorContainer,
          ),
        );
      }
      return; // Stop if form invalid or category not selected
    }

    // Ensure drink ID is valid
    if (widget.drinkToEdit.id == null) {
      _showError("Error: Cannot update drink without a valid ID.");
      return;
    }

    setState(() => _isLoading = true);

    // Create a new DrinkEntry object with the updated data
    // Use the *original* timestamp and username
    final updatedDrinkData = DrinkEntry(
      id: widget.drinkToEdit.id, // Keep the original ID
      timestamp: widget.drinkToEdit.timestamp, // Keep the original timestamp
      userName: widget.drinkToEdit.userName, // Keep the original user
      // --- Updated Fields ---
      type: _selectedCategory!.name, // Use new category name
      name: _nameController.text.isNotEmpty ? _nameController.text : null,
      volume: _volume,
      abv: _abv,
      units: _units, // Pass the newly calculated units
      location: _locationController.text.isNotEmpty ? _locationController.text : null,
    );

    try {
      // Call the new API service method
      await _apiService.updateDrink(widget.drinkToEdit.id!, updatedDrinkData);

      // Check mounted after await
      if (!currentContext.mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${updatedDrinkData.name ?? updatedDrinkData.type} updated successfully!'),
          backgroundColor: Colors.green[700],
        ),
      );
      navigator.pop(true); // Pop and signal success (true) to refresh HomeScreen

    } on SessionExpiredException catch (_) {
      print("Session expired during drink update.");
      if(currentContext.mounted) {
        Provider.of<AuthProvider>(currentContext, listen: false).logout();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
      }
    } catch (e) {
      print("Failed to update drink: $e");
      if (currentContext.mounted) {
        _showError('Failed to update drink: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    final currentContext = context;
    if (!currentContext.mounted) return;
    final colorScheme = Theme.of(currentContext).colorScheme;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onErrorContainer)),
        backgroundColor: colorScheme.errorContainer,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  // --- End Save Logic ---

  @override
  Widget build(BuildContext context) {
    // Recalculate units string whenever build runs
    final unitsString = "Units: ${_units.toStringAsFixed(2)}";

    return Scaffold(
      appBar: AppBar(
        title: Text("Edit ${widget.drinkToEdit.name ?? widget.drinkToEdit.type}"),
        // --- REMOVED ACTION BUTTON ---
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.check),
        //     tooltip: 'Save Changes',
        //     onPressed: _isLoading ? null : _submitForm, // Disable when loading
        //   ),
        // ],
        // --- END REMOVAL ---
      ),
      body: Stack( // Use stack to show loading overlay
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
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
                  ),
                  const SizedBox(height: 16),

                  // --- Dropdown 1: Category ---
                  DropdownMenu<DrinkCategory>(
                    initialSelection: _selectedCategory,
                    label: const Text('Category *'),
                    expandedInsets: EdgeInsets.zero,
                    onSelected: _onCategoryChanged,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: DrinkCategory.beer, label: 'Beer'),
                      DropdownMenuEntry(value: DrinkCategory.cider, label: 'Cider'),
                      DropdownMenuEntry(value: DrinkCategory.wine, label: 'Wine'),
                      DropdownMenuEntry(value: DrinkCategory.shot, label: 'Shot'),
                      DropdownMenuEntry(value: DrinkCategory.cocktail, label: 'Cocktail'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Dropdown 2: Preset (Conditional) ---
                  Visibility(
                    visible: _selectedCategory != null && _selectedCategory != DrinkCategory.shot,
                    child: DropdownMenu<String>(
                      key: ValueKey(_selectedCategory),
                      initialSelection: _selectedPreset, // This will be null if no match
                      hintText: 'Select preset (optional)', // Add hint text
                      label: Text(_selectedCategory == DrinkCategory.cocktail ? 'Cocktail Type' : 'Preset Size'),
                      expandedInsets: EdgeInsets.zero,
                      onSelected: _onPresetChanged,
                      // --- MODIFIED: Use state variable ---
                      enabled: _selectedCategory == DrinkCategory.cocktail ? !_cocktailsLoading : true,
                      // --- END MODIFICATION ---
                      dropdownMenuEntries: _presetOptions.map((String preset) {
                        return DropdownMenuEntry<String>(value: preset, label: preset);
                      }).toList(),
                    ),
                  ),
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
                    onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
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

                  // --- NEW: Save Button at bottom ---
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt), // Use save icon
                    label: const Text("Save Changes"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _submitForm, // Disable when loading
                  ),
                  // --- END NEW BUTTON ---
                ],
              ),
            ),
          ),
          // --- Loading Overlay ---
          if (_isLoading)
            Container(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha:0.6),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}