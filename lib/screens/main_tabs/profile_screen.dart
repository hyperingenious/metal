import 'package:flutter/material.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:lushh/widgets/profile_edi_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lushh/widgets/expandable_prompts.dart';

// Add prompts collection ID
const String promptsCollectionId = String.fromEnvironment(
  'PROMPTS_COLLECTIONID',
);

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

  // Prompts data
  List<Map<String, dynamic>> _promptAnswers = [];
  bool _isPromptsLoading = false;
  String? _promptsError;
  // Remove _expandedPromptIndex since it's now handled in the widget

  // Questions data
  final List<Map<String, dynamic>> _maleQuestions = [
    {
      'question': 'The quality I admire most in a relationship is…',
      'options': [
        'Mutual respect',
        'Unconditional support',
        'Shared laughter',
        'Honesty and open communication',
        'Trust and loyalty',
        'A sense of adventure',
        'The ability to grow together',
        'Thoughtfulness',
        'Emotional intelligence',
        'Good communication',
      ],
    },
    {
      'question': 'I feel most connected when we are…',
      'options': [
        'Having a deep conversation over coffee',
        'Laughing at something completely silly',
        'Exploring a new place together',
        'Cooking a meal as a team',
        'Just being quiet and comfortable in each other\'s presence',
        'Talking about our dreams and goals',
        'Sharing our favorite music with each other',
        'Debating a movie\'s plot for hours',
        'Working on a project together',
        'Talking on a long drive',
      ],
    },
    {
      'question': 'I\'m looking for a partner who can challenge me to…',
      'options': [
        'Step outside my comfort zone',
        'Try new things',
        'Think more deeply about things',
        'Be more adventurous',
        'Improve my communication skills',
        'Be more emotionally intelligent',
        'Read more books',
        'Pursue my dreams',
        'Be a better version of myself',
      ],
    },
    {
      'question': 'The most romantic thing I can do for someone is…',
      'options': [
        'Making them a home-cooked meal',
        'Planning a surprise trip or adventure',
        'Making them a cup of tea',
        'Showing them I\'m listening by remembering the little things',
        'Supporting them when they\'re pursuing a dream',
        'Giving them a relaxing massage after a long day',
        'Bringing them flowers just because',
        'A romantic date',
        'Sending a thoughtful text just to say I\'m thinking of them',
        'Telling them how I feel',
      ],
    },
    {
      'question': 'The perfect gift I could receive is…',
      'options': [
        'A thoughtful, handwritten note',
        'An experience, not a thing',
        'Tickets to a sports game or a concert',
        'Something that shows you were really listening',
        'A surprise weekend trip',
        'A great book',
        'A great meal',
        'Something to help me with my hobby',
        'A day of no responsibilities',
        'Anything handmade',
      ],
    },
    {
      'question': 'My ideal way to be comforted after a bad day is…',
      'options': [
        'A long, quiet walk',
        'A hug and a quiet movie night',
        'A great home-cooked meal',
        'A little bit of space to myself',
        'To talk it out with a good listener',
        'A good workout',
        'A surprise',
        'A good beer',
        'A long drive with some good music',
        'A cup of tea',
      ],
    },
    {
      'question': 'A perfect Friday night looks like…',
      'options': [
        'A low-key dinner with friends',
        'A great movie on the couch with some comfort food',
        'Quality time with parents or siblings',
        'Trying out a new restaurant or bar',
        'Getting a good workout in after a long week',
        'A board game night with a few close friends',
        'Going to a live music show',
        'An adventurous road trip to a new place',
        'Grilling and chilling with a beer',
        'Unplugging and enjoying some peace and quiet',
        'A spontaneous trip to the mountains',
      ],
    },
  ];

  final List<Map<String, dynamic>> _femaleQuestions = [
    {
      'question': 'I know I\'ve found a good match when…',
      'options': [
        'The conversation flows naturally',
        'He makes me laugh',
        'I feel a genuine connection',
        'He\'s a good listener',
        'We both forget to check our phones',
        'He\'s a good friend',
        'He challenges me to be a better person',
        'We have the same sense of humor',
        'He makes me feel safe',
        'We have a mutual respect',
      ],
    },
    {
      'question': 'A quality I admire most on a date is…',
      'options': [
        'Their ability to listen',
        'Their confidence',
        'Their thoughtfulness',
        'Their sense of humor',
        'Their manners',
        'Their ability to make me feel comfortable',
        'Their respect for my time',
        'Their ability to be present',
        'Their kindness',
        'Their honesty',
      ],
    },
    {
      'question': 'The best way to get to know me is…',
      'options': [
        'Over a good meal',
        'By asking me about my passions',
        'By having a deep conversation',
        'By just letting me be myself',
        'By seeing me with my friends',
        'By sharing a new experience with me',
        'Over a cup of tea',
        'By asking me about my dreams',
        'By just hanging out',
        'By trying a new cafe',
      ],
    },
    {
      'question': 'My communication style is best described as…',
      'options': [
        'Direct and honest',
        'I prefer to talk things out',
        'I\'m a good listener',
        'I\'m a good texter',
        'I\'m a great communicator',
        'I\'m a good listener, but I\'m also a great talker',
        'I\'m a good texter, but I prefer to talk on the phone',
        'I\'m a good communicator, but I\'m also a good listener',
        'I\'m a good communicator, but I\'m also a good texter',
        'I\'m a good communicator, but I also like to have fun',
      ],
    },
    {
      'question': 'My perfect first date would be…',
      'options': [
        'A long walk in a park',
        'Coffee at a local cafe',
        'Trying out a new restaurant or bar',
        'A quiet dinner where we can talk',
        'Getting an ice cream',
        'An adventurous road trip to a new city',
        'Bowling or mini golf',
        'A comedy show',
        'Going to a live music show',
        'A picnic',
      ],
    },
    {
      'question': 'The most romantic gesture to me is…',
      'options': [
        'A thoughtful text after the date',
        'A handwritten note',
        'A surprise visit',
        'A surprise trip',
        'A home-cooked meal',
        'A thoughtful gift',
        'A long walk with a good conversation',
        'A simple hug',
        'A compliment',
        'A great date',
      ],
    },
    {
      'question': 'My biggest pet peeve is…',
      'options': [
        'When someone is on their phone during a date',
        'A messy car',
        'Being late',
        'Rude waiters',
        'When someone chews with their mouth open',
        'A person with no manners',
        'When someone is a bad driver',
        'A person who talks too much about themselves',
        'Being ignored',
        'When someone is a bad listener',
      ],
    },
  ];

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
              : (data['heightCm'] is String &&
                        data['heightCm'] != null &&
                        data['heightCm'].toString().isNotEmpty
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

  Future<void> _fetchPromptsData() async {
    if (userId == null || gender == null) return;

    setState(() {
      _isPromptsLoading = true;
      _promptsError = null;
    });

    try {
      final promptDocs = await databases.listDocuments(
        databaseId:
            databaseId, // This is now correctly imported from appwrite.dart
        collectionId: promptsCollectionId,
        queries: [Query.equal('user', userId!)],
      );

      List<Map<String, dynamic>> answers = [];
      if (promptDocs.documents.isNotEmpty) {
        final data = promptDocs.documents[0].data;
        final questions = gender!.toLowerCase() == 'male'
            ? _maleQuestions
            : _femaleQuestions;

        for (int i = 0; i < 7; i++) {
          final answer = data['answer_${i + 1}'];
          if (answer != null && answer.toString().isNotEmpty) {
            answers.add({
              'question': questions[i]['question'],
              'answer': answer.toString(),
            });
          }
        }
      }

      setState(() {
        _promptAnswers = answers;
        _isPromptsLoading = false;
      });
    } catch (e) {
      setState(() {
        _promptsError = "Failed to load prompts.";
        _isPromptsLoading = false;
      });
    }
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

      // Get images
      final imageDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: imageCollectionId,
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
        collectionId: usersCollectionId,
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
        collectionId: biodataCollectionId,
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
          } else if (data['height'] is String &&
              data['height'].toString().isNotEmpty) {
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
              collectionId: hobbiesCollectionId,
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
      bool changed =
          userId != currentUserId ||
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

        // Fetch prompts data after profile data is loaded
        await _fetchPromptsData();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = null;
          debugError = null;
        });

        // Still fetch prompts data even if profile didn't change
        await _fetchPromptsData();
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

  Future<void> _refreshProfileData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      debugError = null;
    });
    await _fetchProfileData();
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
                                      ? CachedNetworkImage(
                                          imageUrl: images[0],
                                          width: double.infinity,
                                          height: mainImageHeight,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 80,
                                                  color: Colors.white,
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
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
                                  color: const Color(0xFF3B2357),
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getProfessionIcon(professionType),
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 7),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          professionType![0].toUpperCase() +
                                              professionType!.substring(1),
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if ((professionName ?? '').isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 1.5,
                                            ),
                                            child: Text(
                                              professionName!,
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w400,
                                                fontSize: 12.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Edit button (top right of image)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () async {
                                  // Await the result from edit screen
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileEditScreen(),
                                    ),
                                  );
                                  // If user edited profile, refresh
                                  if (result == true) {
                                    await _refreshProfileData();
                                  }
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
                          if ((college ?? '').isNotEmpty ||
                              (email ?? '').isNotEmpty)
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
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
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
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
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
                          fontSize: 22,
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
                                  child: CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    width: double.infinity,
                                    height: screenHeight * 0.8,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
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

                    // Prompts Section - moved to end
                    if (_promptAnswers.isNotEmpty) ...[
                      ExpandablePrompts(prompts: _promptAnswers),
                    ] else if (_isPromptsLoading) ...[
                      const SizedBox(height: 32),
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B4DFF),
                          ),
                        ),
                      ),
                    ] else if (_promptsError != null) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          _promptsError!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
