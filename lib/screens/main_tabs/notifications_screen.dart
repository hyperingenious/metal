import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data for notifications
    final notifications = [
      {
        'icon': PhosphorIconsFill.heart,
        'iconBg': const Color(0xFF6D4B86),
        'userImg': 'https://randomuser.me/api/portraits/women/1.jpg',
        'userName': 'Alex Siri',
        'message': 'Showed interest in you!',
        'time': '7:55 PM',
        'highlight': true,
      },
      {
        'icon': PhosphorIconsFill.calendarHeart,
        'iconBg': const Color(0xFF6D4B86),
        'userImg': 'https://randomuser.me/api/portraits/women/2.jpg',
        'userName': 'Cute Girl 22',
        'message': 'Asked for a date!',
        'time': '7:55 PM',
        'highlight': false,
      },
      {
        'icon': PhosphorIconsFill.chatCircleText,
        'iconBg': const Color(0xFF6D4B86),
        'userImg': 'https://randomuser.me/api/portraits/men/3.jpg',
        'userName': 'GOD',
        'message': 'Messaged You',
        'time': '7:55 PM',
        'highlight': false,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEAD6F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: const Color(0xFFEAD6F7),
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            'Notifications',
            style: TextStyle(
              color: Color(0xFF3B2357),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF3B2357), size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
            splashRadius: 22,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Container(
            color: notif['highlight'] == true ? const Color(0xFFD6BEEA) : Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: notif['iconBg'] as Color,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: PhosphorIcon(
                      notif['icon'] as IconData,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(notif['userImg'] as String),
                  ),
                ],
              ),
              title: Text(
                notif['userName'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF3B2357),
                ),
              ),
              subtitle: Text(
                notif['message'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Color(0xFF6D4B86),
                ),
              ),
              trailing: Text(
                notif['time'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  color: Color(0xFF6D4B86),
                ),
              ),
              horizontalTitleGap: 12,
              minLeadingWidth: 0,
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
