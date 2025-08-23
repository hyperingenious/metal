import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/main_tabs/components/explore_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:math'; // Added for distance calculation
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lushh/widgets/expandable_prompts.dart';
import 'package:lushh/services/config_service.dart';
import 'package:lushh/screens/main_tabs/components/bio_section.dart';
import 'package:lushh/screens/main_tabs/components/interests_section.dart';
import 'package:lushh/screens/main_tabs/components/details_section.dart';
import 'package:lushh/screens/main_tabs/components/primary_gradient_button.dart';
import 'package:lushh/screens/main_tabs/components/additional_images_section.dart';
import 'package:lushh/screens/main_tabs/components/swipeable_profile_card.dart';
import 'package:lushh/constants/prompt_questions.dart';

// Replace environment variables with ConfigService
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');
final updateNowCollectionId = ConfigService().get('UPDATE_NOW_COLLECTIONID');

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

  // Scroll controller for scrolling to top
  final ScrollController _scrollController = ScrollController();

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
    _checkForUpdates(); // Add update check
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

  @override
  void dispose() {
    _swipeController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      // Fetch distance for the first profile after profiles are loaded
      _fetchAndSetDistance();
      // Preload next batch in background
      _preloadNextProfiles();
      // Also update the cache in the background with latest data
      _updateCacheInBackground(page: _currentPage);
      return;
    }

    // If not found locally, fetch from server robustly
    await _robustFetchProfiles(page: 0, reset: true);
    // Fetch distance for the first profile after profiles are loaded
    _fetchAndSetDistance();
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
          // No longer filter out profiles with existing connections
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

        final bool emptyProfiles = profilesList.isEmpty;

        if (!emptyProfiles) {
          final List<Map<String, dynamic>> newProfiles =
              List<Map<String, dynamic>>.from(
                profilesList.map((e) => Map<String, dynamic>.from(e)),
              );

          // No longer filter out profiles with existing connections before caching
          // Save to local storage
          await _saveProfilesToLocal(newProfiles, page);
          // If user is still on this page, update UI with new data
          if (mounted && page == _currentPage) {
            setState(() {
              _profiles = newProfiles;
              _currentProfileIndex = 0;
            });
          }
        } else {
          // Server returned empty profiles, but don't update UI state here
          // since this is background cache update
          debugPrint('Server returned empty profiles in background update');
        }
      }
    } catch (e) {
      debugPrint('Error updating cache in background: $e');
    }
  }

  Future<void> _fetchProfiles({required int page, bool reset = false}) async {
    // Always fetch new profiles if reset is true or local stack is empty
    if (!reset && _profiles.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _fetchingNextBatch = false;
      });
      // Fetch distance for the first profile after profiles are loaded
      _fetchAndSetDistance();
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

        List<dynamic> profilesList = [];
        if (data is Map<String, dynamic> && data.containsKey('profiles')) {
          profilesList = data['profiles'] ?? [];
        }

        final bool emptyProfiles = profilesList.isEmpty;

        if (!emptyProfiles) {
          // Server returned profiles, use them
          setState(() {
            _profiles = List<Map<String, dynamic>>.from(
              profilesList.map((e) => Map<String, dynamic>.from(e)),
            );
            _currentProfileIndex = 0;
            _currentPage = page;
            _isLoading = false;
            _noMoreProfiles = false;
            _fetchingNextBatch = false;
            _hasError = false;
          });
          // Save to local storage as soon as you fetch
          _saveProfilesToLocal(_profiles, _currentPage);
        } else {
          // Server returned empty profiles, check if we have cached profiles
          final cachedProfiles = await _loadProfilesFromLocal();
          if (cachedProfiles) {
            // We have cached profiles, use them
            setState(() {
              _isLoading = false;
              _noMoreProfiles = false;
              _fetchingNextBatch = false;
              _hasError = false;
            });
          } else {
            // No cached profiles either, show no more profiles
            setState(() {
              _noMoreProfiles = true;
              _isLoading = false;
              _profiles = [];
              _fetchingNextBatch = false;
              _hasError = false;
            });
          }
        }

        // Fetch distance for the first profile after profiles are loaded
        _fetchAndSetDistance();
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
        final bool emptyProfiles = profilesList.isEmpty;
        if (!emptyProfiles) {
          _preloadedProfiles = List<Map<String, dynamic>>.from(
            profilesList.map((e) => Map<String, dynamic>.from(e)),
          );
        } else {
          // Server returned empty profiles for preloading, but don't update UI state
          // since this is just preloading and current profiles should still be available
          debugPrint('Server returned empty profiles for preloading');
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
        // Success - Remove profile from cache and current list
        await _removeProfileFromCache(receiverUserId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invitation sent!',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );

        // Scroll to top after successful invitation
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }

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

  /// Remove profile from cache by userId
  Future<void> _removeProfileFromCache(String userId) async {
    try {
      // Remove from current profiles list
      setState(() {
        _profiles.removeWhere(
          (profile) => profile['userId']?.toString() == userId,
        );
      });

      // Remove from preloaded profiles
      _preloadedProfiles.removeWhere(
        (profile) => profile['userId']?.toString() == userId,
      );

      // Update local storage cache
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_localProfilesKey);
      if (profilesJson != null) {
        final List<dynamic> decoded = json.decode(profilesJson);
        final List<Map<String, dynamic>> cachedProfiles = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // Remove the profile from cached list
        cachedProfiles.removeWhere(
          (profile) => profile['userId']?.toString() == userId,
        );

        // Save updated cache back to local storage
        await prefs.setString(_localProfilesKey, json.encode(cachedProfiles));
      }
    } catch (e) {
      debugPrint('Error removing profile from cache: $e');
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
        databaseId: databaseId,
        collectionId: locationCollectionId,
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

  // Add update checking methods
  Future<void> _checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch update info from Appwrite
      final documents = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: updateNowCollectionId,
        queries: [Query.limit(1)],
      );

      final updateData = documents.documents.first.data;
      final latestVersion = updateData['latest_version']?.toString();
      final updateLink = updateData['updateLink']?.toString();
      final forceUpdate = updateData['force_update'] == true;

      if (latestVersion == null || updateLink == null) {
        return;
      }

      // Compare versions
      if (_compareVersions(currentVersion, latestVersion) < 0) {
        if (mounted) {
          _showUpdateDialog(
            currentVersion,
            latestVersion,
            updateLink,
            forceUpdate,
          );
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    // Pad with zeros if needed
    while (v1Parts.length < v2Parts.length) v1Parts.add(0);
    while (v2Parts.length < v1Parts.length) v2Parts.add(0);

    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] < v2Parts[i]) return -1;
      if (v1Parts[i] > v2Parts[i]) return 1;
    }
    return 0;
  }

  void _showUpdateDialog(
    String currentVersion,
    String latestVersion,
    String updateLink,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Update icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4DFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsBold.arrowUp,
                    color: Color(0xFF8B4DFF),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  forceUpdate ? 'Update Required' : 'Update Available',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Color(0xFF3B2357),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'A new version is available',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: const Color(0xFF6D4B86).withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Version info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF8B4DFF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: const Color(0xFF6D4B86).withOpacity(0.7),
                            ),
                          ),
                          Text(
                            currentVersion,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF3B2357),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B4DFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.arrowRight,
                          color: Color(0xFF8B4DFF),
                          size: 16,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Latest',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: const Color(0xFF6D4B86).withOpacity(0.7),
                            ),
                          ),
                          Text(
                            latestVersion,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF3B2357),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final uri = Uri.parse(updateLink);
                        final success = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (success && !forceUpdate) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        print('Error launching update link: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(PhosphorIconsBold.download, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Update Now',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Dismiss button (only for non-force updates)
                if (!forceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Remind me later',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: const Color(0xFF6D4B86).withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F6FA), Color(0xFFECE9F1)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B4DFF).withOpacity(0.3),
                        const Color(0xFF8B4DFF).withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B4DFF),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Finding amazing people...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Color(0xFF3B2357),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F6FA), Color(0xFFECE9F1)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.wifiSlash,
                      color: Color(0xFF8B4DFF),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Oops! Something went wrong",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: Color(0xFF3B2357),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "We couldn't load profiles right now. Please check your connection and try again.",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      color: Color(0xFF6D4B86),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B4DFF), Color(0xFFA855FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B4DFF).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        await _robustFetchProfiles(page: 0, reset: true);
                        _preloadNextProfiles();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsBold.arrowClockwise,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Try Again",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Only show "no more profiles" when we've confirmed no profiles from both local and server
    if (_noMoreProfiles && _profiles.isEmpty && !_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B4DFF), Color(0xFFECE9F1)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modern App Bar
                ExploreAppBar(
  canUndo: _profileHistory.isNotEmpty,
  onUndo: _undoLastSkip,
  onSettings: () {
    Navigator.pushNamed(context, '/settings');
  },
),
                // Content
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.userCircle,
                              color: Color(0xFF8B4DFF),
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "You've seen everyone!",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              color: Color(0xFF3B2357),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Try expanding your age range or distance in settings to discover more amazing people.",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              fontSize: 16,
                              color: Color(0xFF6D4B86),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    final String? image =
        (profile['images'] != null && profile['images'].isNotEmpty)
        ? profile['images'][0].toString()
        : null;
    final List<String> additionalImages = (profile['images'] != null)
        ? List<String>.from(profile['images'].skip(1).map((e) => e.toString()))
        : [];

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

    // Get prompts data
    final List<dynamic> promptsRaw = profile['prompts'] is List
        ? profile['prompts'] as List
        : [];
    List<Map<String, dynamic>> promptAnswers = [];

    if (promptsRaw.isNotEmpty && gender != null) {
      final questions = gender.toLowerCase() == 'male'
    ? maleQuestions
    : femaleQuestions;

      for (int i = 0; i < 7 && i < promptsRaw.length; i++) {
        final answer = promptsRaw[i];
        if (answer != null &&
            answer.toString().isNotEmpty &&
            answer.toString() != 'null') {
          promptAnswers.add({
            'question': questions[i]['question'],
            'answer': answer.toString(),
          });
        }
      }
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F6FA), Color(0xFFECE9F1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern App Bar with floating effect
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B4DFF), Color(0xFFA855FF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Lushh',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_profileHistory.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B4DFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.arrowUUpLeft,
                            color: Color(0xFF8B4DFF),
                            size: 22,
                          ),
                          onPressed: _undoLastSkip,
                          tooltip: "Back",
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D4B86).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          PhosphorIconsRegular.gearSix,
                          color: Color(0xFF6D4B86),
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(fontFamily: 'Poppins'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Profile Card with enhanced design
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
                            if (velocity.abs() > 200 || _dragDx.abs() > 80) {
                              setState(() {
                                _isSwiping = true;
                              });
                              final isLeft = (_dragDx < 0) || (velocity < 0);
                              final double endRotation = isLeft ? -0.21 : 0.21;

                              _swipeAnimation =
                                  Tween<Offset>(
                                    begin: Offset(_dragDx / screenWidth, 0),
                                    end: Offset(isLeft ? -2.0 : 2.0, 0.4),
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _swipeController,
                                      curve: Curves.easeOut,
                                    ),
                                  );
                              _swipeRotationAnimation =
                                  Tween<double>(
                                    begin: (_dragDx / screenWidth) * 0.21,
                                    end: endRotation,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _swipeController,
                                      curve: Curves.easeOut,
                                    ),
                                  );
                              _swipeController.forward();
                            } else {
                              _swipeAnimation =
                                  Tween<Offset>(
                                    begin: Offset(_dragDx / screenWidth, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _swipeController,
                                      curve: Curves.easeOut,
                                    ),
                                  );
                              _swipeRotationAnimation =
                                  Tween<double>(
                                    begin: (_dragDx / screenWidth) * 0.21,
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
                                offset = Offset(_dragDx / screenWidth, 0);
                                rotation = (_dragDx / screenWidth) * 0.21;
                              }
                              return Transform.translate(
                                offset: Offset(
                                  offset.dx * screenWidth,
                                  offset.dy * screenHeight * 0.15,
                                ),
                                child: Transform.rotate(
                                  angle: rotation,
                                  child: child,
                                ),
                              );
                            },
                            child: SwipeableProfileCard(
  image: image,
  name: name,
  age: age,
  professionType: professionType,
  professionSubtype: professionSubtype,
  sendingInvite: _sendingInvite,
  onInvite: _sendInvite,
  onSwipe: () => _onSwipeLeftOrRight(removeWithAnimation: false),
  showFetchingBadge: _fetchingNextBatch,
),
                          ),
                        ),

                        // Enhanced Bio Section
                        BioSection(bio: bio),

                        // Enhanced Interests Section
InterestsSection(hobbies: hobbies),
                        // Enhanced Details Section
                        DetailsSection(
                          heightDisplay: heightDisplay,
                          city: city,
                          state: state,
                          country: country,
                          distanceKm: _distanceKm,
                          distanceLoading: _distanceLoading,
                          distanceError: _distanceError,
                        ),
                        // Additional Images Section
                                              if (additionalImages.isNotEmpty)
  AdditionalImagesSection(
    images: additionalImages,
    screenHeight: screenHeight,
    insertAfterIndexOne:
        promptAnswers.isNotEmpty ? ExpandablePrompts(prompts: promptAnswers) : null,
  ),
if (additionalImages.length < 2 && promptAnswers.isNotEmpty)
  ExpandablePrompts(prompts: promptAnswers), 
                                                const SizedBox(height: 24),

                        // Enhanced Action Button
PrimaryGradientButton(
  text: _sendingInvite ? 'Sending Love...' : 'Send Love ✨',
  icon: _sendingInvite ? null : PhosphorIconsBold.heart,
  loading: _sendingInvite,
  onPressed: _sendingInvite ? null : _sendInvite,
),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}