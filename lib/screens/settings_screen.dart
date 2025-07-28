
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:metal/screens/phone_input_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Hide name switch
  bool _hideName = false;

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

  // Appwrite IDs
  final String databaseId = '685a90fa0009384c5189';
  final String preferenceCollectionID = '685ab0ab0009a8b2d795';

  @override
  void initState() {
    super.initState();
    _fetchInitialSettings();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load settings: $e")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logout failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF6D4B86);

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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Color(0xFFBFA2D9), height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 32),
                  child: Row(
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
                        },
                        activeColor: const Color(0xFF3B2357),
                        inactiveThumbColor: const Color(0xFFBFA2D9),
                        inactiveTrackColor: const Color(0xFFE5D3F3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Age Range Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Preferred Age Range",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro Display',
                          color: Color(0xFF3B2357),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${_minAge ?? ''} - ${_maxAge ?? ''} years",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      RangeSlider(
                        values: RangeValues(
                          (_minAge ?? minAllowedAge).toDouble(),
                          (_maxAge ?? maxAllowedAge).toDouble(),
                        ),
                        min: minAllowedAge.toDouble(),
                        max: maxAllowedAge.toDouble(),
                        divisions: maxAllowedAge - minAllowedAge,
                        activeColor: accentColor,
                        inactiveColor: accentColor.withOpacity(0.15),
                        labels: RangeLabels(
                          "${_minAge ?? ''}",
                          "${_maxAge ?? ''}",
                        ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Min: ${_minAge ?? ''}",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          Text(
                            "Max: ${_maxAge ?? ''}",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Max Distance Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Max Preferred Distance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro Display',
                          color: Color(0xFF3B2357),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${_maxDistance ?? ''} km",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accentColor,
                          inactiveTrackColor: accentColor.withOpacity(0.2),
                          thumbColor: accentColor,
                          overlayColor: accentColor.withOpacity(0.15),
                          trackHeight: 5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 13),
                        ),
                        child: Slider(
                          value: (_maxDistance ?? minDistance).toDouble(),
                          min: minDistance.toDouble(),
                          max: maxDistance.toDouble(),
                          divisions: maxDistance - minDistance,
                          label: "${_maxDistance ?? ''} km",
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
                const SizedBox(height: 32),
                // Save Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isEdited && !_saving ? _saveSettings : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF Pro Display',
                        ),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        disabledBackgroundColor: accentColor.withOpacity(0.3),
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text("Save"),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3B2357), width: 1.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 19),
                        textStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        _logout();
                      },
                      icon: const Icon(Icons.logout, size: 22),
                      label: const Text('Log out'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
