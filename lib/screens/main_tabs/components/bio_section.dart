import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BioSection extends StatelessWidget {
  final String? bio;

  const BioSection({super.key, this.bio});

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
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}