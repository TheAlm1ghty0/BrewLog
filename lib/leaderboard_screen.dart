import 'package:flutter/material.dart';
import 'models/drink_entry.dart';

class LeaderboardScreen extends StatelessWidget {
  final List<DrinkEntry> drinks;
  const LeaderboardScreen({super.key, required this.drinks});

  @override
  Widget build(BuildContext context) {
    // If no data yet, show a simple empty state
    if (drinks.isEmpty) {
      return Column(
        children: [
          // Fixed group totals row (zeros)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceVariant,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Text("Group: 0 drinks"),
                Text("0 ml"),
                Text("0.00 units"),
              ],
            ),
          ),
          const Expanded(
            child: Center(child: Text("No drinks logged yet")),
          ),
        ],
      );
    }

    // For now, mock aggregation by user:
    // - All entries are under "You"
    // Later: replace with real userId grouping (Map<userId, List<DrinkEntry>>).
    final Map<String, List<DrinkEntry>> byUser = {
      "You": drinks,
      // Add more mock users if you want to see the leaderboard effect:
      // "Alice": drinks.where((e) => e.timestamp.isBefore(DateTime.now().subtract(const Duration(days: 1)))).toList(),
      // "Bob": drinks.take(drinks.length ~/ 2).toList(),
    };

    // Group totals
    final int groupTotalDrinks = drinks.length;
    final double groupTotalVolume =
    drinks.fold<double>(0, (sum, e) => sum + e.volume);
    final double groupTotalUnits =
    drinks.fold<double>(0, (sum, e) => sum + e.units);

    // Build leaderboard rows
    final List<_LeaderboardRow> leaderboard = byUser.entries.map((entry) {
      final String user = entry.key;
      final List<DrinkEntry> userDrinks = entry.value;
      final int totalDrinks = userDrinks.length;
      final double totalVolume =
      userDrinks.fold<double>(0, (sum, e) => sum + e.volume);
      final double totalUnits =
      userDrinks.fold<double>(0, (sum, e) => sum + e.units);
      return _LeaderboardRow(
        user: user,
        totalDrinks: totalDrinks,
        totalVolume: totalVolume,
        totalUnits: totalUnits,
      );
    }).toList();

    // Default sort: by total drinks (descending)
    leaderboard.sort((a, b) => b.totalDrinks.compareTo(a.totalDrinks));

    return Column(
      children: [
        // Fixed group totals row under AppBar
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Group: $groupTotalDrinks drinks",
                  style: Theme.of(context).textTheme.bodyMedium),
              Text("${groupTotalVolume.toStringAsFixed(0)} ml",
                  style: Theme.of(context).textTheme.bodyMedium),
              Text("${groupTotalUnits.toStringAsFixed(2)} units",
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        // Leaderboard list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              final row = leaderboard[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text("${index + 1}"),
                  ),
                  title: Text(row.user),
                  subtitle: Text(
                    "${row.totalDrinks} drinks • "
                        "${row.totalVolume.toStringAsFixed(0)} ml • "
                        "${row.totalUnits.toStringAsFixed(2)} units",
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow {
  final String user;
  final int totalDrinks;
  final double totalVolume;
  final double totalUnits;

  _LeaderboardRow({
    required this.user,
    required this.totalDrinks,
    required this.totalVolume,
    required this.totalUnits,
  });
}