import '../model/restaurant.dart';

abstract class SearchableLocation {
  String get name;
  String get category;
  String get description;
  double get latitude;
  double get longitude;
  double get rating;
  double get distance;
  String get imageUrl;
}

// Make Restaurant implement SearchableLocation
extension SearchableRestaurant on Restaurant {
  String get category => this.category;
  String get description => this.description;
}