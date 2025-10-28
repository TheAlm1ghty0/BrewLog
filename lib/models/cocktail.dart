/// Represents a predefined cocktail from the database.
class Cocktail {
  final int id;
  final String name;
  final double defaultVolume;
  final double defaultAbv;

  Cocktail({
    required this.id,
    required this.name,
    required this.defaultVolume,
    required this.defaultAbv,
  });

  /// Creates a Cocktail object from a JSON map.
  factory Cocktail.fromJson(Map<String, dynamic> json) {
    return Cocktail(
      id: json['id'] as int,
      name: json['name'] as String,
      defaultVolume: (json['default_volume'] as num).toDouble(),
      defaultAbv: (json['default_abv'] as num).toDouble(),
    );
  }

  // Optional: Add a toString() for easy debugging
  @override
  String toString() {
    return 'Cocktail(id: $id, name: $name, volume: $defaultVolume, abv: $defaultAbv)';
  }
}