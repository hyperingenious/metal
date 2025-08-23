import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_5.dart';
import 'package:lushh/services/config_service.dart';

// Import all IDs using ConfigService
final databaseId = ConfigService().get('DATABASE_ID');
final completionStatusCollectionId = ConfigService().get('COMPLETION_STATUS_COLLECTIONID');
final hobbiesCollectionID = ConfigService().get('HOBBIES_COLLECTIONID');
final bioDataCollectionID = ConfigService().get('BIODATA_COLLECTIONID');

class AddHobbiesScreen extends StatefulWidget {
  const AddHobbiesScreen({super.key});

  @override
  State<AddHobbiesScreen> createState() => _AddHobbiesScreenState();
}

class _AddHobbiesScreenState extends State<AddHobbiesScreen> {
  List<Map<String, dynamic>> allHobbies = [];
  final List<String> selectedHobbyIds = [];
  bool _loading = true;
  bool _isSubmitting = false; // Add this line

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to fetch hobbies: $e")));
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

    setState(() {
      _isSubmitting = true; // Add this line
    });

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
    } finally {
      setState(() {
        _isSubmitting = false; // Add this line
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF9B5DE5);
    final gradientStart = const Color(0xFF9B5DE5);
    final gradientEnd = const Color(0xFFF15BB5);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FF),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Hero header
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [gradientStart, gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Select Your Hobbies 💜",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Pick up to 5 that best describe your vibe.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main content card
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: allHobbies.map((hobby) {
                                final hobbyId = hobby['id'] as String;
                                final hobbyName = hobby['name'] as String;
                                final isSelected =
                                    selectedHobbyIds.contains(hobbyId);
                                return ChoiceChip(
                                  label: Text(
                                    hobbyName,
                                    style: TextStyle(
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
                                  labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color: isSelected
                                          ? accentColor
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  elevation: isSelected ? 4 : 0,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit, // Update this line
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 4,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: _isSubmitting // Update this line
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text("Continue"),
                              ),
                            ),
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
}
