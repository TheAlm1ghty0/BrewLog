import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
// Corrected import path for ManualEntryScreen
import 'manual_entry_screen.dart';
import '../models/drink_entry.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'create_leaderboard_screen.dart';
import 'join_leaderboard_screen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart'; // Ensure ApiService has SessionExpiredException
import '../models/leaderboard.dart';
import 'share_leaderboard_screen.dart';
import 'edit_drink_screen.dart'; // Import edit screen


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  final NotchBottomBarController _barController =
  NotchBottomBarController(index: 0);

  final ApiService _apiService = ApiService();
  List<DrinkEntry> _userDrinks = [];
  Future<List<Leaderboard>>? _userLeaderboardsFuture;
  Leaderboard? _selectedLeaderboard;
  Future<LeaderboardDetail>? _leaderboardDetailsFuture;

  final Set<String> _hiddenRecentSignatures = {};
  DateTimeRange? _myDrinksDateFilter;
  int _lastNonAddIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // --- Utility to handle SessionExpiredException ---
  Future<void> _handleApiCall(Future Function() apiCall, {String? errorMessagePrefix}) async {
    // Use local context variable for safety across async gaps
    final currentContext = context;
    if (!currentContext.mounted) return;

    try {
      await apiCall();
    } on SessionExpiredException catch (_) {
      print("SessionExpiredException caught in _handleApiCall.");
      if (currentContext.mounted) _handleSessionExpired(currentContext);
    } catch (e) {
      print("Error during API call: $e");
      if (currentContext.mounted) {
        final prefix = errorMessagePrefix ?? 'Failed to perform action';
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('$prefix: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  void _handleSessionExpired(BuildContext context) {
    // Check mounted again, although called immediately after catch
    if (!context.mounted) return;
    print("Handling session expired, calling logout.");

    // Access provider safely
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout(); // This should trigger navigation via AuthCheck

    // Show a message (optional, as navigation might happen instantly)
    // Consider showing dialog *before* logout if navigation is too fast
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log in again.'),
        backgroundColor: Colors.orange,
      ),
    );
    // Navigation back to LoginScreen is handled by AuthCheck listening to AuthProvider changes
  }
  // --- End Utility ---


  Future<void> _fetchInitialData() async {
    if (mounted) setState(() => _isLoading = true);

    // Wrap API calls with error handler
    await _handleApiCall(() async {
      final results = await Future.wait([
        _apiService.getUserDrinks(
          startDate: _myDrinksDateFilter?.start.toUtc(), // Send UTC
          endDate: _myDrinksDateFilter?.end.toUtc(), // Send UTC
        ),
        _apiService.getUserLeaderboards(),
      ]);
      // Check mounted *after* await
      if (!mounted) return;

      final drinks = results[0] as List<DrinkEntry>;
      final leaderboards = results[1] as List<Leaderboard>;

      // Use setState safely
      setState(() {
        _userDrinks = drinks;
        _userLeaderboardsFuture = Future.value(leaderboards);

        Leaderboard? newSelectedLeaderboard;
        // Find existing selection among new list
        if (_selectedLeaderboard != null) {
          newSelectedLeaderboard = leaderboards
              .cast<Leaderboard?>()
              .firstWhere((lb) => lb?.id == _selectedLeaderboard!.id, orElse: () => null);
        }

        // If no selection or old selection gone, default to first
        if (newSelectedLeaderboard == null && leaderboards.isNotEmpty) {
          newSelectedLeaderboard = leaderboards.first;
        }

        // Fetch details for the selected leaderboard
        if (newSelectedLeaderboard != null) {
          _selectLeaderboard(newSelectedLeaderboard); // This sets state for details future
        } else {
          _selectedLeaderboard = null;
          _leaderboardDetailsFuture = null; // Clear details future
        }
      });
    }, errorMessagePrefix: 'Failed to load initial data');

    // Ensure loading is stopped even if mounted check fails mid-way in try block
    if (mounted) setState(() => _isLoading = false);
  }


  // Selects a leaderboard and triggers fetching its details
  void _selectLeaderboard(Leaderboard leaderboard) {
    // Check mounted before setState
    if (!mounted) return;

    setState(() {
      _selectedLeaderboard = leaderboard;
      _isLoading = true; // Show loading while fetching details
      // Wrap detail fetching in error handler
      _leaderboardDetailsFuture = Future(() async {
        try {
          return await _apiService.getLeaderboardDetails(leaderboard.id);
        } on SessionExpiredException {
          if (mounted) _handleSessionExpired(context);
          rethrow; // Re-throw to let FutureBuilder show error
        } catch (e) {
          print("Error fetching leaderboard details: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load leaderboard details: ${e.toString().replaceFirst('Exception: ', '')}')),
            );
          }
          rethrow; // Re-throw to let FutureBuilder show error
        } finally {
          if (mounted) setState(() => _isLoading = false); // Stop loading indicator
        }
      });
    });
  }

  Future<void> _refreshData() async {
    await _fetchInitialData();
  }

  // --- Add Drink Logic ---
  Future<void> _navigateAndAddDrink() async {
    final currentContext = context; // Capture context
    if (!currentContext.mounted) return;

    final authProvider = Provider.of<AuthProvider>(currentContext, listen: false);
    final currentUser = authProvider.username;

    if (currentUser != null) {
      // Navigate to ManualEntryScreen
      final drinkFromForm = await Navigator.of(currentContext).push<DrinkEntry>(
        MaterialPageRoute(
          builder: (ctx) => ManualEntryScreen( // Pass context `ctx` here
            userName: currentUser,
            userDrinks: _userDrinks, // Pass current drinks for recents
            hiddenSignatures: _hiddenRecentSignatures,
            onHideRecent: _handleHideRecent,
          ),
        ),
      );

      // Check mounted after navigation returns
      if (!currentContext.mounted) return;

      // If a drink was returned from the form, add it via API
      if (drinkFromForm != null) {
        setState(() => _isLoading = true); // Show loading
        await _handleApiCall(() async {
          await _apiService.addDrink(drinkFromForm);
          await _refreshData(); // Refresh all data after adding
        }, errorMessagePrefix: 'Failed to add drink');
        if (currentContext.mounted) setState(() => _isLoading = false); // Hide loading
      }
    } else {
      // Should not happen if user is authenticated, but handle defensively
      print("Error: currentUser is null in _navigateAndAddDrink");
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in.')),
        );
      }
    }
  }


  // Hides a recent drink signature for the current session
  void _handleHideRecent(DrinkEntry drink) {
    if (!mounted) return;
    final signature = '${drink.type}-${drink.volume}-${drink.abv}';
    setState(() {
      _hiddenRecentSignatures.add(signature);
      // We might need to explicitly rebuild the ManualEntryScreen's recents
      // if it relies solely on the initial list passed. Passing a callback is better.
    });
  }


  int get _currentIndex => _barController.index;

  // Handles tab changes in the bottom navigation
  Future<void> _onTabChanged(int index) async {
    final currentContext = context; // Capture context
    if (!currentContext.mounted) return;

    // Handle the "Add" button tap (index 1)
    if (index == 1) {
      setState(() => _barController.index = 1); // Show notch animation
      await Future.delayed(const Duration(milliseconds: 300)); // Wait for animation
      if (!currentContext.mounted) return; // Check mounted after delay

      // Show the Add Drink options (Manual/Picture)
      final action = await showModalBottomSheet<String>(
        context: currentContext, // Use captured context
        builder: (sheetContext) => Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Manual Entry'),
              onTap: () => Navigator.pop(sheetContext, 'manual'),
            ),
            const ListTile(
              leading: Icon(Icons.camera_alt_outlined),
              title: Text('Picture Entry (Coming Soon)'),
              enabled: false,
            ),
          ],
        ),
      );

      // Check mounted after modal closes
      if (!currentContext.mounted) return;

      // If manual entry selected, navigate to the screen
      if (action == 'manual') {
        await _navigateAndAddDrink(); // Call the refactored add drink logic
      }

      // Check mounted again before resetting index
      if (!currentContext.mounted) return;
      // Return to the last viewed non-add tab
      setState(() => _barController.index = _lastNonAddIndex);
      // Keep PageView on the correct page (0 or 1, representing Leaderboard or MyDrinks)
      _pageController.animateToPage(_lastNonAddIndex == 0 ? 0 : 1,
          duration: const Duration(milliseconds: 1), curve: Curves.easeInOut);


    }
    // Handle switching between Leaderboard (0) and My Drinks (2)
    else {
      _lastNonAddIndex = index; // Remember this tab index
      setState(() => _barController.index = index);
      // Animate PageView to the corresponding page (index 0 -> page 0, index 2 -> page 1)
      _pageController.animateToPage(index == 0 ? 0 : 1,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }


  // --- Date Range Filtering for "My Drinks" ---
  Future<void> _showDateRangePicker() async {
    final currentContext = context; // Capture context
    if (!currentContext.mounted) return;

    final newDateRange = await showDateRangePicker(
      context: currentContext,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Allow up to today
      initialDateRange: _myDrinksDateFilter,
    );

    // Check mounted after await
    if (!currentContext.mounted) return;

    if (newDateRange != null) {
      // Set end date to end of day for inclusiveness
      final adjustedEndDate = DateTime(newDateRange.end.year, newDateRange.end.month, newDateRange.end.day, 23, 59, 59);
      final adjustedRange = DateTimeRange(start: newDateRange.start, end: adjustedEndDate);

      setState(() {
        _myDrinksDateFilter = adjustedRange;
      });
      await _refreshData(); // Refetch drinks with the new filter
    }
  }

  void _clearDateFilter() {
    if (!mounted) return;
    setState(() {
      _myDrinksDateFilter = null;
    });
    _refreshData(); // Refetch all drinks
  }
  // --- End Date Range Filtering ---


  // --- Leaderboard Switching Logic ---
  Future<void> _showLeaderboardSwitcher() async {
    final currentContext = context; // Capture context
    if (!currentContext.mounted) return;

    final navigator = Navigator.of(currentContext);
    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);

    // Use the existing future to avoid re-fetching list unnecessarily
    final currentLeaderboardsFuture = _userLeaderboardsFuture;
    if (currentLeaderboardsFuture == null) {
      // Should not happen if initial fetch worked, but handle defensively
      print("Error: _userLeaderboardsFuture is null in _showLeaderboardSwitcher");
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Could not load leaderboard list.')));
      return;
    }


    showModalBottomSheet(
      context: currentContext, // Use captured context
      builder: (sheetContext) => FutureBuilder<List<Leaderboard>>(
        future: currentLeaderboardsFuture, // Use the stored future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Handle error during initial fetch or empty list
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return SafeArea(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(snapshot.hasError ? 'Error loading leaderboards' : 'No leaderboards found.')),
                const Divider(),
                // Always allow creating/joining even if list fails/is empty
                _buildCreateAndJoinTiles(sheetContext, navigator),
              ],
            ));
          }

          // Display list of leaderboards
          final leaderboards = snapshot.data!;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...leaderboards.map((lb) => ListTile(
                  leading: const Icon(Icons.leaderboard_outlined),
                  title: Text(lb.name),
                  selected: lb.id == _selectedLeaderboard?.id,
                  onTap: () {
                    _selectLeaderboard(lb); // Select and fetch details
                    Navigator.pop(sheetContext); // Close bottom sheet
                  },
                )),
                const Divider(),
                _buildCreateAndJoinTiles(sheetContext, navigator), // Add Create/Join options
              ],
            ),
          );
        },
      ),
    );
  }


  // Helper for Create/Join tiles in bottom sheet
  Widget _buildCreateAndJoinTiles(BuildContext sheetContext, NavigatorState appNavigator) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Create Leaderboard'),
          onTap: () async {
            Navigator.pop(sheetContext); // Close sheet first
            final result = await appNavigator.push(
              MaterialPageRoute(builder: (context) => const CreateLeaderboardScreen()),
            );
            // If creation was successful (returned true), refresh data
            if (!mounted) return; // Check mounted after await
            if (result == true) await _refreshData();
          },
        ),
        ListTile(
          leading: const Icon(Icons.group_add_outlined),
          title: const Text('Join Leaderboard'),
          onTap: () async {
            Navigator.pop(sheetContext); // Close sheet first
            final result = await appNavigator.push(
              MaterialPageRoute(builder: (context) => const JoinLeaderboardScreen()),
            );
            // If joining was successful, refresh data
            if (!mounted) return; // Check mounted after await
            if (result == true) await _refreshData();
          },
        ),
      ],
    );
  }
  // --- End Leaderboard Switching ---


  // Builds the AppBar dynamically based on the current tab
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    Widget? leadingWidget;
    List<Widget> actions = [];
    Widget titleWidget;

    // --- My Drinks Tab (index 2 -> page 1) ---
    if (_currentIndex == 2) {
      titleWidget = const Text("My Drinks");
      // Filter Action
      actions.add(IconButton(
        icon: const Icon(Icons.filter_list),
        tooltip: 'Filter by date range',
        onPressed: _showDateRangePicker,
      ));
      // Settings Action
      actions.add(IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: 'Settings',
        onPressed: () {
          // Check mounted before navigating
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => SettingsScreen(onDataChanged: _refreshData)),
          );
        },
      ));
    }
    // --- Leaderboard Tab (index 0 -> page 0) ---
    else if (_currentIndex == 0) {
      // Title includes leaderboard name
      // Removed status chip logic from here
      titleWidget = Text( // Just use Text directly
        _selectedLeaderboard?.name ?? "Leaderboard",
        overflow: TextOverflow.ellipsis,
      );

      // Leading: Share button if user is creator
      if (_selectedLeaderboard != null && _selectedLeaderboard!.creatorUsername == authProvider.username) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.ios_share_outlined), // Use share icon
          tooltip: 'Invite Members',
          onPressed: () {
            if (!context.mounted) return; // Check mounted
            if (_selectedLeaderboard != null) {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => ShareLeaderboardScreen(leaderboard: _selectedLeaderboard!)));
            }
          },
        );
      }
      // Action: Leaderboard switcher menu
      actions.add(IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Switch Leaderboard',
        onPressed: () => _showLeaderboardSwitcher(),
      ));
    }
    // --- Add Tab (index 1 - temporary state) ---
    else {
      titleWidget = const Text("Add Drink");
      // No specific actions needed for the brief "Add" tab state
    }

    return AppBar(
      leading: leadingWidget,
      centerTitle: true,
      title: titleWidget,
      actions: actions,
    );
  }


  // Helper to get appropriate icon based on drink type string
  IconData _iconForDrink(String type) {
    final t = type.toLowerCase();
    if (t.contains('pint') || t.contains('can') || t.contains('beer') || t.contains('lager') || t.contains('ale') || t.contains('cider')) {
      return Icons.sports_bar; // Beer mug
    } else if (t.contains('wine')) {
      return Icons.wine_bar; // Wine glass
    } else if (t.contains('cocktail') || t.contains('spirit') || t.contains('shot') || t.contains('mixer')) {
      return Icons.local_bar; // Cocktail glass
    } else if (t.contains('water')) {
      return Icons.water_drop;
    } else if (t.contains('coffee') || t.contains('tea') || t.contains('latte') || t.contains('cappuccino')) {
      return Icons.coffee;
    } else if (t.contains('soda') || t.contains('pop') || t.contains('fizzy')) {
      return Icons.local_cafe; // Generic cup often used for soda
    }
    else {
      return Icons.local_drink; // Generic fallback
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter drinks for the "My Drinks" view based on the date range filter
    // Only filter if _myDrinksDateFilter is not null
    final displayedDrinks = _myDrinksDateFilter == null
        ? _userDrinks
        : _userDrinks.where((drink) {
      final drinkDateLocal = drink.timestamp.toLocal(); // Compare in local time
      // Ensure filter dates are handled correctly
      final startDate = _myDrinksDateFilter!.start;
      // End date is already adjusted to end of day in _showDateRangePicker
      final endDate = _myDrinksDateFilter!.end;
      // Check if drink date is on or after start AND on or before end
      return !drinkDateLocal.isBefore(startDate) && !drinkDateLocal.isAfter(endDate);
    }).toList();

    // Only show drinks for the currently logged-in user on "My Drinks" tab
    final authProvider = Provider.of<AuthProvider>(context, listen: false); // Use listen:false if only reading username
    final currentUserDrinks = displayedDrinks.where((d) => d.userName == authProvider.username).toList();


    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              // Update bottom bar index based on page index
              if (!mounted) return;
              setState(() {
                // Page 0 -> Tab 0 (Leaderboard)
                // Page 1 -> Tab 2 (My Drinks)
                _barController.index = index == 0 ? 0 : 2;
                _lastNonAddIndex = _barController.index;
              });
            },
            children: [
              // --- Page 0: Leaderboard ---
              RefreshIndicator(
                onRefresh: _refreshData,
                child: FutureBuilder<LeaderboardDetail>(
                  future: _leaderboardDetailsFuture,
                  builder: (context, snapshot) {
                    // Loading State
                    if (snapshot.connectionState == ConnectionState.waiting && _leaderboardDetailsFuture != null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Error State
                    if (snapshot.hasError) {
                      return LayoutBuilder( // Ensure error message is scrollable for RefreshIndicator
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(child: Text('Error: ${snapshot.error}')),
                          ),
                        ),
                      );
                    }
                    // No Data / No Leaderboard Selected State
                    if (!snapshot.hasData || snapshot.data == null) {
                      return LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('No leaderboard selected or you are not part of any.'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.menu),
                                    label: const Text('Select Leaderboard'),
                                    onPressed: _showLeaderboardSwitcher,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    // Success State
                    return LeaderboardScreen(leaderboardDetail: snapshot.data!);
                  },
                ),
              ),
              // --- Page 1: My Drinks ---
              DrinkListView(
                // Pass only the current user's filtered drinks
                drinks: currentUserDrinks,
                iconForDrink: _iconForDrink,
                onRefresh: _refreshData, // Pass refresh callback
                activeFilter: _myDrinksDateFilter,
                onClearFilter: _clearDateFilter,
              ),
            ],
          ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: colorScheme.scrim.withOpacity(0.6), // Use scrim color for overlay
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      extendBody: true, // Keep body behind nav bar
      bottomNavigationBar: AnimatedNotchBottomBar(
        notchBottomBarController: _barController,
        color: colorScheme.surfaceContainer, // Use M3 surface container color
        notchColor: colorScheme.primary,
        showLabel: true, // Show labels under icons
        textOverflow: TextOverflow.ellipsis, // Handle long labels if needed
        maxLine: 1,
        shadowElevation: 8, // Standard elevation
        kBottomRadius: 15.0, // Corner radius
        kIconSize: 24.0, // Icon size
        removeMargins: false, // Keep default margins
        bottomBarWidth: 500, // Adjust width if needed for larger screens? Default might be fine.
        durationInMilliSeconds: 300, // Animation duration
        itemLabelStyle: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant), // Style for inactive labels
        bottomBarItems: [
          // Leaderboard Item
          BottomBarItem(
            inActiveItem: Icon(Icons.leaderboard_outlined, color: colorScheme.onSurfaceVariant),
            activeItem: Icon(Icons.leaderboard, color: colorScheme.onPrimary), // Icon color when active (in notch)
            itemLabel: 'Leaderboard',
          ),
          // Add Item (Notch)
          BottomBarItem(
            inActiveItem: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
            activeItem: Icon(Icons.add, color: colorScheme.onPrimary),
            itemLabel: 'Add',
          ),
          // My Drinks Item
          BottomBarItem(
            inActiveItem: Icon(Icons.local_drink_outlined, color: colorScheme.onSurfaceVariant),
            activeItem: Icon(Icons.local_drink, color: colorScheme.onPrimary),
            itemLabel: 'My Drinks',
          ),
        ],
        onTap: _onTabChanged,
        elevation: 8, // Added elevation again just in case
      ),
    );
  }
}



