import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_3.dart';

// Import all variables using String.fromEnvironment
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

class AddHeightScreen extends StatefulWidget {
  const AddHeightScreen({super.key});

  @override
  State<AddHeightScreen> createState() => _AddHeightScreenState();
}

class _AddHeightScreenState extends State<AddHeightScreen> {
  int _selectedHeight = 170;
  final FixedExtentScrollController _controller = FixedExtentScrollController(
    initialItem: 40,
  ); // 130 + 40 = 170
  bool _isLoading = false;

  final List<int> heightList = List.generate(121, (i) => 130 + i); // 130–250 cm

  Future<void> _submit() async {
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
        data: {'height': _selectedHeight},
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
          data: {'isHeightAdded': true},
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AddGenderScreen()),
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
  Widget build(BuildContext context) {
    final themeColor = Colors.black;
    final accentColor = const Color(0xFF6D4B86);

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        title: Text(
          "Your Height",
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: themeColor,
        elevation: 0.5,
      ),
      body: SafeArea(
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
                      "Add your height",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "How tall are you? This helps us personalize your experience.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Card-like container
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            "Select your height",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 180,
                            child: CupertinoPicker(
                              scrollController: _controller,
                              itemExtent: 48,
                              onSelectedItemChanged: (index) {
                                setState(
                                  () => _selectedHeight = heightList[index],
                                );
                              },
                              selectionOverlay: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: accentColor.withOpacity(0.2),
                                      width: 2,
                                    ),
                                    bottom: BorderSide(
                                      color: accentColor.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              children: heightList
                                  .map(
                                    (h) => Center(
                                      child: Text(
                                        '$h cm',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: h == _selectedHeight
                                              ? accentColor
                                              : Colors.black87,
                                          fontWeight: h == _selectedHeight
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text("Continue"),
                            ),
                          ),
                          const SizedBox(height: 12),
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
    );
  }
}
