import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:intl/intl.dart';
import 'package:lushh/screens/profile_completion/screen_2.dart';
import 'package:lushh/services/config_service.dart';

// Environment constants using ConfigService
final appwriteEndpoint = ConfigService().get('APPWRITE_ENDPOINT');
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final biodataCollectionId = ConfigService().get('BIODATA_COLLECTIONID');
final blockedCollectionId = ConfigService().get('BLOCKED_COLLECTIONID');
final completionStatusCollectionId = ConfigService().get(
  'COMPLETION_STATUS_COLLECTIONID',
);
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');
final hasShownCollectionId = ConfigService().get('HAS_SHOWN_COLLECTIONID');
final hobbiesCollectionId = ConfigService().get('HOBBIES_COLLECTIONID');
final imageCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');
final messageInboxCollectionId = ConfigService().get(
  'MESSAGE_INBOX_COLLECTIONID',
);
final messagesCollectionId = ConfigService().get('MESSAGES_COLLECTIONID');
final notificationsCollectionId = ConfigService().get(
  'NOTIFICATIONS_COLLECTIONID',
);
final preferenceCollectionId = ConfigService().get('PREFERENCE_COLLECTIONID');
final reportsCollectionId = ConfigService().get('REPORTS_COLLECTIONID');
final settingsCollectionId = ConfigService().get('SETTINGS_COLLECTIONID');
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID');

// Appwrite setup (unchanged)
final client = Client()
  ..setEndpoint(appwriteEndpoint)
  ..setProject(projectId)
  ..setSelfSigned(status: true);

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
    final picked = await showDatePicker(
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
              onSurface: Colors.black87,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Name: $name\nDOB: $dob")));

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

      final settingsDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: settingsCollectionId,
        queries: [Query.equal('user', userId)],
      );

      if (settingsDoc.documents.isEmpty) {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: settingsCollectionId,
          documentId: ID.unique(),
          data: {'isIncognito': false, 'isHideName': false, 'user': userId},
        );
      }

      final userBioDataDocument = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        queries: [Query.equal('user', userId)],
      );

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
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: completionStatusCollectionId,
          documentId: userCompletionStatusDocument.documents[0].$id,
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
      backgroundColor: const Color(0xfffafafa),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Let's know you better",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const Text(
                "Please provide your full name and date of birth to continue.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Full Name",
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.deepPurple,
                              ),
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
                                      ? Colors.black87
                                      : Colors.grey,
                                  fontWeight: _selectedDate != null
                                      ? FontWeight.w500
                                      : FontWeight.w400,
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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text(
                    _isLoading ? "Loading..." : "Continue",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
