import 'package:flutter/material.dart';
import '../model/restaurant.dart';

class SearchBarWidget extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final bool showResults;
  final List<Restaurant> filteredRestaurants;
  final Function(Restaurant) onRestaurantSelected;

  const SearchBarWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showResults,
    required this.filteredRestaurants,
    required this.onRestaurantSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search restaurants...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
        if (showResults && filteredRestaurants.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredRestaurants.length,
              itemBuilder: (context, index) {
                final restaurant = filteredRestaurants[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    restaurant.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.cuisine),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(' ${restaurant.rating}'),
                          Text(' • ${restaurant.distance} km'),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => onRestaurantSelected(restaurant),
                );
              },
            ),
          ),
      ],
    );
  }
}