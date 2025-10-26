import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Import color picker
import '../providers/theme_provider.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _isGenerating = false;

  Future<void> _generateTheme() async {
    setState(() => _isGenerating = true);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await themeProvider.fetchNewAiInspiration();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('New AI theme generated!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to generate theme: $e', style: TextStyle(color: colorScheme.onErrorContainer)),
          backgroundColor: colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showColorPicker(BuildContext context, int index, Color currentColor) {
    Color pickerColor = currentColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
              // enableAlpha: false, // Optional: disable alpha slider
              // pickerAreaHeightPercent: 0.8, // Optional: adjust size
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Select'),
              onPressed: () {
                Provider.of<ThemeProvider>(context, listen: false)
                    .updateColorAt(index, pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Theme Mode Switch ---
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode)),
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode)),
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto)),
                  ],
                  selected: <ThemeMode>{themeProvider.themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    themeProvider.setThemeMode(newSelection.first);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- AI Palette Generator ---
            Text('AI Generated Palette', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Tap to lock/unlock, long press to pick manually.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final color = themeProvider.paletteColors[index];
                final isLocked = themeProvider.lockedColors[index];
                final brightness = ThemeData.estimateBrightnessForColor(color);
                final iconColor = brightness == Brightness.dark ? Colors.white : Colors.black;

                return GestureDetector(
                  onTap: () => themeProvider.toggleLock(index),
                  onLongPress: () => _showColorPicker(context, index, color),
                  child: Container(
                    width: MediaQuery.of(context).size.width / 3 - 16, // Adjust width for 3 per row
                    height: 80,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (isLocked)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(Icons.lock, size: 16, color: iconColor.withValues(alpha: 0.7)),
                          ),
                        Center(
                          child: Text(
                            _getRoleLabel(index),
                            style: TextStyle(fontSize: 10, color: iconColor.withValues(alpha: 0.9)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            _isGenerating
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate New Palette'),
              onPressed: _generateTheme,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to label the swatches (adjust based on final mapping)
  String _getRoleLabel(int index) {
    switch (index) {
      case 0: return 'Primary';
      case 1: return 'Secondary';
      case 2: return 'Tertiary';
      case 3: return 'Surface/\nBackground'; // Neutral
      case 4: return 'Container/\nOutline'; // Neutral Variant
      default: return '';
    }
  }
}