import 'package:flutter/material.dart';
import '../models/leaderboard.dart';
import 'package:intl/intl.dart';

class LeaderboardScreen extends StatelessWidget {
  final LeaderboardDetail leaderboardDetail;
  const LeaderboardScreen({super.key, required this.leaderboardDetail});

  // Formats volume consistently (L for >= 1000ml, ml otherwise with commas)
  String _formatVolume(double ml) {
    return ml >= 1000
        ? "${(ml / 1000).toStringAsFixed(2)} L"
        : "${NumberFormat('#,##0').format(ml)} ml";
  }

  // Builds the status chip (Finished / Goal Achieved)
  Widget _buildStatusChip(BuildContext context) {
    final details = leaderboardDetail.details;
    final colorScheme = Theme.of(context).colorScheme;

    // Only show chip if the leaderboard has finished
    if (details.endDate == null || details.endDate!.isAfter(DateTime.now().toUtc())) { // Compare with UTC now
      return const SizedBox.shrink(); // Not finished yet
    }

    bool goalMet = false;
    // Check if a goal was set and met
    if (details.goalCategory != null && details.goalValue != null) {
      double finalTotal = 0;
      // Use final totals if available (calculated in backend)
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

    // Display appropriate chip based on goal status
    if (goalMet) {
      return Chip(
        label: const Text('Goal Achieved!'),
        backgroundColor: colorScheme.tertiaryContainer,
        avatar: Icon(Icons.emoji_events, color: colorScheme.onTertiaryContainer, size: 18),
        labelStyle: TextStyle(color: colorScheme.onTertiaryContainer, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        visualDensity: VisualDensity.compact,
      );
    } else {
      return Chip(
        label: const Text('Finished'),
        backgroundColor: colorScheme.secondaryContainer,
        avatar: Icon(Icons.check_circle_outline, color: colorScheme.onSecondaryContainer, size: 18),
        labelStyle: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        visualDensity: VisualDensity.compact,
      );
    }
  }

  // Builds the goal progress bar section
  Widget _buildGoalProgress(BuildContext context, Leaderboard details, double currentProgressValue, double goalValue) {
    final colorScheme = Theme.of(context).colorScheme;
    String goalText = '';
    String currentText = '';

    // Format text based on goal category
    switch (details.goalCategory) {
      case 'drinks':
        currentText = '${currentProgressValue.toInt()}';
        goalText = '/ ${goalValue.toInt()} Drinks';
        break;
      case 'volume':
        currentText = _formatVolume(currentProgressValue);
        goalText = '/ ${_formatVolume(goalValue)}';
        break;
      case 'units':
        currentText = currentProgressValue.toStringAsFixed(1); // Use 1 decimal for units display
        goalText = '/ ${goalValue.toStringAsFixed(1)} Units';
        break;
      default: return const SizedBox.shrink(); // Hide if no valid category
    }

    // Calculate progress percentage, clamped between 0 and 1
    final double progressPercent = (currentProgressValue / goalValue).clamp(0.0, 1.0);
    final bool isComplete = progressPercent >= 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: colorScheme.surfaceContainerLowest, // Use lowest container color for contrast
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Leaderboard Goal', style: Theme.of(context).textTheme.titleMedium),
              // Combine current and goal text
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: <TextSpan>[
                    TextSpan(text: currentText, style: TextStyle(fontWeight: FontWeight.bold, color: isComplete ? colorScheme.tertiary : colorScheme.primary)),
                    TextSpan(text: goalText),
                  ],
                ),
              )

            ],
          ),
          const SizedBox(height: 8),
          // Use ClipRRect for rounded corners on the progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 12, // Slightly thicker bar
              // Use tertiary color if complete, primary otherwise
              color: isComplete ? colorScheme.tertiary : colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest, // Contrasting background
            ),
          ),
        ],
      ),
    );
  }

  // Builds a single stat widget for the group totals row
  Widget _buildTotalStat(BuildContext context, IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.secondary), // Use secondary color
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)), // Bolder value
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = leaderboardDetail.entries;
    final details = leaderboardDetail.details;

    // Calculate current group totals based on the entries received
    final int currentGroupTotalDrinks = entries.fold(0, (sum, e) => sum + e.totalDrinks);
    final double currentGroupTotalVolume = entries.fold(0.0, (sum, e) => sum + e.totalVolume);
    final double currentGroupTotalUnits = entries.fold(0.0, (sum, e) => sum + e.totalUnits);

    // Determine current progress value for the goal bar
    double currentProgressValue = 0;
    if (details.goalCategory != null) {
      switch (details.goalCategory) {
        case 'drinks': currentProgressValue = currentGroupTotalDrinks.toDouble(); break;
        case 'volume': currentProgressValue = currentGroupTotalVolume; break;
        case 'units': currentProgressValue = currentGroupTotalUnits; break;
      }
    }


    return Column(
      children: [
        // Display status chip only if finished
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), // Adjust padding
          child: _buildStatusChip(context),
        ),

        // Display goal progress bar only if goal is set
        if (details.goalCategory != null && details.goalValue != null)
          _buildGoalProgress(context, details, currentProgressValue, details.goalValue!),

        // Display overall group totals row
        Container(
          // Use a slightly elevated surface color for the totals bar
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTotalStat(context, Icons.format_list_numbered, '$currentGroupTotalDrinks', 'Drinks'),
              _buildTotalStat(context, Icons.water_drop_outlined, _formatVolume(currentGroupTotalVolume), 'Volume'),
              _buildTotalStat(context, Icons.calculate_outlined, currentGroupTotalUnits.toStringAsFixed(1), 'Units'), // Use 1 decimal
            ],
          ),
        ),
        const Divider(height: 1), // Add divider

        // Main leaderboard list
        Expanded(
          child: entries.isEmpty
          // Show message if no drinks logged yet for this leaderboard
              ? const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No drinks have been logged for this leaderboard yet.', textAlign: TextAlign.center),
          ))
          // Build the list of user entries
              : ListView.builder(
            // --- FIX: Add bottom padding to avoid nav bar ---
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 100.0), // Added padding
            // --- END FIX ---
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rank = index + 1;
              IconData rankIcon;
              Color? rankIconColor = Theme.of(context).colorScheme.secondary; // Default rank color

              // Assign specific icons/colors for top ranks
              switch (rank) {
                case 1: rankIcon = Icons.emoji_events; rankIconColor = Colors.amber[600]; break; // Gold
                case 2: rankIcon = Icons.military_tech; rankIconColor = Colors.grey[400]; break; // Silver
                case 3: rankIcon = Icons.workspace_premium; rankIconColor = Colors.brown[400]; break; // Bronze
                default: rankIcon = Icons.circle; rankIconColor = rankIconColor.withOpacity(0.6); // Faded circle for others
              }


              return Card(
                // Use slightly elevated card color
                // color: Theme.of(context).colorScheme.surfaceContainerHigh,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: Column( // Use column for rank + icon
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("#$rank", style: Theme.of(context).textTheme.labelSmall),
                      Icon(rankIcon, color: rankIconColor, size: 20),
                    ],
                  ),
                  title: Text(
                    entry.username,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    // Format stats clearly
                    "${entry.totalDrinks} Drinks • ${_formatVolume(entry.totalVolume)} • ${entry.totalUnits.toStringAsFixed(1)} Units", // Use 1 decimal
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  // Trailing could show difference from leader, or just be removed
                  // trailing: Text(
                  //   "#${index + 1}",
                  //   style: Theme.of(context).textTheme.titleLarge,
                  // ),
                  dense: true, // Make tiles more compact
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}