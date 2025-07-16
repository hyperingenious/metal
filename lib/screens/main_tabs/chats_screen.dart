import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../../appwrite/appwrite.dart';

Future<List<Map<String, dynamic>>> fetchActiveChats() async {
  try {
    // Get JWT for authentication
    final jwt = await account.createJWT();
    final token = jwt.jwt;

    final uri = Uri.parse('http://localhost:3000/api/v1/chats/active');
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer $token');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception(
        jsonDecode(body)['error'] ?? 'Failed to fetch active chats',
      );
    }

    final Map<String, dynamic> decoded = jsonDecode(body);
    final List<dynamic> data = decoded['chats'] ?? [];
    return data.cast<Map<String, dynamic>>();
  } catch (e) {
    return [];
  }
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<List<Map<String, dynamic>>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatsFuture = fetchActiveChats();
  }

  @override
  Widget build(BuildContext context) {
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load chats',
                style: const TextStyle(
                  color: Colors.red,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return const Center(
              child: Text(
                'no connections made yet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black,
                  letterSpacing: 0.1,
                ),
              ),
            );
          }
          return ListView.separated(
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
                    backgroundImage: chat['partnerPhotoUrl'] != null && chat['partnerPhotoUrl'].toString().isNotEmpty
                        ? NetworkImage(chat['partnerPhotoUrl'])
                        : null,
                    child: (chat['partnerPhotoUrl'] == null || chat['partnerPhotoUrl'].toString().isEmpty)
                        ? const Icon(Icons.person, color: Color(0xFF6D4B86))
                        : null,
                  ),
                  title: Text(
                    chat['partnerName'] ?? 'Unknown',
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
                      // You can show messageCount or dateProposalStatus or a placeholder
                      'Messages: ${chat['messageCount'] ?? 0} | Status: ${chat['dateProposalStatus'] ?? 'none'}',
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
                      '', // No time field in API, leave blank or add if available
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
                  onTap: () {
                    // TODO: Navigate to chat detail screen with connectionId etc.
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
