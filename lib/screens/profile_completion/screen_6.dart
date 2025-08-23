import 'package:flutter/material.dart';

import 'package:lushh/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_7.dart';
import 'package:lushh/services/config_service.dart';

// Import all ids using ConfigService
final databaseId = ConfigService().get('DATABASE_ID');
final completionStatusCollectionId = ConfigService().get('COMPLETION_STATUS_COLLECTIONID');
final preferenceCollectionID = ConfigService().get('PREFERENCE_COLLECTIONID');
final hobbiesCollectionID = ConfigService().get('HOBBIES_COLLECTIONID');

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Preferences saved!")));
      // Navigate to AddImagesScreen after saving preferences
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const AddImagesScreen()));
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
    // styling only — logic unchanged
    final accentColor = const Color(0xFF9B4D96); // match age screen accent
    return Scaffold(
      // full-screen gradient like the age-screen
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D4B86), Color(0xFF9B4D96), Color(0xFFE573A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "Preferences",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Choose how far away you want to see matches (in km).",
                        style: TextStyle(
                          fontSize: 15.5,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 26),

                      // Glassmorphic card — contains both slider + hobbies (keeps flow consistent with age screen)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Distance display + slider
                                const Text(
                                  "Max preferred distance",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "${_selectedMaxDistance} km",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Slider(
                                  value: _selectedMaxDistance.toDouble(),
                                  min: minDistance.toDouble(),
                                  max: maxDistance.toDouble(),
                                  divisions: maxDistance - minDistance,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white.withOpacity(0.3),
                                  label: "${_selectedMaxDistance} km",
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMaxDistance = value.round();
                                    });
                                  },
                                ),
                                const SizedBox(height: 22),

                                // Hobbies section
                                const Text(
                                  "Pick up to 5 preferred hobbies",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: allHobbies.map((hobby) {
                                    final hobbyId = hobby['id'] as String;
                                    final hobbyName = hobby['name'] as String;
                                    final isSelected = selectedHobbyIds.contains(hobbyId);
                                    return GestureDetector(
                                      onTap: () => _toggleHobby(hobbyId),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(isSelected ? 0.0 : 0.25)),
                                        ),
                                        child: Text(
                                          hobbyName,
                                          style: TextStyle(
                                            color: isSelected ? accentColor : Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Continue button styled like age-range screen
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: accentColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 6,
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
