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
    final mainImageHeight = screenHeight * 0.6;

    // Helper for profession icon (imitate explore)
    IconData _getProfessionIcon(String? professionType) {
      switch (professionType?.toLowerCase()) {
        case 'student':
          return Icons.school;
        case 'engineer':
          return Icons.engineering;
        case 'designer':
          return Icons.brush;
        case 'doctor':
          return Icons.local_hospital;
        case 'artist':
          return Icons.palette;
        case 'other':
          return Icons.work_outline;
        default:
          return Icons.work_outline;
      }
    }

    int? age;
    if (dob != null && dob!.isNotEmpty) {
      try {
        final dobDate = DateTime.parse(dob!);
        final now = DateTime.now();
        age = now.year - dobDate.year;
        if (now.month < dobDate.month ||
            (now.month == dobDate.month && now.day < dobDate.day)) {
          age--;
        }
      } catch (_) {}
    }

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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: DefaultTextStyle(
                        style: const TextStyle(fontFamily: 'Poppins'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Main Profile Card (imitate explore) ---
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Main image with gradient overlay
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: mainImageHeight,
                                      child: Stack(
                                        children: [
                                          images.isNotEmpty && images[0].isNotEmpty
                                              ? Image.network(
                                                  images[0],
                                                  width: double.infinity,
                                                  height: mainImageHeight,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      Container(
                                                        width: double.infinity,
                                                        height: mainImageHeight,
                                                        color: Colors.grey[300],
                                                        child: const Icon(
                                                          Icons.person,
                                                          size: 80,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  width: double.infinity,
                                                  height: mainImageHeight,
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                          // Gradient overlay at the bottom
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.transparent,
                                                      Color.fromARGB(120, 0, 0, 0),
                                                      Color.fromARGB(180, 0, 0, 0),
                                                    ],
                                                    stops: [0.0, 0.6, 0.85, 1.0],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Profession at top left
                                  if ((professionType ?? '').isNotEmpty)
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.92),
                                          borderRadius: BorderRadius.circular(22),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: const Color(0xFF8B4DFF),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getProfessionIcon(professionType),
                                              color: const Color(0xFF8B4DFF),
                                              size: 22,
                                            ),
                                            const SizedBox(width: 7),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  professionType![0].toUpperCase() +
                                                      professionType!.substring(1),
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Color(0xFF3B2357),
                                                  ),
                                                ),
                                                if ((professionName ?? '').isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 1.5),
                                                    child: Text(
                                                      professionName!,
                                                      style: const TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontWeight: FontWeight.w400,
                                                        fontSize: 12.5,
                                                        color: Color(0xFF6D4B86),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Edit button at top right
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const ProfileEditScreen(),
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
                                  // Name, gender, age at bottom left
                                  Positioned(
                                    left: 16,
                                    bottom: 32,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name ?? '',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 28,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black38,
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${(gender ?? '').isNotEmpty ? gender![0].toUpperCase() : "?"}, ${age != null ? age : "--"}',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 26,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black38,
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // College and email at bottom right
                                  if ((college ?? '').isNotEmpty || (email ?? '').isNotEmpty)
                                    Positioned(
                                      right: 16,
                                      bottom: 32,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if ((college ?? '').isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
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
                                          if ((email ?? '').isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
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
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // --- End Main Card ---

                            // Bio Section
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                "Bio",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF3B2357),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                              child: Text(
                                bio ?? "No bio provided.",
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: Color(0xFF3B2357),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            // About me Section
                            const Text(
                              "About me",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Color(0xFF3B2357),
                              ),
                            ),
                            const SizedBox(height: 10),
                            hobbies.isNotEmpty
                                ? Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: hobbies.map<Widget>((hobby) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F6FA),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          hobby[0].toUpperCase() + hobby.substring(1),
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: Color(0xFF6D4B86),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : const Text(
                                    "No hobbies listed.",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13,
                                      color: Color(0xFF6D4B86),
                                    ),
                                  ),
                            // Height Section (below About me)
                            if (heightCm != null && heightCm! > 0) ...[
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.ruler,
                                    color: Color(0xFF6D4B86),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    "Height: $heightCm cm",
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                      color: Color(0xFF3B2357),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Additional Images Section (imitate explore)
                            if (images.length > 1)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...images.skip(1).map((imgUrl) {
                                    if (imgUrl.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: screenHeight * 0.8,
                                          child: Image.network(
                                            imgUrl,
                                            width: double.infinity,
                                            height: screenHeight * 0.8,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                Container(
                                                  width: double.infinity,
                                                  height: screenHeight * 0.8,
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    size: 80,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
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
