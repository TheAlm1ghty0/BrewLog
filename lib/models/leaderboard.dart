// Represents a single leaderboard in a list
class Leaderboard {
  final int id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final String? goalCategory;
  final double? goalValue;
  final String creatorUsername;
  final String inviteCode;

  Leaderboard({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    this.goalCategory,
    this.goalValue,
    required this.creatorUsername,
    required this.inviteCode,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      id: json['id'],
      name: json['name'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      goalCategory: json['goal_category'],
      goalValue: (json['goal_value'] as num?)?.toDouble(),
      creatorUsername: json['creator']['username'],
      inviteCode: json['invite_code'],
    );
  }
}

// Represents a single user's entry in a specific leaderboard's rankings
class LeaderboardEntry {
  final String username;
  final int totalDrinks;
  final double totalVolume;
  final double totalUnits;

  LeaderboardEntry({
    required this.username,
    required this.totalDrinks,
    required this.totalVolume,
    required this.totalUnits,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      username: json['username'],
      totalDrinks: json['total_drinks'],
      totalVolume: (json['total_volume'] as num).toDouble(),
      totalUnits: (json['total_units'] as num).toDouble(),
    );
  }
}

// Represents the combined details for a single leaderboard view
class LeaderboardDetail {
  final Leaderboard details;
  final List<LeaderboardEntry> entries;
  final int? finalTotalDrinks;
  final double? finalTotalVolume;
  final double? finalTotalUnits;

  LeaderboardDetail({
    required this.details,
    required this.entries,
    this.finalTotalDrinks,
    this.finalTotalVolume,
    this.finalTotalUnits,
  });

  factory LeaderboardDetail.fromJson(Map<String, dynamic> json) {
    var entriesList = json['entries'] as List;
    List<LeaderboardEntry> entries = entriesList.map((i) => LeaderboardEntry.fromJson(i)).toList();
    return LeaderboardDetail(
      details: Leaderboard.fromJson(json['details']),
      entries: entries,
      finalTotalDrinks: json['final_total_drinks'],
      finalTotalVolume: (json['final_total_volume'] as num?)?.toDouble(),
      finalTotalUnits: (json['final_total_units'] as num?)?.toDouble(),
    );
  }
}