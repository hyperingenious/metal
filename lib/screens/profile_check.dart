import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import 'dart:ui';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../services/config_service.dart';

// Import config values using ConfigService
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID');
final biodataCollectionId = ConfigService().get('BIODATA_COLLECTIONID');
final imagesCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');

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

  // Palette
  static const _ink = Color(0xFF3B2357);
  static const _inkMuted = Color(0xFF6D4B86);
  static const _brand = Color(0xFF8B4DFF);
  static const _bg = Colors.white;

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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: _ink,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Divider get _softDivider =>
      Divider(height: 28, thickness: 1, color: Colors.black.withOpacity(0.06));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _profile == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
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
              color: _ink,
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
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft, color: _inkMuted),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 16,
          title: const Text(
            'Profile',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: _ink,
              letterSpacing: 0.2,
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
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
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
                        child: AspectRatio(
                          aspectRatio: 3 / 4, // consistent portrait card
                          child: Stack(
                            children: [
                              image != null && image.isNotEmpty
                                  ? Image.network(
                                      image,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      frameBuilder: (context, child, frame, _) {
                                        return AnimatedOpacity(
                                          opacity: frame == null ? 0 : 1,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOut,
                                          child: child,
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 80,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 80,
                                          color: Colors.white,
                                        ),
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
                                          Color.fromARGB(200, 0, 0, 0),
                                        ],
                                        stops: [0.0, 0.55, 0.82, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Profession at top left of main image
                    if (professionType != null && professionType.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(color: _brand, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getProfessionIcon(professionType),
                                    color: _brand,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        professionType[0].toUpperCase() +
                                            professionType.substring(1),
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                          color: _ink,
                                        ),
                                      ),
                                      if (professionSubtype != null &&
                                          professionSubtype.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 1.5,
                                          ),
                                          child: Text(
                                            professionSubtype,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12,
                                              color: _inkMuted,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Name, gender, age at bottom left
                    Positioned(
                      left: 16,
                      bottom: 22,
                      right: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 28,
                                    color: Colors.white,
                                    height: 1.1,
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
                                    fontSize: 20,
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
                  ],
                ),
              ),

              // Bio
              Align(
                alignment: Alignment.center,
                child: Text(
                  "Bio",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: _ink,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  bio ?? "No bio provided.",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: _ink,
                    height: 1.35,
                  ),
                ),
              ),

              _softDivider,

              // About me
              _sectionTitle("About me"),
              Builder(
                builder: (context) {
                  if (hobbies.isEmpty) {
                    return const Text(
                      "No hobbies listed.",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: _inkMuted,
                      ),
                    );
                  }
                  return Wrap(
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
                      final label = hobbyName.isNotEmpty
                          ? hobbyName
                          : hobbyCategory;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EEFF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _brand.withOpacity(0.25)),
                        ),
                        child: Text(
                          label.isNotEmpty
                              ? label[0].toUpperCase() + label.substring(1)
                              : '',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: _inkMuted,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              if (heightDisplay != null && heightDisplay.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.ruler,
                      color: _inkMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      "Height: $heightDisplay",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // Location
              if ((city != null && city.isNotEmpty) ||
                  (state != null && state.isNotEmpty) ||
                  (country != null && country.isNotEmpty)) ...[
                _sectionTitle("Location"),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((city != null && city.isNotEmpty) ||
                        (state != null && state.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: _inkMuted,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Lives in ${city ?? ''}${(city != null && city.isNotEmpty && state != null && state.isNotEmpty) ? ', ' : ''}${state ?? ''}",
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: _inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (country != null && country.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place, color: _inkMuted, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "From $country",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: _inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Additional Images Section
              if (images.length > 1) ...[
                _sectionTitle("Photos"),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length - 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3 / 4,
                  ),
                  itemBuilder: (context, index) {
                    final imgUrl = images[index + 1];
                    if (imgUrl.isEmpty) return const SizedBox.shrink();
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          frameBuilder: (context, child, frame, _) {
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              child: child,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
