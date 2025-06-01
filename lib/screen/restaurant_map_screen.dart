import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../data/restaurant_data.dart';
import '../model/restaurant.dart';
import '../widget/restaurant_details_widget.dart';
import '../widget/search_bar_widget.dart';

class RestaurantMapScreen extends StatefulWidget {
  const RestaurantMapScreen({super.key});

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen>
    with TickerProviderStateMixin {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  Restaurant? selectedRestaurant;
  String searchQuery = "";
  List<Restaurant> filteredRestaurants = [];
  bool showSearchResults = false;
  Set<int> favorites = <int>{};
  geo.Position? userLocation;
  List<PointAnnotation> restaurantAnnotations = [];
  String selectedCategory = 'All';
  bool isLoading = true;
  bool isMapReady = false;

  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _filterAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _filterAnimation;

  OnPointAnnotationClickListener? _annotationClickListener;

  final Dio _dio = Dio();
  final String mapboxAccessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // Restaurant categories with colors and icons
  final Map<String, Map<String, dynamic>> categoryConfig = {
    'All': {'color': Colors.grey, 'icon': Icons.restaurant},
    'Fast Food': {'color': Colors.red, 'icon': Icons.fastfood},
    'Fine Dining': {'color': Colors.purple, 'icon': Icons.restaurant_menu},
    'Cafe': {'color': Colors.brown, 'icon': Icons.local_cafe},
    'Pizza': {'color': Colors.orange, 'icon': Icons.local_pizza},
    'Asian': {'color': Colors.green, 'icon': Icons.ramen_dining},
    'Dessert': {'color': Colors.pink, 'icon': Icons.cake},
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
    filteredRestaurants = restaurants;

    // Setup annotation click listener
    // // Setup the click listener correctly
    // pointAnnotationManager!.addOnPointAnnotationClickListener(
    //   OnPointAnnotationClickListener(
    //     onPointAnnotationClick: (PointAnnotation annotation) {
    //       _onAnnotationTapped(annotation);
    //       return true; // Return true to consume the event
    //     },
    //   ),
    // );
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _filterAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _filterAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => isLoading = true);

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        geo.Position position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        setState(() {
          userLocation = position;
          isLoading = false;
        });

        if (mapboxMap != null) {
          await _moveToUserLocation();
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar("Error getting location: $e");
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
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _setupMap();
  }

  Future<void> _setupMap() async {
    if (mapboxMap == null) return;

    setState(() => isLoading = true);

    try {
      // Create point annotation manager
      pointAnnotationManager =
          await mapboxMap!.annotations.createPointAnnotationManager();

      if (_annotationClickListener != null) {
        pointAnnotationManager!.addOnPointAnnotationClickListener(
          
          _annotationClickListener!,
        );
      }

      // Add restaurant markers
      await _addRestaurantMarkers();

      // Add user location marker if available
      if (userLocation != null) {
        await _addUserLocationMarker();
        await _moveToUserLocation();
      }

      setState(() {
        isMapReady = true;
        isLoading = false;
      });

      // Start animations
      _fabAnimationController.forward();
      _filterAnimationController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar("Error setting up map: $e");
    }
  }

  Future<void> _addRestaurantMarkers() async {
    if (pointAnnotationManager == null) return;

    // Clear existing annotations
    await pointAnnotationManager!.deleteAll();
    restaurantAnnotations.clear();

    for (Restaurant restaurant in filteredRestaurants) {
      final categoryColor =
          categoryConfig[restaurant.category]?['color'] ?? Colors.grey;

      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(restaurant.longitude, restaurant.latitude),
        ),
        textField: restaurant.name,
        textOffset: [0.0, -2.5],
        textColor: Colors.black.value,
        textSize: 11.0,
        textHaloColor: Colors.white.value,
        textHaloWidth: 1.0,
        iconImage: _getRestaurantIcon(restaurant.category),
        iconSize: _getIconSize(restaurant.rating),
        iconColor: categoryColor.value,
        iconOpacity: 0.9,
      );

      final annotation = await pointAnnotationManager!.create(
        pointAnnotationOptions,
      );
      restaurantAnnotations.add(annotation);
    }

