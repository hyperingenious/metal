import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../appwrite/appwrite.dart';
import '../../services/config_service.dart';
import '../chat_screen.dart';

/// Key for storing cached chats in SharedPreferences
const String _cachedChatsKey = 'cached_active_chats';

/// Fetches the list of active chats for the current user.
/// Each chat will include the last message (if any), its sender, and the unread count.
Future<List<Map<String, dynamic>>> fetchActiveChatsWithLastMessage() async {
  try {
    // Get JWT for authentication
    final jwt = await account.createJWT();
    final token = jwt.jwt;

    // Fetch active chats
    final uri = Uri.parse(
      '${ConfigService.baseUrl}/api/v1/chats/active',
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
          databaseId: databaseId,
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
          
          // Check if the message is deleted
          final bool isDeleted = lastMsg['is_deleted'] == true;
          final lastMessageText = isDeleted 
              ? 'Message deleted'
              : (lastMsg['message'] ?? '[No message]');
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
          databaseId: databaseId,
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

    // Cache the chats locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedChatsKey, jsonEncode(chats));
    } catch (_) {}

    return chats;
  } catch (e) {
    // On error, try to return cached chats if available
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cachedChatsKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadCachedChatsAndFetch();
  }

  // Add this method to refresh chats when returning from chat screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh chats when the screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedChatsAndFetch();
    });
  }

  /// Loads cached chats immediately, then fetches fresh chats in the background.
  Future<void> _loadCachedChatsAndFetch() async {
    // 1. Try to load cached chats for instant display
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cachedChatsKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        setState(() {
          _chats = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch fresh chats in the background and update if changed
    try {
      final freshChats = await fetchActiveChatsWithLastMessage();
      if (mounted) {
        // Only update if data is different (by connectionId or length)
        bool shouldUpdate = false;
        if (_chats.length != freshChats.length) {
          shouldUpdate = true;
        } else {
          for (int i = 0; i < _chats.length; i++) {
            if (_chats[i]['connectionId'] != freshChats[i]['connectionId'] ||
                _chats[i]['lastMessageDisplay'] !=
                    freshChats[i]['lastMessageDisplay'] ||
                _chats[i]['unreadCount'] != freshChats[i]['unreadCount']) {
              shouldUpdate = true;
              break;
            }
          }
        }
        if (shouldUpdate) {
          setState(() {
            _chats = freshChats;
            _loading = false;
            _error = false;
          });
        } else if (_loading) {
          setState(() {
            _loading = false;
            _error = false;
          });
        }
      }
    } catch (_) {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _deleteConnection(String connectionId) async {
    setState(() {
      _loading = true;
    });
    try {
      // First, refresh the chat list to ensure we have the latest data
      await _loadCachedChatsAndFetch();
      
      // Verify the connection still exists in the refreshed list
      final chatExists = _chats.any((chat) => chat['connectionId'] == connectionId);
      if (!chatExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection not found or already deleted')),
          );
        }
        setState(() {
          _loading = false;
        });
        return;
      }

      // Get JWT for authentication
      final jwt = await account.createJWT();
      final token = jwt.jwt;

      // Call the API endpoint instead of direct Appwrite deletion
      final uri = Uri.parse(
        '${ConfigService.baseUrl}/api/v1/chats/remove',
      );

      final httpClient = HttpClient();
      final request = await httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');
      
      // Send the connectionId in the request body
      final requestBody = jsonEncode({'connectionId': connectionId});
      request.write(requestBody);
      
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to remove chat',
        );
      }

      // Optionally, show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection deleted')),
        );
      }
      
      // Refresh the chat list after successful deletion
      await _loadCachedChatsAndFetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete connection: $e')),
        );
      }
      setState(() {
        _loading = false;
      });
    }
  }

  void _showDeleteConnectionModal(BuildContext context, String? connectionId) {
    if (connectionId == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 40),
              const SizedBox(height: 16),
              const Text(
                'Delete Connection?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF3B2357),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to delete this connection? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6D4B86),
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteConnection(connectionId);
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(Map<String, dynamic> chat) {
    final hasPhoto = (chat['partnerPhotoUrl'] != null &&
        chat['partnerPhotoUrl'].toString().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFCF9BFF), Color(0xFFB96AFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB96AFF).withOpacity(0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF3E6FA),
          image: hasPhoto
              ? DecorationImage(
                  image: NetworkImage(chat['partnerPhotoUrl']),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: (!hasPhoto)
            ? const Icon(
                Icons.person,
                color: Color(0xFFB96AFF),
                size: 24,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
            child: Row(
              children: const [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.black,
                  size: 22,
                ),
                SizedBox(width: 12),
                Text(
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDF9FF), Color(0xFFF6EEFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB96AFF)),
                    strokeWidth: 4,
                  ),
                ),
              )
            : _error
                ? Center(
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
                  )
                : _chats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.forum_outlined,
                              color: Color(0xFFB96AFF),
                              size: 60,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No connections made yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF3B2357),
                                letterSpacing: 0.2,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Start a conversation and make new friends!",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6D4B86),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          setState(() {
                            _loading = true;
                          });
                          await _loadCachedChatsAndFetch();
                        },
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          itemCount: _chats.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final chat = _chats[index];
                            final int unreadCount = chat['unreadCount'] ?? 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFEADAF7),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFB96AFF).withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    final String userId = chat['partnerId'] ?? '';
                                    final String connectionId = chat['connectionId'] ?? '';
                                    
                                    // Navigate to chat screen and wait for result
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          userId: userId,
                                          connectionId: connectionId,
                                        ),
                                      ),
                                    );
                                    
                                    // Refresh chat list when returning from chat screen
                                    if (result == true || mounted) {
                                      await _loadCachedChatsAndFetch();
                                    }
                                  },
                                  onLongPress: () {
                                    _showDeleteConnectionModal(context, chat['connectionId']);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _buildAvatar(chat),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      chat['partnerName'] ?? 'Unknown',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 16.5,
                                                        color: const Color(0xFF3B2357),
                                                        height: 1.1,
                                                        letterSpacing: 0.1,
                                                        shadows: [
                                                          Shadow(
                                                            offset: const Offset(0, 0),
                                                            blurRadius: 0.4,
                                                            color: Colors.black.withOpacity(0.05),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (unreadCount > 0)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 8),
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFB96AFF),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFFB96AFF).withOpacity(0.22),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 3),
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
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                chat['lastMessageDisplay'] ?? 'No messages yet',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 13.5,
                                                  color: unreadCount > 0
                                                      ? const Color(0xFFB96AFF)
                                                      : const Color(0xFF6D4B86),
                                                  height: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB96AFF).withOpacity(0.10),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Color(0xFFB96AFF),
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}