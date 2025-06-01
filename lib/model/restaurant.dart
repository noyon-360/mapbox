class Restaurant {
  final int id;
  final String name;
  final String cuisine;
  final double rating;
  final double distance;
  final int duration;
  final double latitude;
  final double longitude;
  final String image;
  final String? imageUrl;
  final String category;
  final String description;
  final String price;
  final String hours;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.distance,
    required this.duration,
    required this.latitude,
    required this.longitude,
    required this.image,
    this.imageUrl,
    required this.category,
    required this.description,
    required this.price,
    required this.hours,
  });
}
