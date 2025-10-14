import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // default to Home
  final PageController _pageController = PageController(initialPage: 1);

  // Placeholder views for now
  final List<Widget> _views = const [
    Center(child: Text("Leaderboard View")),
    Center(child: Text("Home View")),
    Center(child: Text("Settings View")),
  ];

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
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to manual entry form
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Picture/Automatic Entry'),
              enabled: false, // disabled for now
              onTap: () {
                // Future: open camera
              },
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
        children: _views,
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
              color: _selectedIndex == 0 ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => _onItemTapped(0),
            ),
            const SizedBox(width: 40), // space for FAB
            IconButton(
              icon: const Icon(Icons.settings),
              color: _selectedIndex == 2 ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}