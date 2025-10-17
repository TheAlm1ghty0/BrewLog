import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drink_entry.dart';
import '../manual_entry.dart';
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

  List<DrinkEntry> _drinks = [];
  int _lastNonAddIndex = 0;

  // Placeholder for the logged-in user's identity.
  // This will be replaced by a real authentication system later.
  final String _currentUserName = "Oscar";

  @override
  void initState() {
    super.initState();
    _loadDrinks(); // Load drinks from local storage on app start
  }

  // --- Local Storage Methods ---

  Future<void> _saveDrinks() async {
    final prefs = await SharedPreferences.getInstance();
    // Convert the list of DrinkEntry objects to a list of JSON maps, then encode to a string
    final String encodedData = jsonEncode(
      _drinks.map((drink) => drink.toJson()).toList(),
    );
    await prefs.setString('drinks_data', encodedData);
  }

  Future<void> _loadDrinks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('drinks_data');
    if (encodedData != null) {
      // Decode the string back to a list of JSON maps, then create DrinkEntry objects
      final List<dynamic> decodedData = jsonDecode(encodedData);
      if (mounted) {
        setState(() {
          _drinks = decodedData.map((item) => DrinkEntry.fromJson(item)).toList();
        });
      }
    }
  }

  // --- UI and Navigation Methods ---

  int get _currentIndex => _barController.index;

  Future<void> _onTabChanged(int index) async {
    if (index != 1) {
      _lastNonAddIndex = index;
    }

    if(mounted) {
      setState(() {
        _barController.index = index;
      });
    }

    if (index == 1) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _showAddDrinkMenu();

      if (mounted) {
        setState(() {
          _barController.index = _lastNonAddIndex;
        });
        _pageController.animateToPage(
          _lastNonAddIndex == 0 ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _pageController.animateToPage(
        index == 0 ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Pass the current user's name to the entry screen
                    builder: (context) => ManualEntryScreen(currentUserName: _currentUserName),
                  ),
                );
                if (result != null && result is DrinkEntry) {
                  setState(() {
                    _drinks.add(result);
                  });
                  await _saveDrinks(); // Save the updated list to local storage
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

  IconData _iconForDrink(String type) {
    final t = type.toLowerCase();
    if (t.contains('pint') || t.contains('can')) {
      return Icons.sports_bar;
    } else if (t.contains('wine')) {
      return Icons.wine_bar;
    } else if (t.contains('cocktail') || t.contains('shot')) {
      return Icons.local_bar;
    } else {
      return Icons.local_drink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barColour = Colors.black45;
    final notchColour = colorScheme.primary;

    return Scaffold(
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (mounted) {
            setState(() {
              _barController.index = index == 0 ? 0 : 2;
              _lastNonAddIndex = _barController.index;
            });
          }
        },
        children: [
          LeaderboardScreen(drinks: _drinks),
          DrinkListView(
            drinks: _drinks,
            iconForDrink: _iconForDrink,
            currentUserName: _currentUserName,
          ),
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

class DrinkListView extends StatefulWidget {
  final List<DrinkEntry> drinks;
  final IconData Function(String) iconForDrink;
  final String currentUserName;

  const DrinkListView({
    super.key,
    required this.drinks,
    required this.iconForDrink,
    required this.currentUserName,
  });

  @override
  State<DrinkListView> createState() => _DrinkListViewState();
}

class _DrinkListViewState extends State<DrinkListView> {
  final Map<String, bool> _expanded = {};
  bool _showLitres = false;

  @override
  void initState() {
    super.initState();
    _checkTotalVolume();
  }

  @override
  void didUpdateWidget(DrinkListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drinks.length != oldWidget.drinks.length) {
      _checkTotalVolume();
    }
  }

  void _checkTotalVolume() {
    final myDrinks = widget.drinks.where((d) => d.userName == widget.currentUserName).toList();
    final totalVolume = myDrinks.fold<double>(0, (sum, e) => sum + e.volume);
    if (totalVolume >= 1000) {
      if (!_showLitres) {
        if(mounted){
          setState(() => _showLitres = true);
        }
      }
    }
  }

  String _formatVolume(double ml) {
    if (_showLitres && ml >= 1000) {
      return "${(ml / 1000).toStringAsFixed(2)} L";
    } else {
      return "${ml.toStringAsFixed(0)} ml";
    }
  }

  String _formatItemVolume(double ml) {
    return ml >= 1000
        ? "${(ml / 1000).toStringAsFixed(2)} L"
        : "${ml.toStringAsFixed(0)} ml";
  }

  Widget _buildSummaryRow(List<DrinkEntry> myDrinks) {
    final totalDrinks = myDrinks.length;
    final totalVolume = myDrinks.fold<double>(0, (sum, e) => sum + e.volume);
    final totalUnits = myDrinks.fold<double>(0, (sum, e) => sum + e.units);

    Widget stat(IconData icon, String label, String value,
        {VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat(Icons.local_drink, "Drinks", "$totalDrinks"),
          stat(Icons.water_drop, "Volume", _formatVolume(totalVolume), onTap: () {
            if(mounted){
              setState(() {
                _showLitres = !_showLitres;
              });
            }
          }),
          stat(Icons.calculate, "Units", totalUnits.toStringAsFixed(2)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter drinks for the current user to display on "My Drinks"
    final myDrinks = widget.drinks.where((d) => d.userName == widget.currentUserName).toList();

    if (myDrinks.isEmpty) {
      return Column(
        children: [
          _buildSummaryRow(myDrinks), // Pass empty list to show 0s
          const Expanded(
            child: Center(child: Text("You haven't logged any drinks yet")),
          ),
        ],
      );
    }

    final Map<String, List<DrinkEntry>> grouped = {};
    for (var d in myDrinks) {
      final dateKey = DateFormat('yyyy-MM-dd').format(d.timestamp.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(d);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        _buildSummaryRow(myDrinks), // Pass filtered list for correct totals
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // In the future, this would fetch from the server
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final dateKey = sortedDates[index];
                final entries = grouped[dateKey];

                if (entries == null || entries.isEmpty) return const SizedBox.shrink();

                entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                final totalUnits =
                entries.fold<double>(0, (sum, e) => sum + e.units);
                final totalDrinks = entries.length;
                final totalVolume =
                entries.fold<double>(0, (sum, e) => sum + e.volume);

                final headerText =
                    "$totalDrinks drinks • ${totalUnits.toStringAsFixed(2)} units • ${_formatItemVolume(totalVolume)}";

                return ExpansionTile(
                  key: PageStorageKey(dateKey),
                  initiallyExpanded: _expanded[dateKey] ?? true,
                  onExpansionChanged: (expanded) {
                    if(mounted){
                      setState(() {
                        _expanded[dateKey] = expanded;
                      });
                    }
                  },
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE, d MMM yyyy')
                            .format(entries.first.timestamp.toLocal()),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Flexible(
                        child: Text(
                          headerText,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    ...entries.map((drink) {
                      final formatted = DateFormat('EEE, d MMM yyyy HH:mm')
                          .format(drink.timestamp.toLocal());
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(widget.iconForDrink(drink.type)),
                          title: Text(
                            "${drink.type} - ${_formatItemVolume(drink.volume)}",
                          ),
                          subtitle: Text(
                            "${drink.abv.toStringAsFixed(1)}% • ${drink.units.toStringAsFixed(2)} units\n"
                                "$formatted${drink.location != null ? " • ${drink.location}" : ""}",
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

