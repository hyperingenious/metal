import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:math'; // Added for distance calculation

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  int _currentProfileIndex = 0;
  int _currentPage = 0;
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String? _jwt;
  bool _fetchingNextBatch = false;
  bool _hasError = false;
  bool _noMoreProfiles = false;
  bool _sendingInvite = false;

  // Preload buffer for next batch
  List<Map<String, dynamic>> _preloadedProfiles = [];
  bool _preloading = false;

  // Animation for swipe
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _swipeRotationAnimation;
  bool _isSwiping = false;
  double _dragDx = 0.0;

  // For undo/Back functionality
  final List<int> _profileHistory = [];

  // For distance calculation
  double? _distanceKm;
  bool _distanceLoading = false;
  String? _distanceError;

  // Use different keys for different OS for native localstorage separation
  static String get _localProfilesKey {
    if (Platform.isIOS) return 'explore_profiles_ios';
    if (Platform.isAndroid) return 'explore_profiles_android';
    return 'explore_profiles';
  }

  static String get _localPageKey {
    if (Platform.isIOS) return 'explore_profiles_page_ios';
    if (Platform.isAndroid) return 'explore_profiles_page_android';
    return 'explore_profiles_page';
  }

  @override
  void initState() {
    super.initState();
    _initAndFetchProfiles();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
    _swipeRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
    _swipeController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        // After animation, move to next profile (do not remove from list)
        await _onSwipeLeftOrRight(removeWithAnimation: false);
        _swipeController.reset();
        setState(() {
          _isSwiping = false;
          _dragDx = 0.0;
        });
      }
    });
    // Fetch distance for the first profile after profiles are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSetDistance();
    });
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchAndSetDistance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchAndSetDistance();
  }

  /// Robustly fetches JWT and then fetches profiles, always ensuring a fresh JWT is used.
  Future<void> _robustFetchProfiles({int page = 0, bool reset = true}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _fetchingNextBatch = false;
      _noMoreProfiles = false;
    });
    try {
      final jwt = await account.createJWT();
      _jwt = jwt.jwt;
      await _fetchProfiles(page: page, reset: reset);
    } on AppwriteException catch (e) {
      debugPrint('AppwriteException: ${e.message}');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _fetchingNextBatch = false;
      });
    } catch (e) {
      debugPrint('Unexpected error: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _fetchingNextBatch = false;
      });
    }
  }

  Future<void> _initAndFetchProfiles() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _noMoreProfiles = false;
    });

    // Try to load from local storage first
    final localLoaded = await _loadProfilesFromLocal();
    if (localLoaded) {
      setState(() {
        _isLoading = false;
      });
      // Preload next batch in background
      _preloadNextProfiles();
      // Also update the cache in the background with latest data
      _updateCacheInBackground(page: _currentPage);
      return;
    }

    // If not found locally, fetch from server robustly
    await _robustFetchProfiles(page: 0, reset: true);
    // Preload next batch in background
    _preloadNextProfiles();
  }

  Future<bool> _loadProfilesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_localProfilesKey);
      final page = prefs.getInt(_localPageKey) ?? 0;
      if (profilesJson != null) {
        final List<dynamic> decoded = json.decode(profilesJson);
        final List<Map<String, dynamic>> loadedProfiles = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (loadedProfiles.isNotEmpty) {
          setState(() {
            _profiles = loadedProfiles;
            _currentProfileIndex = 0;
            _currentPage = page;
          });
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error loading profiles from local: $e');
    }
    return false;
  }

  Future<void> _saveProfilesToLocal(
    List<Map<String, dynamic>> profiles,
    int page,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localProfilesKey, json.encode(profiles));
      await prefs.setInt(_localPageKey, page);
    } catch (e) {
      debugPrint('Error saving profiles to local: $e');
    }
  }

  // New: Update the cache in the background with latest data for the current page
  Future<void> _updateCacheInBackground({int page = 0}) async {
    try {
      // Ensure JWT is available
      if (_jwt == null) {
        final jwt = await account.createJWT();
        _jwt = jwt.jwt;
      }
      final response = await http.get(
        Uri.parse(
          'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/profiles/random-simple',
        ),
        headers: {
          'Authorization': 'Bearer $_jwt',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> profilesList = [];
        if (data is List && data.isNotEmpty) {
          profilesList = data;
        } else if (data is Map<String, dynamic> &&
            data.containsKey('profiles')) {
          profilesList = data['profiles'] ?? [];
        }

        if (profilesList.isNotEmpty) {
          final List<Map<String, dynamic>> newProfiles =
              List<Map<String, dynamic>>.from(
                profilesList.map((e) => Map<String, dynamic>.from(e)),
              );
          // Save to local storage
          await _saveProfilesToLocal(newProfiles, page);
          // If user is still on this page, update UI with new data
          if (mounted && page == _currentPage) {
            setState(() {
              _profiles = newProfiles;
              _currentProfileIndex = 0;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating cache in background: $e');
    }
  }

  // No longer remove profile from local on skip
  Future<void> _removeProfileFromLocal(int index) async {
    // No-op for skip/undo logic
  }

  Future<void> _fetchProfiles({required int page, bool reset = false}) async {
    // Always fetch new profiles if reset is true or local stack is empty
    if (!reset && _profiles.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _fetchingNextBatch = false;
      });
      // Also update the cache in the background with latest data
      _updateCacheInBackground(page: page);
      return;
    }

    if (_jwt == null) {
      await _robustFetchProfiles(page: page, reset: reset);
      return;
    }
    setState(() {
      _fetchingNextBatch = true;
      _hasError = false;
      _noMoreProfiles = false;
    });
    try {
      final response = await http.get(
        Uri.parse(
          'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/profiles/random-simple',
        ),
        headers: {
          'Authorization': 'Bearer $_jwt',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        bool emptyProfiles = false;
        List<dynamic> profilesList = [];

        if (data is List && data.isEmpty) {
          emptyProfiles = true;
        } else if (data is Map<String, dynamic>) {
          if (data.isEmpty) {
            emptyProfiles = true;
          } else if (data.length == 1 &&
              data.values.first is List &&
              (data.values.first as List).isEmpty) {
            emptyProfiles = true;
          } else if (data.containsKey('profiles')) {
            profilesList = data['profiles'] ?? [];
            if (profilesList.isEmpty) {
              emptyProfiles = true;
            }
          }
        }

        setState(() {
          if (!emptyProfiles && profilesList.isNotEmpty) {
            _profiles = List<Map<String, dynamic>>.from(
              profilesList.map((e) => Map<String, dynamic>.from(e)),
            );
            _currentProfileIndex = 0;
            _currentPage = page;
            _isLoading = false;
            _noMoreProfiles = false;
            // Save to local storage as soon as you fetch
            _saveProfilesToLocal(_profiles, _currentPage);
          } else {
            _noMoreProfiles = true;
            _isLoading = false;
          }
          _fetchingNextBatch = false;
          _hasError = false;
        });

        // Also update the cache in the background with latest data
        _updateCacheInBackground(page: page);
      } else {
        debugPrint('Failed to fetch profiles: ${response.body}');
        setState(() {
          _hasError = true;
          _isLoading = false;
          _fetchingNextBatch = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _fetchingNextBatch = false;
      });
    }
  }

  /// Preload the next batch of profiles in the background
  Future<void> _preloadNextProfiles() async {
    if (_preloading || _preloadedProfiles.isNotEmpty) return;
    _preloading = true;
    try {
      // Ensure JWT is available
      if (_jwt == null) {
        final jwt = await account.createJWT();
        _jwt = jwt.jwt;
      }
      final response = await http.get(
        Uri.parse(
          'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/profiles/random-simple',
        ),
        headers: {
          'Authorization': 'Bearer $_jwt',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> profilesList = [];
        if (data is List && data.isNotEmpty) {
          profilesList = data;
        } else if (data is Map<String, dynamic> &&
            data.containsKey('profiles')) {
          profilesList = data['profiles'] ?? [];
        }
        if (profilesList.isNotEmpty) {
          _preloadedProfiles = List<Map<String, dynamic>>.from(
            profilesList.map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error preloading profiles: $e');
    }
    _preloading = false;
  }

  // Instead of removing, just move to next profile and keep history for undo
  Future<void> _onSwipeLeftOrRight({bool removeWithAnimation = true}) async {
    if (_profiles.isEmpty) return;

    setState(() {
      // Save current index to history for undo
      _profileHistory.add(_currentProfileIndex);
      // Move to next profile
      if (_currentProfileIndex < _profiles.length - 1) {
        _currentProfileIndex++;
      } else {
        // If at end, try to load more or show no more profiles
        if (_preloadedProfiles.isNotEmpty) {
          _profiles = List<Map<String, dynamic>>.from(_preloadedProfiles);
          _preloadedProfiles.clear();
          _currentProfileIndex = 0;
          _isLoading = false;
          _noMoreProfiles = false;
          // Also update the cache in the background for the new page
          _updateCacheInBackground(page: _currentPage + 1);
        } else if (_noMoreProfiles && _profiles.isNotEmpty) {
          // Loop infinitely through local stack
          _currentProfileIndex = 0;
        } else {
          // If no preloaded profiles, fetch new ones from server
          _isLoading = true;
          _fetchProfiles(page: _currentPage + 1, reset: true).then((_) {
            _preloadNextProfiles();
          });
        }
      }
    });

    // If after moving, we are at the end of the stack (no more profiles), fetch new ones
    if (_currentProfileIndex >= _profiles.length) {
      setState(() {
        _isLoading = true;
      });
      await _fetchProfiles(page: _currentPage + 1, reset: true);
      await _preloadNextProfiles();
      return;
    }

    // Preload if near end
    if (_profiles.length - _currentProfileIndex <= 2 &&
        !_preloading &&
        _preloadedProfiles.isEmpty) {
      _preloadNextProfiles();
    }
    // Update distance after profile index changes
    _fetchAndSetDistance();
  }

  // Undo last skip
  void _undoLastSkip() {
    if (_profileHistory.isNotEmpty) {
      setState(() {
        _currentProfileIndex = _profileHistory.removeLast();
      });
      _fetchAndSetDistance();
    }
  }

  Future<void> _sendInvite() async {
    if (_profiles.isEmpty || _sendingInvite) return;

    setState(() {
      _sendingInvite = true;
    });

    final profile = _profiles[_currentProfileIndex];
    final String? receiverUserId = profile['userId']?.toString();

    if (receiverUserId == null || receiverUserId.isEmpty) {
      setState(() {
        _sendingInvite = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send invite: userId missing.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      );
      return;
    }

    try {
      // Ensure JWT is available
      if (_jwt == null) {
        final jwt = await account.createJWT();
        _jwt = jwt.jwt;
      }

      final response = await http.post(
        Uri.parse(
          'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/notification/invitations/send',
        ),
        headers: {
          'Authorization': 'Bearer $_jwt',
          'Content-Type': 'application/json',
        },
        body: json.encode({'receiverUserId': receiverUserId}),
      );

      if (response.statusCode == 200) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invitation sent!',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );
        // After sending, move to next profile (do not remove from list)
        setState(() {
          _profileHistory.add(_currentProfileIndex);
          if (_currentProfileIndex < _profiles.length - 1) {
            _currentProfileIndex++;
          } else {
            if (_preloadedProfiles.isNotEmpty) {
              _profiles = List<Map<String, dynamic>>.from(_preloadedProfiles);
              _preloadedProfiles.clear();
              _currentProfileIndex = 0;
              _isLoading = false;
              _noMoreProfiles = false;
              // Also update the cache in the background for the new page
              _updateCacheInBackground(page: _currentPage + 1);
            } else {
              _isLoading = true;
              _fetchProfiles(page: _currentPage + 1, reset: true).then((_) {
                _preloadNextProfiles();
              });
            }
          }
        });

        // If after moving, we are at the end of the stack (no more profiles), fetch new ones
        if (_currentProfileIndex >= _profiles.length) {
          setState(() {
            _isLoading = true;
          });
          await _fetchProfiles(page: _currentPage + 1, reset: true);
          await _preloadNextProfiles();
          return;
        }

        // Preload if near end
        if (_profiles.length - _currentProfileIndex <= 2 &&
            !_preloading &&
            _preloadedProfiles.isEmpty) {
          _preloadNextProfiles();
        }
      } else {
        // Error from server
        String errorMsg = 'Failed to send invite.';
        try {
          final data = json.decode(response.body);
          if (data is Map && data['error'] != null) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending invite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error sending invite: $e',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      );
    } finally {
      setState(() {
        _sendingInvite = false;
      });
    }
  }

  /// Helper to calculate age from dob string (format: 2005-10-17T00:00:00.000+00:00)
  int? _calculateAgeFromDob(String? dobString) {
    if (dobString == null || dobString.isEmpty) return null;
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }

  // Helper to get icon for profession type
  IconData _getProfessionIcon(String? professionType) {
    switch (professionType?.toLowerCase()) {
      case 'student':
        return Icons.school;
      case 'engineer':
        return Icons.engineering;
      case 'designer':
        return Icons.brush;
      case 'doctor':
        return Icons.local_hospital;
      case 'artist':
        return Icons.palette;
      case 'other':
        return Icons.work_outline;
      default:
        return Icons.work_outline;
    }
  }

  Future<void> _fetchAndSetDistance() async {
    if (_profiles.isEmpty || _currentProfileIndex >= _profiles.length) return;
    setState(() {
      _distanceLoading = true;
      _distanceError = null;
    });
    try {
      // Get current user id
      final user = await account.get();
      final String currentUserId = user.$id;
      // Fetch current user's location from Appwrite
      final locationDocs = await databases.listDocuments(
        databaseId: '685a90fa0009384c5189',
        collectionId: '685fe47700022b8331dc',
        queries: [Query.equal('user', currentUserId)],
      );
      if (locationDocs.documents.isEmpty) {
        setState(() {
          _distanceError = 'Your location is not set.';
          _distanceLoading = false;
        });
        return;
      }
      final myLoc = locationDocs.documents.first.data;
      final double? myLat = (myLoc['latitude'] is num)
          ? (myLoc['latitude'] as num).toDouble()
          : double.tryParse(myLoc['latitude']?.toString() ?? '');
      final double? myLng = (myLoc['longitude'] is num)
          ? (myLoc['longitude'] as num).toDouble()
          : double.tryParse(myLoc['longitude']?.toString() ?? '');
      if (myLat == null || myLng == null) {
        setState(() {
          _distanceError = 'Your location is invalid.';
          _distanceLoading = false;
        });
        return;
      }
      // Get profile's location
      final profile = _profiles[_currentProfileIndex];


      final location = profile['location'] is Map<String, dynamic>
          ? profile['location']
          : <String, dynamic>{};
      final double? profLat = (location['latitude'] is num)
          ? (location['latitude'] as num).toDouble()
          : double.tryParse(location['latitude']?.toString() ?? '');
      final double? profLng = (location['longitude'] is num)
          ? (location['longitude'] as num).toDouble()
          : double.tryParse(location['longitude']?.toString() ?? '');
      if (profLat == null || profLng == null) {
        setState(() {
          _distanceError = 'Profile location is invalid.';
          _distanceLoading = false;
        });
        return;
      }
      // Calculate distance
      final double dist = _calculateDistanceKm(myLat, myLng, profLat, profLng);
      setState(() {
        _distanceKm = dist;
        _distanceLoading = false;
        _distanceError = null;
      });
    } catch (e) {
      setState(() {
        _distanceError = 'Failed to get distance.';
        _distanceLoading = false;
      });
    }
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371; // Earth radius in km
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Failed to load profiles.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _robustFetchProfiles(page: 0, reset: true);
                  _preloadNextProfiles();
                },
                child: const Text(
                  "Retry",
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if ((_noMoreProfiles && _profiles.isEmpty) || _profiles.isEmpty) {
      // Show the special message if no more profiles and nothing in local
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: const Text(
              'Metal',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF2D1B3A),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.gearSix,
                  color: Color(0xFF6D4B86),
                  size: 22,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                splashRadius: 22,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "No more profiles found.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  "Try expanding your min/max age or max distance in settings.",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: Color(0xFF6D4B86),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_preloading)
                const Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      );
    }

    // Defensive: If index is out of range, loop back to start if we have profiles
    if (_currentProfileIndex >= _profiles.length) {
      if (_noMoreProfiles && _profiles.isNotEmpty) {
        // Loop infinitely through local stack
        setState(() {
          _currentProfileIndex = 0;
        });
      } else {
        // This should not happen, but if it does, fetch new profiles
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          setState(() {
            _isLoading = true;
          });
          await _fetchProfiles(page: _currentPage + 1, reset: true);
          await _preloadNextProfiles();
        });
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        );
      }
    }

    final profile = _profiles[_currentProfileIndex];
    final biodata = profile['biodata'] is Map<String, dynamic>
        ? profile['biodata']
        : <String, dynamic>{};
    final location = profile['location'] is Map<String, dynamic>
        ? profile['location']
        : <String, dynamic>{};
    final hobbies = profile['hobbies'] is List
        ? profile['hobbies'] as List
        : <dynamic>[];
    final user = biodata['user'] is Map<String, dynamic>
        ? biodata['user']
        : <String, dynamic>{};
    final String name = user['name']?.toString() ?? 'Unknown';
    final String? gender = biodata['gender']?.toString();
    final String? bio = biodata['bio']?.toString();
    final String? image = profile['primaryImage']?.toString();
    final String? city = location['city']?.toString();
    final String? state = location['state']?.toString();
    final String? country = location['country']?.toString();

    // Get age from dob
    final String? dobString = biodata['dob']?.toString();
    final int? age = _calculateAgeFromDob(dobString);

    // Get profession info
    final String? professionType = biodata['profession_name']?.toString();
    final String? professionSubtype = biodata['sub_type']?.toString();

    // Get height in cm from biodata
    final dynamic heightValue = biodata['height'];
    String? heightDisplay;
    if (heightValue != null) {
      if (heightValue is num) {
        heightDisplay = "${heightValue.toString()} cm";
      } else if (heightValue is String && heightValue.trim().isNotEmpty) {
        heightDisplay = "${heightValue.trim()} cm";
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: const Text(
            'Metal',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Color(0xFF2D1B3A),
            ),
          ),
          actions: [
            if (_profileHistory.isNotEmpty)
              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.arrowUUpLeft,
                  color: Colors.black,
                  size: 28,
                ),
                onPressed: _undoLastSkip,
                splashRadius: 22,
                tooltip: "Back",
              ),
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.gearSix,
                color: Color(0xFF6D4B86),
                size: 22,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              splashRadius: 22,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Poppins'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card with swipe functionality and animation
              GestureDetector(
                onHorizontalDragStart: (details) {
                  if (_isSwiping) return;
                  setState(() {
                    _dragDx = 0.0;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  if (_isSwiping) return;
                  setState(() {
                    _dragDx += details.delta.dx;
                  });
                },
                onHorizontalDragEnd: (details) {
                  if (_isSwiping) return;
                  final velocity = details.primaryVelocity ?? 0.0;
                  // Only consider a swipe if the velocity or drag distance is significant
                  if (velocity.abs() > 200 || _dragDx.abs() > 80) {
                    setState(() {
                      _isSwiping = true;
                    });
                    // Animate off screen in the swipe direction
                    final isLeft = (_dragDx < 0) || (velocity < 0);

                    // For a tilted swipe, we animate both translation and rotation.
                    // We'll rotate a bit (e.g. 12 degrees) in the direction of the swipe.
                    final double endRotation = isLeft
                        ? -0.21
                        : 0.21; // ~12 degrees in radians

                    _swipeAnimation =
                        Tween<Offset>(
                          begin: Offset(
                            _dragDx / MediaQuery.of(context).size.width,
                            0,
                          ),
                          end: Offset(
                            isLeft ? -2.0 : 2.0,
                            0.4,
                          ), // add a bit of vertical movement
                        ).animate(
                          CurvedAnimation(
                            parent: _swipeController,
                            curve: Curves.easeOut,
                          ),
                        );
                    _swipeRotationAnimation =
                        Tween<double>(
                          begin:
                              (_dragDx / MediaQuery.of(context).size.width) *
                              0.21,
                          end: endRotation,
                        ).animate(
                          CurvedAnimation(
                            parent: _swipeController,
                            curve: Curves.easeOut,
                          ),
                        );
                    _swipeController.forward();
                  } else {
                    // Animate back to center
                    _swipeAnimation =
                        Tween<Offset>(
                          begin: Offset(
                            _dragDx / MediaQuery.of(context).size.width,
                            0,
                          ),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _swipeController,
                            curve: Curves.easeOut,
                          ),
                        );
                    _swipeRotationAnimation =
                        Tween<double>(
                          begin:
                              (_dragDx / MediaQuery.of(context).size.width) *
                              0.21,
                          end: 0.0,
                        ).animate(
                          CurvedAnimation(
                            parent: _swipeController,
                            curve: Curves.easeOut,
                          ),
                        );
                    _swipeController.forward().then((_) {
                      setState(() {
                        _dragDx = 0.0;
                        _isSwiping = false;
                      });
                    });
                  }
                },
                child: AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, child) {
                    Offset offset;
                    double rotation;
                    if (_isSwiping) {
                      offset = _swipeAnimation.value;
                      rotation = _swipeRotationAnimation.value;
                    } else {
                      offset = Offset(
                        _dragDx / MediaQuery.of(context).size.width,
                        0,
                      );
                      rotation =
                          (_dragDx / MediaQuery.of(context).size.width) * 0.21;
                    }
                    return Transform.translate(
                      offset: Offset(
                        offset.dx * MediaQuery.of(context).size.width,
                        offset.dy * MediaQuery.of(context).size.height * 0.15,
                      ),
                      child: Transform.rotate(angle: rotation, child: child),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // --- Begin: Image with bottom gradient overlay ---
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: Stack(
                              children: [
                                image != null && image.isNotEmpty
                                    ? Image.network(
                                        image,
                                        width: double.infinity,
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.8,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  width: double.infinity,
                                                  height: 420,
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                      )
                                    : Container(
                                        width: double.infinity,
                                        height: 420,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.person,
                                          size: 80,
                                          color: Colors.white,
                                        ),
                                      ),
                                // Gradient overlay at the bottom
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.transparent,
                                            Color.fromARGB(
                                              120,
                                              0,
                                              0,
                                              0,
                                            ), // semi-transparent black
                                            Color.fromARGB(
                                              180,
                                              0,
                                              0,
                                              0,
                                            ), // more opaque at very bottom
                                          ],
                                          stops: [0.0, 0.6, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // --- End: Image with bottom gradient overlay ---

                        // Profession at top left of main image (moved from right)
                        if (professionType != null && professionType.isNotEmpty)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF8B4DFF),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getProfessionIcon(professionType),
                                    color: const Color(0xFF8B4DFF),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 7),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        professionType[0].toUpperCase() +
                                            professionType.substring(1),
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF3B2357),
                                        ),
                                      ),
                                      if (professionSubtype != null &&
                                          professionSubtype.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 1.5,
                                          ),
                                          child: Text(
                                            professionSubtype,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12.5,
                                              color: Color(0xFF6D4B86),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Invite circular button just above the name
                        Positioned(
                          left: 16,
                          bottom:
                              120, // Increased from 90 to 120 for more space above the name
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _sendingInvite ? null : _sendInvite,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B4DFF),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _sendingInvite
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            PhosphorIconsBold.userPlus,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Name, gender, age at bottom left
                        Positioned(
                          left: 16,
                          bottom: 32,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 28,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${gender != null && gender.isNotEmpty ? gender[0].toUpperCase() : "?"}, ${age != null ? age : "--"}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 26,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              // Profession Section (removed from here)
                            ],
                          ),
                        ),
                        // Removed the old Invite button from bottom center
                        if (_fetchingNextBatch)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bio Section
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "Bio",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF3B2357),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  bio ?? "No bio provided.",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: Color(0xFF3B2357),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // About me Section
              const Text(
                "About me",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
              const SizedBox(height: 10),
              hobbies.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hobbies.map<Widget>((hobby) {
                        final String hobbyName =
                            hobby is Map && hobby['hobby_name'] != null
                            ? hobby['hobby_name'].toString()
                            : '';
                        final String hobbyCategory =
                            hobby is Map && hobby['hobby_category'] != null
                            ? hobby['hobby_category'].toString()
                            : '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F6FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hobbyName.isNotEmpty
                                ? hobbyName[0].toUpperCase() +
                                      hobbyName.substring(1)
                                : hobbyCategory,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Color(0xFF6D4B86),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  : const Text(
                      "No hobbies listed.",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: Color(0xFF6D4B86),
                      ),
                    ),
              // Height Section (below About me)
              if (heightDisplay != null && heightDisplay.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.ruler,
                      color: Color(0xFF6D4B86),
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      "Height: $heightDisplay",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Color(0xFF3B2357),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              // Location Section
              if ((city != null && city.isNotEmpty) ||
                  (state != null && state.isNotEmpty) ||
                  (country != null && country.isNotEmpty))
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if ((city != null && city.isNotEmpty) ||
                        (state != null && state.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF6D4B86),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Lives in ${city ?? ''}${(city != null && city.isNotEmpty && state != null && state.isNotEmpty) ? ', ' : ''}${state ?? ''}",
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                color: Color(0xFF6D4B86),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (country != null && country.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.place,
                              color: Color(0xFF6D4B86),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "From $country",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                color: Color(0xFF6D4B86),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 32),
              // Additional Images Section
              if (profile['additionalImages'] is List &&
                  (profile['additionalImages'] as List).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...((profile['additionalImages'] as List).map<Widget>((
                      imgUrl,
                    ) {
                      if (imgUrl == null || imgUrl.toString().isEmpty)
                        return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: Image.network(
                              imgUrl.toString(),
                              width: double.infinity,
                              height: MediaQuery.of(context).size.height * 0.8,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: double.infinity,
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.8,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      );
                    })).toList(),
                  ],
                ),
              // Distance Section
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
                child: Builder(
                  builder: (context) {
                    if (_distanceLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (_distanceError != null) {
                      return Center(
                        child: Text(
                          _distanceError!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Color(0xFF6D4B86),
                          ),
                        ),
                      );
                    } else if (_distanceKm != null) {
                      return Align(
                        alignment: Alignment.bottomLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF3B2357),
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Lives ${_distanceKm!.round()} km away',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 24,
                                color: Color(0xFF3B2357),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
