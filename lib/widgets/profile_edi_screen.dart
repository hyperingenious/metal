import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:lushh/services/config_service.dart';

// --- THEME CONSTANTS (from explore_screen.dart style) ---
const Color kBackgroundColor = Color(0xFFF8EBF9);
const Color kCardColor = Colors.white;
const Color kPrimaryColor = Color(0xFF7B4AE2);
const Color kTextColor = Color(0xFF3B2357);
const Color kAccentColor = Color(0xFF3B2357);
const double kCardRadius = 24.0;
const double kCardElevation = 0.0;
const double kCardPadding = 20.0;
const double kSectionSpacing = 28.0;
const double kFieldRadius = 16.0;
const double kFieldPadding = 14.0;
const double kButtonRadius = 16.0;
const double kButtonHeight = 44.0;
const double kButtonFontSize = 15.0;
const String kFontFamily = 'Poppins';

// Config service instance
final _configService = ConfigService();

class ProfileEditScreen extends StatefulWidget {
  final String? initialName;
  final List<String> initialImages;
  final String? initialProfession;
  final String? initialProfessionName;
  final String? initialBio;

  const ProfileEditScreen({
    Key? key,
    this.initialName,
    this.initialImages = const ['', '', '', '', '', ''],
    this.initialProfession,
    this.initialProfessionName,
    this.initialBio,
  }) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late List<String> _images;
  int _highlightedIndex = 0;

  final List<String> _professions = [
    'Student',
    'Engineer',
    'Designer',
    'Doctor',
    'Artist',
    'Other',
  ];

  String? _selectedProfession;
  late TextEditingController _professionNameController;
  late TextEditingController _bioController;

  bool _isLoading = true;
  String? _errorMessage;

  String? _originalName;
  String? _originalProfession;
  String? _originalBio;

  String? _gender;
  List<Map<String, dynamic>> _promptQuestions = [];
  List<int?> _promptAnswers = List.filled(7, null);
  bool _isPromptLoading = true;
  String? _promptError;
  String? _promptDocId;

  List<int?> _originalPromptAnswers = List.filled(7, null);

