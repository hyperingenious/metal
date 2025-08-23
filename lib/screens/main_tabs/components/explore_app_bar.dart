// lib/screens/main_tabs/components/explore_app_bar.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExploreAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback? onSettings;

  const ExploreAppBar({
    super.key,
    this.canUndo = false,
    this.onUndo,
    this.onSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Text(
        'Lushh',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: Color(0xFF2D1B3A),
        ),
      ),
      actions: [
        if (canUndo)
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.arrowUUpLeft,
              color: Colors.black,
              size: 28,
            ),
            onPressed: onUndo,
            splashRadius: 22,
            tooltip: 'Back',
          ),
        IconButton(
          icon: const Icon(
            PhosphorIconsRegular.gearSix,
            color: Color(0xFF6D4B86),
            size: 22,
          ),
          onPressed: onSettings ??
              () {
                Navigator.pushNamed(context, '/settings');
              },
          splashRadius: 22,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}