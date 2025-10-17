import 'package:flutter/material.dart';
import '../models/drink_entry.dart';

class LeaderboardScreen extends StatelessWidget {
  final List<DrinkEntry> drinks;
  const LeaderboardScreen({super.key, required this.drinks});

  String _formatVolume(double ml) {
    if (ml >= 1000) {
      return "${(ml / 1000).toStringAsFixed(2)} L";
    } else {
      return "${ml.toStringAsFixed(0)} ml";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (drinks.isEmpty) {
      return const Center(child: Text("No drinks logged yet"));
    }

    final totalDrinks = drinks.length;
    final totalVolume = drinks.fold<double>(0, (sum, e) => sum + e.volume);
    final totalUnits = drinks.fold<double>(0, (sum, e) => sum + e.units);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.emoji_events)),
            title: const Text("Overall Leaderboard"),
            subtitle: Text(
              "$totalDrinks drinks • ${_formatVolume(totalVolume)} • ${totalUnits.toStringAsFixed(2)} units",
            ),
          ),
        ),
      ],
    );
  }
}