import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/phone_input_screen.dart';

// Import Appwrite IDs from .env using String.fromEnvironment
const String databaseId = String.fromEnvironment('DATABASE_ID');
const String preferenceCollectionID = String.fromEnvironment(
  'PREFERENCE_COLLECTIONID',
);
const String settingsCollectionID = String.fromEnvironment(
  'SETTINGS_COLLECTIONID',
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Hide name switch
  bool _hideName = false;
  bool _incognitoMode = false;

  // Age range
  final int minAllowedAge = 18;
  final int maxAllowedAge = 60;
  int? _initialMinAge;
  int? _initialMaxAge;
  int? _minAge;
  int? _maxAge;

  // Max distance
  final int minDistance = 1;
  final int maxDistance = 100;
  int? _initialMaxDistance;
  int? _maxDistance;

  // Loading state
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = await account.get();
      final userId = user.$id;

      // First, check if settings document exists
      final settingsDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: settingsCollectionID,
        queries: [
          Query.equal('user', userId),
        ],
      );

      // If no settings document exists, create one
      if (settingsDoc.documents.isEmpty) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: settingsCollectionID,
          documentId: 'unique()',
          data: {
            'isIncognito': false,
            'isHideName': false,
            'user': userId,
          },
        );
      } else {
        // Load existing settings
        final doc = settingsDoc.documents[0];
        setState(() {
          _hideName = doc.data['isHideName'] ?? false;
          _incognitoMode = doc.data['isIncognito'] ?? false;
        });
      }

      // Now fetch preferences
      await _fetchInitialSettings();
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to initialize settings: $e")),
      );
    }
  }

  Future<void> _fetchInitialSettings() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = await account.get();
      final userId = user.$id;

      final prefeDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: preferenceCollectionID,
        queries: [
          Query.equal('user', userId),
          Query.select(['min_age', 'max_age', 'max_distance_km']),
        ],
      );

      if (prefeDoc.documents.isNotEmpty) {
        final doc = prefeDoc.documents[0];
        final minAge = (doc.data['min_age'] ?? 22) as int;
        final maxAge = (doc.data['max_age'] ?? 30) as int;
        final maxDist = (doc.data['max_distance_km'] ?? 10) as int;

        setState(() {
          _initialMinAge = minAge;
          _initialMaxAge = maxAge;
          _minAge = minAge;
          _maxAge = maxAge;
          _initialMaxDistance = maxDist;
          _maxDistance = maxDist;
          _loading = false;
        });
      } else {
        // Defaults if not found
        setState(() {
          _initialMinAge = 22;
          _initialMaxAge = 30;
          _minAge = 22;
          _maxAge = 30;
          _initialMaxDistance = 10;
          _maxDistance = 10;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load settings: $e")));
    }
  }

  bool get _isEdited {
    return (_minAge != _initialMinAge) ||
        (_maxAge != _initialMaxAge) ||
        (_maxDistance != _initialMaxDistance);
  }

  Future<void> _saveSettings() async {
    if (!_isEdited) return;
    setState(() {
      _saving = true;
    });
    try {
      final user = await account.get();
      final userId = user.$id;

      final prefeDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: preferenceCollectionID,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (prefeDoc.documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Could not find your profile data. Please try again.",
            ),
          ),
        );
        setState(() {
          _saving = false;
        });
        return;
      }

      final prefDocId = prefeDoc.documents[0].$id;

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: preferenceCollectionID,
        documentId: prefDocId,
        data: {
          'min_age': _minAge,
          'max_age': _maxAge,
          'max_distance_km': _maxDistance,
        },
      );

      setState(() {
        _initialMinAge = _minAge;
        _initialMaxAge = _maxAge;
        _initialMaxDistance = _maxDistance;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved!")),
      );
    } on AppwriteException catch (e) {
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Appwrite error: ${e.message ?? 'Unknown error'}"),
        ),
      );
    } catch (e) {
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred: $e")),
      );
    }
  }

  Future<void> _saveToggleSettings() async {
    try {
      final user = await account.get();
      final userId = user.$id;

      final settingsDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: settingsCollectionID,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (settingsDoc.documents.isNotEmpty) {
        final docId = settingsDoc.documents[0].$id;
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: settingsCollectionID,
          documentId: docId,
          data: {
            'isIncognito': _incognitoMode,
            'isHideName': _hideName,
            'user': userId,
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save toggle settings: $e")),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logout failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF6D4B86);

    // Replace MainLoader with centered CircularProgressIndicator
    if (_loading || _saving) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: accentColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3B2357)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF3B2357),
          ),
        ),
        actions: [
          if (_isEdited && !_saving)
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF3B2357),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(
              color: Color(0xFFBFA2D9),
              height: 1,
              thickness: 1,
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hide name',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: Color(0xFF3B2357),
                        ),
                      ),
                      Switch(
                        value: _hideName,
                        onChanged: (val) {
                          setState(() {
                            _hideName = val;
                          });
                          _saveToggleSettings(); // Save immediately when changed
                        },
                        activeColor: const Color(0xFF3B2357),
                        inactiveThumbColor: const Color(0xFFBFA2D9),
                        inactiveTrackColor: const Color(0xFFE5D3F3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When enabled, only the first letter of your name will be visible to others',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Incognito mode',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: Color(0xFF3B2357),
                        ),
                      ),
                      Switch(
                        value: _incognitoMode,
                        onChanged: (val) {
                          setState(() {
                            _incognitoMode = val;
                          });
                          _saveToggleSettings(); // Save immediately when changed
                        },
                        activeColor: const Color(0xFF3B2357),
                        inactiveThumbColor: const Color(0xFFBFA2D9),
                        inactiveTrackColor: const Color(0xFFE5D3F3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your profile will be hidden from others and you won't appear in recommendations. You can still browse anonymously",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 40,
            ), // More space after toggle switches
            // Age Range Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "How old are they?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF Pro Display',
                      color: Color(0xFF3B2357),
                    ),
                  ),
                  const SizedBox(height: 12), // More space after heading
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ), // Slightly more padding
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Between ${_minAge ?? ''} and ${_maxAge ?? ''}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF3B2357),
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentColor,
                      inactiveTrackColor: accentColor.withOpacity(0.2),
                      thumbColor: accentColor,
                      overlayColor: accentColor.withOpacity(0.15),
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: RangeSlider(
                      values: RangeValues(
                        (_minAge ?? minAllowedAge).toDouble(),
                        (_maxAge ?? maxAllowedAge).toDouble(),
                      ),
                      min: minAllowedAge.toDouble(),
                      max: maxAllowedAge.toDouble(),
                      activeColor: accentColor,
                      inactiveColor: accentColor.withOpacity(0.2),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _minAge = values.start.round();
                          _maxAge = values.end.round();
                          if (_minAge! > _maxAge!) {
                            final temp = _minAge;
                            _minAge = _maxAge;
                            _maxAge = temp;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // More space between sections
            // Max Distance Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "How far away are they?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF Pro Display',
                      color: Color(0xFF3B2357),
                    ),
                  ),
                  const SizedBox(height: 12), // More space after heading
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ), // Slightly more padding
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Up to ${_maxDistance ?? ''} kilometres away",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF3B2357),
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentColor,
                      inactiveTrackColor: accentColor.withOpacity(0.2),
                      thumbColor: accentColor,
                      overlayColor: accentColor.withOpacity(0.15),
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: Slider(
                      value: (_maxDistance ?? minDistance).toDouble(),
                      min: minDistance.toDouble(),
                      max: maxDistance.toDouble(),
                      divisions: maxDistance - minDistance,
                      onChanged: (value) {
                        setState(() {
                          _maxDistance = value.round();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120), // More space before save button
            // Remove the Save Button section entirely
            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3B2357),
                    width: 1,
                  ),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF3B2357),
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    _logout();
                  },
                  icon: const Icon(Icons.logout, size: 20, color: Color(0xFF3B2357)),
                  label: const Text('Log out'),
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ), // Better spacing before delete account
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Implement delete account logic
                },
                child: const Text(
                  'Delete account',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32), // More bottom padding
          ],
        ),
      ),
    );
  }
}
