import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/phone_input_screen.dart';
import 'package:lushh/services/config_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import Appwrite IDs using ConfigService
final databaseId = ConfigService().get('DATABASE_ID');
final preferenceCollectionID = ConfigService().get('PREFERENCE_COLLECTIONID');
final settingsCollectionID = ConfigService().get('SETTINGS_COLLECTIONID');

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

  // Colors
  static const _primaryColor = Color(0xFF8B4DFF);
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _bgColor = Color(0xFFFAFAFC);

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
        queries: [Query.equal('user', userId)],
      );

      // If no settings document exists, create one
      if (settingsDoc.documents.isEmpty) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: settingsCollectionID,
          documentId: 'unique()',
          data: {'isIncognito': false, 'isHideName': false, 'user': userId},
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
            content: Text("Could not find your profile data. Please try again."),
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
        SnackBar(content: Text("Error: ${e.message ?? 'Unknown error'}")),
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
        SnackBar(content: Text("Failed to save: $e")),
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
    if (_loading || _saving) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: CircularProgressIndicator(
            color: _primaryColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Compact Header
            _buildHeader(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Privacy Section
                      _buildSectionLabel('Privacy'),
                      const SizedBox(height: 12),
                      _buildToggleItem(
                        icon: PhosphorIconsRegular.eyeSlash,
                        title: 'Hide name',
                        subtitle: 'Show only first letter',
                        value: _hideName,
                        onChanged: (val) {
                          setState(() => _hideName = val);
                          _saveToggleSettings();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildToggleItem(
                        icon: PhosphorIconsRegular.detective,
                        title: 'Incognito mode',
                        subtitle: 'Browse anonymously',
                        value: _incognitoMode,
                        onChanged: (val) {
                          setState(() => _incognitoMode = val);
                          _saveToggleSettings();
                        },
                      ),
                      const SizedBox(height: 32),
                      // Discovery Section
                      _buildSectionLabel('Discovery'),
                      const SizedBox(height: 16),
                      _buildSliderSection(
                        title: 'Age range',
                        value: '${_minAge ?? 22} – ${_maxAge ?? 30}',
                        child: SliderTheme(
                          data: _sliderTheme,
                          child: RangeSlider(
                            values: RangeValues(
                              (_minAge ?? minAllowedAge).toDouble(),
                              (_maxAge ?? maxAllowedAge).toDouble(),
                            ),
                            min: minAllowedAge.toDouble(),
                            max: maxAllowedAge.toDouble(),
                            onChanged: (values) {
                              setState(() {
                                _minAge = values.start.round();
                                _maxAge = values.end.round();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSliderSection(
                        title: 'Maximum distance',
                        value: '${_maxDistance ?? 10} km',
                        child: SliderTheme(
                          data: _sliderTheme,
                          child: Slider(
                            value: (_maxDistance ?? minDistance).toDouble(),
                            min: minDistance.toDouble(),
                            max: maxDistance.toDouble(),
                            onChanged: (value) {
                              setState(() {
                                _maxDistance = value.round();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Account Section
                      _buildSectionLabel('Account'),
                      const SizedBox(height: 12),
                      _buildActionItem(
                        icon: PhosphorIconsRegular.signOut,
                        title: 'Log out',
                        onTap: _logout,
                      ),
                      const SizedBox(height: 8),
                      _buildActionItem(
                        icon: PhosphorIconsRegular.trash,
                        title: 'Delete account',
                        isDestructive: true,
                        onTap: () {
                          // TODO: Implement delete account
                        },
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
    );
  }

  SliderThemeData get _sliderTheme => SliderThemeData(
        activeTrackColor: _primaryColor,
        inactiveTrackColor: _primaryColor.withOpacity(0.15),
        thumbColor: _primaryColor,
        overlayColor: _primaryColor.withOpacity(0.1),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
      );

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                PhosphorIconsRegular.arrowLeft,
                color: _textPrimary,
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (_isEdited)
            GestureDetector(
              onTap: _saveSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 52), // Balance the header
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: _textSecondary.withOpacity(0.7),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: _textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: _primaryColor,
              activeTrackColor: _primaryColor.withOpacity(0.3),
              inactiveThumbColor: _textSecondary.withOpacity(0.4),
              inactiveTrackColor: _textSecondary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection({
    required String title,
    required String value,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : _textPrimary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(
              PhosphorIconsRegular.caretRight,
              color: _textSecondary.withOpacity(0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
