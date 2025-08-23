import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_6.dart';
import 'package:lushh/services/config_service.dart';

// Import IDs using ConfigService
final databaseId = ConfigService().get('DATABASE_ID');
final completionStatusCollectionId = ConfigService().get('COMPLETION_STATUS_COLLECTIONID');
final preferenceCollectionID = ConfigService().get('PREFERENCE_COLLECTIONID');

class AddMinMaxAgeScreen extends StatefulWidget {
  const AddMinMaxAgeScreen({super.key});

  @override
  State<AddMinMaxAgeScreen> createState() => _AddMinMaxAgeScreenState();
}

class _AddMinMaxAgeScreenState extends State<AddMinMaxAgeScreen> {
  // Age range limits
  final int minAllowedAge = 18;
  final int maxAllowedAge = 60;

  // Selected range as integers
  int _minAge = 22;
  int _maxAge = 30;

  bool _loading = false;

  Future<void> _submit() async {
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

      // Save min and max age to Appwrite (as integers)
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: preferenceCollectionID,
        documentId: prefDocId,
        data: {'min_age': _minAge, 'max_age': _maxAge},
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
          data: {'isAddedMinMaxAge': true},
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddPreferredMaxDistAndHobbiesScreen(),
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
        title: const Text("Preferred Age Range"),
        backgroundColor: Colors.white,
        foregroundColor: themeColor,
        elevation: 0.5,
      ),
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
                            "Set your preferred age range",
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
                            "Choose the age range you are interested in for your matches.",
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
                                  "Select age range",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: accentColor,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  "$_minAge - $_maxAge years",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                RangeSlider(
                                  values: RangeValues(
                                    _minAge.toDouble(),
                                    _maxAge.toDouble(),
                                  ),
                                  min: minAllowedAge.toDouble(),
                                  max: maxAllowedAge.toDouble(),
                                  divisions: maxAllowedAge - minAllowedAge,
                                  activeColor: accentColor,
                                  inactiveColor: accentColor.withOpacity(0.15),
                                  labels: RangeLabels("$_minAge", "$_maxAge"),
                                  onChanged: (RangeValues values) {
                                    setState(() {
                                      _minAge = values.start.round();
                                      _maxAge = values.end.round();
                                      if (_minAge > _maxAge) {
                                        final temp = _minAge;
                                        _minAge = _maxAge;
                                        _maxAge = temp;
                                      }
                                    });
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Min: $_minAge",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                    Text(
                                      "Max: $_maxAge",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
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