  static final List<Map<String, dynamic>> _maleQuestions = [
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

  static final List<Map<String, dynamic>> _femaleQuestions = [
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
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _images = List<String>.from(widget.initialImages);
    if (_images.length < 6) {
      _images = List<String>.from(_images)
        ..addAll(List.filled(6 - _images.length, ''));
    } else if (_images.length > 6) {
      _images = _images.sublist(0, 6);
    }
    _selectedProfession = widget.initialProfession ?? _professions.first;
    _professionNameController = TextEditingController(
      text: widget.initialProfessionName ?? '',
    );
    _bioController = TextEditingController(text: widget.initialBio ?? '');
    _originalName = widget.initialName ?? '';
    _originalProfession = widget.initialProfession ?? _professions.first;
    _originalBio = widget.initialBio ?? '';

    _nameController.addListener(_onProfileFieldChanged);
    _professionNameController.addListener(_onProfileFieldChanged);
    _bioController.addListener(_onProfileFieldChanged);

    _fetchProfileImagesAndBio();
    _fetchPromptData();
  }

  void _onProfileFieldChanged() {
    setState(() {});
  }

  Future<void> _fetchProfileImagesAndBio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await account.get();
      final String currentUserId = user.$id;

      final userDoc = await databases.listDocuments(
        databaseId: _configService.get('DATABASE_ID'),
        collectionId: _configService.get('USERS_COLLECTIONID'),
        queries: [Query.equal('\$id', currentUserId)],
      );

      String? fetchedName;
      List<String> fetchedImages = List.filled(6, '');

      if (userDoc.documents.isNotEmpty) {
        final data = userDoc.documents.first.data;
        fetchedName = data['name'] as String?;

        final imageDocs = await databases.listDocuments(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('IMAGE_COLLECTIONID'),
          queries: [Query.equal('user', currentUserId)],
        );

        if (imageDocs.documents.isNotEmpty) {
          for (var doc in imageDocs.documents) {
            for (int i = 1; i <= 6; ++i) {
              final imageUrl = doc.data['image_$i'];
              if (imageUrl != null &&
                  imageUrl is String &&
                  imageUrl.isNotEmpty) {
                fetchedImages[i - 1] = imageUrl;
              }
            }
          }
        }
      }

      String? fetchedProfession;
      String? fetchedProfessionName;
      String? fetchedBio;
      final bioDataDocs = await databases.listDocuments(
        databaseId: _configService.get('DATABASE_ID'),
        collectionId: _configService.get('BIODATA_COLLECTIONID'),
        queries: [Query.equal('user', currentUserId)],
      );
      if (bioDataDocs.documents.isNotEmpty) {
        final data = bioDataDocs.documents.first.data;
        fetchedProfession = data['profession_type'] as String?;
        fetchedProfessionName = data['profession_name'] as String?;
        fetchedBio = data['bio'] as String?;
      }

      setState(() {
        _nameController.text = fetchedName ?? widget.initialName ?? '';
        _images = fetchedImages;
        _isLoading = false;
        _originalName = fetchedName ?? widget.initialName ?? '';
        _selectedProfession =
            fetchedProfession ?? widget.initialProfession ?? _professions.first;
        _professionNameController.text =
            fetchedProfessionName ?? widget.initialProfessionName ?? '';
        _bioController.text = fetchedBio ?? widget.initialBio ?? '';
        _originalProfession =
            fetchedProfession ?? widget.initialProfession ?? _professions.first;
        _originalBio = fetchedBio ?? widget.initialBio ?? '';
      });
    } on AppwriteException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? "Failed to load images.";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load images.";
      });
    }
  }

  Future<void> _fetchPromptData() async {
    setState(() {
      _isPromptLoading = true;
      _promptError = null;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      final bioDataDoc = await databases.listDocuments(
        databaseId: _configService.get('DATABASE_ID'),
        collectionId: _configService.get('BIODATA_COLLECTIONID'),
        queries: [
          Query.equal('user', userId),
          Query.select(['gender']),
        ],
      );
      if (bioDataDoc.documents.isEmpty) {
        setState(() {
          _promptError = "Could not determine gender.";
          _isPromptLoading = false;
        });
        return;
      }
      _gender = bioDataDoc.documents[0].data['gender']
          ?.toString()
          ?.toLowerCase();
      if (_gender == 'male') {
        _promptQuestions = _maleQuestions;
      } else if (_gender == 'female') {
        _promptQuestions = _femaleQuestions;
      } else {
        setState(() {
          _promptError = "Gender not set.";
          _isPromptLoading = false;
        });
        return;
      }

      final promptDocs = await databases.listDocuments(
        databaseId: _configService.get('DATABASE_ID'),
        collectionId: _configService.get('PROMPTS_COLLECTIONID'),
        queries: [Query.equal('user', userId)],
      );
      if (promptDocs.documents.isNotEmpty) {
        final data = promptDocs.documents[0].data;
        _promptDocId = promptDocs.documents[0].$id;
        for (int i = 0; i < 7; i++) {
          final answer = data['answer_${i + 1}'];
          if (answer != null) {
            final options = _promptQuestions[i]['options'] as List<String>;
            final idx = options.indexOf(answer);
            _promptAnswers[i] = idx >= 0 ? idx : null;
          }
        }
        _originalPromptAnswers = List<int?>.from(_promptAnswers);
      } else {
        _originalPromptAnswers = List<int?>.from(_promptAnswers);
      }
      setState(() {
        _isPromptLoading = false;
      });
    } catch (e) {
      setState(() {
        _promptError = "Failed to load prompts.";
        _isPromptLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onProfileFieldChanged);
    _professionNameController.removeListener(_onProfileFieldChanged);
    _bioController.removeListener(_onProfileFieldChanged);
    _nameController.dispose();
    _professionNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _setAsMainPhoto(int index) async {
    if (index < 0 ||
        index >= _images.length ||
        index == 0 ||
        _images[index].isEmpty)
      return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await account.get();
      final String currentUserId = user.$id;

      final imageDocs = await databases.listDocuments(
        databaseId: _configService.get('DATABASE_ID'),
        collectionId: _configService.get('IMAGE_COLLECTIONID'),
        queries: [Query.equal('user', currentUserId)],
      );

      if (imageDocs.documents.isNotEmpty) {
        final docId = imageDocs.documents.first.$id;
        Map<String, dynamic> updateData = {};

        setState(() {
          final temp = _images[0];
          _images[0] = _images[index];
          _images[index] = temp;
          _highlightedIndex = 0;
        });

        for (int i = 0; i < 6; i++) {
          String value = _images[i];
          if (value.isEmpty ||
              !(Uri.tryParse(value)?.hasAbsolutePath ?? false) ||
              !(Uri.tryParse(value)?.isAbsolute ?? false)) {
            updateData['image_${i + 1}'] = null;
          } else {
            updateData['image_${i + 1}'] = value;
          }
        }

        await databases.updateDocument(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('IMAGE_COLLECTIONID'),
          documentId: docId,
          data: updateData,
        );
      } else {
        setState(() {
          final temp = _images[0];
          _images[0] = _images[index];
          _images[index] = temp;
          _highlightedIndex = 0;
        });
      }
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Failed to set as main photo.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to set as main photo.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage(int index) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await account.get();
      final String currentUserId = user.$id;

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final storageFile = await storage.createFile(
        bucketId: _configService.get('STORAGE_BUCKETID'),
        fileId: ID.unique(),
        file: InputFile.fromPath(path: pickedFile.path),
      );

      String fileUrl =
          'https://sgp.cloud.appwrite.io/v1/storage/buckets/${_configService.get('STORAGE_BUCKETID') ?? "686c230b002fb6f5149e"}/files/${storageFile.$id}/view?project=${_configService.get('PROJECT_ID') ?? "696d271a00370d723a6c"}&mode=admin';

      final imageDocs = await databases.listDocuments(
        databaseId: _configService.get('DATABASE_ID'),
        collectionId: _configService.get('IMAGE_COLLECTIONID'),
        queries: [Query.equal('user', currentUserId)],
      );

      String imageField = 'image_${index + 1}';

      if (imageDocs.documents.isNotEmpty) {
        final docId = imageDocs.documents.first.$id;
        final Map<String, dynamic> updateData = {};
        updateData[imageField] = fileUrl;

        await databases.updateDocument(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('IMAGE_COLLECTIONID'),
          documentId: docId,
          data: updateData,
        );
      } else {
        final Map<String, dynamic> data = {
          'user': currentUserId,
          for (int i = 1; i <= 6; i++) 'image_$i': null,
        };
        data[imageField] = fileUrl;

        await databases.createDocument(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('IMAGE_COLLECTIONID'),
          documentId: ID.unique(),
          data: data,
        );
      }

      setState(() {
        _images[index] = fileUrl;
        _isLoading = false;
      });
    } on AppwriteException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? "Failed to upload image.";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to upload image.";
      });
    }
  }

  void _showImageActions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      builder: (context) {
        final isMain = index == 0;
        final hasImage = _images[index].isNotEmpty;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage && !isMain)
                ListTile(
                  leading: const Icon(Icons.star, color: kPrimaryColor),
                  title: const Text('Set as Main Photo', style: TextStyle(fontFamily: kFontFamily, color: kTextColor)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _setAsMainPhoto(index);
                  },
                ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.edit, color: kPrimaryColor),
                  title: const Text('Replace Photo', style: TextStyle(fontFamily: kFontFamily, color: kTextColor)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndUploadImage(index);
                  },
                ),
              if (hasImage)
                ListTile(
                  leading: Icon(
                    Icons.delete,
                    color: isMain ? Colors.grey : Colors.red,
                  ),
                  title: Text(
                    isMain ? 'Cannot delete main photo' : 'Delete Photo',
                    style: TextStyle(
                      color: isMain ? Colors.grey : Colors.red,
                      fontFamily: kFontFamily,
                    ),
                  ),
                  enabled: !isMain,
                  onTap: isMain
                      ? null
                      : () async {
                          setState(() {
                            _images[index] = '';
                          });
                          try {
                            final user = await account.get();
                            final String currentUserId = user.$id;
                            final imageDocs = await databases.listDocuments(
                              databaseId: _configService.get('DATABASE_ID'),
                              collectionId: _configService.get('IMAGE_COLLECTIONID'),
                              queries: [Query.equal('user', currentUserId)],
                            );
                            String imageField = 'image_${index + 1}';
                            if (imageDocs.documents.isNotEmpty) {
                              final docId = imageDocs.documents.first.$id;
                              await databases.updateDocument(
                                databaseId: _configService.get('DATABASE_ID'),
                                collectionId: _configService.get('IMAGE_COLLECTIONID'),
                                documentId: docId,
                                data: {imageField: null},
                              );
                            }
                          } catch (_) {}
                          Navigator.pop(context);
                        },
                ),
              if (!hasImage)
                ListTile(
                  leading: const Icon(Icons.add_a_photo, color: kPrimaryColor),
                  title: const Text('Add Photo', style: TextStyle(fontFamily: kFontFamily, color: kTextColor)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickAndUploadImage(index);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  bool get _isSaveEnabled {
    final nameChanged = (_nameController.text.trim() != (_originalName ?? ''));
    final professionChanged =
        (_selectedProfession != (_originalProfession ?? _professions.first));
    final bioChanged = (_bioController.text.trim() != (_originalBio ?? ''));
    final promptChanged = !_listEquals(_promptAnswers, _originalPromptAnswers);
    return nameChanged || professionChanged || bioChanged || promptChanged;
  }

  bool _listEquals(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _saveProfileChanges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      final nameChanged =
          (_nameController.text.trim() != (_originalName ?? ''));
      final professionChanged =
          (_selectedProfession != (_originalProfession ?? _professions.first));
      final bioChanged = (_bioController.text.trim() != (_originalBio ?? ''));
      final promptChanged = !_listEquals(
        _promptAnswers,
        _originalPromptAnswers,
      );

      bool updated = false;

      if (nameChanged) {
        await databases.updateDocument(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('USERS_COLLECTIONID'),
          documentId: userId,
          data: {'name': _nameController.text.trim()},
        );
        setState(() {
          _originalName = _nameController.text.trim();
        });
        updated = true;
      }

      if (professionChanged || bioChanged) {
        final biodDataDocument = await databases.listDocuments(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('BIODATA_COLLECTIONID'),
          queries: [Query.equal('user', userId)],
        );
        if (biodDataDocument.documents.isNotEmpty) {
          final updateData = <String, dynamic>{};
          if (professionChanged) {
            updateData['profession_type'] = _selectedProfession;
            updateData['profession_name'] = _professionNameController.text.trim();
          }
          if (bioChanged) {
            updateData['bio'] = _bioController.text.trim();
          }
          await databases.updateDocument(
            databaseId: _configService.get('DATABASE_ID'),
            collectionId: _configService.get('BIODATA_COLLECTIONID'),
            documentId: biodDataDocument.documents[0].$id,
            data: updateData,
          );
          setState(() {
            if (professionChanged) _originalProfession = _selectedProfession;
            if (bioChanged) _originalBio = _bioController.text.trim();
          });
          updated = true;
        } else {
          setState(() {
            _errorMessage = "Profile data not found.";
          });
          return false;
        }
      }

      if (promptChanged) {
        Map<String, dynamic> promptData = {'user': userId};
        for (int i = 0; i < 7; i++) {
          final idx = _promptAnswers[i];
          final options = _promptQuestions[i]['options'] as List<String>;
          promptData['answer_${i + 1}'] =
              (idx != null && idx >= 0 && idx < options.length)
              ? options[idx]
              : null;
        }

        if (_promptDocId != null) {
          await databases.updateDocument(
            databaseId: _configService.get('DATABASE_ID'),
            collectionId: _configService.get('PROMPTS_COLLECTIONID'),
            documentId: _promptDocId!,
            data: promptData,
          );
        } else {
          await databases.createDocument(
            databaseId: _configService.get('DATABASE_ID'),
            collectionId: _configService.get('PROMPTS_COLLECTIONID'),
            documentId: ID.unique(),
            data: promptData,
          );
        }
        setState(() {
          _originalPromptAnswers = List<int?>.from(_promptAnswers);
        });
        updated = true;
      }

      if (!nameChanged && !professionChanged && !bioChanged && !promptChanged) {
        setState(() {
          _errorMessage = "No changes to save.";
        });
        return false;
      }

      if (updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: kPrimaryColor),
                SizedBox(width: 12),
                Text(
                  "Updated successfully!",
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w500,
                    color: kTextColor,
                  ),
                ),
              ],
            ),
            backgroundColor: kBackgroundColor,
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kButtonRadius),
            ),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        );
        return true;
      }

      return false;
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Failed to save changes.";
      });
      return false;
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to save changes.";
      });
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePromptAnswers() async {
    setState(() {
      _isPromptLoading = true;
      _promptError = null;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      Map<String, dynamic> data = {'user': userId};
      for (int i = 0; i < 7; i++) {
        final idx = _promptAnswers[i];
        final options = _promptQuestions[i]['options'] as List<String>;
        data['answer_${i + 1}'] =
            (idx != null && idx >= 0 && idx < options.length)
            ? options[idx]
            : null;
      }

      if (_promptDocId != null) {
        await databases.updateDocument(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('PROMPTS_COLLECTIONID'),
          documentId: _promptDocId!,
          data: data,
        );
      } else {
        await databases.createDocument(
          databaseId: _configService.get('DATABASE_ID'),
          collectionId: _configService.get('PROMPTS_COLLECTIONID'),
          documentId: ID.unique(),
          data: data,
        );
      }

      setState(() {
        _isPromptLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Prompts updated!", style: TextStyle(fontFamily: kFontFamily, color: kTextColor)),
          backgroundColor: kBackgroundColor,
        ),
      );
    } catch (e) {
      setState(() {
        _promptError = "Failed to save prompts.";
        _isPromptLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.52;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kAccentColor),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontFamily: kFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: kAccentColor,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaveEnabled && !_isLoading
                      ? kPrimaryColor
                      : kPrimaryColor.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kButtonRadius),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  elevation: 0,
                  minimumSize: const Size(0, kButtonHeight),
                ),
                onPressed: _isSaveEnabled && !_isLoading
                    ? () async {
                        final success = await _saveProfileChanges();
                        if (success) {
                          Navigator.pop(context, true);
                        }
                      }
                    : null,
                child: const Text(
                  "Save",
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: kButtonFontSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: kAccentColor,
                            fontSize: 17,
                            fontFamily: kFontFamily,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kButtonRadius),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          ),
                          onPressed: _fetchProfileImagesAndBio,
                          child: const Text("Retry", style: TextStyle(fontFamily: kFontFamily, color: Colors.white)),
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
                            horizontal: 18,
                            vertical: 0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: kCardColor,
                              borderRadius: BorderRadius.circular(kCardRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(kCardRadius),
                                  child: _images.isNotEmpty && _images[0].isNotEmpty
                                      ? Image.network(
                                          _images[0],
                                          height: imageHeight,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          color: Colors.black.withOpacity(0.18),
                                          colorBlendMode: BlendMode.darken,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                                height: imageHeight,
                                                width: double.infinity,
                                                color: Colors.black.withOpacity(0.18),
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: kPrimaryColor,
                                                  size: 80,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          height: imageHeight,
                                          width: double.infinity,
                                          color: kPrimaryColor.withOpacity(0.10),
                                          child: const Icon(
                                            Icons.person,
                                            color: kPrimaryColor,
                                            size: 80,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 22,
                                  left: 22,
                                  right: 70,
                                  child: TextField(
                                    controller: _nameController,
                                    style: const TextStyle(
                                      fontFamily: kFontFamily,
                                      fontSize: 22,
                                      color: kAccentColor,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Your Name',
                                      hintStyle: TextStyle(
                                        color: kAccentColor.withOpacity(0.5),
                                        fontFamily: kFontFamily,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    cursorColor: kPrimaryColor,
                                  ),
                                ),
                                Positioned(
                                  top: 18,
                                  right: 18,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        _showImageActions(0);
                                      },
                                      child: const CircleAvatar(
                                        radius: 20,
                                        backgroundColor: kBackgroundColor,
                                        child: Icon(
                                          PhosphorIconsRegular.pencilSimple,
                                          size: 20,
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_images[0].isNotEmpty)
                                  Positioned(
                                    bottom: 18,
                                    left: 18,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kBackgroundColor.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.star,
                                            color: kPrimaryColor,
                                            size: 17,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "Main Photo",
                                            style: TextStyle(
                                              color: kPrimaryColor,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: kFontFamily,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: kSectionSpacing),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double spacing = 14;
                              final int crossAxisCount = 3;
                              final double itemWidth =
                                  (constraints.maxWidth -
                                      (spacing * (crossAxisCount - 1))) /
                                  crossAxisCount;
                              final double itemHeight = itemWidth * 0.68;

                              return SizedBox(
                                height: (itemHeight * 2) + spacing,
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: spacing,
                                        crossAxisSpacing: spacing,
                                        childAspectRatio: itemWidth / itemHeight,
                                      ),
                                  itemCount: 6,
                                  itemBuilder: (context, index) {
                                    final isHighlighted =
                                        index == _highlightedIndex;
                                    final hasImage =
                                        _images.isNotEmpty &&
                                        _images[index].isNotEmpty;
                                    return GestureDetector(
                                      onTap: () {
                                        _showImageActions(index);
                                      },
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isHighlighted
                                                    ? kPrimaryColor
                                                    : Colors.transparent,
                                                width: 3,
                                              ),
                                              borderRadius: BorderRadius.circular(
                                                14,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(
                                                14,
                                              ),
                                              child: hasImage
                                                  ? Image.network(
                                                      _images[index],
                                                      fit: BoxFit.cover,
                                                      width: itemWidth,
                                                      height: itemHeight,
                                                      errorBuilder: (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) =>
                                                          Container(
                                                        color: kBackgroundColor,
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                          color: kPrimaryColor,
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: itemWidth,
                                                      height: itemHeight,
                                                      color: kPrimaryColor.withOpacity(0.08),
                                                      child: const Center(
                                                        child: Icon(
                                                          PhosphorIconsRegular.plus,
                                                          color: kPrimaryColor,
                                                          size: 26,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (isHighlighted &&
                                              index != 0 &&
                                              hasImage)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: kBackgroundColor.withOpacity(0.92),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Icon(
                                                      Icons.star,
                                                      color: kPrimaryColor,
                                                      size: 13,
                                                    ),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      "Main",
                                                      style: TextStyle(
                                                        color: kPrimaryColor,
                                                        fontWeight: FontWeight.w600,
                                                        fontFamily: kFontFamily,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (hasImage)
                                            Positioned.fill(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(14),
                                                  splashColor: kPrimaryColor.withOpacity(0.08),
                                                  highlightColor: kPrimaryColor.withOpacity(0.04),
                                                  onTap: () {
                                                    _showImageActions(index);
                                                  },
                                                ),
                                              ),
                                            ),
                                          if (hasImage)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: kBackgroundColor.withOpacity(0.92),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.more_horiz,
                                                  size: 18,
                                                  color: kPrimaryColor,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: kSectionSpacing),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Card(
                            color: kCardColor,
                            elevation: kCardElevation,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kCardRadius),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kCardPadding,
                                vertical: kCardPadding,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Profession",
                                    style: TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                      color: kAccentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _selectedProfession,
                                    items: _professions
                                        .map(
                                          (profession) => DropdownMenuItem<String>(
                                            value: profession,
                                            child: Text(
                                              profession,
                                              style: const TextStyle(
                                                fontFamily: kFontFamily,
                                                fontSize: 15,
                                                color: kAccentColor,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedProfession = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(kFieldRadius),
                                        borderSide: const BorderSide(
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: kBackgroundColor,
                                    ),
                                    icon: const Icon(
                                      PhosphorIconsRegular.caretDown,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _professionNameController,
                                    decoration: InputDecoration(
                                      labelText: "Profession Name",
                                      labelStyle: const TextStyle(
                                        fontFamily: kFontFamily,
                                        color: kPrimaryColor,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(kFieldRadius),
                                        borderSide: const BorderSide(
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: kBackgroundColor,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "Bio",
                                    style: TextStyle(
                                      fontFamily: kFontFamily,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                      color: kAccentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _bioController,
                                    maxLength: 150,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: "Tell us about yourself",
                                      labelStyle: const TextStyle(
                                        fontFamily: kFontFamily,
                                        color: kPrimaryColor,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(kFieldRadius),
                                        borderSide: const BorderSide(
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: kBackgroundColor,
                                      counterStyle: const TextStyle(
                                        fontFamily: kFontFamily,
                                        fontSize: 12,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSectionSpacing),
                        if (_isPromptLoading)
                          Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                          )
                        else if (_promptError != null)
                          Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Text(
                              _promptError!,
                              style: const TextStyle(color: Colors.red, fontFamily: kFontFamily),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Card(
                              color: kCardColor,
                              elevation: kCardElevation,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kCardRadius),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(kCardPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Edit Prompts",
                                      style: TextStyle(
                                        fontFamily: kFontFamily,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 17,
                                        color: kAccentColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    for (int i = 0; i < _promptQuestions.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 32.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _promptQuestions[i]['question'],
                                              style: const TextStyle(
                                                fontFamily: kFontFamily,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 22,
                                                color: kPrimaryColor,
                                                height: 1.3,
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: List<Widget>.generate(
                                                (_promptQuestions[i]['options'] as List<String>).length,
                                                (idx) => ChoiceChip(
                                                  label: Text(
                                                    _promptQuestions[i]['options'][idx],
                                                    style: TextStyle(
                                                      fontFamily: kFontFamily,
                                                      fontSize: 14,
                                                      color: _promptAnswers[i] == idx
                                                          ? Colors.white
                                                          : kAccentColor,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  selected: _promptAnswers[i] == idx,
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      _promptAnswers[i] = selected ? idx : null;
                                                    });
                                                    _onProfileFieldChanged();
                                                  },
                                                  selectedColor: kPrimaryColor,
                                                  backgroundColor: kBackgroundColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                    side: BorderSide(
                                                      color: _promptAnswers[i] == idx
                                                          ? kPrimaryColor
                                                          : Colors.transparent,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                  elevation: _promptAnswers[i] == idx ? 3 : 0,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: kSectionSpacing),
                      ],
                    ),
                  ),
                ),
    );
  }
}
