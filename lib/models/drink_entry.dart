class DrinkEntry {
  final DateTime timestamp;
  final String type;
  final double volume;
  final double abv;
  final double units;
  final String userName; // Automatically attached, not manually entered
  final String? location;

  DrinkEntry({
    required this.timestamp,
    required this.type,
    required this.volume,
    required this.abv,
    required this.units,
    required this.userName, // Will be passed from the "logged-in" user state
    this.location,
  });

  // Method to convert a DrinkEntry object into a JSON map for local storage
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'volume': volume,
    'abv': abv,
    'units': units,
    'userName': userName,
    'location': location,
  };

  // Factory constructor to create a DrinkEntry object from a JSON map
  factory DrinkEntry.fromJson(Map<String, dynamic> json) => DrinkEntry(
    timestamp: DateTime.parse(json['timestamp']),
    type: json['type'],
    volume: json['volume'],
    abv: json['abv'],
    units: json['units'],
    userName: json['userName'],
    location: json['location'],
  );
}

