import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/isAnsweredAllQuestionsScreen.dart';
import 'package:lushh/services/config_service.dart';

// Import all ids using ConfigService
final databaseId = ConfigService().get('DATABASE_ID');
final completionStatusCollectionId = ConfigService().get('COMPLETION_STATUS_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({Key? key}) : super(key: key);

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final String country = "India";
  String? selectedState;
  String? selectedCity;
  Position? currentPosition;
  bool isGettingLocation = false;
  bool isSubmitting = false;

  Map<String, List<String>>? stateCityMap;
  bool isLoadingStates = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadStateCityData();
  }

  Future<void> _loadStateCityData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/cities_states.json');
      Map<String, dynamic> jsonData = json.decode(jsonString);

      final Map<String, List<String>> parsed = {};
      jsonData.forEach((key, value) {
        if (value is List) {
          parsed[key.trim()] = value.map((e) => e.toString()).toList();
        }
      });

      if (parsed.isEmpty) {
        setState(() {
          loadError = "No valid state/city data found in JSON.";
          isLoadingStates = false;
        });
        return;
      }

      setState(() {
        stateCityMap = parsed;
        isLoadingStates = false;
      });
    } catch (e, stack) {
      setState(() {
        loadError = "Failed to load states and cities: $e\n$stack";
        isLoadingStates = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isGettingLocation = true);

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled.")),
          );
          await Geolocator.openLocationSettings();
          setState(() => isGettingLocation = false);
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permission denied.")),
            );
            setState(() => isGettingLocation = false);
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Location permission permanently denied. Please enable it in settings."),
            ),
          );
          setState(() => isGettingLocation = false);
          return;
        }

        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        setState(() {
          currentPosition = pos;
          isGettingLocation = false;
        });
      } else {
        http.Response response = await http
            .get(Uri.parse('https://ipapi.co/json/'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          dynamic data = json.decode(response.body);
          final lat = double.tryParse(data['latitude'].toString());
          final lon = double.tryParse(data['longitude'].toString());

          if (lat != null && lon != null) {
            setState(() {
              currentPosition = Position(
                latitude: lat,
                longitude: lon,
                timestamp: DateTime.now(),
                accuracy: 1,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 1,
                headingAccuracy: 1,
              );
              isGettingLocation = false;
            });
          }
        }
      }
    } catch (e, stack) {
      setState(() => isGettingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e\n$stack')),
      );
    }
  }

  void _onStateChanged(String? value) {
    setState(() {
      selectedState = value;
      selectedCity = null;
    });
  }

  void _onCityChanged(String? value) {
    setState(() {
      selectedCity = value;
    });
  }

  Future<void> _onSubmit() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);

    if (selectedState == null || selectedCity == null || currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select state, city, and get your location.'),
        ),
      );
      setState(() => isSubmitting = false);
      return;
    }

    try {
      final user = await account.get();
      final userId = user.$id;

      final userLocationDocument = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: locationCollectionId,
        queries: [Query.equal('user', userId)],
      );

      if (userLocationDocument.documents.isNotEmpty) {
        String docId = userLocationDocument.documents[0].$id;
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: locationCollectionId,
          documentId: docId,
          data: {
            'country': "India",
            'state': selectedState,
            'city': selectedCity,
            'latitude': currentPosition!.latitude,
            'longitude': currentPosition!.longitude,
          },
        );
      } else {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: locationCollectionId,
          documentId: ID.unique(),
          data: {
            'country': "India",
            'state': selectedState,
            'city': selectedCity,
            'latitude': currentPosition!.latitude,
            'longitude': currentPosition!.longitude,
            'user': userId,
          },
        );
      }

      final statusDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: completionStatusCollectionId,
        queries: [Query.equal('user', userId)],
      );

      if (statusDoc.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: completionStatusCollectionId,
          documentId: statusDoc.documents[0].$id,
          data: {'isLocationAdded': true},
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const IsAnsweredAllQuestionsScreen(),
        ),
      );
    } catch (e, stack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e\n$stack')),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.black;
    final accentColor = const Color(0xFF6D4B86);

    if (isLoadingStates) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loadError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(loadError!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (stateCityMap == null || stateCityMap!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: Text("No state/city data available.",
              style: TextStyle(color: Colors.red)),
        ),
      );
    }

    final states = stateCityMap!.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D4B86), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: accentColor, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            "Add your location",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "We’ll match you with people nearby ❤️",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Country", accentColor),
                            _buildReadOnlyField(country),
                            const SizedBox(height: 18),
                            _buildLabel("State", accentColor),
                            _buildDropdown(
                              value: selectedState,
                              items: states,
                              hint: "Select State",
                              onChanged: _onStateChanged,
                              accentColor: accentColor,
                            ),
                            const SizedBox(height: 18),
                            _buildLabel("City", accentColor),
                            _buildDropdown(
                              value: selectedCity,
                              items: selectedState == null
                                  ? []
                                  : (stateCityMap![selectedState] ?? []),
                              hint: "Select City",
                              onChanged: selectedState == null
                                  ? null
                                  : _onCityChanged,
                              accentColor: accentColor,
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isGettingLocation
                                    ? null
                                    : _getCurrentLocation,
                                icon: const Icon(Icons.my_location_rounded),
                                label: Text(
                                  isGettingLocation
                                      ? "Getting Location..."
                                      : currentPosition != null
                                          ? "Location Set 🎯"
                                          : "Get Current Location",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            if (currentPosition != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  "Lat: ${currentPosition!.latitude.toStringAsFixed(5)}, "
                                  "Lng: ${currentPosition!.longitude.toStringAsFixed(5)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: accentColor.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 90,
            right: 24,
            child: FloatingActionButton(
              onPressed: isSubmitting ? null : () async => await _onSubmit(),
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              child: isSubmitting
                  ? const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: color,
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?>? onChanged,
    required Color accentColor,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
    );
  }
}
