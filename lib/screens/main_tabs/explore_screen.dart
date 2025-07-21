import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _currentProfileIndex = 0;
  int _currentPage = 0;
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String? _jwt;
  bool _fetchingNextBatch = false;
  bool _hasError = false;
  bool _noMoreProfiles = false;
  bool _sendingInvite = false;

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
      return;
    }

    // If not found locally, fetch from server robustly
    await _robustFetchProfiles(page: 0, reset: true);
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

  Future<void> _removeProfileFromLocal(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_profiles.isNotEmpty && index < _profiles.length) {
        _profiles.removeAt(index);
        await prefs.setString(_localProfilesKey, json.encode(_profiles));
        // If all profiles are removed, clear the key
        if (_profiles.isEmpty) {
          await prefs.remove(_localProfilesKey);
        }
      }
    } catch (e) {
      debugPrint('Error removing profile from local: $e');
    }
  }

  Future<void> _fetchProfiles({required int page, bool reset = false}) async {
    // Only fetch if there are no profiles in local storage
    if (_profiles.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _fetchingNextBatch = false;
      });
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

  Future<void> _skipProfile() async {
    if (_profiles.isEmpty) return;

    // Remove the current profile from local storage and memory
    await _removeProfileFromLocal(_currentProfileIndex);

    setState(() {
      if (_currentProfileIndex >= _profiles.length) {
        _currentProfileIndex = 0;
      }
    });

    // If no profiles left, fetch new ones
    if (_profiles.isEmpty && !_fetchingNextBatch) {
      setState(() {
        _isLoading = true;
      });
      await _fetchProfiles(page: _currentPage + 1, reset: true);
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
        const SnackBar(content: Text('Could not send invite: userId missing.')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation sent!')));
        // After sending, remove the current profile from local storage and memory
        await _removeProfileFromLocal(_currentProfileIndex);

        setState(() {
          if (_currentProfileIndex >= _profiles.length) {
            _currentProfileIndex = 0;
          }
        });

        // If no profiles left, fetch new ones
        if (_profiles.isEmpty && !_fetchingNextBatch) {
          setState(() {
            _isLoading = true;
          });
          await _fetchProfiles(page: _currentPage + 1, reset: true);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      debugPrint('Error sending invite: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending invite: $e')));
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
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_noMoreProfiles || _profiles.isEmpty) {
      // Show the special message if no more profiles
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
              'Purple-Y',
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
            children: const [
              Text(
                "No more profiles found.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
              SizedBox(height: 12),
              Padding(
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
            ],
          ),
        ),
      );
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
    // final int? age = biodata['age'] is int
    //     ? biodata['age'] as int
    //     : int.tryParse(biodata['age']?.toString() ?? '');
    final String? gender = biodata['gender']?.toString();
    final String? bio = biodata['bio']?.toString();
    final String? image = profile['primaryImage']?.toString();
    final String? city = location['city']?.toString();
    final String? state = location['state']?.toString();
    final String? country = location['country']?.toString();

    // Get age from dob
    final String? dobString = biodata['dob']?.toString();
    final int? age = _calculateAgeFromDob(dobString);

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
            'Purple-Y',
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
                PhosphorIconsRegular.bell,
                color: Color(0xFF6D4B86),
                size: 22,
              ),
              onPressed: () {},
              splashRadius: 22,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: image != null && image.isNotEmpty
                        ? Image.network(
                            image,
                            width: double.infinity,
                            height: 420,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
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
                  ),
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
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
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
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Center(
                      child: SizedBox(
                        width: 180,
                        child: ElevatedButton(
                          onPressed: _sendingInvite ? null : _sendInvite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4DFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: _sendingInvite
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Send an Invite",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // Skip Button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: ElevatedButton(
                      onPressed: _skipProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.85),
                        foregroundColor: const Color(0xFF8B4DFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        elevation: 0,
                        side: const BorderSide(
                          color: Color(0xFF8B4DFF),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        "Skip",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF8B4DFF),
                        ),
                      ),
                    ),
                  ),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                bio ?? "No bio provided.",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 16.5,
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
                            fontSize: 12,
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
            const SizedBox(height: 24),
            // Location Section
            if ((city != null && city.isNotEmpty) ||
                (state != null && state.isNotEmpty) ||
                (country != null && country.isNotEmpty))
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  if ((city != null && city.isNotEmpty) ||
                      (state != null && state.isNotEmpty))
                    const SizedBox(width: 12),
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
                      child: SizedBox(
                        height: 26,
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
                    ),
                ],
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