// --- Drink List View Widget ---
// (Moved here as it's primarily used by HomeScreen)
class DrinkListView extends StatefulWidget {
  final List<DrinkEntry> drinks;
  final IconData Function(String) iconForDrink;
  final Future<void> Function() onRefresh;
  final DateTimeRange? activeFilter;
  final VoidCallback onClearFilter;

  const DrinkListView({
    super.key,
    required this.drinks,
    required this.iconForDrink,
    required this.onRefresh,
    this.activeFilter,
    required this.onClearFilter,
  });

  @override
  State<DrinkListView> createState() => _DrinkListViewState();
}

class _DrinkListViewState extends State<DrinkListView> {
  // Store expansion state for each date group
  final Map<String, bool> _expanded = {};
  // Store volume display preference (ml vs L)
  bool _showLitres = false;

  final ApiService _apiService = ApiService(); // Needed for delete

  @override
  void initState() {
    super.initState();
    // Decide initial volume display based on total volume
    _updateLitreToggle(widget.drinks);
  }

  @override
  void didUpdateWidget(DrinkListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update volume display preference if drinks list changes significantly
    if (widget.drinks.length != oldWidget.drinks.length ||
        widget.drinks.fold<double>(0,(sum,e)=>sum+e.volume) != oldWidget.drinks.fold<double>(0,(sum,e)=>sum+e.volume) ) {
      _updateLitreToggle(widget.drinks);
    }
  }

