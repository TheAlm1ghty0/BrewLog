import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import the TonalPalette and CorePalette (for error tones) and Hct
import 'package:material_color_utilities/material_color_utilities.dart';
import '../services/api_service.dart';

class ThemeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // --- Theme State ---
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeData _lightTheme = ThemeData.light(useMaterial3: true);
  ThemeData _darkTheme = ThemeData.dark(useMaterial3: true);

  // --- Palette State ---
  // These are the 5 KEY colors from the AI/User
  // Mapped: [Primary, Secondary, Tertiary, Neutral, NeutralVariant]
  List<Color> _paletteColors = [
    Colors.deepPurple, // Default Primary
    Color(0xff4fc3f7),  // Default Secondary (Light Blue)
    Color(0xff009688),  // Default Tertiary (Teal)
    Color(0xff424242),  // Default Neutral (Dark Grey for dark surface)
    Color(0xff757575),  // Default NeutralVariant (Grey for dark outline/container)
  ];
  List<bool> _lockedColors = [false, false, false, false, false];

  // --- Public Getters ---
  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => _lightTheme;
  ThemeData get darkTheme => _darkTheme;
  List<Color> get paletteColors => List.unmodifiable(_paletteColors); // Return unmodifiable list
  List<bool> get lockedColors => List.unmodifiable(_lockedColors); // Return unmodifiable list

  ThemeProvider() {
    loadTheme();
  }

  // --- Main Theme Generation Logic ---

  /// Step 1: Fetches 5 new inspiration colors from the AI
  Future<void> fetchNewAiInspiration() async {
    // 1. Build the list of locked colors to send to the API
    List<Color?> lockedInput = [];
    // Store the original locked colors to re-apply them later
    List<Color?> originalLockedColors = [];
    for (int i = 0; i < 5; i++) {
      if (_lockedColors[i]) {
        lockedInput.add(_paletteColors[i]);
        originalLockedColors.add(_paletteColors[i]);
      } else {
        lockedInput.add(null);
        originalLockedColors.add(null); // Keep track of which were locked
      }
    }

    List<Color> newAiColors;
    try {
      // 2. Call the API
      newAiColors = await _apiService.getAiUIPalette(lockedInput);
    } catch (e) {
      debugPrint("Failed to get AI palette: $e");
      rethrow; // Rethrow to show a SnackBar in the UI
    }

    // 3. Update the palette colors with the AI result
    _paletteColors = List.from(newAiColors); // Assign the new colors

    // --- Correction: Re-apply originally locked colors ---
    // Ensure the exact locked colors are preserved, overriding AI's subtle changes
    for (int i = 0; i < 5; i++) {
      if (originalLockedColors[i] != null) { // Check if this index was locked
        _paletteColors[i] = originalLockedColors[i]!;
      }
    }
    // --- End Correction ---


    // 4. Apply the new theme based on the potentially corrected palette
    _applyThemeFromPalette();
  }


  /// Step 2: User manually updates a color (e.g., from color picker)
  void updateColorAt(int index, Color color) {
    // Create a mutable copy, update, then assign back
    List<Color> mutablePalette = List.from(_paletteColors);
    mutablePalette[index] = color;
    _paletteColors = mutablePalette; // Assign the updated list back

    List<bool> mutableLocks = List.from(_lockedColors);
    mutableLocks[index] = true; // Lock color after a manual pick
    _lockedColors = mutableLocks; // Assign the updated list back

    _applyThemeFromPalette(); // Re-generate the theme
  }


  /// Step 3: Generates and applies the full M3 theme from the 5 colors
  void _applyThemeFromPalette() {
    // Ensure we have 5 colors before proceeding
    if (_paletteColors.length != 5) {
      print("Error: Palette does not contain 5 colors.");
      // Optionally set a default theme or handle error
      return;
    }

    // 1. Convert ARGB int values to HCT and create TonalPalettes
    final hctPrimary = Hct.fromInt(_paletteColors[0].value);
    final primaryPalette = TonalPalette.of(hctPrimary.hue, hctPrimary.chroma);

    final hctSecondary = Hct.fromInt(_paletteColors[1].value);
    final secondaryPalette = TonalPalette.of(hctSecondary.hue, hctSecondary.chroma);

    final hctTertiary = Hct.fromInt(_paletteColors[2].value);
    final tertiaryPalette = TonalPalette.of(hctTertiary.hue, hctTertiary.chroma);

    // --- REVERTED: Using Option B for Neutrals ---
    // Create neutrals directly from AI colors 4 and 5
    final hctNeutral = Hct.fromInt(_paletteColors[3].value);
    final neutralPalette = TonalPalette.of(hctNeutral.hue, hctNeutral.chroma);

    final hctNeutralVariant = Hct.fromInt(_paletteColors[4].value);
    final neutralVariantPalette = TonalPalette.of(hctNeutralVariant.hue, hctNeutralVariant.chroma);
    // --- END Option B ---

    // We still need a standard Error palette
    final errorPalette = CorePalette.of(Colors.red.value).error;


    // 2. Generate the base ColorSchemes
    ColorScheme lightColorScheme;
    ColorScheme darkColorScheme;
    try {
      lightColorScheme = _createColorScheme(
        brightness: Brightness.light,
        primary: primaryPalette,
        secondary: secondaryPalette,
        tertiary: tertiaryPalette,
        neutral: neutralPalette, // Using Option B
        neutralVariant: neutralVariantPalette, // Using Option B
        error: errorPalette,
      );
      darkColorScheme = _createColorScheme(
        brightness: Brightness.dark,
        primary: primaryPalette,
        secondary: secondaryPalette,
        tertiary: tertiaryPalette,
        neutral: neutralPalette, // Using Option B
        neutralVariant: neutralVariantPalette, // Using Option B
        error: errorPalette,
      );
    } catch (e) {
      print("Error creating base ColorScheme: $e");
      _lightTheme = ThemeData.light(useMaterial3: true);
      _darkTheme = ThemeData.dark(useMaterial3: true);
      notifyListeners(); // Notify with defaults if scheme creation fails
      return;
    }

    // --- Apply Container Color Overrides ---
    // Define specific tones for container levels using the NEUTRAL palette
    // Light Theme Tones (Brighter -> Darker)
    final ltContainerHighest = Color(neutralPalette.get(96)); // Tone from AI Neutral
    final ltContainerHigh = Color(neutralPalette.get(94));
    final ltContainer = Color(neutralPalette.get(92));
    final ltContainerLow = Color(neutralPalette.get(90));
    final ltContainerLowest = Color(neutralPalette.get(87));

    // Dark Theme Tones (Darker -> Brighter)
    final dtContainerLowest = Color(neutralPalette.get(4)); // Tone from AI Neutral
    final dtContainerLow = Color(neutralPalette.get(10));
    final dtContainer = Color(neutralPalette.get(12));
    final dtContainerHigh = Color(neutralPalette.get(17));
    final dtContainerHighest = Color(neutralPalette.get(22));


    _lightTheme = ThemeData(
      colorScheme: lightColorScheme.copyWith(
        // Override surface container colors explicitly
        surfaceContainerLowest: ltContainerLowest,
        surfaceContainerLow: ltContainerLow,
        surfaceContainer: ltContainer,
        surfaceContainerHigh: ltContainerHigh,
        surfaceContainerHighest: ltContainerHighest,
      ),
      useMaterial3: true,
    );

    _darkTheme = ThemeData(
      colorScheme: darkColorScheme.copyWith(
        // Override surface container colors explicitly
        surfaceContainerLowest: dtContainerLowest,
        surfaceContainerLow: dtContainerLow,
        surfaceContainer: dtContainer,
        surfaceContainerHigh: dtContainerHigh,
        surfaceContainerHighest: dtContainerHighest,
      ),
      useMaterial3: true,
    );
    // --- End Container Overrides ---


    // 3. Save and notify
    _saveThemeToPrefs();
    notifyListeners();
  }

  // --- Theme Mode Methods ---
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeModeToPrefs();
    notifyListeners();
  }

  void toggleLock(int index) {
    // Create mutable copy, update, assign back
    List<bool> mutableLocks = List.from(_lockedColors);
    mutableLocks[index] = !mutableLocks[index];
    _lockedColors = mutableLocks;

    notifyListeners(); // Notify UI to update lock icon
    // No need to save locks here, they are saved when the theme is applied/saved
  }


  // --- Helper & Persistence ---

  /// Uses the 5 TonalPalettes to generate a full Flutter ColorScheme
  ColorScheme _createColorScheme({
    required Brightness brightness,
    required TonalPalette primary,
    required TonalPalette secondary,
    required TonalPalette tertiary,
    required TonalPalette neutral,
    required TonalPalette neutralVariant,
    required TonalPalette error,
  }) {
    bool isLight = brightness == Brightness.light;
    // Base ColorScheme using standard tones for primary/secondary/tertiary/error etc.
    // Surface/SurfaceVariant tones adjusted slightly from strict defaults for potentially better base contrast
    return ColorScheme(
      brightness: brightness,
      primary: Color(primary.get(isLight ? 40 : 80)),
      onPrimary: Color(primary.get(isLight ? 100 : 20)),
      primaryContainer: Color(primary.get(isLight ? 90 : 30)),
      onPrimaryContainer: Color(primary.get(isLight ? 10 : 90)),
      secondary: Color(secondary.get(isLight ? 40 : 80)),
      onSecondary: Color(secondary.get(isLight ? 100 : 20)),
      secondaryContainer: Color(secondary.get(isLight ? 90 : 30)),
      onSecondaryContainer: Color(secondary.get(isLight ? 10 : 90)),
      tertiary: Color(tertiary.get(isLight ? 40 : 80)),
      onTertiary: Color(tertiary.get(isLight ? 100 : 20)),
      tertiaryContainer: Color(tertiary.get(isLight ? 90 : 30)),
      onTertiaryContainer: Color(tertiary.get(isLight ? 10 : 90)),
      error: Color(error.get(isLight ? 40 : 80)),
      onError: Color(error.get(isLight ? 100 : 20)),
      errorContainer: Color(error.get(isLight ? 90 : 30)),
      onErrorContainer: Color(error.get(isLight ? 10 : 90)),

      // Using slightly adjusted base surface/background tones here
      surface: Color(neutral.get(isLight ? 98 : 6)), // Slightly darker light surface, slightly brighter dark surface
      onSurface: Color(neutral.get(isLight ? 10 : 90)),
      surfaceVariant: Color(neutralVariant.get(isLight ? 90 : 30)), // Standard M3
      onSurfaceVariant: Color(neutralVariant.get(isLight ? 30 : 80)), // Standard M3

      outline: Color(neutralVariant.get(isLight ? 50 : 60)),
      outlineVariant: Color(neutralVariant.get(isLight ? 80 : 30)),
      shadow: Color(neutral.get(0)),
      scrim: Color(neutral.get(0)),
      inverseSurface: Color(neutral.get(isLight ? 20 : 90)),
      onInverseSurface: Color(neutral.get(isLight ? 95 : 20)),
      inversePrimary: Color(primary.get(isLight ? 80 : 40)),
      background: Color(neutral.get(isLight ? 98 : 6)), // Match adjusted surface
      onBackground: Color(neutral.get(isLight ? 10 : 90)), // Match adjusted onSurface
      surfaceTint: Color(primary.get(isLight ? 40 : 80)),
    );
  }


  Future<void> _saveThemeModeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
    // Save all 5 key colors
    final colorStrings = _paletteColors.map((c) => c.value.toString()).toList();
    await prefs.setStringList('palette_colors', colorStrings);
    // Save locks
    final lockStrings = _lockedColors.map((b) => b.toString()).toList();
    await prefs.setStringList('locked_colors', lockStrings);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Load ThemeMode
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.dark.index; // Default to dark if not saved
    _themeMode = ThemeMode.values[themeIndex];

    // Load Palette Colors
    final colorStrings = prefs.getStringList('palette_colors');
    if (colorStrings != null && colorStrings.length == 5) {
      try {
        _paletteColors = colorStrings.map((s) => Color(int.parse(s))).toList();
      } catch (e) {
        print("Error parsing saved palette colors: $e. Using defaults.");
        // Reset to defaults if parsing fails
        _paletteColors = [ Colors.deepPurple, Color(0xff4fc3f7), Color(0xff009688), Color(0xff424242), Color(0xff757575), ];
      }
    } else {
      // Use defaults if not saved or incorrect length
      _paletteColors = [ Colors.deepPurple, Color(0xff4fc3f7), Color(0xff009688), Color(0xff424242), Color(0xff757575), ];
    }


    // Load Locks
    final lockStrings = prefs.getStringList('locked_colors');
    if (lockStrings != null && lockStrings.length == 5) {
      try {
        _lockedColors = lockStrings.map((s) => s == 'true').toList();
      } catch (e) {
        print("Error parsing saved locked colors: $e. Using defaults.");
        _lockedColors = [false, false, false, false, false];
      }

    } else {
      _lockedColors = [false, false, false, false, false]; // Default to unlocked
    }

    // Re-generate the theme from the saved/default 5-color palette
    // Add try-catch here as well in case initial palette is problematic
    try {
      _applyThemeFromPalette();
    } catch (e) {
      print("Error applying loaded theme: $e. Using default themes.");
      _lightTheme = ThemeData.light(useMaterial3: true);
      _darkTheme = ThemeData.dark(useMaterial3: true);
      notifyListeners(); // Notify with defaults if apply fails
    }


    // No need to notifyListeners here if _applyThemeFromPalette does it
    // However, if _applyThemeFromPalette might throw *before* notifyListeners,
    // ensure notifyListeners is called in the catch block or finally block if needed.
    // Current structure calls notifyListeners within _applyThemeFromPalette.
  }
}

