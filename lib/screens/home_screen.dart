import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../appwrite/appwrite.dart';
import 'main_tabs/profile_screen.dart';
import 'main_tabs/explore_screen.dart';
import 'main_tabs/notifications_screen.dart';
import 'main_tabs/chats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ProfileScreen(),
    ExploreScreen(),
    NotificationsScreen(),
    ChatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xfff8ebf9),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000), // very light black, 10% opacity
              blurRadius: 16,
              spreadRadius: 0,
              offset: Offset(0, -2), // shadow at the top
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          selectedItemColor: const Color(0xFF412758),
          unselectedItemColor: const Color(0xFF412758),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xfff8ebf9),
          elevation: 0, // Remove default shadow
          items: [
            BottomNavigationBarItem(
              icon: _currentIndex == 0
                  ? const PhosphorIcon(PhosphorIconsFill.user, color: Color(0xFF412758), size: 30.0,)
                  : const PhosphorIcon(PhosphorIconsRegular.user, color: Color(0xFF412758), size: 30.0,),
              label: "Profile",
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 1
                  ? const PhosphorIcon(PhosphorIconsFill.magnifyingGlass, color: Color(0xFF412758), size: 30.0,)
                  : const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, color: Color(0xFF412758), size: 30.0,),
              label: "Explore",
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 2
                  ? const PhosphorIcon(PhosphorIconsFill.bell, color: Color(0xFF412758), size: 30.0,)
                  : const PhosphorIcon(PhosphorIconsRegular.bell, color: Color(0xFF412758), size: 30.0,),
              label: "Notifications",
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 3
                  ? const PhosphorIcon(PhosphorIconsFill.chatsCircle, color: Color(0xFF412758), size: 30.0,)
                  : const PhosphorIcon(PhosphorIconsRegular.chatsCircle, color: Color(0xFF412758), size: 30.0,),
              label: "Chats",
            ),
          ],
        ),
      ),
    );
  }
}
