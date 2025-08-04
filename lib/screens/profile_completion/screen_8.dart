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

// Import all ids from .env using String.fromEnvironment
const String databaseId = String.fromEnvironment('DATABASE_ID');
const String completionStatusCollectionId = String.fromEnvironment(
  'COMPLETION_STATUS_COLLECTIONID',
);
const String locationCollectionId = String.fromEnvironment(
  'LOCATION_COLLECTIONID',
);

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
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/cities_states.json');
      } on FlutterError catch (e) {
        setState(() {
          loadError =
              "Resource not found: assets/cities_states.json\n${e.message}";
          isLoadingStates = false;
        });
        return;
      } catch (e) {
        setState(() {
          loadError = "Unexpected error loading resource: $e";
          isLoadingStates = false;
        });
        return;
      }
      Map<String, dynamic> jsonData;
      try {
        jsonData = json.decode(jsonString);
      } catch (e) {
        setState(() {
          loadError = "Invalid JSON format in cities_states.json: $e";
          isLoadingStates = false;
        });
        return;
      }

      // Only keep top-level keys that are String and values that are List<String>
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
    setState(() {
      isGettingLocation = true;
    });

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Native location for Android/iOS
        bool serviceEnabled;
        try {
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        } catch (e) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error checking location services: $e")),
          );
          return;
        }
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled.")),
          );
          try {
            await Geolocator.openLocationSettings();
          } catch (e) {
            // ignore, just inform user
          }
          setState(() => isGettingLocation = false);
          return;
        }

        LocationPermission permission;
        try {
          permission = await Geolocator.checkPermission();
        } catch (e) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error checking location permission: $e")),
          );
          return;
        }
        if (permission == LocationPermission.denied) {
          try {
            permission = await Geolocator.requestPermission();
          } catch (e) {
            setState(() => isGettingLocation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error requesting location permission: $e"),
              ),
            );
            return;
          }
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
                "Location permission permanently denied. Please enable it in settings.",
              ),
            ),
          );
          setState(() => isGettingLocation = false);
          return;
        }

        Position pos;
        try {
          pos =
              await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('Location request timed out. Try again.');
                },
              );
        } on TimeoutException catch (_) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location request timed out. Try again.'),
            ),
          );
          return;
        } on PermissionDeniedException catch (e) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permission denied: $e')),
          );
          return;
        } catch (e) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
          return;
        }

        setState(() {
          currentPosition = pos;
          isGettingLocation = false;
        });
      } else if (Platform.isLinux) {
        // Linux: Use IP-based geolocation as fallback
        http.Response response;
        try {
          response = await http
              .get(Uri.parse('https://ipapi.co/json/'))
              .timeout(const Duration(seconds: 10));
        } on TimeoutException catch (_) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('IP location request timed out.')),
          );
          return;
        } catch (e) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch IP location: $e')),
          );
          return;
        }
        if (response.statusCode == 200) {
          dynamic data;
          try {
            data = json.decode(response.body);
          } catch (e) {
            setState(() => isGettingLocation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid response from IP location service: $e'),
              ),
            );
            return;
          }
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
          } else {
            setState(() => isGettingLocation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Unable to parse coordinates from IP location."),
              ),
            );
            return;
          }
        } else {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Failed to fetch IP location. Status: ${response.statusCode}",
              ),
            ),
          );
          return;
        }
      } else {
        // Fallback for other platforms (web, macOS, windows, etc.)
        http.Response response;
        try {
          response = await http
              .get(Uri.parse('https://ipapi.co/json/'))
              .timeout(const Duration(seconds: 10));
        } on TimeoutException catch (_) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('IP location request timed out.')),
          );
          return;
        } catch (e) {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch IP location: $e')),
          );
          return;
        }
        if (response.statusCode == 200) {
          dynamic data;
          try {
            data = json.decode(response.body);
          } catch (e) {
            setState(() => isGettingLocation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid response from IP location service: $e'),
              ),
            );
            return;
          }
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
          } else {
            setState(() => isGettingLocation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Unable to parse coordinates from IP location."),
              ),
            );
            return;
          }
        } else {
          setState(() => isGettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Failed to fetch IP location. Status: ${response.statusCode}",
              ),
            ),
          );
          return;
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
    if (selectedState == null ||
        selectedCity == null ||
        currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select state, city, and get your location.'),
        ),
      );
      return;
    }

    try {
      final user = await account.get();
      final userId = user.$id;

      try {
        final userLocationDocument = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: locationCollectionId,
          queries: [Query.equal('user', userId)],
        );

        if (userLocationDocument.documents.isNotEmpty) {
          String userLocationDocId = userLocationDocument.documents[0].$id;
          await databases.updateDocument(
            databaseId: databaseId,
            collectionId: locationCollectionId,
            documentId: userLocationDocId,
            data: {
              'country': "India",
              'state': selectedState,
              'city': selectedCity,
              'latitude': currentPosition!.latitude,
              'longitude': currentPosition!.longitude,
            },
          );
        }
        if (userLocationDocument.documents.isEmpty) {
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
        // Update completion status
        final userCompletionStatusDocument = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: completionStatusCollectionId,
          queries: [
            Query.equal('user', userId),
            Query.select(['\$id']),
          ],
        );

        if (userCompletionStatusDocument.documents.isNotEmpty) {
          final documentId = userCompletionStatusDocument.documents[0].$id;
          await databases.updateDocument(
            databaseId: databaseId,
            collectionId: completionStatusCollectionId,
            documentId: documentId,
            data: {'isLocationAdded': true,},
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const IsAnsweredAllQuestionsScreen(),
          ),
        );
      } on AppwriteException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save location: ${e.message ?? e.toString()}',
            ),
          ),
        );
        return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error saving location: $e')),
        );
        return;
      }

      dynamic userCompletionStatusDocument;
      try {
        userCompletionStatusDocument = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: completionStatusCollectionId,
          queries: [
            Query.equal('user', userId),
            Query.select(['\$id']),
          ],
        );
      } on AppwriteException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch completion status: ${e.message ?? e.toString()}',
            ),
          ),
        );
        return;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error fetching completion status: $e'),
          ),
        );
        return;
      }

      if (userCompletionStatusDocument.documents.isNotEmpty) {
        final documentId = userCompletionStatusDocument.documents[0].$id;
        try {
          await databases.updateDocument(
            databaseId: databaseId,
            collectionId: completionStatusCollectionId,
            documentId: documentId,
            data: {'isLocationAdded': true,},
          );
        } on AppwriteException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update completion status: ${e.message ?? e.toString()}',
              ),
            ),
          );
          return;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unexpected error updating completion status: $e'),
            ),
          );
          return;
        }
      }
    } catch (e, stack) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unexpected error: $e\n$stack')));
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
          child: SingleChildScrollView(
            child: Text(
              loadError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (stateCityMap == null || stateCityMap!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: Text(
            "No state/city data available.",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final states = stateCityMap!.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Add your location",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Let us know where you are! Add your state, city, and set your current location to get relevant matches and content.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Country
                              Text(
                                "Country",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  country,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // State
                              Text(
                                "State",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedState,
                                items: states
                                    .map(
                                      (state) => DropdownMenuItem(
                                        value: state,
                                        child: Text(state),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _onStateChanged,
                                decoration: _inputDecoration(
                                  "Select State",
                                  accentColor,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 18),
                              // City
                              Text(
                                "City",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedCity,
                                items: selectedState == null
                                    ? []
                                    : (stateCityMap![selectedState] ?? [])
                                          .map(
                                            (city) => DropdownMenuItem(
                                              value: city,
                                              child: Text(city),
                                            ),
                                          )
                                          .toList(),
                                onChanged: selectedState == null
                                    ? null
                                    : _onCityChanged,
                                decoration: _inputDecoration(
                                  "Select City",
                                  accentColor,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 26),
                              // Get location button
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
                                        ? "Location Set"
                                        : "Get Current Location",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
                              const SizedBox(height: 36),
                              const SizedBox(height: 60), // Spacer
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // FAB
          Positioned(
            bottom: 90,
            right: 24,
            child: FloatingActionButton(
              onPressed: () async {
                await _onSubmit();
              },
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.arrow_forward_rounded, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, Color accentColor) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[100],
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
