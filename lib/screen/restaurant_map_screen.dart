import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../data/restaurant_data.dart';
import '../model/restaurant.dart';
import '../widget/restaurant_details_widget.dart';
import '../widget/search_bar_widget.dart';

class RestaurantMapScreen extends StatefulWidget {
  const RestaurantMapScreen({Key? key}) : super(key: key);

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  Restaurant? selectedRestaurant;
  String searchQuery = "";
  List<Restaurant> filteredRestaurants = [];
  bool showSearchResults = false;
  Set<int> favorites = <int>{};
  geo.Position? userLocation;
  List<PointAnnotation> restaurantAnnotations = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    filteredRestaurants = restaurants;
  }

  Future<void> _getCurrentLocation() async {
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        geo.Position position = await geo.Geolocator.getCurrentPosition();
        setState(() {
          userLocation = position;
        });

        // Move camera to user location if map is ready
        if (mapboxMap != null) {
          await _moveToUserLocation();
        }
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _moveToUserLocation() async {
    if (userLocation != null && mapboxMap != null) {
      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              userLocation!.longitude,
              userLocation!.latitude,
            ),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _setupMap();
  }

  Future<void> _setupMap() async {
    if (mapboxMap == null) return;

    // Create point annotation manager
    pointAnnotationManager =
        await mapboxMap!.annotations.createPointAnnotationManager();

    // Add restaurant markers
    await _addRestaurantMarkers();

    // Add user location marker if available
    if (userLocation != null) {
      await _addUserLocationMarker();
      await _moveToUserLocation();
    }

    final _annot = _onAnnotationTapped();

    // Set up tap listener
    pointAnnotationManager!.addOnPointAnnotationClickListener();
    // pointAnnotationManager!.addOnPointAnnotationClickListener();
  }

  Future<void> _addRestaurantMarkers() async {
    if (pointAnnotationManager == null) return;

    restaurantAnnotations.clear();

    for (Restaurant restaurant in restaurants) {
      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(restaurant.longitude, restaurant.latitude),
        ),
        textField: restaurant.name,
        textOffset: [0.0, -2.0],
        textColor: Colors.black.value,
        textSize: 12.0,
        iconImage: "restaurant-15", // Using built-in Mapbox icon
        iconSize: 1.5,
      );

      final annotation = await pointAnnotationManager!.create(
        pointAnnotationOptions,
      );
      restaurantAnnotations.add(annotation);
    }
  }

  Future<void> _addUserLocationMarker() async {
    if (pointAnnotationManager == null || userLocation == null) return;

    final userLocationOptions = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(userLocation!.longitude, userLocation!.latitude),
      ),
      iconImage: "marker-15", // Using built-in Mapbox icon
      iconSize: 1.5,
      iconColor: Colors.blue.value,
    );

    await pointAnnotationManager!.create(userLocationOptions);
  }

  Future<PointAnnotation> _onAnnotationTapped(
    PointAnnotation annotation,
  ) async {
    // Find the restaurant based on the annotation's position

    for (final restaurant in restaurants) {
      final matches =
          (annotation.geometry.coordinates.lng - restaurant.longitude).abs() <
              0.0001 &&
          (annotation.geometry.coordinates.lat - restaurant.latitude).abs() <
              0.0001;

      if (matches) {
        setState(() {
          selectedRestaurant = restaurant;
        });
        _showRestaurantDetails(restaurant);
        break;
      }
    }

    for (int i = 0; i < restaurants.length; i++) {
      final restaurant = restaurants[i];
      final restaurantPoint = Point(
        coordinates: Position(restaurant.longitude, restaurant.latitude),
      );

      // Check if the tapped annotation matches a restaurant location
      final annotationLng = annotation.geometry.coordinates.lng;
      final annotationLat = annotation.geometry.coordinates.lat;
      final restaurantLng = restaurantPoint.coordinates.lng;
      final restaurantLat = restaurantPoint.coordinates.lat;

      // Use a small tolerance for comparison due to floating point precision
      if ((annotationLng - restaurantLng).abs() < 0.0001 &&
          (annotationLat - restaurantLat).abs() < 0.0001) {
        setState(() {
          selectedRestaurant = restaurant;
        });
        _showRestaurantDetails(restaurant);
        return annotation; // Return true to indicate the tap was handled
      }
    }
    return annotation; // Return false if no restaurant was found for this annotation
  }

  void _showRestaurantDetails(Restaurant restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => RestaurantDetailModal(
            restaurant: restaurant,
            isFavorite: favorites.contains(restaurant.id),
            onFavoriteToggle: () => _toggleFavorite(restaurant.id),
            onMessage: () => _handleMessage(restaurant),
          ),
    );
  }

  void _toggleFavorite(int restaurantId) {
    setState(() {
      if (favorites.contains(restaurantId)) {
        favorites.remove(restaurantId);
      } else {
        favorites.add(restaurantId);
      }
    });
  }

  void _handleMessage(Restaurant restaurant) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Message ${restaurant.name}')));
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      filteredRestaurants =
          restaurants
              .where(
                (restaurant) =>
                    restaurant.name.toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                    restaurant.cuisine.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
    });
  }

  void _onRestaurantSelected(Restaurant restaurant) async {
    setState(() {
      selectedRestaurant = restaurant;
      showSearchResults = false;
      searchQuery = "";
    });

    if (mapboxMap != null) {
      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(restaurant.longitude, restaurant.latitude),
          ),
          zoom: 16.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }

    _showRestaurantDetails(restaurant);
  }

  void _goToMyLocation() async {
    if (userLocation != null && mapboxMap != null) {
      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              userLocation!.longitude,
              userLocation!.latitude,
            ),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } else {
      await _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          MapWidget(
            key: const ValueKey("mapWidget"),

            // mapOptions: MapOptions(
            //   accessToken: dotenv.env['MAPBOX_ACCESS_TOKEN']!,
            // ),
            cameraOptions: CameraOptions(
              center:
                  userLocation != null
                      ? Point(
                        coordinates: Position(
                          userLocation!.longitude,
                          userLocation!.latitude,
                        ),
                      )
                      : Point(coordinates: Position(-82.4552, 27.9496)),
              zoom: 14.0,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
          ),

          // Search Bar
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: SearchBarWidget(
              searchQuery: searchQuery,
              onSearchChanged: _onSearchChanged,
              showResults: showSearchResults,
              filteredRestaurants: filteredRestaurants,
              onRestaurantSelected: _onRestaurantSelected,
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
