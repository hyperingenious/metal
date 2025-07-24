import 'package:flutter/material.dart';

import 'package:metal/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:metal/screens/profile_completion/screen_7.dart';

class AddPreferredMaxDistAndHobbiesScreen extends StatefulWidget {
  const AddPreferredMaxDistAndHobbiesScreen({super.key});

  @override
  State<AddPreferredMaxDistAndHobbiesScreen> createState() =>
      _AddPreferredMaxDistAndHobbiesScreenState();
}

class _AddPreferredMaxDistAndHobbiesScreenState
    extends State<AddPreferredMaxDistAndHobbiesScreen> {
  // Max distance range
  final int minDistance = 1;
  final int maxDistance = 100;
  int _selectedMaxDistance = 10;

  // Hobbies
  List<Map<String, dynamic>> allHobbies = [];
  final List<String> selectedHobbyIds = [];
  bool _loading = true;

  String databaseId = '685a90fa0009384c5189';
  String completionStatusCollectionId = '686777d300169b27b237';
  String preferenceCollectionID = '685ab0ab0009a8b2d795';
  String hobbiesCollectionID = '685acd8b00010dd66e1c';

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

    setState(() {
      _loading = true;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      final prefeDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: preferenceCollectionID,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (prefeDoc.documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Could not find your profile data. Please try again.",
            ),
          ),
        );
        setState(() {
          _loading = false;
        });
        return;
      }

      final prefDocId = prefeDoc.documents[0].$id;

      // Save max distance and hobbies to Appwrite
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: preferenceCollectionID,
        documentId: prefDocId,
        data: {
          'max_distance_km': _selectedMaxDistance,
          'preferred_hobbies': selectedHobbyIds,
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
          data: {'isAddedPreferredMaxDistAndHobbies': true},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preferences saved!")),
      );
      // Navigate to AddImagesScreen after saving preferences
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AddImagesScreen(),
        ),
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
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.black;
    final accentColor = const Color(0xFF6D4B86);

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Preferences",
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: SingleChildScrollView(
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
                            "Set your max preferred distance",
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
                            "Choose how far away you want to see matches (in km).",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black.withOpacity(0.7),
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Distance slider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${_selectedMaxDistance} km",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: accentColor,
                                inactiveTrackColor: accentColor.withOpacity(0.2),
                                thumbColor: accentColor,
                                overlayColor: accentColor.withOpacity(0.15),
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 13),
                              ),
                              child: Slider(
                                value: _selectedMaxDistance.toDouble(),
                                min: minDistance.toDouble(),
                                max: maxDistance.toDouble(),
                                divisions: maxDistance - minDistance,
                                label: "${_selectedMaxDistance} km",
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMaxDistance = value.round();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Hobbies header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Pick up to 5 preferred hobbies",
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
                            "Select hobbies that best match your interests.",
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
                    // Hobbies chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: allHobbies.map((hobby) {
                          final hobbyId = hobby['id'] as String;
                          final hobbyName = hobby['name'] as String;
                          final isSelected = selectedHobbyIds.contains(hobbyId);
                          return ChoiceChip(
                            label: Text(
                              hobbyName,
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isSelected ? Colors.white : accentColor,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => _toggleHobby(hobbyId),
                            selectedColor: accentColor,
                            backgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected
                                    ? accentColor
                                    : Colors.grey.shade300,
                                width: 1.2,
                              ),
                            ),
                            elevation: isSelected ? 2 : 0,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Submit button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit, // Disable when loading
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: 0.1,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
