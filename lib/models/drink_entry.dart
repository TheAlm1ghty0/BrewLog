class DrinkEntry {
  final int? id; // The unique ID from the database (nullable for creation)
  final DateTime timestamp;
  final String type; // e.g., Beer, Wine, Cocktail
  final String? name; // e.g., Punk IPA, Mojito
  final double volume;
  final double abv;
  final double units;
  final String userName;
  final String? location;

  DrinkEntry({
    this.id,
    required this.timestamp,
    required this.type,
    this.name, // Added optional name
    required this.volume,
    required this.abv,
    required this.units,
    required this.userName,
    this.location,
  });

  // Factory constructor to parse the API response
  factory DrinkEntry.fromJson(Map<String, dynamic> json) {
    return DrinkEntry(
      id: json['id'] as int?,
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'] as String,
      name: json['name'] as String?, // Added name parsing
      volume: (json['volume'] as num).toDouble(),
      abv: (json['abv'] as num).toDouble(),
      units: (json['units'] as num).toDouble(),
      userName: json['owner']['username'] as String,
      location: json['location'] as String?,
    );
  }
}