  // Updates the _showLitres flag based on total volume
  void _updateLitreToggle(List<DrinkEntry> drinks) {
    final totalVolume = drinks.fold<double>(0, (sum, e) => sum + e.volume);
    // Automatically switch to Litres if >= 1000ml, unless user manually toggled back to ml
    // Let's simplify: always default to Litres if >= 1000ml initially. User can toggle.
    final shouldShowLitres = totalVolume >= 1000;
    // Update state only if needed
    if (_showLitres != shouldShowLitres && mounted) {
      // Check if user manually set it to ml? For now, let's just default based on volume.
      setState(() => _showLitres = shouldShowLitres);
    }
  }

  // Formats volume for the summary row (respects _showLitres toggle)
  String _formatSummaryVolume(double ml) {
    if (_showLitres) {
      return "${(ml / 1000).toStringAsFixed(2)} L";
    } else {
      // Use comma formatting for thousands in ml
      return "${NumberFormat('#,##0').format(ml)} ml";
    }
  }

  // Formats volume for individual drink items (always uses L if >= 1000ml)
  String _formatItemVolume(double ml) {
    return ml >= 1000
        ? "${(ml / 1000).toStringAsFixed(2)} L"
        : "${ml.toStringAsFixed(0)} ml"; // No decimals for ml in items
  }