    // Add user location marker if available
    if (userLocation != null) {
      await _addUserLocationMarker();
    }
  }

  String _getRestaurantIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fast food':
        return "fast-food-15";
      case 'fine dining':
        return "restaurant-15";
      case 'cafe':
        return "cafe-15";
      case 'pizza':
        return "pizza-15";
      case 'asian':
        return "restaurant-15";
      case 'dessert':
        return "ice-cream-15";
      default:
        return "restaurant-15";
    }
  }

  double _getIconSize(double rating) {
    if (rating >= 4.5) return 2.0;
    if (rating >= 4.0) return 1.8;
    if (rating >= 3.5) return 1.6;
    return 1.4;
  }

  Future<void> _addUserLocationMarker() async {
    if (pointAnnotationManager == null || userLocation == null) return;

    final userLocationOptions = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(userLocation!.longitude, userLocation!.latitude),
      ),
      iconImage: "marker-15",
      iconAnchor: IconAnchor.CENTER,
      iconSize: 2.0,
      iconColor: Colors.blue.value,
      textField: "You are here",
      textOffset: [0.0, -2.0],
      textColor: Colors.blue.value,
      textSize: 12.0,
      textHaloColor: Colors.white.value,
      textHaloWidth: 1.0,
    );

    await pointAnnotationManager!.create(userLocationOptions);
  }

  void _onAnnotationTapped(PointAnnotation annotation) {
    for (final restaurant in filteredRestaurants) {
      final matches =
          (annotation.geometry.coordinates.lng - restaurant.longitude).abs() <
              0.0001 &&
          (annotation.geometry.coordinates.lat - restaurant.latitude).abs() <
              0.0001;

      if (matches) {
        setState(() => selectedRestaurant = restaurant);
        _showRestaurantDetails(restaurant);
        _highlightRestaurant(restaurant);
        return;
      }
    }
  }

  Future<void> _highlightRestaurant(Restaurant restaurant) async {
    if (mapboxMap != null) {
      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(restaurant.longitude, restaurant.latitude),
          ),
          zoom: 17.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _showRestaurantDetails(Restaurant restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder:
          (context) => RestaurantDetailModal(
            restaurant: restaurant,
            isFavorite: favorites.contains(restaurant.id),
            onFavoriteToggle: () => _toggleFavorite(restaurant.id),
            onMessage: () => _handleMessage(restaurant),

            // onDirections: () => _getDirections(restaurant),
            // onCall: () => _callRestaurant(restaurant),
          ),
    );
  }

  void _toggleFavorite(int restaurantId) {
    setState(() {
      if (favorites.contains(restaurantId)) {
        favorites.remove(restaurantId);
        _showSuccessSnackBar("Removed from favorites");
      } else {
        favorites.add(restaurantId);
        _showSuccessSnackBar("Added to favorites");
      }
    });
  }

  void _handleMessage(Restaurant restaurant) {
    _showSuccessSnackBar('Opening chat with ${restaurant.name}');
  }

  void _getDirections(Restaurant restaurant) {
    _showSuccessSnackBar('Getting directions to ${restaurant.name}');
  }

  void _callRestaurant(Restaurant restaurant) {
    _showSuccessSnackBar('Calling ${restaurant.name}');
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      showSearchResults = query.isNotEmpty;
      _filterRestaurants();
    });
  }

  void _filterRestaurants() {
    setState(() {
      filteredRestaurants =
          restaurants.where((restaurant) {
            final matchesSearch =
                searchQuery.isEmpty ||
                restaurant.name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                restaurant.cuisine.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );

            final matchesCategory =
                selectedCategory == 'All' ||
                restaurant.category == selectedCategory;

            return matchesSearch && matchesCategory;
          }).toList();
    });

    if (isMapReady) {
      _addRestaurantMarkers();
    }
  }

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      showSearchResults = false;
      searchQuery = "";
    });
    _filterRestaurants();
  }

  void _onRestaurantSelected(Restaurant restaurant) async {
    setState(() {
      selectedRestaurant = restaurant;
      showSearchResults = false;
      searchQuery = "";
    });

    await _highlightRestaurant(restaurant);
    _showRestaurantDetails(restaurant);
  }

  void _goToMyLocation() async {
    if (userLocation != null && mapboxMap != null) {
      await _moveToUserLocation();
      _showSuccessSnackBar("Centered on your location");
    } else {
      await _getCurrentLocation();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SlideTransition(
      position: _filterAnimation,
      child: Container(
        height: 50,
        margin: const EdgeInsets.only(left: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categoryConfig.keys.length,
          itemBuilder: (context, index) {
            final category = categoryConfig.keys.elementAt(index);
            final config = categoryConfig[category]!;
            final isSelected = selectedCategory == category;

            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      config['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : config['color'],
                    ),
                    const SizedBox(width: 4),
                    Text(category),
                  ],
                ),
                onSelected: (_) => _onCategorySelected(category),
                selectedColor: config['color'],
                backgroundColor: Colors.white,
                elevation: isSelected ? 4 : 2,
                shadowColor: config['color'].withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? config['color'] : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading restaurants...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final annotation in restaurantAnnotations) {
      print(
        'Annotation ID: ${annotation.id}, '
        'Longitude: ${annotation.geometry.coordinates.lng}, '
        'Latitude: ${annotation.geometry.coordinates.lat}',
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          MapWidget(
            key: const ValueKey("mapWidget"),

            onMapIdleListener: (mapIdleEventData) {
              print(mapIdleEventData.timestamp);
            },
            onTapListener: (context) {
              print(restaurantAnnotations.first.id);
              // You need to determine which annotation was tapped; here is a placeholder example:
              // If you have the tapped annotation, pass it as an argument.
              // Replace 'tappedAnnotation' with the actual annotation object.
              if (_annotationClickListener != null &&
                  restaurantAnnotations.isNotEmpty) {
                // This is just an example; you should use the actual tapped annotation.
                _annotationClickListener!.onPointAnnotationClick(
                  restaurantAnnotations.first,
                );
              }
            },

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
            styleUri:
                Theme.of(context).brightness == Brightness.dark
                    ? MapboxStyles.DARK
                    : MapboxStyles.STANDARD,
            onMapCreated: _onMapCreated,
          ),

          // Loading overlay
          if (isLoading) _buildLoadingOverlay(),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
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

          // Category Filter
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: _buildCategoryFilter(),
          ),

          // Restaurant count indicator
          if (!isLoading && isMapReady)
            Positioned(
              top: MediaQuery.of(context).padding.top + 140,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${filteredRestaurants.length} restaurants',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

          // My Location Button
          Positioned(
            bottom: 100,
            right: 16,
            child: ScaleTransition(
              scale: _fabAnimation,
              child: FloatingActionButton(
                onPressed: _goToMyLocation,
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 8,
                child: const Icon(Icons.my_location),
              ),
            ),
          ),

          // Favorites Button
          Positioned(
            bottom: 170,
            right: 16,
            child: ScaleTransition(
              scale: _fabAnimation,
              child: FloatingActionButton.small(
                onPressed: () {
                  // Show favorites
                  _showSuccessSnackBar('${favorites.length} favorites');
                },
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 8,
                child: Stack(
                  children: [
                    const Icon(Icons.favorite),
                    if (favorites.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${favorites.length}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
