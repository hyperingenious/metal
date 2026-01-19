import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BioSection extends StatelessWidget {
  final String? bio;

  const BioSection({super.key, this.bio});

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
                  PhosphorIconsRegular.quotes,
                  color: Color(0xFF8B4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "About",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio ?? "✨ Getting to know each other is the best part!",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: bio != null ? const Color(0xFF3B2357) : const Color(0xFF8B4DFF),
              height: 1.6,
            ),
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