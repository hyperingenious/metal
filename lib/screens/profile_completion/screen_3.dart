import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_4.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lushh/services/config_service.dart';

// Import all IDs and keys using ConfigService
final appwriteEndpoint = ConfigService().get('APPWRITE_ENDPOINT');
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final biodataCollectionId = ConfigService().get('BIODATA_COLLECTIONID');
final blockedCollectionId = ConfigService().get('BLOCKED_COLLECTIONID');
final completionStatusCollectionId = ConfigService().get('COMPLETION_STATUS_COLLECTIONID');
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');
final hasShownCollectionId = ConfigService().get('HAS_SHOWN_COLLECTIONID');
final hobbiesCollectionId = ConfigService().get('HOBBIES_COLLECTIONID');
final imageCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');
final messageInboxCollectionId = ConfigService().get('MESSAGE_INBOX_COLLECTIONID');
final messagesCollectionId = ConfigService().get('MESSAGES_COLLECTIONID');
final notificationsCollectionId = ConfigService().get('NOTIFICATIONS_COLLECTIONID');
final preferenceCollectionId = ConfigService().get('PREFERENCE_COLLECTIONID');
final reportsCollectionId = ConfigService().get('REPORTS_COLLECTIONID');
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID');

class AddGenderScreen extends StatefulWidget {
  const AddGenderScreen({super.key});

  @override
  State<AddGenderScreen> createState() => _AddGenderScreenState();
}

class _AddGenderScreenState extends State<AddGenderScreen> {
  String? _selectedGender;
  String _selectedProfession = 'Student';
  final TextEditingController _professionNameController =
      TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;

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

    setState(() => _isLoading = true);

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

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        documentId: bioDataDocumentID,
        data: {
          'gender': _selectedGender!.toLowerCase(),
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
      setState(() => _isLoading = false);
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
    final primaryGradient = const LinearGradient(
      colors: [Color(0xFFa855f7), Color(0xFFec4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final textPrimary = const Color(0xFF1F2937);
    final textSecondary = const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FD),
      appBar: AppBar(
        title: const Text(
          "Let’s get to know you ❤️",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                "We’ll match you better when you share a few details 😉",
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionCard(
                icon: PhosphorIconsRegular.genderIntersex,
                title: "Who are you?",
                subtitle: "Pick what feels right for you 💖",
                child: Row(
                  children: [
                    Expanded(child: _buildGenderOption('Male')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildGenderOption('Female')),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildSectionCard(
                icon: PhosphorIconsRegular.briefcase,
                title: "What do you do?",
                subtitle: "Your vibe attracts your tribe ✨",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _professions
                          .map((p) => _buildProfessionOption(p))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _professionNameController,
                      label: "Profession Name",
                      hint: "e.g. Software Engineer",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildSectionCard(
                icon: PhosphorIconsRegular.user,
                title: "Share your vibe",
                subtitle: "Write something fun about yourself 😄",
                child: _buildTextField(
                  controller: _bioController,
                  label: "About Me",
                  hint: "I love sunsets, coffee, and spontaneous trips...",
                  maxLength: 150,
                  maxLines: 4,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "Continue ",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFa855f7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), // Increased from 16 to 24 for more rounded corners
          border: Border.all(
            color: isSelected
                ? const Color(0xFFa855f7)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              gender == 'Male'
                  ? PhosphorIconsRegular.genderMale
                  : PhosphorIconsRegular.genderFemale,
              color: isSelected ? const Color(0xFFa855f7) : const Color(0xFF6B7280),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              gender,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: isSelected ? const Color(0xFFa855f7) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionOption(String profession) {
    final isSelected = _selectedProfession == profession;
    return GestureDetector(
      onTap: () => setState(() => _selectedProfession = profession),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFa855f7), Color(0xFFec4899)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFFa855f7).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Text(
          profession,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            color: isSelected ? Colors.white : const Color(0xFFa855f7),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Color(0xFFa855f7),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: const Color(0xFFa855f7).withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: const Color(0xFFa855f7).withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFa855f7), width: 2),
        ),
        counterStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Color(0xFFa855f7),
        ),
      ),
    );
  }
}
