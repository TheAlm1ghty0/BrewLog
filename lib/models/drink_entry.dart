class DrinkEntry {
  final DateTime timestamp;
  final String type;
  final double volume;
  final double abv;
  final double units;
  final String? location; // optional for now

  DrinkEntry({
    required this.timestamp,
    required this.type,
    required this.volume,
    required this.abv,
    required this.units,
    this.location,
  });
}