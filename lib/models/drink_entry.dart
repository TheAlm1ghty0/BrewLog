class DrinkEntry {
  final int? id; // The unique ID from the database
  final DateTime timestamp;
  final String type;
  final double volume;
  final double abv;
  final double units;
  final String userName;
  final String? location;

  DrinkEntry({
    this.id,
    required this.timestamp,
    required this.type,
    required this.volume,
    required this.abv,
    required this.units,
    required this.userName,
    this.location,
  });

  // Factory constructor to parse the API response
  factory DrinkEntry.fromJson(Map<String, dynamic> json) {
    return DrinkEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
      volume: (json['volume'] as num).toDouble(),
      abv: (json['abv'] as num).toDouble(),
      units: (json['units'] as num).toDouble(),
      userName: json['owner']['username'], // Extract from nested owner object
      location: json['location'],
    );
  }
}