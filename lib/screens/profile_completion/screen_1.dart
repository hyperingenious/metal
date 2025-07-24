import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:intl/intl.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:metal/screens/profile_completion/screen_2.dart';

class AddDobAndNameScreen extends StatefulWidget {
  const AddDobAndNameScreen({super.key});

  @override
  State<AddDobAndNameScreen> createState() => _AddDobAndNameScreenState();
}

class _AddDobAndNameScreenState extends State<AddDobAndNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false; // <-- Add this line

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

  String databaseId = '685a90fa0009384c5189';
  String bioDataCollectionID = '685aac1d0013a8a6752f';
  String userCollectionId = '68616ecc00163ed41e57';
  String completionStatusCollectionId = '686777d300169b27b237';
  String preferenceCollectionID = '685ab0ab0009a8b2d795';

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      setState(() => _isLoading = true); // <-- Start loading
      try {
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
          collectionId: bioDataCollectionID,
          queries: [Query.equal('user', userId)],
        );

        final prefeDoc = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: preferenceCollectionID,
          queries: [
            Query.equal('user', userId),
            Query.select(['\$id']),
          ],
        );

        if (prefeDoc.documents.isEmpty) {
          await databases.createDocument(
            databaseId: databaseId,
            collectionId: preferenceCollectionID,
            documentId: ID.unique(),
            data: {'user': userId,},
          );
        }

        if (userBioDataDocument.total == 0) {
          await databases.createDocument(
            databaseId: databaseId,
            collectionId: bioDataCollectionID,
            documentId: ID.unique(),
            data: {'user': userId, 'dob': dob},
          );
        }

        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: userCollectionId,
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
      } finally {
        setState(() => _isLoading = false); // <-- Stop loading
      }
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
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Let’s know you better",
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
                onPressed: _isLoading ? null : _submit, // <-- Disable when loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 2,
                ),
                icon: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
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
