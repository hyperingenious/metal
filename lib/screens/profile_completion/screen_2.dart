import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_3.dart';
import 'package:lushh/services/config_service.dart';

// Environment variables using ConfigService
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

class AddHeightScreen extends StatefulWidget {
  const AddHeightScreen({super.key});

  @override
  State<AddHeightScreen> createState() => _AddHeightScreenState();
}

class _AddHeightScreenState extends State<AddHeightScreen> {
  static const Color accentColor = Color(0xFF6D4B86);

  int _selectedHeight = 170;
  bool _isLoading = false;
  final FixedExtentScrollController _controller = FixedExtentScrollController(initialItem: 40);

  final List<int> heightList = List.generate(121, (i) => 130 + i); // 130–250 cm

  Future<void> _submit() async {
    if (_isLoading) return; // prevent double-tap
    setState(() => _isLoading = true);

    try {
      final user = await account.get();
      final userId = user.$id;

      final bioDataDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        queries: [Query.equal('user', userId), Query.select(['\$id'])],
      );
      if (bioDataDocs.documents.isEmpty) {
        throw Exception('Could not find your profile data.');
      }

      final bioId = bioDataDocs.documents.first.$id;
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        documentId: bioId,
        data: {'height': _selectedHeight},
      );

      final completionDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: completionStatusCollectionId,
        queries: [Query.equal('user', userId), Query.select(['\$id'])],
      );
      if (completionDocs.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: completionStatusCollectionId,
          documentId: completionDocs.documents.first.$id,
          data: {'isHeightAdded': true},
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AddGenderScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffafafa),
      appBar: AppBar(
        title: const Text(
          "Your Height",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add your height",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                "How tall are you? This helps us personalize your experience.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
                  child: Column(
                    children: [
                      const Text(
                        "Select your height",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: accentColor),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: CupertinoPicker(
                          scrollController: _controller,
                          itemExtent: 48,
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedHeight = heightList[index]);
                          },
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: accentColor.withOpacity(0.25), width: 2),
                                bottom: BorderSide(color: accentColor.withOpacity(0.25), width: 2),
                              ),
                            ),
                          ),
                          children: heightList.map((h) {
                            final isSelected = h == _selectedHeight;
                            return AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 20,
                                color: isSelected ? accentColor : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              child: Text('$h cm'),
                            );
                          }).toList(),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  "Continue",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
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
    );
  }
}
