import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DetailsSection extends StatelessWidget {
  final String? heightDisplay;
  final String? city;
  final String? state;
  final String? country;
  final double? distanceKm;
  final bool distanceLoading;
  final String? distanceError;

  const DetailsSection({
    super.key,
    this.heightDisplay,
    this.city,
    this.state,
    this.country,
    this.distanceKm,
    required this.distanceLoading,
    this.distanceError,
  });

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
                  PhosphorIconsRegular.info,
                  color: Color(0xFF8B4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Details",
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

          if (heightDisplay != null && heightDisplay!.isNotEmpty) ...[
            _buildDetailRow(
              PhosphorIconsRegular.ruler,
              "Height",
              heightDisplay!,
            ),
            const SizedBox(height: 12),
          ],

          if ((city != null && city!.isNotEmpty) ||
              (state != null && state!.isNotEmpty)) ...[
            _buildDetailRow(
              PhosphorIconsRegular.mapPin,
              "Lives in",
              "${city ?? ''}${(city != null && city!.isNotEmpty && state != null && state!.isNotEmpty) ? ', ' : ''}${state ?? ''}",
            ),
            const SizedBox(height: 12),
          ],

          if (country != null && country!.isNotEmpty) ...[
            _buildDetailRow(
              PhosphorIconsRegular.globe,
              "From",
              country!,
            ),
            const SizedBox(height: 12),
          ],

          if (distanceKm != null) ...[
            _buildDetailRow(
              PhosphorIconsRegular.path,
              "Distance",
              "${distanceKm!.round()} km away",
            ),
          ] else if (distanceLoading) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4DFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B4DFF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Calculating distance...",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFF6D4B86),
                  ),
                ),
              ],
            ),
          ] else if (distanceError != null) ...[
            _buildDetailRow(
              PhosphorIconsRegular.warningCircle,
              "Distance",
              distanceError!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4DFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF8B4DFF), size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF6D4B86),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Color(0xFF3B2357),
            ),
          ),
        ),
      ],
    );
  }
}