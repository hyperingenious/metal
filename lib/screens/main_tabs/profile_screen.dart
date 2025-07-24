import 'package:flutter/material.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:metal/widgets/profile_edi_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userId;
  String? name;
  String? dob;
  String? gender;
  List<String> hobbies = [];
  List<String> images = [];
  bool isLoading = true;

  String? college;
  String? email;

  // New fields from biodata
  String? bio;
  String? professionType;
  String? professionName;
  int? heightCm;

  String? errorMessage;
  String? debugError; // For debugging

  // For cache
  static const String _profileCacheKey = 'profile_cache_v1';

  @override
  void initState() {
    super.initState();
    _loadProfileFromCache().then((_) {
      // Always fetch in background and update UI if changed
      _fetchProfileData();
    });
  }

  Future<void> _loadProfileFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileCacheKey);
    if (cached != null) {
      try {
        final data = json.decode(cached);
        setState(() {
          userId = data['userId'] as String?;
          name = data['name'] as String?;
          dob = data['dob'] as String?;
          gender = data['gender'] as String?;
          hobbies = (data['hobbies'] as List?)?.cast<String>() ?? [];
          images = (data['images'] as List?)?.cast<String>() ?? [];
          college = data['college'] as String?;
          email = data['email'] as String?;
          bio = data['bio'] as String?;
          professionType = data['professionType'] as String?;
          professionName = data['professionName'] as String?;
          heightCm = data['heightCm'] is int
              ? data['heightCm'] as int
              : (data['heightCm'] is String && data['heightCm'] != null && data['heightCm'].toString().isNotEmpty
                  ? int.tryParse(data['heightCm'].toString())
                  : null);
          isLoading = false;
          errorMessage = null;
          debugError = null;
        });
      } catch (e) {
        // Ignore cache if corrupted
      }
    }
  }

  Future<void> _saveProfileToCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileCacheKey, json.encode(data));
  }

  Future<void> _fetchProfileData() async {
    try {
      // Don't set isLoading here, so UI stays responsive with cache
      setState(() {
        errorMessage = null;
        debugError = null;
      });

      final user = await account.get();
      final String currentUserId = user.$id;

      // Replace with your actual database and collection IDs
      String databaseId = '685a90fa0009384c5189';
      String imagesCollectionId = '685aa0ef00090023c8a3';
      const String userCollectionId = '68616ecc00163ed41e57';
      String bioDataCollectionID = '685aac1d0013a8a6752f';

      // Get images
      final imageDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: imagesCollectionId,
        queries: [Query.equal('user', currentUserId)],
      );

      List<String> fetchedImages = [];
      if (imageDocs.documents.isNotEmpty) {
        for (var doc in imageDocs.documents) {
          for (int i = 1; i <= 6; i++) {
            final imageUrl = doc.data['image_$i'];
            if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
              fetchedImages.add(imageUrl);
            }
          }
        }
      }

      // Get user name, email, and college (if available)
      final userDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: userCollectionId,
        queries: [Query.equal(r'$id', currentUserId)],
      );
      String? fetchedName;
      String? fetchedCollege;
      String? fetchedEmail;
      if (userDocs.documents.isNotEmpty) {
        final userData = userDocs.documents.first.data;
        fetchedName = userData['name'] as String?;
        fetchedCollege = userData['college'] as String?;
        fetchedEmail = userData['email'] as String?;
      }

      // Get biodata
      final biodataDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: bioDataCollectionID,
        queries: [Query.equal('user', currentUserId)],
      );

      String? fetchedDob;
      String? fetchedGender;
      List<String> fetchedHobbies = [];
      String? fetchedBio;
      String? fetchedProfessionType;
      String? fetchedProfessionName;
      int? fetchedHeightCm;

      if (biodataDocs.documents.isNotEmpty) {
        final data = biodataDocs.documents.first.data;
        fetchedDob = data['dob'] as String?;
        fetchedGender = data['gender'] as String?;
        fetchedBio = data['bio'] as String?;
        fetchedProfessionType = data['profession_type'] as String?;
        fetchedProfessionName = data['profession_name'] as String?;
        // Height can be int or string, handle both
        if (data['height'] != null) {
          if (data['height'] is int) {
            fetchedHeightCm = data['height'] as int;
          } else if (data['height'] is String && data['height'].toString().isNotEmpty) {
            fetchedHeightCm = int.tryParse(data['height'].toString());
          }
        }
        if (data['hobbies'] is List && (data['hobbies'] as List).isNotEmpty) {
          // Fix: Ensure we only extract String IDs from the hobbies list
          final List<dynamic> hobbiesRaw = data['hobbies'];
          final List<String> hobbyIds = hobbiesRaw
              .map((e) {
                if (e is String) return e;
                if (e is Map && e.containsKey(r'$id'))
                  return e[r'$id'].toString();
                return null;
              })
              .whereType<String>()
              .toList();

          if (hobbyIds.isNotEmpty) {
            final hobbyDocs = await databases.listDocuments(
              databaseId: databaseId,
              collectionId: '685acd8b00010dd66e1c', // hobbiesCollectionID
              queries: [
                Query.equal(r'$id', hobbyIds),
                Query.select(['hobby_name']),
                Query.limit(100),
              ],
            );

            fetchedHobbies = hobbyDocs.documents
                .map((doc) => doc.data['hobby_name'] as String?)
                .whereType<String>()
                .toList();
          }
        }
      }

      // Prepare data for cache
      final profileData = {
        'userId': currentUserId,
        'name': fetchedName ?? 'No Name',
        'dob': fetchedDob ?? '',
        'gender': fetchedGender ?? '',
        'hobbies': fetchedHobbies,
        'images': fetchedImages,
        'college': fetchedCollege ?? '',
        'email': fetchedEmail ?? '',
        'bio': fetchedBio ?? '',
        'professionType': fetchedProfessionType ?? '',
        'professionName': fetchedProfessionName ?? '',
        'heightCm': fetchedHeightCm ?? '',
      };

      // Save to cache
      await _saveProfileToCache(profileData);

      // Only update UI if data changed
      bool changed = userId != currentUserId ||
          name != (fetchedName ?? 'No Name') ||
          dob != (fetchedDob ?? '') ||
          gender != (fetchedGender ?? '') ||
          college != (fetchedCollege ?? '') ||
          email != (fetchedEmail ?? '') ||
          bio != (fetchedBio ?? '') ||
          professionType != (fetchedProfessionType ?? '') ||
          professionName != (fetchedProfessionName ?? '') ||
          (heightCm ?? '') != (fetchedHeightCm ?? '') ||
          !_listEquals(hobbies, fetchedHobbies) ||
          !_listEquals(images, fetchedImages);

      if (changed) {
        setState(() {
          userId = currentUserId;
          name = fetchedName ?? 'No Name';
          dob = fetchedDob ?? '';
          gender = fetchedGender ?? '';
          hobbies = fetchedHobbies;
          images = fetchedImages;
          college = fetchedCollege ?? '';
          email = fetchedEmail ?? '';
          bio = fetchedBio ?? '';
          professionType = fetchedProfessionType ?? '';
          professionName = fetchedProfessionName ?? '';
          heightCm = fetchedHeightCm;
          isLoading = false;
          errorMessage = null;
          debugError = null;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = null;
          debugError = null;
        });
      }
    } on AppwriteException catch (e) {
      setState(() {
        isLoading = false;
        errorMessage =
            e.message ??
            "Failed to load profile data. Please check your connection and try again.";
        debugError = e.toString();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Failed to load profile data. Please try again later.";
        debugError = e.toString();
      });
    }
  }

  // Helper for list equality
  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 26,
            color: Color(0xFF3B2357),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.gearSix,
              size: 22,
              color: Color(0xFF3B2357),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[400], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (debugError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            debugError!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                              debugError = null;
                            });
                            _fetchProfileData();
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : (userId == null || userId!.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, color: Colors.grey[400], size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              "No profile data found.",
                              style: TextStyle(
                                color: Color(0xFF3B2357),
                                fontSize: 16,
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                  debugError = null;
                                });
                                _fetchProfileData();
                              },
                              child: const Text("Reload"),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B2357),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: images.isNotEmpty && images[0].isNotEmpty
                                          ? Image.network(
                                              images[0],
                                              height: imageHeight,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              color: Colors.black.withOpacity(0.25),
                                              colorBlendMode: BlendMode.darken,
                                            )
                                          : Container(
                                              height: imageHeight,
                                              width: double.infinity,
                                              color: Colors.black.withOpacity(0.25),
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 80,
                                              ),
                                            ),
                                    ),
                                    // Name
                                    Positioned(
                                      top: 18,
                                      left: 18,
                                      right: 60,
                                      child: Text(
                                        name ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 24,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black38,
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Edit button
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () {
                                            // Navigate to ProfileEditScreen
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const ProfileEditScreen(),
                                              ),
                                            );
                                          },
                                          child: const CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.white,
                                            child: Icon(
                                              PhosphorIconsRegular.pencilSimple,
                                              size: 18,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // College (if available)
                                    if ((college ?? '').isNotEmpty)
                                      Positioned(
                                        top: 52,
                                        left: 18,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              PhosphorIconsRegular.buildings,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              college ?? "",
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                color: Colors.white.withOpacity(0.95),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Email (if available)
                                    if ((email ?? '').isNotEmpty)
                                      Positioned(
                                        top: (college ?? '').isNotEmpty ? 76 : 52,
                                        left: 18,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              PhosphorIconsRegular.envelope,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              email ?? "",
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                color: Colors.white.withOpacity(0.95),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Gender, Age, Hobbies
                                    Positioned(
                                      bottom: 24,
                                      left: 18,
                                      right: 18,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            children: [
                                              // Gender
                                              Text(
                                                (gender ?? '').isNotEmpty
                                                    ? gender![0].toUpperCase()
                                                    : '',
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1,
                                                  letterSpacing: 0.5,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black26,
                                                      blurRadius: 2,
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              // Age
                                              Text(
                                                dob != null && dob!.isNotEmpty
                                                    ? _calculateAge(dob!).toString()
                                                    : '',
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1,
                                                  letterSpacing: 0.5,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black26,
                                                      blurRadius: 2,
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          // Hobbies
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: hobbies
                                                  .map(
                                                    (tag) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 7,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(18),
                                                        gradient: const LinearGradient(
                                                          colors: [
                                                            Color(0xFFF8EBF9),
                                                            Color(0xFFE0D7F3),
                                                          ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        border: Border.all(
                                                          color: Color(
                                                            0xFFBFA2E0,
                                                          ).withOpacity(0.5),
                                                          width: 1.2,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Color(
                                                              0xFFBFA2E0,
                                                            ).withOpacity(0.18),
                                                            blurRadius: 8,
                                                            offset: Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        tag,
                                                        style: const TextStyle(
                                                          fontFamily: 'Poppins',
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF3B2357),
                                                          letterSpacing: 0.1,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Biodata card moved below profile photo
                            if ((bio ?? '').isNotEmpty ||
                                (professionType ?? '').isNotEmpty ||
                                (professionName ?? '').isNotEmpty ||
                                (heightCm != null && heightCm! > 0))
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 18,
                                  bottom: 0,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B2357).withOpacity(0.93),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if ((bio ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                PhosphorIconsRegular.quotes,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  bio!,
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if ((professionType ?? '').isNotEmpty ||
                                          (professionName ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                PhosphorIconsRegular.briefcase,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  [
                                                    if ((professionType ?? '').isNotEmpty)
                                                      professionType,
                                                    if ((professionName ?? '').isNotEmpty)
                                                      professionName
                                                  ].where((e) => e != null && e!.isNotEmpty).join(' • '),
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (heightCm != null && heightCm! > 0)
                                        Row(
                                          children: [
                                            const Icon(
                                              PhosphorIconsRegular.ruler,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "$heightCm cm",
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 32),
                            // Show all images in a grid or a message if no images
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Builder(
                                builder: (context) {
                                  // If there are no images at all, show a message
                                  final hasAnyImages =
                                      images.isNotEmpty &&
                                      images.any((img) => img.isNotEmpty);
                                  if (!hasAnyImages) {
                                    return Container(
                                      height: 120,
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "No images added",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          color: Color(0xFF3B2357),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }

                                  // Otherwise, show the grid with images and empty slots (up to 6)
                                  final double spacing = 16;
                                  final double crossAxisCount = 3;
                                  final double itemWidth =
                                      (MediaQuery.of(context).size.width -
                                          32 -
                                          (spacing * (crossAxisCount - 1))) /
                                      crossAxisCount;
                                  final double itemHeight = itemWidth * 0.68;

                                  // Pad images to 6 slots with empty strings
                                  List<String> paddedImages = List<String>.from(images);
                                  while (paddedImages.length < 6) {
                                    paddedImages.add('');
                                  }
                                  // Only show up to 6
                                  paddedImages = paddedImages.take(6).toList();

                                  return SizedBox(
                                    height: (itemHeight * 2) + spacing,
                                    child: GridView.builder(
                                      padding: EdgeInsets.zero,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            mainAxisSpacing: spacing,
                                            crossAxisSpacing: spacing,
                                            childAspectRatio: itemWidth / itemHeight,
                                          ),
                                      itemCount: 6,
                                      itemBuilder: (context, index) {
                                        if (paddedImages[index].isNotEmpty) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.13),
                                                  blurRadius: 14,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(14),
                                              child: Image.network(
                                                paddedImages[index],
                                                fit: BoxFit.cover,
                                                width: itemWidth,
                                                height: itemHeight,
                                                errorBuilder:
                                                    (context, error, stackTrace) =>
                                                        Container(
                                                          color: Colors.grey[300],
                                                          child: const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          // Only show empty slots if there is at least one image
                                          return const SizedBox.shrink();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Optionally, show more fetched data here in a Card or ListTile
                            if ((userId ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Card(
                                  color: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  int _calculateAge(String dobString) {
    try {
      final dobDate = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dobDate.year;
      if (now.month < dobDate.month ||
          (now.month == dobDate.month && now.day < dobDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }
}
