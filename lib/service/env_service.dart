import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> setupMapbox() async {
  try {
    // Load environment variables
    await dotenv.load();

    // Validate token exists
    final tokenCheck = dotenv.env["MAPBOX_ACCESS_TOKEN"];

    if (tokenCheck != null) {
      MapboxOptions.setAccessToken(tokenCheck);
      print("Mapbox initialized successfully");
    } else {
      print("Mapbox initalized faild");
    }
    // Initialize Mapbox
  } catch (e) {
    print("Error initializing Mapbox: $e");
    rethrow; // Important to let the error propagate
  }
}
