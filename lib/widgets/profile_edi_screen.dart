import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:metal/appwrite/appwrite.dart'; // Import your Appwrite client
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String bioDataCollectionId = '685aac1d0013a8a6752f';
  final String _databaseId = '685a90fa0009384c5189';
  final String _userCollectionId = '68616ecc00163ed41e57';
  final String _imagesCollectionId = '685aa0ef00090023c8a3';
  final String _storageBucketId =
      '686c230b002fb6f5149e'; // Use your storage bucket id

  late TextEditingController _nameController;
  late List<String> _images;
  int _highlightedIndex = 0;

  // Profession dropdown
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

  // For change detection
  String? _originalName;
  String? _originalProfession;
  String? _originalBio;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _images = List<String>.from(widget.initialImages);
    // Ensure _images is always length 6
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
    _bioController = TextEditingController(
      text: widget.initialBio ?? '',
    );
    _originalName = widget.initialName ?? '';
    _originalProfession = widget.initialProfession ?? _professions.first;
    _originalBio = widget.initialBio ?? '';

    // Listen for changes to update the UI for the Save button
    _nameController.addListener(_onProfileFieldChanged);
    _professionNameController.addListener(_onProfileFieldChanged);
    _bioController.addListener(_onProfileFieldChanged);

    _fetchProfileImagesAndBio();
  }

  void _onProfileFieldChanged() {
    setState(() {}); // Triggers rebuild for Save button enable/disable
  }

  Future<void> _fetchProfileImagesAndBio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final user = await account.get();
      final String currentUserId = user.$id;

      // Fetch user document
      final userDoc = await databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _userCollectionId,
        queries: [Query.equal('\$id', currentUserId)],
      );

      String? fetchedName;
      List<String> fetchedImages = List.filled(6, '');

      if (userDoc.documents.isNotEmpty) {
        final data = userDoc.documents.first.data;
        fetchedName = data['name'] as String?;

        final imageDocs = await databases.listDocuments(
          databaseId: _databaseId,
          collectionId: _imagesCollectionId,
          queries: [Query.equal('user', currentUserId)],
        );

        if (imageDocs.documents.isNotEmpty) {
          // Only fill the 6 slots, don't append more than 6
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

      // Fetch profession and bio from biodata collection
      String? fetchedProfession;
      String? fetchedProfessionName;
      String? fetchedBio;
      final bioDataDocs = await databases.listDocuments(
        databaseId: _databaseId,
        collectionId: bioDataCollectionId,
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
        _selectedProfession = fetchedProfession ?? widget.initialProfession ?? _professions.first;
        _professionNameController.text = fetchedProfessionName ?? widget.initialProfessionName ?? '';
        _bioController.text = fetchedBio ?? widget.initialBio ?? '';
        _originalProfession = fetchedProfession ?? widget.initialProfession ?? _professions.first;
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

  // Swap images and update Appwrite image collection so that the selected image becomes image_1
  Future<void> _setAsMainPhoto(int index) async {
    if (index < 0 ||
        index >= _images.length ||
        index == 0 ||
        _images[index].isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await account.get();
      final String currentUserId = user.$id;

      // Find the user's image document in the images collection
      final imageDocs = await databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _imagesCollectionId,
        queries: [Query.equal('user', currentUserId)],
      );

      if (imageDocs.documents.isNotEmpty) {
        final docId = imageDocs.documents.first.$id;
        // Prepare new image fields: swap image_1 and image_{index+1}
        Map<String, dynamic> updateData = {};

        // Swap in local list
        setState(() {
          final temp = _images[0];
          _images[0] = _images[index];
          _images[index] = temp;
          _highlightedIndex = 0;
        });

        // For each image field, ensure that if the value is not a valid URL, set it to null
        for (int i = 0; i < 6; i++) {
          String value = _images[i];
          // If the value is empty or not a valid URL, set to null
          if (value.isEmpty ||
              !(Uri.tryParse(value)?.hasAbsolutePath ?? false) ||
              !(Uri.tryParse(value)?.isAbsolute ?? false)) {
            updateData['image_${i + 1}'] = null;
          } else {
            updateData['image_${i + 1}'] = value;
          }
        }

        await databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _imagesCollectionId,
          documentId: docId,
          data: updateData,
        );
      } else {
        // No document found, just swap locally
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

  // Helper: Pick image from gallery and upload to Appwrite, then update image collection
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

      // Upload to Appwrite Storage
      final storageFile = await storage.createFile(
        bucketId: _storageBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: pickedFile.path),
      );

      // Get the file URL
      String fileUrl =
          'https://fra.cloud.appwrite.io/v1/storage/buckets/$_storageBucketId/files/${storageFile.$id}/view?project=685a8d7a001b583de71d&mode=admin';

      // Find the user's image document in the images collection
      final imageDocs = await databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _imagesCollectionId,
        queries: [Query.equal('user', currentUserId)],
      );

      String imageField = 'image_${index + 1}';

      if (imageDocs.documents.isNotEmpty) {
        // Update the existing document
        final docId = imageDocs.documents.first.$id;
        final Map<String, dynamic> updateData = {};
        updateData[imageField] = fileUrl;

        await databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _imagesCollectionId,
          documentId: docId,
          data: updateData,
        );
      } else {
        // Create a new document with all 6 image fields, only one filled
        final Map<String, dynamic> data = {
          'user': currentUserId,
          for (int i = 1; i <= 6; i++) 'image_$i': null,
        };
        data[imageField] = fileUrl;

        await databases.createDocument(
          databaseId: _databaseId,
          collectionId: _imagesCollectionId,
          documentId: ID.unique(),
          data: data,
        );
      }

      // Update local state
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

  // New: Show a modal bottom sheet for image actions (set as main, replace, delete, add)
  void _showImageActions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  leading: const Icon(Icons.star, color: Color(0xFF7B4AE2)),
                  title: const Text('Set as Main Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _setAsMainPhoto(index);
                  },
                ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF7B4AE2)),
                  title: const Text('Replace Photo'),
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
                    style: TextStyle(color: isMain ? Colors.grey : Colors.red),
                  ),
                  enabled: !isMain,
                  onTap: isMain
                      ? null
                      : () async {
                          setState(() {
                            _images[index] = '';
                          });
                          // Also update Appwrite image collection
                          try {
                            final user = await account.get();
                            final String currentUserId = user.$id;
                            final imageDocs = await databases.listDocuments(
                              databaseId: _databaseId,
                              collectionId: _imagesCollectionId,
                              queries: [Query.equal('user', currentUserId)],
                            );
                            String imageField = 'image_${index + 1}';
                            if (imageDocs.documents.isNotEmpty) {
                              final docId = imageDocs.documents.first.$id;
                              // Set the field to null for deletion
                              await databases.updateDocument(
                                databaseId: _databaseId,
                                collectionId: _imagesCollectionId,
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
                  leading: const Icon(
                    Icons.add_a_photo,
                    color: Color(0xFF7B4AE2),
                  ),
                  title: const Text('Add Photo'),
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

  // Function to check if Save Changes button should be enabled
  bool get _isSaveEnabled {
    final nameChanged = (_nameController.text.trim() != (_originalName ?? ''));
    final professionChanged =
        (_selectedProfession != (_originalProfession ?? _professions.first));
    final bioChanged = (_bioController.text.trim() != (_originalBio ?? ''));
    return nameChanged || professionChanged || bioChanged;
  }

  // The function to be called on save (to be implemented by you)
  Future<void> _saveProfileChanges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      final nameChanged = (_nameController.text.trim() != (_originalName ?? ''));
      final professionChanged =
          (_selectedProfession != (_originalProfession ?? _professions.first));
      final bioChanged = (_bioController.text.trim() != (_originalBio ?? ''));

      bool updated = false;

      // Update name in user collection if changed
      if (nameChanged) {
        await databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _userCollectionId,
          documentId: userId,
          data: {
            'name': _nameController.text.trim(),
          },
        );
        setState(() {
          _originalName = _nameController.text.trim();
        });
        updated = true;
      }

      // Update profession and/or bio in biodata collection if changed
      if (professionChanged || bioChanged) {
        final biodDataDocument = await databases.listDocuments(
          databaseId: _databaseId,
          collectionId: bioDataCollectionId,
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
            databaseId: _databaseId,
            collectionId: bioDataCollectionId,
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
        }
      }

      // If nothing was updated, show a message (optional)
      if (!nameChanged && !professionChanged && !bioChanged) {
        setState(() {
          _errorMessage = "No changes to save.";
        });
      }

      // Show beautiful themed snackbar if updated
      if (updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Color(0xFF7B4AE2)),
                SizedBox(width: 12),
                Text(
                  "Updated successfully!",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3B2357),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFF8EBF9),
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        );
      }
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Failed to save changes.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to save changes.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3B2357)),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF3B2357),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaveEnabled && !_isLoading
                      ? const Color(0xFF7B4AE2)
                      : const Color(0xFF7B4AE2).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                ),
                onPressed: _isSaveEnabled && !_isLoading
                    ? () async {
                        await _saveProfileChanges();
                      }
                    : null,
                child: const Text(
                  "Save",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF3B2357),
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchProfileImagesAndBio,
                      child: const Text("Retry"),
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
                              child: _images.isNotEmpty && _images[0].isNotEmpty
                                  ? Image.network(
                                      _images[0],
                                      height: imageHeight,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      color: Colors.black.withOpacity(0.25),
                                      colorBlendMode: BlendMode.darken,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: imageHeight,
                                                width: double.infinity,
                                                color: Colors.black.withOpacity(
                                                  0.25,
                                                ),
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.white,
                                                  size: 80,
                                                ),
                                              ),
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
                            // Name field
                            Positioned(
                              top: 18,
                              left: 18,
                              right: 60,
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Your Name',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                cursorColor: Colors.white,
                              ),
                            ),
                            // Edit image button (for main image)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    _showImageActions(0);
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
                            // New: Main photo badge
                            if (_images[0].isNotEmpty)
                              Positioned(
                                bottom: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.star,
                                        color: Color(0xFF7B4AE2),
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Main Photo",
                                        style: TextStyle(
                                          color: Color(0xFF7B4AE2),
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
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
                    const SizedBox(height: 32),
                    // Images grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double spacing = 16;
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
                                                ? const Color(0xFF7B4AE2)
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
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Container(
                                                        color: Colors.grey[300],
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  width: itemWidth,
                                                  height: itemHeight,
                                                  color: const Color(
                                                    0xFFD9D9D9,
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      PhosphorIconsRegular.plus,
                                                      color: Color(0xFF7B4AE2),
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      // Main badge for highlighted image (not slot 0)
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
                                              color: Colors.white.withOpacity(
                                                0.85,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.star,
                                                  color: Color(0xFF7B4AE2),
                                                  size: 13,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  "Main",
                                                  style: TextStyle(
                                                    color: Color(0xFF7B4AE2),
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: 'Poppins',
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Overlay a subtle action hint
                                      if (hasImage)
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              splashColor: Colors.black
                                                  .withOpacity(0.08),
                                              highlightColor: Colors.black
                                                  .withOpacity(0.04),
                                              onTap: () {
                                                _showImageActions(index);
                                              },
                                            ),
                                          ),
                                        ),
                                      // Add a subtle "..." icon for more actions
                                      if (hasImage)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.85,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.more_horiz,
                                              size: 18,
                                              color: Color(0xFF7B4AE2),
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
                    const SizedBox(height: 32),
                    // Profession and Bio section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Profession",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF3B2357),
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
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Color(0xFF3B2357),
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
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7B4AE2),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8EBF9),
                                ),
                                icon: const Icon(
                                  PhosphorIconsRegular.caretDown,
                                  color: Color(0xFF7B4AE2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _professionNameController,
                                decoration: InputDecoration(
                                  labelText: "Profession Name",
                                  labelStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF7B4AE2),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7B4AE2),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8EBF9),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Bio",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF3B2357),
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
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF7B4AE2),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7B4AE2),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8EBF9),
                                  counterStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF7B4AE2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Save Changes button removed from here
                    // const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
