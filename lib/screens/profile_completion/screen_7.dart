import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:metal/screens/profile_completion/screen_8.dart';

class AddImagesScreen extends StatefulWidget {
  const AddImagesScreen({super.key});

  @override
  State<AddImagesScreen> createState() => _AddImagesScreenState();
}

class _AddImagesScreenState extends State<AddImagesScreen> {
  final int minImages = 4;
  final int maxImages = 6;
  late List<XFile?> _selectedImages;
  bool _loading = false;

  String databaseId = '685a90fa0009384c5189';
  String completionStatusCollectionId = '686777d300169b27b237';
  String imagesCollectionId = '685aa0ef00090023c8a3';
  String storageBucketId = '686c230b002fb6f5149e';

  final ImagePicker _picker = ImagePicker();

  // Theme colors (align with other screens)
  final Color themeColor = Colors.black;
  final Color accentColor = const Color(0xFF6D4B86);

  @override
  void initState() {
    super.initState();
    _selectedImages = List<XFile?>.filled(maxImages, null, growable: false);
  }

  int get _imageCount => _selectedImages.where((img) => img != null).length;
  List<XFile> get _imagesForUpload => _selectedImages.whereType<XFile>().toList();

  Future<void> _pickImages() async {
    final List<XFile>? picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        int slot = 0;
        for (int i = 0; i < maxImages && slot < picked.length; i++) {
          if (_selectedImages[i] == null) {
            _selectedImages[i] = picked[slot];
            slot++;
          }
        }
      });
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _selectedImages[index] = null;
    });
  }

  Future<void> _submit() async {
    if (_imageCount < minImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select at least $minImages images"),
          backgroundColor: accentColor,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final user = await account.get();
      final userId = user.$id;

      List<String> imageUrls = [];
      for (final image in _imagesForUpload) {
        final fileBytes = await image.readAsBytes();
        final fileName = image.name;

        final storageFile = await storage.createFile(
          bucketId: storageBucketId,
          fileId: ID.unique(),
          file: InputFile.fromBytes(bytes: fileBytes, filename: fileName),
        );

        String url =
            'https://fra.cloud.appwrite.io/v1/storage/buckets/$storageBucketId/files/${storageFile.$id}/view?project=685a8d7a001b583de71d&mode=admin';
        imageUrls.add(url);
      }

      final imagesDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: imagesCollectionId,
        queries: [
          Query.equal('user', userId),
          Query.select(['\$id']),
        ],
      );

      if (imagesDoc.documents.isNotEmpty) {
        final docId = imagesDoc.documents[0].$id;
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: imagesCollectionId,
          documentId: docId,
          data: {
            for (int i = 0; i < imageUrls.length; i++)
              'image_${i + 1}': imageUrls[i],
          },
        );
      } else {
        await databases.createDocument(
          databaseId: databaseId,
          collectionId: imagesCollectionId,
          documentId: ID.unique(),
          data: {
            'user': userId,
            ...{for (int i = 0; i < imageUrls.length; i++) 'image_${i + 1}': imageUrls[i]},
          },
        );
      }

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
          data: {'isAllImagesAdded': true,},
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AddLocationScreen()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Images uploaded successfully!"),
          backgroundColor: accentColor,
        ),
      );
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Appwrite error: ${e.message ?? 'Unknown error'}"),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An unexpected error occurred: $e"),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: maxImages,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final image = _selectedImages[index];
        if (image != null) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImageAt(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withOpacity(0.18), width: 1.2),
              ),
              child: Center(
                child: Icon(
                  Icons.add_a_photo,
                  color: accentColor,
                  size: 32,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Add Your Images",
          style: TextStyle(
            color: themeColor,
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: IconThemeData(color: themeColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                "Upload at least 4 images of yourself",
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
                "Pick your best photos. You can add up to 6 images.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.7),
                  fontFamily: 'SF Pro Display',
                ),
              ),
              const SizedBox(height: 28),
              _buildImageGrid(),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
