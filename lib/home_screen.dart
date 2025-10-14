import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';

import 'models/drink_entry.dart';
import 'manual_entry.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  final NotchBottomBarController _barController =
  NotchBottomBarController(index: 0);

  final List<DrinkEntry> _drinks = [];

  int get _currentIndex => _barController.index;

  Future<void> _onTabChanged(int index) async {
    _barController.index = index;
    setState(() {});

    if (index == 1) {
      // Wait for notch animation
      await Future.delayed(const Duration(milliseconds: 300));

      // Show the add menu and wait until it's closed
      await _showAddDrinkMenu();

      // After everything is closed, reset to last non-add page
      if (mounted) {
        final fallbackIndex = _currentIndex == 0 ? 0 : 2;
        _barController.index = fallbackIndex;
        _pageController.jumpToPage(fallbackIndex == 0 ? 0 : 1);
        setState(() {});
      }
    } else {
      _pageController.jumpToPage(index == 0 ? 0 : 1);
    }
  }

  Future<void> _showAddDrinkMenu() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Manual Entry'),
              onTap: () async {
                Navigator.pop(context); // close sheet
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualEntryScreen(),
                  ),
                );
                if (result != null && result is DrinkEntry) {
                  setState(() {
                    _drinks.add(result);
                  });
                }
              },
            ),
            const ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Picture/Automatic Entry'),
              enabled: false,
            ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _currentIndex == 0
            ? "Leaderboard"
            : _currentIndex == 1
            ? "Add Drink"
            : "My Drinks",
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Settings tapped")),
            );
          },
        ),
      ],
    );
  }

  Color contrastColor(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barColour = Colors.black45;//colorScheme.surface;
    final notchColour = colorScheme.primary;

    return Scaffold(
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          // Map PageView index back to bar index (0=Leaderboard, 2=My Drinks)
          _barController.index = index == 0 ? 0 : 2;
          setState(() {});
        },
        children: [
          LeaderboardScreen(drinks: _drinks),
          DrinkListView(drinks: _drinks),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: AnimatedNotchBottomBar(
        notchBottomBarController: _barController,
        color: barColour,
        notchColor: notchColour,
        showLabel: true,
        elevation: 8,
        kBottomRadius: 15.0,
        kIconSize: 24.0,
        bottomBarItems: [
          BottomBarItem(
            inActiveItem:
            Icon(Icons.leaderboard, color: contrastColor(barColour)),
            activeItem:
            Icon(Icons.leaderboard, color: contrastColor(notchColour)),
            itemLabel: 'Leaderboard',
          ),
          BottomBarItem(
            inActiveItem: Icon(Icons.add, color: contrastColor(barColour)),
            activeItem: Icon(Icons.add, color: contrastColor(notchColour)),
            itemLabel: 'Add',
          ),
          BottomBarItem(
            inActiveItem:
            Icon(Icons.local_drink, color: contrastColor(barColour)),
            activeItem:
            Icon(Icons.local_drink, color: contrastColor(notchColour)),
            itemLabel: 'My Drinks',
          ),
        ],
        onTap: _onTabChanged,
      ),
    );
  }
}

class DrinkListView extends StatelessWidget {
  final List<DrinkEntry> drinks;
  const DrinkListView({super.key, required this.drinks});

  @override
  Widget build(BuildContext context) {
    if (drinks.isEmpty) {
      return const Center(child: Text("No drinks logged yet"));
    }

    // Group drinks by date
    final Map<String, List<DrinkEntry>> grouped = {};
    for (var d in drinks) {
      final dateKey = DateFormat('yyyy-MM-dd').format(d.timestamp.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(d);
    }

    // Sort dates newest first
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final entries = grouped[dateKey]!;

        // Sort entries newest first
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final totalUnits = entries.fold<double>(0, (sum, e) => sum + e.units);
        final totalDrinks = entries.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEE, d MMM yyyy')
                        .format(entries.first.timestamp.toLocal()),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    "$totalDrinks drinks • ${totalUnits.toStringAsFixed(2)} units",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            // Drinks for that day
            ...entries.map((drink) {
              final formatted = DateFormat('EEE, d MMM yyyy HH:mm')
                  .format(drink.timestamp.toLocal());
              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.local_drink),
                  title: Text(
                      "${drink.type} - ${drink.volume.toStringAsFixed(0)} ml"),
                  subtitle: Text(
                    "${drink.abv.toStringAsFixed(1)}% • ${drink.units.toStringAsFixed(2)} units\n"
                        "$formatted${drink.location != null ? " • ${drink.location}" : ""}",
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}