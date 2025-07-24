import 'package:flutter/cupertino.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:metal/screens/profile_completion/screen_4.dart';

class AddGenderScreen extends StatefulWidget {
  const AddGenderScreen({super.key});

  @override
  State<AddGenderScreen> createState() => _AddGenderScreenState();
}

String databaseId = '685a90fa0009384c5189';
String bioDataCollectionID = '685aac1d0013a8a6752f';
String userCollectionId = '68616ecc00163ed41e57';
String completionStatusCollectionId = '686777d300169b27b237';

class _AddGenderScreenState extends State<AddGenderScreen> {
  final List<String> genders = ['Male', 'Female'];
  String _selectedGender = 'Male';
  final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: 0);

  bool _isLoading = false; // <-- 1. Add loading state

  Future<void> _submit() async {
    setState(() => _isLoading = true); // <-- 2. Start loading
    try {
      final user = await account.get();
      final userId = user.$id;

      final bioDataDocument = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: bioDataCollectionID,
        queries: [Query.equal('user', userId), Query.select(['\$id'])],
      );

      if (bioDataDocument.documents.isEmpty) {
        throw Exception('Bio data document not found for user');
      }

      String bioDataDocumentID = bioDataDocument.documents[0].$id;

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: bioDataCollectionID,
        documentId: bioDataDocumentID,
        data: {
          'gender': _selectedGender.toLowerCase(),
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
          data: {
            'isGenderAdded': true,
          },
        );
      }

      setState(() => _isLoading = false); // <-- 3. Stop loading before navigation

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AddHobbiesScreen()),
      );
    } catch (e) {
      setState(() => _isLoading = false); // <-- 3. Stop loading on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.black;
    final accentColor = const Color(0xFF6D4B86);

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        title: const Text("Your Gender"),
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
                      "Select your gender",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Let us know your gender to personalize your experience.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black.withOpacity(0.7),
                        fontFamily: 'SF Pro Display',
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
                            "Choose your gender",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: accentColor,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 140,
                            child: CupertinoPicker(
                              scrollController: _controller,
                              itemExtent: 48,
                              onSelectedItemChanged: (index) {
                                setState(() => _selectedGender = genders[index]);
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
                              children: genders
                                  .map(
                                    (g) => Center(
                                      child: Text(
                                        g,
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: g == _selectedGender
                                              ? accentColor
                                              : Colors.black87,
                                          fontWeight: g == _selectedGender
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontFamily: 'SF Pro Display',
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
                              onPressed: _isLoading ? null : _submit, // <-- 4. Disable when loading
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
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 3,
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