  // --- Drink Deletion Logic ---
  Future<void> _handleDeleteDrink(DrinkEntry drink) async {
    final currentContext = context; // Capture context
    if (!currentContext.mounted) return;

    // Ensure drink has an ID before attempting delete
    if (drink.id == null) {
      print("Error: Attempted to delete drink with null ID.");
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Cannot delete unsynced drink.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(currentContext, listen: false); // Needed for error handling

    AwesomeDialog(
      context: currentContext, // Use captured context
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'Delete Drink',
      desc: 'Delete this ${drink.name ?? drink.type} entry?\n(${_formatItemVolume(drink.volume)}, ${drink.abv.toStringAsFixed(1)}%)\nThis action cannot be undone.', // Use name in desc
      btnCancelOnPress: () {},
      btnOkText: 'Delete',
      btnOkColor: Theme.of(currentContext).colorScheme.error,
      btnOkOnPress: () async {
        // Use local context for async gap safety
        final localContext = currentContext;
        if (!localContext.mounted) return;

        final scaffoldMessenger = ScaffoldMessenger.of(localContext);
        try {
          await _apiService.deleteDrink(drink.id); // Call API to delete

          // Check mounted after await before showing SnackBar/refreshing
          if (!localContext.mounted) return;
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('${drink.name ?? drink.type} deleted.'), backgroundColor: Colors.green[700]), // Use name in snackbar
          );
          await widget.onRefresh(); // Trigger data refresh in HomeScreen
        } on SessionExpiredException catch (_) {
          print("Session expired during drink deletion.");
          if(localContext.mounted) {
            // Access provider safely to trigger logout
            Provider.of<AuthProvider>(localContext, listen: false).logout();
            ScaffoldMessenger.of(localContext).showSnackBar(
              const SnackBar(content: Text('Session expired. Please log in again.')),
            );
          }
        } catch (e) {
          print("Failed to delete drink: $e");
          if(localContext.mounted){
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Failed to delete drink: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
    ).show();
  }
  // --- End Drink Deletion ---

  // --- MODIFIED: Show Edit/Delete Menu (showMenu) ---
  Future<void> _showEditDeleteMenu(BuildContext tileContext, RelativeRect position, DrinkEntry drink) async {
    // We need the navigator from the main screen's context
    // but the tileContext should be fine as it's part of the same widget tree
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);

    // Get the RenderBox of the overlay to calculate position
    // final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    await showMenu(
      context: tileContext, // Use the tile's BuildContext
      position: position, // Use the calculated RelativeRect
      items: [
        // --- Edit Option ---
        PopupMenuItem(
          value: 'edit', // Return a value
          child: const ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit Drink'),
            dense: true,
          ),
          // onTap: () async { ... }, // onTap in PopupMenuItem doesn't work well with async navigation
        ),
        // --- Delete Option ---
        PopupMenuItem(
          value: 'delete', // Return a value
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('Delete Drink', style: TextStyle(color: theme.colorScheme.error)),
            dense: true,
          ),
          // onTap: () { ... },
        ),
      ],
      elevation: 8.0,
      shape: Theme.of(context).cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Use theme shape
    ).then((value) async { // Handle the result *after* the menu closes
      if (value == null) {
        // Menu dismissed
        return;
      }

      if (value == 'edit') {
        // Edit Option selected
        // Wait a frame for the menu to close before navigating
        await Future.delayed(Duration.zero);
        if (!mounted) return; // Check mount status
        final result = await navigator.push(
          MaterialPageRoute(
            builder: (context) => EditDrinkScreen(drinkToEdit: drink),
          ),
        );
        // Check mounted after navigation returns
        if (!mounted) return;
        // If edit screen returns true, refresh data
        if (result == true) {
          widget.onRefresh();
        }
      } else if (value == 'delete') {
        // Delete Option selected
        // No need to delay, just call the dialog function
        _handleDeleteDrink(drink);
      }
    });
  }
  // --- END MODIFICATION ---


  // Builds the summary row displaying totals
  Widget _buildSummaryRow() {
    final totalDrinks = widget.drinks.length;
    final totalVolume = widget.drinks.fold<double>(0, (sum, e) => sum + e.volume);
    final totalUnits = widget.drinks.fold<double>(0, (sum, e) => sum + e.units);

    // Reusable stat widget component
    Widget stat(IconData icon, String label, String value, {VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
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
          // Allow toggling volume display only if total > 1000ml
          stat(Icons.water_drop, "Volume", _formatSummaryVolume(totalVolume),
              onTap: totalVolume >= 1000 ? () {
                if (mounted) setState(() => _showLitres = !_showLitres);
              } : null),
          stat(Icons.calculate_outlined, "Units", totalUnits.toStringAsFixed(2)),
        ],
      ),
    );
  }

  // Builds the main list, grouping drinks by date
  Widget _buildGroupedList() {
    // Group drinks by date (local time)
    final Map<String, List<DrinkEntry>> grouped = {};
    for (var d in widget.drinks) {
      final dateKey = DateFormat('yyyy-MM-dd').format(d.timestamp.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(d);
    }

    // Sort date keys newest first
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      // --- FIX: Add bottom padding to avoid nav bar ---
      padding: const EdgeInsets.only(top: 8, bottom: 100.0), // Increased bottom padding
      // --- END FIX ---
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final entries = grouped[dateKey]!;

        // Sort entries within the day newest first
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Calculate totals for the day
        final totalUnits = entries.fold<double>(0, (sum, e) => sum + e.units);
        final totalDrinks = entries.length;
        final totalVolume = entries.fold<double>(0, (sum, e) => sum + e.volume);

        // Build ExpansionTile for the date group
        return ExpansionTile(
          key: PageStorageKey(dateKey), // Keep expansion state on scroll
          initiallyExpanded: _expanded[dateKey] ?? true, // Default to expanded
          onExpansionChanged: (expanded) {
            // Store expansion state if changed
            if (mounted) setState(() => _expanded[dateKey] = expanded);
          },
          // Header showing Date and Daily Totals
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, d MMM yyyy').format(entries.first.timestamp.toLocal()),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              // Daily totals summary in header
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$totalDrinks'),
                  const SizedBox(width: 4),
                  Icon(Icons.local_drink, size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text('${totalUnits.toStringAsFixed(1)} U'), // Use 1 decimal for units here?
                  const SizedBox(width: 8),
                  Text(_formatItemVolume(totalVolume)),
                ],
              )
            ],
          ),
          // Children: List of drink cards for the day
          children: [
            ...entries.map((drink) {
              final formattedTime = DateFormat('HH:mm').format(drink.timestamp.toLocal()); // Only time needed here

              // --- MODIFICATION: Wrap Card in Builder ---
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Builder( // Use Builder to get specific context for ListTile
                    builder: (tileContext) {
                      return ListTile(
                        // --- MODIFIED: Use onLongPress and pass context/position ---
                        onLongPress: () {
                          // Find the render box and its position
                          final RenderBox renderBox = tileContext.findRenderObject() as RenderBox;
                          final Offset offset = renderBox.localToGlobal(Offset.zero); // Get global position
                          final Size size = renderBox.size;

                          // --- YOUR SUGGESTED FIX (modified for valid Rect) ---
                          // Define a 2px high rect at the bottom of the card, inset by 10%
                          final Rect anchorRect = Rect.fromLTRB(
                              offset.dx + (size.width * 0.1), // left: inset 10%
                              offset.dy + size.height + 2,          // top: at the bottom of the card
                              offset.dx + (size.width * 0.1) + 1, // right: inset 10% (width 80%)
                              offset.dy + size.height + 2       // bottom: 2px below the card
                          );
                          final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

                          _showEditDeleteMenu(
                              tileContext,
                              RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size),
                              drink
                          );
                          // --- END YOUR FIX ---
                        },
                        // --- END MODIFICATION ---
                        leading: Icon(widget.iconForDrink(drink.type), color: Theme.of(context).colorScheme.primary),
                        title: Text(
                          drink.name != null && drink.name!.isNotEmpty
                              ? drink.name!
                              : drink.type, // Fallback to type
                          style: drink.name != null && drink.name!.isNotEmpty
                              ? null // Default title style
                              : TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        subtitle: Text(
                          "${_formatItemVolume(drink.volume)} • ${drink.abv.toStringAsFixed(1)}% • ${drink.units.toStringAsFixed(2)} units • $formattedTime"
                              "${drink.location != null && drink.location!.isNotEmpty ? "\n@ ${drink.location}" : ""}",
                        ),
                        isThreeLine: drink.location != null && drink.location!.isNotEmpty,
                        dense: true,
                      );
                    }
                ),
              );
              // --- END MODIFICATION ---
            }),
            const SizedBox(height: 8), // Padding at bottom of group
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show active date filter chip if present
        if (widget.activeFilter != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Reduced vertical padding
            child: Chip(
              avatar: const Icon(Icons.filter_list),
              label: Text(
                '${DateFormat.yMd().format(widget.activeFilter!.start)} - ${DateFormat.yMd().format(widget.activeFilter!.end)}',
              ),
              onDeleted: widget.onClearFilter,
              deleteIconColor: Theme.of(context).colorScheme.onSecondaryContainer,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
        // Always show the summary row
        _buildSummaryRow(),
        const Divider(height: 1), // Add subtle divider
        // Main content area (list or empty state)
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: widget.drinks.isEmpty
            // Show empty state message if no drinks match filter/user
                ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Allow refresh even when empty
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - (widget.activeFilter != null ? 50 : 0) - 80), // Adjust height
                  child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_drink_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(widget.activeFilter != null
                              ? "No drinks logged in this period."
                              : "No drinks logged yet."
                          ),
                          if (widget.activeFilter != null) ...[
                            const SizedBox(height: 8),
                            TextButton(onPressed: widget.onClearFilter, child: const Text("Clear Filter"))
                          ]

                        ],
                      )
                  ),
                ),
              ),
            )
            // Show the grouped list if drinks exist
                : _buildGroupedList(),
          ),
        ),
      ],
    );
  }
}

