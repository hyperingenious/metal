import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../../appwrite/appwrite.dart';
import '../chat_screen.dart';

/// Fetches the list of active chats for the current user.
/// Each chat will include the last message (if any), its sender, and the unread count.
Future<List<Map<String, dynamic>>> fetchActiveChatsWithLastMessage() async {
  try {
    // Get JWT for authentication
    final jwt = await account.createJWT();
    final token = jwt.jwt;

    // Fetch active chats
    final uri = Uri.parse(
      'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/active',
    );

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
    final List<Map<String, dynamic>> chats = data.cast<Map<String, dynamic>>();

    // For each chat, fetch the last message from the messages collection
    // We'll use Appwrite's Databases API directly
    final databases = Databases(client);
    const String dbId = '685a90fa0009384c5189';
    const String messagesCollectionId = '685aae75000e3642cbc0';

    // Get current user id
    final user = await account.get();
    final String currentUserId = user.$id;

    // For each chat, fetch the last message (if any) and unread count
    for (final chat in chats) {
      final String? connectionId = chat['connectionId'];
      if (connectionId == null) continue;

      try {
        // Fetch last message
        final messagesResult = await databases.listDocuments(
          databaseId: dbId,
          collectionId: messagesCollectionId,
          queries: [
            Query.equal('connectionId', connectionId),
            Query.orderDesc('\$createdAt'),
            Query.limit(1),
          ],
        );
        if (messagesResult.documents.isNotEmpty) {
          final lastMsg = messagesResult.documents.first.data;
          final sender = lastMsg['senderId'];
          String senderId = '';
          String senderName = '';
          if (sender is Map) {
            senderId = sender[r'$id'] ?? sender['id'] ?? '';
            senderName = sender['name'] ?? '';
          } else if (sender is String) {
            senderId = sender;
          }
          final isMe = senderId == currentUserId;
          final displaySender = isMe
              ? 'You'
              : (senderName.isNotEmpty
                    ? senderName
                    : (chat['partnerName'] ?? 'Someone'));
          final lastMessageText = lastMsg['message'] ?? '[No message]';
          chat['lastMessageDisplay'] = '$displaySender: $lastMessageText';
        } else {
          chat['lastMessageDisplay'] = 'No messages yet';
        }
      } catch (e) {
        chat['lastMessageDisplay'] = 'No messages yet';
      }

      // Fetch unread count for this chat
      try {
        final unreadResult = await databases.listDocuments(
          databaseId: dbId,
          collectionId: messagesCollectionId,
          queries: [
            Query.equal('connectionId', connectionId),
            Query.notEqual('senderId', user.$id),
            Query.equal('is_read', false),
          ],
        );
        chat['unreadCount'] = unreadResult.documents.length;
      } catch (e) {
        chat['unreadCount'] = 0;
      }
    }

    return chats;
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
    _chatsFuture = fetchActiveChatsWithLastMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.black,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Chats',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB96AFF)),
                  strokeWidth: 4,
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load chats',
                    style: TextStyle(
                      color: Color(0xFFB96AFF),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    color: Color(0xFFB96AFF),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No connections made yet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF3B2357),
                      letterSpacing: 0.2,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Start a conversation and make new friends!",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6D4B86),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            itemCount: chats.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Divider(
                color: const Color(0xFFE5D3F3),
                thickness: 1,
                height: 1,
              ),
            ),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final int unreadCount = chat['unreadCount'] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: 2,
                  shadowColor: const Color(0xFFB96AFF).withOpacity(0.08),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      final String userId = chat['partnerId'] ?? '';
                      final String connectionId = chat['connectionId'] ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            userId: userId,
                            connectionId: connectionId,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFB96AFF,
                                  ).withOpacity(0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFF3E6FA),
                              backgroundImage:
                                  chat['partnerPhotoUrl'] != null &&
                                      chat['partnerPhotoUrl']
                                          .toString()
                                          .isNotEmpty
                                  ? NetworkImage(chat['partnerPhotoUrl'])
                                  : null,
                              child:
                                  (chat['partnerPhotoUrl'] == null ||
                                      chat['partnerPhotoUrl']
                                          .toString()
                                          .isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFFB96AFF),
                                      size: 32,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        chat['partnerName'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                          color: Color(0xFF3B2357),
                                          height: 1.1,
                                          letterSpacing: 0.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB96AFF),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFB96AFF,
                                                ).withOpacity(0.18),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  chat['lastMessageDisplay'] ??
                                      'No messages yet',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13.5,
                                    color: unreadCount > 0
                                        ? const Color(0xFFB96AFF)
                                        : const Color(0xFF6D4B86),
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: const Color(0xFFB96AFF).withOpacity(0.7),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
