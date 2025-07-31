import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

// Import all ids from .env using String.fromEnvironment
// Updated to match actual .env variable names
const databaseId = String.fromEnvironment('DATABASE_ID');
const usersCollectionId = String.fromEnvironment('USERS_COLLECTIONID');
const biodataCollectionId = String.fromEnvironment('BIODATA_COLLECTIONID');
const imagesCollectionId = String.fromEnvironment('IMAGE_COLLECTIONID');
const locationCollectionId = String.fromEnvironment('LOCATION_COLLECTIONID');

class ProfileCheck extends StatefulWidget {
  final String userId;

  const ProfileCheck({super.key, required this.userId});

  @override
  State<ProfileCheck> createState() => _ProfileCheckState();
}

class _ProfileCheckState extends State<ProfileCheck> {
  bool _isLoading = true;
  bool _hasError = false;

  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userId = widget.userId;

      // 1. Fetch user document
      final userDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId, // users collection
        queries: [Query.equal('\$id', userId)],
      );
      final userDoc = userDocs.documents.isNotEmpty
          ? userDocs.documents.first
          : null;

      // 2. Fetch biodata document
      final biodataDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: biodataCollectionId, // biodata collection
        queries: [Query.equal('user', userId)],
      );
      final biodataDoc = biodataDocs.documents.isNotEmpty
          ? biodataDocs.documents.first
          : null;

      // 3. Fetch images document
      final imagesDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: imagesCollectionId, // images collection
        queries: [Query.equal('user', userId)],
      );
      final imagesDoc = imagesDocs.documents.isNotEmpty
          ? imagesDocs.documents.first
          : null;

      // 4. Fetch location document
      final locationDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: locationCollectionId, // location collection
        queries: [Query.equal('user', userId)],
      );
      final locationDoc = locationDocs.documents.isNotEmpty
          ? locationDocs.documents.first
          : null;

      // 5. Process hobbies from biodata
      List<Map<String, dynamic>> hobbiesList = [];
      if (biodataDoc != null && biodataDoc.data['hobbies'] is List) {
        final hobbiesData = biodataDoc.data['hobbies'] as List;
        hobbiesList = hobbiesData.cast<Map<String, dynamic>>();
      }

      // 6. Gather images (image_1 ... image_6)
      List<String> images = [];
      if (imagesDoc != null) {
        for (int i = 1; i <= 6; i++) {
          final img = imagesDoc.data['image_$i'];
          if (img != null && img is String && img.isNotEmpty) {
            images.add(img);
          }
        }
      }

      // Now, combine all the data into your _profile map
      setState(() {
        _profile = {
          'user': userDoc?.data,
          'biodata': biodataDoc?.data,
          'images': images,
          'location': locationDoc?.data,
          'hobbies': hobbiesList,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// Helper to calculate age from dob string (format: 2005-10-17T00:00:00.000+00:00)
  int? _calculateAgeFromDob(String? dobString) {
    if (dobString == null || dobString.isEmpty) return null;
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }

  // Helper to get icon for profession type
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              PhosphorIconsRegular.arrowLeft,
              color: Color(0xFF6D4B86),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Color(0xFF3B2357),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Failed to load profile.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text(
                  "Retry",
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final biodata = _profile!['biodata'] is Map<String, dynamic>
        ? _profile!['biodata']
        : <String, dynamic>{};
    final location = _profile!['location'] is Map<String, dynamic>
        ? _profile!['location']
        : <String, dynamic>{};
    final hobbies = _profile!['hobbies'] is List
        ? _profile!['hobbies'] as List
        : <dynamic>[];
    final user = biodata['user'] is Map<String, dynamic>
        ? biodata['user']
        : <String, dynamic>{};

    final String name = user['name']?.toString() ?? 'Unknown';
    final String? gender = biodata['gender']?.toString();
    final String? bio = biodata['bio']?.toString();
    final List<String> images = _profile!['images'] is List
        ? List<String>.from(_profile!['images'])
        : <String>[];
    final String? image = images.isNotEmpty ? images.first : null;
    final String? city = location['city']?.toString();
    final String? state = location['state']?.toString();
    final String? country = location['country']?.toString();

    // Get age from dob
    final String? dobString = biodata['dob']?.toString();
    final int? age = _calculateAgeFromDob(dobString);

    // Get profession info
    final String? professionType = biodata['profession_name']?.toString();
    final String? professionSubtype = biodata['sub_type']?.toString();

    // Get height in cm from biodata
    final dynamic heightValue = biodata['height'];
    String? heightDisplay;
    if (heightValue != null) {
      if (heightValue is num) {
        heightDisplay = "${heightValue.toString()} cm";
      } else if (heightValue is String && heightValue.trim().isNotEmpty) {
        heightDisplay = "${heightValue.trim()} cm";
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(
              PhosphorIconsRegular.arrowLeft,
              color: Color(0xFF6D4B86),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 16,
          title: const Text(
            'Profile',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Color(0xFF2D1B3A),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Poppins'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
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
                    // Main Image with bottom gradient overlay
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: Stack(
                          children: [
                            image != null && image.isNotEmpty
                                ? Image.network(
                                    image,
                                    width: double.infinity,
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.8,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: double.infinity,
                                              height: 420,
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
                                    height: 420,
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
                    // Profession at top left of main image
                    if (professionType != null && professionType.isNotEmpty)
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
                                    professionType[0].toUpperCase() +
                                        professionType.substring(1),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF3B2357),
                                    ),
                                  ),
                                  if (professionSubtype != null &&
                                      professionSubtype.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1.5),
                                      child: Text(
                                        professionSubtype,
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
                    // Name, gender, age at bottom left
                    Positioned(
                      left: 16,
                      bottom: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
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
                            '${gender != null && gender.isNotEmpty ? gender[0].toUpperCase() : "?"}, ${age != null ? age : "--"}',
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
                  ],
                ),
              ),
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
                        final String hobbyName =
                            hobby is Map && hobby['hobby_name'] != null
                            ? hobby['hobby_name'].toString()
                            : '';
                        final String hobbyCategory =
                            hobby is Map && hobby['hobby_category'] != null
                            ? hobby['hobby_category'].toString()
                            : '';
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
                            hobbyName.isNotEmpty
                                ? hobbyName[0].toUpperCase() +
                                      hobbyName.substring(1)
                                : hobbyCategory,
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
              if (heightDisplay != null && heightDisplay.isNotEmpty) ...[
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
                      "Height: $heightDisplay",
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
              // Location Section
              if ((city != null && city.isNotEmpty) ||
                  (state != null && state.isNotEmpty) ||
                  (country != null && country.isNotEmpty))
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if ((city != null && city.isNotEmpty) ||
                        (state != null && state.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF6D4B86),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Lives in ${city ?? ''}${(city != null && city.isNotEmpty && state != null && state.isNotEmpty) ? ', ' : ''}${state ?? ''}",
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                color: Color(0xFF6D4B86),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (country != null && country.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.place,
                              color: Color(0xFF6D4B86),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "From $country",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                color: Color(0xFF6D4B86),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 32),
              // Additional Images Section
              if (images.length > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...(images.skip(1).map<Widget>((imgUrl) {
                      if (imgUrl == null || imgUrl.toString().isEmpty)
                        return const SizedBox.shrink();
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
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: Image.network(
                              imgUrl.toString(),
                              width: double.infinity,
                              height: MediaQuery.of(context).size.height * 0.8,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: double.infinity,
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.8,
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
                    })).toList(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
