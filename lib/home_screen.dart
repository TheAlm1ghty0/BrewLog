import 'package:flutter/material.dart';
import 'models/drink_entry.dart';
import 'manual_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // default to Home
  final PageController _pageController = PageController(initialPage: 1);
  final List<DrinkEntry> _drinks = [];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  void _showAddDrinkMenu() {
    showModalBottomSheet(
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
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Picture/Automatic Entry'),
              enabled: false,
              onTap: () {},
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          const Center(child: Text("Leaderboard View (placeholder)")),
          DrinkListView(drinks: _drinks),
          const Center(child: Text("Settings View (placeholder)")),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDrinkMenu,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.leaderboard),
              color: _selectedIndex == 0
                  ? Theme.of(context).colorScheme.primary
                  : null,
              onPressed: () => _onItemTapped(0),
            ),
            const SizedBox(width: 40),
            IconButton(
              icon: const Icon(Icons.settings),
              color: _selectedIndex == 2
                  ? Theme.of(context).colorScheme.primary
                  : null,
              onPressed: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}

class DrinkListView extends StatelessWidget {
  final List<DrinkEntry> drinks;
  const DrinkListView({super.key, required this.drinks});

  @override
  Widget build(BuildContext context) {
    final sorted = [...drinks]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final drink = sorted[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.local_drink),
            title: Text("${drink.type} - ${drink.volume.toStringAsFixed(0)} ml"),
            subtitle: Text(
              "${drink.abv.toStringAsFixed(1)}% • ${drink.units.toStringAsFixed(2)} units\n"
                  "${drink.timestamp.toLocal()}${drink.location != null ? " • ${drink.location}" : ""}",
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}