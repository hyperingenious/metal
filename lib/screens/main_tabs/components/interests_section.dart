import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InterestsSection extends StatelessWidget {
  final List<dynamic> hobbies;

  const InterestsSection({super.key, required this.hobbies});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
                            const Color(0xFF8B4DFF).withOpacity(0.15),
                            const Color(0xFFA855FF).withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
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
              : Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.smiley,
                      color: const Color(0xFF8B4DFF).withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Interests coming soon...",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: const Color(0xFF8B4DFF).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B4DFF).withOpacity(0.2),
                  const Color(0xFF8B4DFF).withOpacity(0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}