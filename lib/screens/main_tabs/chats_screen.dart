import 'package:flutter/material.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy chat data
    final List<Map<String, String>> chats = List.generate(6, (index) {
      return {
        'name': 'Kamal Kumar',
        'message': '✅ Bandi free nhi hai bhai',
        'time': '1:21 am',
        'avatar':
            'https://images.unsplash.com/photo-1511367461989-f85a21fda167?auto=format&fit=facearea&w=400&h=400&facepad=2.5',
      };
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3E6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: const Color(0xFFF3E6FA),
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: const Text(
            'Chats',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Color(0xFF3B2357),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Icon(
                Icons.search,
                color: const Color(0xFF3B2357),
                size: 26,
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: chats.length,
        separatorBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(left: 72, right: 0),
          height: 1,
          color: const Color(0xFFE5D3F3),
        ),
        itemBuilder: (context, index) {
          final chat = chats[index];
          return Padding(
            padding: const EdgeInsets.only(left: 8, right: 0),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 8, right: 8, top: 0, bottom: 0),
              leading: CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(chat['avatar']!),
              ),
              title: Text(
                chat['name']!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15.5,
                  color: Color(0xFF3B2357),
                  height: 1.1,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  chat['message']!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                    color: Color(0xFF6D4B86),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  chat['time']!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: 11.5,
                    color: Color(0xFF6D4B86),
                  ),
                ),
              ),
              horizontalTitleGap: 12,
              minVerticalPadding: 12,
            ),
          );
        },
      ),
    );
  }
}
