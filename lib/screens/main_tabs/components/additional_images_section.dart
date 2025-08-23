import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AdditionalImagesSection extends StatelessWidget {
  final List<String> images;
  final double screenHeight;
  final Widget? insertAfterIndexOne;

  const AdditionalImagesSection({
    super.key,
    required this.images,
    required this.screenHeight,
    this.insertAfterIndexOne,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...images.asMap().entries.expand((entry) {
          final idx = entry.key;
          final imgUrl = entry.value;
          final widgets = <Widget>[];

          if (imgUrl.isNotEmpty) {
            widgets.add(
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    width: double.infinity,
                    height: screenHeight * 0.7,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: screenHeight * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8B4DFF),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: screenHeight * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.image,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          if (idx == 1 && insertAfterIndexOne != null) {
            widgets.add(insertAfterIndexOne!);
          }
          return widgets;
        }).toList(),
      ],
    );
  }
}