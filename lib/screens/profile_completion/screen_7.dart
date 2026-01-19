import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/screens/profile_completion/screen_8.dart';
import 'package:lushh/services/config_service.dart';

final databaseId = ConfigService().get('DATABASE_ID');
final completionStatusCollectionId = ConfigService().get('COMPLETION_STATUS_COLLECTIONID');
final imagesCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final storageBucketId = ConfigService().get('STORAGE_BUCKETID') ?? "686c230b002fb6f5149e";
final appwriteProjectId = ConfigService().get('PROJECT_ID') ?? "696d271a00370d723a6c";

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

  final ImagePicker _picker = ImagePicker();

  final Color themeColor = Colors.black;
  final Color accentColor = const Color(0xFF6D4B86);

  @override
  void initState() {
    super.initState();
    _selectedImages = List<XFile?>.filled(maxImages, null, growable: false);
  }

  int get _imageCount => _selectedImages.where((img) => img != null).length;
  List<XFile> get _imagesForUpload =>
      _selectedImages.whereType<XFile>().toList();

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
            'https://sgp.cloud.appwrite.io/v1/storage/buckets/$storageBucketId/files/${storageFile.$id}/view?project=$appwriteProjectId&mode=admin';
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
            ...{
              for (int i = 0; i < imageUrls.length; i++)
                'image_${i + 1}': imageUrls[i],
            },
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
          data: {'isAllImagesAdded': true},
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
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final image = _selectedImages[index];
        if (image != null) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _removeImageAt(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
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
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withOpacity(0.25),
                  width: 1.3,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        color: accentColor.withOpacity(0.85), size: 30),
                    const SizedBox(height: 6),
                    Text(
                      "Add",
                      style: TextStyle(
                        color: accentColor.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
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
      backgroundColor: const Color(0xfffafafa),
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
          ),
        ),
        iconTheme: IconThemeData(color: themeColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      "Upload at least 4 images of yourself",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Pick your best photos. You can add up to 6 images.",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _buildImageGrid(),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
