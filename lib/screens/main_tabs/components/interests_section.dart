import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InterestsSection extends StatelessWidget {
  final List<dynamic> hobbies;

  const InterestsSection({super.key, required this.hobbies});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4DFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsRegular.heart,
                  color: Color(0xFF8B4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Interests",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          hobbies.isNotEmpty
              ? Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B4DFF).withOpacity(0.1),
                            const Color(0xFFA855FF).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF8B4DFF).withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        hobbyName.isNotEmpty
                            ? '${hobbyName[0].toUpperCase()}${hobbyName.substring(1)}'
                            : hobbyCategory,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF8B4DFF),
                        ),
                      ),
                    );
                  }).toList(),
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B4DFF).withOpacity(0.1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.smiley,
                        color: Color(0xFF8B4DFF),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Interests coming soon...",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Color(0xFF8B4DFF),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}