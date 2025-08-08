import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:intl/intl.dart';
import 'package:lushh/screens/profile_completion/screen_2.dart';

// Import IDs and keys using String.fromEnvironment
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
const settingsCollectionId = String.fromEnvironment('SETTINGS_COLLECTIONID');
const usersCollectionId = String.fromEnvironment('USERS_COLLECTIONID');

final client = Client()
  ..setEndpoint(appwriteEndpoint)
  ..setProject(projectId)
  ..setSelfSigned(status: true)
  ..setDevKey(appwriteDevKey);

final account = Account(client);
final databases = Databases(client);
final storage = Storage(client);
final realtime = Realtime(client);

class AddDobAndNameScreen extends StatefulWidget {
  const AddDobAndNameScreen({super.key});
  @override
  State<AddDobAndNameScreen> createState() => _AddDobAndNameScreenState();
}

class _AddDobAndNameScreenState extends State<AddDobAndNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final name = _nameController.text.trim();
      final dob = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // TODO: Replace this with Appwrite document update logic
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Name: $name\nDOB: $dob")));

      // Check if age is more than 18
      final today = DateTime.now();
      final age =
          today.year -
          _selectedDate!.year -
          ((today.month < _selectedDate!.month ||
                  (today.month == _selectedDate!.month &&
                      today.day < _selectedDate!.day))
              ? 1
              : 0);
      if (age < 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be at least 18 years old.")),
        );
        return;
      }

      final user = await account.get();
      final userId = user.$id;
      final userBioDataDocument = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        queries: [Query.equal('user', userId)],
      );

      final prefeDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: preferenceCollectionId,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (prefeDoc.documents.isEmpty) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: preferenceCollectionId,
          documentId: ID.unique(),
          data: {'user': userId},
        );
      }

      // Create settings document if it doesn't exist
      final settingsDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: settingsCollectionId,
        queries: [
          Query.equal('user', userId),
        ],
      );

      if (settingsDoc.documents.isEmpty) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: settingsCollectionId,
          documentId: ID.unique(),
          data: {
            'isIncognito': false,
            'isHideName': false,
            'user': userId,
          },
        );
      }

      if (userBioDataDocument.total == 0) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: biodataCollectionId,
          documentId: ID.unique(),
          data: {'user': userId, 'dob': dob},
        );
      }

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
        data: {'name': name},
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
          data: {'isAddedDOBAndName': true},
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AddHeightScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all details")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 40, // Add status bar height + extra space
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Let's know you better",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? "Please enter your name"
                        : null,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate != null
                                ? DateFormat(
                                    'MMMM d, yyyy',
                                  ).format(_selectedDate!)
                                : "Select Date of Birth",
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Remove the old continue button here
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // New Continue button at bottom right
          Positioned(
            bottom: 24,
            right: 24,
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 2,
                ),
                icon: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.arrow_forward, color: Colors.white),
                label: _isLoading
                    ? const Text(
                        "Loading...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
