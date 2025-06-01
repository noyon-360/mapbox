import 'package:flutter/material.dart';
import '../model/restaurant.dart';

class SearchBarWidget extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final bool showResults;
  final List<dynamic> filteredResults; // Changed to dynamic to support multiple types
  final Function(dynamic) onResultSelected; // Changed to dynamic
  final Function(String)? onCategorySelected; // Optional category filter
  final bool isSearching;

  const SearchBarWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showResults,
    required this.filteredResults,
    required this.onResultSelected,
    this.onCategorySelected,
    this.isSearching = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Categories for search filtering
  final List<String> _searchCategories = [
    'All',
    'Restaurants',
    'Hotels',
    'Attractions',
    'Shops',
    'Services'
  ];
  
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _focusNode = FocusNode();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (widget.showResults) {
      _animationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.showResults != oldWidget.showResults) {
      if (widget.showResults) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
    
    if (widget.searchQuery != oldWidget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
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
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search restaurants, hotels, places...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: widget.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                        _focusNode.unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
            onSubmitted: (_) => _focusNode.unfocus(),
          ),
        ),
        
        // Category Pills (only show when search is active)
        if (widget.showResults || widget.searchQuery.isNotEmpty)
          Container(
            height: 40,
            margin: const EdgeInsets.only(top: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _searchCategories.length,
              itemBuilder: (context, index) {
                final category = _searchCategories[index];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                        if (widget.onCategorySelected != null) {
                          widget.onCategorySelected!(category);
                        }
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        
        // Search Results
        if (widget.showResults)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _animation,
                child: child,
              );
            },
            child: Container(
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
              constraints: const BoxConstraints(maxHeight: 300),
              child: widget.isSearching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : widget.filteredResults.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              'No results found',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.filteredResults.length,
                          itemBuilder: (context, index) {
                            final result = widget.filteredResults[index];
                            
                            // Determine the icon based on the type
                            IconData icon;
                            Color iconColor;
                            
                            if (result is Restaurant) {
                              icon = Icons.restaurant;
                              iconColor = Colors.orange;
                            } else if (result.category == 'Hotel') {
                              icon = Icons.hotel;
                              iconColor = Colors.blue;
                            } else if (result.category == 'Attraction') {
                              icon = Icons.attractions;
                              iconColor = Colors.purple;
                            } else if (result.category == 'Shop') {
                              icon = Icons.shopping_bag;
                              iconColor = Colors.green;
                            } else {
                              icon = Icons.place;
                              iconColor = Colors.red;
                            }
                            
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: iconColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                result.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(result.category),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      Text(' ${result.rating}'),
                                      Text(' • ${result.distance} km'),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                widget.onResultSelected(result);
                                _focusNode.unfocus();
                              },
                            );
                          },
                        ),
            ),
          ),
      ],
    );
  }
}