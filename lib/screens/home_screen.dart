import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../models/drink_entry.dart';
import 'manual_entry_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'create_leaderboard_screen.dart';
import 'join_leaderboard_screen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart'; // <-- Import ApiService to get the custom exception
import '../models/leaderboard.dart';
import 'share_leaderboard_screen.dart';

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

  // --- NEW: Helper function to handle session expiry ---
  void _handleSessionExpired() {
    // We check 'mounted' to ensure we don't call this if the widget is no longer on screen
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has expired. Please log in again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- UPDATED: Now catches SessionExpiredException ---
  Future<void> _fetchInitialData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getUserDrinks(
          startDate: _myDrinksDateFilter?.start,
          endDate: _myDrinksDateFilter?.end,
        ),
        _apiService.getUserLeaderboards(),
      ]);
      if (!mounted) return;

      final drinks = results[0] as List<DrinkEntry>;
      final leaderboards = results[1] as List<Leaderboard>;

      setState(() {
        _userDrinks = drinks;
        _userLeaderboardsFuture = Future.value(leaderboards);

        Leaderboard? newSelectedLeaderboard;
        if (_selectedLeaderboard != null) {
          newSelectedLeaderboard = leaderboards
              .cast<Leaderboard?>()
              .firstWhere((lb) => lb?.id == _selectedLeaderboard!.id,
              orElse: () => null);
        }

        if (newSelectedLeaderboard == null && leaderboards.isNotEmpty) {
          newSelectedLeaderboard = leaderboards.first;
        }

        if (newSelectedLeaderboard != null) {
          _selectLeaderboard(newSelectedLeaderboard);
        } else {
          _selectedLeaderboard = null;
          _leaderboardDetailsFuture = null;
        }
      });
    } on SessionExpiredException catch (_) { // <-- NEW CATCH BLOCK
      _handleSessionExpired();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load initial data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectLeaderboard(Leaderboard leaderboard) {
    setState(() {
      _selectedLeaderboard = leaderboard;
      _leaderboardDetailsFuture =
          _apiService.getLeaderboardDetails(leaderboard.id);
    });
  }

  Future<void> _refreshData() async {
    // Note: _fetchInitialData now handles the session exception,
    // so _refreshData automatically gets that new power.
    await _fetchInitialData();
  }

  void _handleHideRecent(DrinkEntry drink) {
    final signature = '${drink.type}-${drink.volume}-${drink.abv}';
    setState(() {
      _hiddenRecentSignatures.add(signature);
    });
  }

  int get _currentIndex => _barController.index;

  Future<void> _onTabChanged(int index) async {
    if (index != 1) {
      _lastNonAddIndex = index;
      if (mounted) setState(() => _barController.index = index);
      _pageController.animateToPage(index == 0 ? 0 : 1,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }

    if (mounted) setState(() => _barController.index = 1);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Manual Entry'),
            onTap: () => Navigator.pop(sheetContext, 'manual'),
          ),
          const ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Picture/Automatic Entry'),
            enabled: false,
          ),
        ],
      ),
    );

    if (action == 'manual') {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final currentUser = authProvider.username;

      if (currentUser != null) {
        final drinkFromForm = await navigator.push<DrinkEntry>(
          MaterialPageRoute(
            builder: (context) => ManualEntryScreen( // Path is now correct
              userName: currentUser,
              userDrinks: _userDrinks,
              hiddenSignatures: _hiddenRecentSignatures,
              onHideRecent: _handleHideRecent,
            ),
          ),
        );
        if (drinkFromForm != null) {
          try {
            await _apiService.addDrink(drinkFromForm);
            await _refreshData();
          } on SessionExpiredException catch (_) { // <-- NEW CATCH BLOCK
            _handleSessionExpired();
          } catch (e) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Failed to add drink: $e')),
            );
          }
        }
      }
    }

    if (mounted) setState(() => _barController.index = _lastNonAddIndex);
  }

  Future<void> _showDateRangePicker() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _myDrinksDateFilter,
    );

    if (newDateRange != null) {
      setState(() {
        _myDrinksDateFilter = newDateRange;
      });
      await _refreshData(); // This will call _fetchInitialData
    }
  }

  void _clearDateFilter() {
    setState(() {
      _myDrinksDateFilter = null;
    });
    _refreshData(); // This will call _fetchInitialData
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    Widget? leadingWidget;
    List<Widget> actions = [];

    if (_currentIndex == 2) {
      actions.add(IconButton(
        icon: const Icon(Icons.filter_list),
        onPressed: _showDateRangePicker,
      ));
      actions.add(IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) =>
                    SettingsScreen(onDataChanged: _refreshData)),
          );
        },
      ));
    }

    if (_currentIndex == 0) {
      if (_selectedLeaderboard != null &&
          _selectedLeaderboard!.creatorUsername == authProvider.username) {
        leadingWidget = IconButton(
          icon: const Icon(Icons.person_add_alt_1),
          onPressed: () {
            if (_selectedLeaderboard != null) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ShareLeaderboardScreen(
                      leaderboard: _selectedLeaderboard!)));
            }
          },
        );
      }
      actions.add(IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _showLeaderboardSwitcher(),
      ));
    }

    return AppBar(
      leading: leadingWidget,
      centerTitle: true,
      // --- UPDATED: Removed FutureBuilder and Chip logic ---
      title: Text(_currentIndex == 0
          ? _selectedLeaderboard?.name ?? "Leaderboard"
          : _currentIndex == 1
          ? "Add Drink"
          : "My Drinks"),
      actions: actions,
    );
  }

  Future<void> _showLeaderboardSwitcher() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (!mounted) return;
      // We'll refetch the leaderboards list when the menu is opened
      // to ensure it's up-to-date.
      final currentLeaderboards = await _apiService.getUserLeaderboards();
      if (mounted) {
        setState(() {
          _userLeaderboardsFuture = Future.value(currentLeaderboards);
        });
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (context) {
          if (currentLeaderboards.isEmpty) {
            return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(title: Text('No leaderboards found.')),
                    const Divider(),
                    _buildCreateAndJoinTiles(navigator),
                  ],
                ));
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...currentLeaderboards.map((lb) => ListTile(
                  leading: const Icon(Icons.leaderboard),
                  title: Text(lb.name),
                  selected: lb.id == _selectedLeaderboard?.id,
                  onTap: () {
                    _selectLeaderboard(lb);
                    navigator.pop();
                  },
                )),
                const Divider(),
                _buildCreateAndJoinTiles(navigator),
              ],
            ),
          );
        },
      );
    } on SessionExpiredException catch (_) { // <-- NEW CATCH BLOCK
      _handleSessionExpired();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to fetch leaderboards: $e')),
      );
    }
  }

  Widget _buildCreateAndJoinTiles(NavigatorState navigator) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Create Leaderboard'),
          onTap: () async {
            navigator.pop();
            final result = await navigator.push(
              MaterialPageRoute(
                  builder: (context) => const CreateLeaderboardScreen()),
            );
            if (result == true && mounted) await _refreshData();
          },
        ),
        ListTile(
          leading: const Icon(Icons.group_add),
          title: const Text('Join Leaderboard'),
          onTap: () async {
            navigator.pop();
            final result = await navigator.push(
              MaterialPageRoute(
                  builder: (context) => const JoinLeaderboardScreen()),
            );
            if (result == true && mounted) await _refreshData();
          },
        ),
      ],
    );
  }

  IconData _iconForDrink(String type) {
    final t = type.toLowerCase();
    if (t.contains('pint') || t.contains('can') || t.contains('beer')) {
      return Icons.sports_bar;
    } else if (t.contains('wine')) {
      return Icons.wine_bar;
    } else if (t.contains('cocktail') ||
        t.contains('shot') ||
        t.contains('spirit')) {
      return Icons.local_bar;
    } else {
      return Icons.local_drink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final displayedDrinks = _myDrinksDateFilter == null
        ? _userDrinks
        : _userDrinks.where((drink) {
      final drinkDate = drink.timestamp;
      final startDate = _myDrinksDateFilter!.start;
      final endDate = _myDrinksDateFilter!.end.add(const Duration(days: 1));
      return drinkDate.isAfter(startDate) && drinkDate.isBefore(endDate);
    }).toList();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          appBar: _buildAppBar(context),
          body: Stack(
            children: [
              PageView(
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
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    child: FutureBuilder<LeaderboardDetail>(
                      future: _leaderboardDetailsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                            _leaderboardDetailsFuture != null) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          // If the error is a session exception, the refresh handler
                          // in _refreshData will have already caught it.
                          // This just displays other errors.
                          return LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight),
                                    child:
                                    Center(child: Text('Error: ${snapshot.error}')),
                                  ),
                                ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight),
                                    child: const Center(
                                        child: Text(
                                            'No leaderboard selected or you are not part of any.')),
                                  ),
                                ),
                          );
                        }
                        return LeaderboardScreen(
                            leaderboardDetail: snapshot.data!);
                      },
                    ),
                  ),
                  DrinkListView(
                    drinks: displayedDrinks,
                    iconForDrink: _iconForDrink,
                    onRefresh: _refreshData,
                    activeFilter: _myDrinksDateFilter,
                    onClearFilter: _clearDateFilter,
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: colorScheme.scrim.withValues(alpha:0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: AnimatedNotchBottomBar(
            notchBottomBarController: _barController,
            color: colorScheme.surfaceContainer,
            notchColor: colorScheme.primary,
            showLabel: true,
            elevation: 8,
            kBottomRadius: 15.0,
            kIconSize: 24.0,
            bottomBarItems: [
              BottomBarItem(
                inActiveItem: Icon(Icons.leaderboard,
                    color: colorScheme.onSurfaceVariant),
                activeItem:
                Icon(Icons.leaderboard, color: colorScheme.onPrimary),
                itemLabel: 'Leaderboard',
              ),
              BottomBarItem(
                inActiveItem: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                activeItem: Icon(Icons.add, color: colorScheme.onPrimary),
                itemLabel: 'Add',
              ),
              BottomBarItem(
                inActiveItem: Icon(Icons.local_drink,
                    color: colorScheme.onSurfaceVariant),
                activeItem:
                Icon(Icons.local_drink, color: colorScheme.onPrimary),
                itemLabel: 'My Drinks',
              ),
            ],
            onTap: _onTabChanged,
          ),
        );
      },
    );
  }
}

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
  final Map<String, bool> _expanded = {};
  bool _showLitres = false;
  // --- NEW: Add ApiService and a handler ---
  final ApiService _apiService = ApiService();

  void _handleSessionExpired() {
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has expired. Please log in again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateLitreToggle(widget.drinks);
  }

  @override
  void didUpdateWidget(DrinkListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drinks.length != oldWidget.drinks.length) {
      _updateLitreToggle(widget.drinks);
    }
  }

  void _updateLitreToggle(List<DrinkEntry> drinks) {
    final totalVolume = drinks.fold<double>(0, (sum, e) => sum + e.volume);
    if (totalVolume >= 1000 && !_showLitres) {
      if (mounted) setState(() => _showLitres = true);
    } else if (totalVolume < 1000 && _showLitres) {
      if (mounted) setState(() => _showLitres = false);
    }
  }

  String _formatSummaryVolume(double ml) {
    if (_showLitres) {
      return "${(ml / 1000).toStringAsFixed(2)} L";
    } else {
      return "${NumberFormat('#,##0').format(ml)} ml";
    }
  }

  String _formatItemVolume(double ml) {
    return ml >= 1000
        ? "${(ml / 1000).toStringAsFixed(2)} L"
        : "${ml.toStringAsFixed(0)} ml";
  }

  Widget _buildSummaryRow() {
    final totalDrinks = widget.drinks.length;
    final totalVolume =
    widget.drinks.fold<double>(0, (sum, e) => sum + e.volume);
    final totalUnits =
    widget.drinks.fold<double>(0, (sum, e) => sum + e.units);

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
          stat(Icons.water_drop, "Volume", _formatSummaryVolume(totalVolume),
              onTap: totalVolume >= 1000
                  ? () {
                if (mounted) {
                  setState(() {
                    _showLitres = !_showLitres;
                  });
                }
              }
                  : null),
          stat(Icons.calculate, "Units", totalUnits.toStringAsFixed(2)),
        ],
      ),
    );
  }

  // --- UPDATED: Now catches SessionExpiredException ---
  Future<void> _handleDeleteDrink(DrinkEntry drink) async {
    // Safety check for the ID
    if (drink.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Cannot delete drink without an ID.')),
      );
      return;
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'Delete Drink',
      desc:
      'Are you sure you want to delete this drink entry? This action cannot be undone.',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        try {
          await _apiService.deleteDrink(drink.id!); // Use the non-null ID
          scaffoldMessenger.showSnackBar(
            const SnackBar(
                content: Text('Drink deleted successfully.'),
                backgroundColor: Colors.green),
          );
          await widget.onRefresh(); // Refresh the data
        } on SessionExpiredException catch (_) { // <-- NEW CATCH BLOCK
          _handleSessionExpired();
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
                content: Text('Failed to delete drink: $e'),
                backgroundColor: Colors.red),
          );
        }
      },
    ).show();
  }

  Widget _buildGroupedList() {
    final Map<String, List<DrinkEntry>> grouped = {};
    for (var d in widget.drinks) {
      final dateKey = DateFormat('yyyy-MM-dd').format(d.timestamp.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(d);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final entries = grouped[dateKey]!;

        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final totalUnits =
        entries.fold<double>(0, (sum, e) => sum + e.units);
        final totalDrinks = entries.length;
        final totalVolume =
        entries.fold<double>(0, (sum, e) => sum + e.volume);

        return ExpansionTile(
          key: PageStorageKey(dateKey),
          initiallyExpanded: _expanded[dateKey] ?? true,
          onExpansionChanged: (expanded) {
            if (mounted) {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$totalDrinks'),
                  const SizedBox(width: 4),
                  const Icon(Icons.local_drink, size: 16),
                  const SizedBox(width: 8),
                  Text('${totalUnits.toStringAsFixed(2)} U'),
                  const SizedBox(width: 8),
                  Text(_formatItemVolume(totalVolume)),
                ],
              )
            ],
          ),
          children: [
            ...entries.map((drink) {
              final formatted = DateFormat('EEE, d MMM yyyy HH:mm')
                  .format(drink.timestamp.toLocal());
              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  onLongPress: () => _handleDeleteDrink(drink),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.activeFilter != null)
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Chip(
              label: Text(
                '${DateFormat.yMd().format(widget.activeFilter!.start)} - ${DateFormat.yMd().format(widget.activeFilter!.end)}',
              ),
              onDeleted: widget.onClearFilter,
            ),
          ),
        _buildSummaryRow(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: widget.drinks.isEmpty
                ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                      child: Text("No drinks logged in this period.")),
                ),
              ),
            )
                : _buildGroupedList(),
          ),
        ),
      ],
    );
  }
}