import 'package:flutter/material.dart';

class PrimaryGradientButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;

  const PrimaryGradientButton({
    super.key,
    required this.text,
    this.icon,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B4DFF), Color(0xFFA855FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4DFF).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 24),
            if (!loading && icon != null) const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}