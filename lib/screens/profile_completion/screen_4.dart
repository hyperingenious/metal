import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_5.dart';

// Import all IDs from .env using String.fromEnvironment
const String databaseId = String.fromEnvironment('DATABASE_ID');
const String completionStatusCollectionId = String.fromEnvironment(
  'COMPLETION_STATUS_COLLECTIONID',
);
const String hobbiesCollectionID = String.fromEnvironment(
  'HOBBIES_COLLECTIONID',
);
const String bioDataCollectionID = String.fromEnvironment(
  'BIODATA_COLLECTIONID',
);

class AddHobbiesScreen extends StatefulWidget {
  const AddHobbiesScreen({super.key});

  @override
  State<AddHobbiesScreen> createState() => _AddHobbiesScreenState();
}

class _AddHobbiesScreenState extends State<AddHobbiesScreen> {
  List<Map<String, dynamic>> allHobbies = [];
  final List<String> selectedHobbyIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getHobbies();
  }

  Future<void> _getHobbies() async {
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: hobbiesCollectionID,
        queries: [Query.limit(100)],
      );

      final hobbies = result.documents.map((doc) {
        return {'id': doc.$id, 'name': doc.data['hobby_name'] as String};
      }).toList();

      setState(() {
        allHobbies = hobbies;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to fetch hobbies: $e")));
    }
  }

  void _toggleHobby(String hobbyId) {
    setState(() {
      if (selectedHobbyIds.contains(hobbyId)) {
        selectedHobbyIds.remove(hobbyId);
      } else {
        if (selectedHobbyIds.length < 5) {
          selectedHobbyIds.add(hobbyId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can select up to 5 hobbies')),
          );
        }
      }
    });
  }

  Future<void> _submit() async {
    if (selectedHobbyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least 1 hobby")),
      );
      return;
    }

    try {
      final user = await account.get();
      final userId = user.$id;

      final bioDataDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: bioDataCollectionID,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (bioDataDoc.documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Could not find your profile data. Please try again.",
            ),
          ),
        );
        return;
      }

      final bioDataDocId = bioDataDoc.documents[0].$id;

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: bioDataCollectionID,
        documentId: bioDataDocId,
        data: {'hobbies': selectedHobbyIds},
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
          data: {'isAddedHobbies': true},
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AddMinMaxAgeScreen()),
      );
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Appwrite error: ${e.message ?? 'Unknown error'}"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.black;
    final accentColor = const Color(0xFF6D4B86);

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
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
                            "Select your hobbies",
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
                            "Pick up to 5 hobbies that best describe your interests.",
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
                                  "Choose up to 5 hobbies",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: accentColor,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // Hobbies chips
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: allHobbies.map((hobby) {
                                    final hobbyId = hobby['id'] as String;
                                    final hobbyName = hobby['name'] as String;
                                    final isSelected = selectedHobbyIds
                                        .contains(hobbyId);
                                    return ChoiceChip(
                                      label: Text(
                                        hobbyName,
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (_) => _toggleHobby(hobbyId),
                                      selectedColor: accentColor,
                                      backgroundColor: Colors.grey.shade100,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: isSelected
                                              ? accentColor
                                              : Colors.grey.shade300,
                                          width: 1.2,
                                        ),
                                      ),
                                      elevation: isSelected ? 2 : 0,
                                      pressElevation: 0,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _submit,
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
                                    child: const Text("Continue"),
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
