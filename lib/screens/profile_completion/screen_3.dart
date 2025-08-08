import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_4.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import all IDs and keys using String.fromEnvironment
const appwriteDevKey = String.fromEnvironment('APPWRITE_DEV_KEY');
const appwriteEndpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
const projectId = String.fromEnvironment('PROJECT_ID');
const databaseId = String.fromEnvironment('DATABASE_ID');
const biodataCollectionId = String.fromEnvironment('BIODATA_COLLECTIONID');
const blockedCollectionId = String.fromEnvironment('BLOCKED_COLLECTIONID');
const completionStatusCollectionId = String.fromEnvironment(
  'COMPLETION_STATUS_COLLECTIONID',
);
const connectionsCollectionId = String.fromEnvironment(
  'CONNECTIONS_COLLECTIONID',
);
const hasShownCollectionId = String.fromEnvironment('HAS_SHOWN_COLLECTIONID');
const hobbiesCollectionId = String.fromEnvironment('HOBBIES_COLLECTIONID');
const imageCollectionId = String.fromEnvironment('IMAGE_COLLECTIONID');
const locationCollectionId = String.fromEnvironment('LOCATION_COLLECTIONID');
const messageInboxCollectionId = String.fromEnvironment(
  'MESSAGE_INBOX_COLLECTIONID',
);
const messagesCollectionId = String.fromEnvironment('MESSAGES_COLLECTIONID');
const notificationsCollectionId = String.fromEnvironment(
  'NOTIFICATIONS_COLLECTIONID',
);
const preferenceCollectionId = String.fromEnvironment(
  'PREFERENCE_COLLECTIONID',
);
const reportsCollectionId = String.fromEnvironment('REPORTS_COLLECTIONID');
const usersCollectionId = String.fromEnvironment('USERS_COLLECTIONID');

class AddGenderScreen extends StatefulWidget {
  const AddGenderScreen({super.key});

  @override
  State<AddGenderScreen> createState() => _AddGenderScreenState();
}

class _AddGenderScreenState extends State<AddGenderScreen> {
  String? _selectedGender; // Changed from 'Male' to null
  String _selectedProfession = 'Student';
  final TextEditingController _professionNameController =
      TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;

  // Profession dropdown options
  final List<String> _professions = [
    'Student',
    'Engineer',
    'Designer',
    'Doctor',
    'Artist',
    'Other',
  ];

  Future<void> _submit() async {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_professionNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your profession name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      final bioDataDocument = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (bioDataDocument.documents.isEmpty) {
        throw Exception('Bio data document not found for user');
      }

      String bioDataDocumentID = bioDataDocument.documents[0].$id;

      // Update biodata with all fields
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        documentId: bioDataDocumentID,
        data: {
          'gender': _selectedGender!.toLowerCase(), // Add ! since we validated it's not null
          'profession_type': _selectedProfession,
          'profession_name': _professionNameController.text.trim(),
          'bio': _bioController.text.trim(),
        },
      );

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
          data: {'isGenderAdded': true},
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AddHobbiesScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _professionNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Simple, clean color scheme
    final primaryColor = const Color(0xFF6366F1);
    final primaryDark = const Color(0xFF3B2357);
    final textPrimary = const Color(0xFF1F2937);
    final textSecondary = const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Tell us more...",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 32, 0, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Complete Your Profile",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          fontFamily: 'Poppins',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Help us personalize your experience by sharing a bit about yourself.",
                        style: TextStyle(
                          fontSize: 16,
                          color: textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),

                // Gender Selection Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.genderIntersex,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Gender",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGenderOption(
                              'Male',
                              PhosphorIconsRegular.genderMale,
                              primaryColor,
                              primaryDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildGenderOption(
                              'Female',
                              PhosphorIconsRegular.genderFemale,
                              primaryColor,
                              primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Profession Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.briefcase,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Profession",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _professions.map((profession) {
                          return _buildProfessionOption(
                            profession,
                            primaryColor,
                            primaryDark,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _professionNameController,
                        decoration: InputDecoration(
                          labelText: "Profession Name",
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Bio Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.user,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Bio",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _bioController,
                        maxLength: 150,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: "Tell us about yourself",
                          labelStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          counterStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text("Continue"),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(
    String gender,
    IconData icon,
    Color accentColor,
    Color darkAccentColor,
  ) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? darkAccentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? darkAccentColor : accentColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : accentColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              gender,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : accentColor,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionOption(
    String profession,
    Color accentColor,
    Color darkAccentColor,
  ) {
    final isSelected = _selectedProfession == profession;

    // Get appropriate icon for each profession
    IconData getProfessionIcon(String prof) {
      switch (prof.toLowerCase()) {
        case 'student':
          return PhosphorIconsRegular.graduationCap;
        case 'engineer':
          return PhosphorIconsRegular.gear;
        case 'designer':
          return PhosphorIconsRegular.palette;
        case 'doctor':
          return PhosphorIconsRegular.stethoscope;
        case 'artist':
          return PhosphorIconsRegular.paintBrush;
        case 'other':
          return PhosphorIconsRegular.briefcase;
        default:
          return PhosphorIconsRegular.briefcase;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProfession = profession;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? darkAccentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? darkAccentColor : accentColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getProfessionIcon(profession),
              color: isSelected ? Colors.white : accentColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              profession,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : accentColor,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
