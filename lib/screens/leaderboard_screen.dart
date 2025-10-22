import 'package:flutter/material.dart';
import '../models/leaderboard.dart';
import 'package:intl/intl.dart';

class LeaderboardScreen extends StatelessWidget {
  final LeaderboardDetail leaderboardDetail;
  const LeaderboardScreen({super.key, required this.leaderboardDetail});

  String _formatVolume(double ml) {
    return ml >= 1000
        ? "${(ml / 1000).toStringAsFixed(2)} L"
        : "${NumberFormat('#,##0').format(ml)} ml";
  }

  Widget _buildStatusChip(BuildContext context) {
    final details = leaderboardDetail.details;
    final colorScheme = Theme.of(context).colorScheme;

    if (details.endDate == null || details.endDate!.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }

    bool goalMet = false;
    if (details.goalCategory != null && details.goalValue != null) {
      double finalTotal = 0;
      switch (details.goalCategory) {
        case 'drinks':
          finalTotal = leaderboardDetail.finalTotalDrinks?.toDouble() ?? 0.0;
          break;
        case 'volume':
          finalTotal = leaderboardDetail.finalTotalVolume ?? 0.0;
          break;
        case 'units':
          finalTotal = leaderboardDetail.finalTotalUnits ?? 0.0;
          break;
      }
      if (finalTotal >= details.goalValue!) {
        goalMet = true;
      }
    }

    if (goalMet) {
      return Chip(
        label: const Text('Goal Achieved!'),
        backgroundColor: colorScheme.tertiaryContainer,
        avatar: Icon(Icons.emoji_events, color: colorScheme.onTertiaryContainer),
        labelStyle: TextStyle(color: colorScheme.onTertiaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
      );
    } else {
      return Chip(
        label: const Text('Finished'),
        backgroundColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = leaderboardDetail.entries;
    final details = leaderboardDetail.details;

    final int groupTotalDrinks = entries.fold(0, (sum, e) => sum + e.totalDrinks);
    final double groupTotalVolume = entries.fold(0.0, (sum, e) => sum + e.totalVolume);
    final double groupTotalUnits = entries.fold(0.0, (sum, e) => sum + e.totalUnits);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _buildStatusChip(context),
        ),

        if (details.goalCategory != null && details.goalValue != null)
          _buildGoalProgress(context, details, groupTotalDrinks, groupTotalVolume, groupTotalUnits),

        Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTotalStat(context, Icons.local_drink, '$groupTotalDrinks', 'Drinks'),
              _buildTotalStat(context, Icons.water_drop, _formatVolume(groupTotalVolume), 'Volume'),
              _buildTotalStat(context, Icons.calculate, groupTotalUnits.toStringAsFixed(2), 'Units'),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No drinks have been logged for this leaderboard yet.'))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      entry.username.isNotEmpty ? entry.username[0].toUpperCase() : "?",
                    ),
                  ),
                  title: Text(
                    entry.username,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    "${entry.totalDrinks} drinks • ${_formatVolume(entry.totalVolume)} • ${entry.totalUnits.toStringAsFixed(2)} units",
                  ),
                  trailing: Text(
                    "#${index + 1}",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGoalProgress(BuildContext context, Leaderboard details, int currentDrinks, double currentVolume, double currentUnits) {
    final colorScheme = Theme.of(context).colorScheme;
    double currentProgress = 0;
    String goalText = '';

    switch (details.goalCategory) {
      case 'drinks':
        currentProgress = currentDrinks.toDouble();
        goalText = '${currentProgress.toInt()} / ${details.goalValue!.toInt()} Drinks';
        break;
      case 'volume':
        currentProgress = currentVolume;
        goalText = '${_formatVolume(currentProgress)} / ${_formatVolume(details.goalValue!)}';
        break;
      case 'units':
        currentProgress = currentUnits;
        goalText = '${currentProgress.toStringAsFixed(2)} / ${details.goalValue!.toStringAsFixed(2)} Units';
        break;
    }

    final double progressPercent = (currentProgress / details.goalValue!).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Leaderboard Goal', style: Theme.of(context).textTheme.titleMedium),
              Text(goalText, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progressPercent,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            color: progressPercent >= 1.0 ? colorScheme.tertiary : colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStat(BuildContext context, IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}