import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:metal/appwrite/appwrite.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String userId, connectionId;
  const ChatScreen({
    super.key,
    required this.userId,
    required this.connectionId,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController(),
      _scrollController = ScrollController();
  final _picker = ImagePicker();
  String? _userName, _userImageUrl, _userErrorMessage, _messagesErrorMessage;
  List<Map<String, dynamic>> _messages = [];
  bool _hasText = false,
      _isLoading = true,
      _hasError = false,
      _messagesLoading = true,
      _messagesError = false,
      _sendingImage = false,
      _sendingText = false;
  StreamSubscription? _realtimeSub;

  // Message count state
  int _messageCount = 0;
  bool _messageCountLoading = true;

  /// Returns a DateTime in the local timezone, from a timestamp (seconds or ms)
  DateTime _timestampToLocalDateTime(dynamic ts) {
    if (ts == null) return DateTime.now();
    int millis;
    if (ts is int) {
      millis = ts < 10000000000 ? ts * 1000 : ts;
    } else if (ts is String) {
      try {
        millis = int.parse(ts);
        if (millis < 10000000000) millis *= 1000;
      } catch (_) {
        try {
          return DateTime.parse(ts).toLocal();
        } catch (_) {
          return DateTime.now();
        }
      }
    } else {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  }

  // 1. Utility: Always get message DateTime from $createdAt (fallback to now)
  DateTime? _getMessageDateTime(Map<String, dynamic> m) {
    if (m[r'$updatedAt'] != null) {
      try {
        return DateTime.parse(m[r'$updatedAt']).toLocal();
      } catch (_) {}
    }
    return null; // Do not use DateTime.now()!
  }

  String _formatDay(DateTime d) {
    final now = DateTime.now();
    final localD = d.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(localD.year, localD.month, localD.day);
    if (msgDay == today) return "Today";
    if (msgDay == today.subtract(const Duration(days: 1))) return "Yesterday";
    return DateFormat('EEEE, MMM d, yyyy').format(localD);
  }

  String _formatTime(DateTime d) =>
      DateFormat('h:mma').format(d.toLocal()).toLowerCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(
      () => setState(() => _hasText = _controller.text.trim().isNotEmpty),
    );
    _fetchUserInfo();
    _fetchMessages();
    _createChatInboxOnLoad();
    _subscribeToRealtime();
    _markMessagesAsRead();
    _fetchMessageCount();
  }

  Future<void> _fetchMessageCount() async {
    setState(() {
      _messageCountLoading = true;
    });
    try {
      // Fetch the connection document to get messageCount
      final doc = await databases.getDocument(
        databaseId: '685a90fa0009384c5189',
        collectionId: '685a95f5001cadd0cfc3',
        documentId: widget.connectionId,
      );
      int count = 0;
      if (doc.data != null && doc.data['messageCount'] != null) {
        final val = doc.data['messageCount'];
        if (val is int) {
          count = val;
        } else if (val is String) {
          count = int.tryParse(val) ?? 0;
        }
      }
      setState(() {
        _messageCount = count;
        _messageCountLoading = false;
      });
    } catch (e) {
      setState(() {
        _messageCount = 0;
        _messageCountLoading = false;
      });
    }
  }

  void _incrementMessageCount() {
    setState(() {
      _messageCount += 1;
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      const String dbId = '685a90fa0009384c5189';
      const String messagesCollectionId = '685aae75000e3642cbc0';

      final result = await databases.listDocuments(
        databaseId: dbId,
        collectionId: messagesCollectionId,
        queries: [
          Query.equal('connectionId', widget.connectionId),
          Query.equal('is_read', false),
          Query.equal('senderId', widget.userId),
          Query.limit(93283838),
        ],
      );

      // For each such message, update is_read to true
      for (final doc in result.documents) {
        if (doc.data['is_read'] == false) {
          try {
            await databases.updateDocument(
              databaseId: dbId,
              collectionId: messagesCollectionId,
              documentId: doc.$id,
              data: {'is_read': true},
            );
          } catch (e) {
            // Ignore errors for individual updates
          }
        }
      }
    } catch (e) {
      // Ignore errors for marking as read
    }
  }

  // Close the realtime connection and cancel timer
  void _closeRealtimeConnection() {
    if (_realtimeSub != null) {
      print(
        'Unsubscribing from realtime events for connectionId: ${widget.connectionId}',
      );
    }
    _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  void _subscribeToRealtime() {
    if (_realtimeSub != null) return;
    _realtimeSub = realtime
        .subscribe([
          'databases.685a90fa0009384c5189.collections.687961d1002e17be4c8a.documents.${widget.connectionId}',
        ])
        .stream
        .listen((event) async {
          final payload = event.payload;
          print(payload);

          if (payload == null || payload is! Map) return;

          final message = Map<String, dynamic>.from(payload);
          if (message[r'$updatedAt'] == null) {
            message[r'$updatedAt'] = DateTime.now().toUtc().toIso8601String();
          }
          print('Received message: $message');
          print('Message ${message[r'$updatedAt']} received');

          setState(() {
            _messages.add(message);
            // Sort by $updatedAt
            _messages.sort((a, b) {
              final aTime = a[r'$updatedAt'] != null
                  ? DateTime.tryParse(
                          a[r'$updatedAt'],
                        )?.millisecondsSinceEpoch ??
                        0
                  : 0;
              final bTime = b[r'$updatedAt'] != null
                  ? DateTime.tryParse(
                          b[r'$updatedAt'],
                        )?.millisecondsSinceEpoch ??
                        0
                  : 0;
              return aTime.compareTo(bTime);
            });
            // Locally increment message count on receive
            _incrementMessageCount();
          });

          // Auto-scroll
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent + 100,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });

          await _markMessagesAsRead();
        });
  }

  int _extractTimestamp(Map<String, dynamic> m) {
    // Used for sorting, always in ms since epoch, local time
    final dt = _getMessageDateTime(m);
    return dt?.millisecondsSinceEpoch ?? 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    _closeRealtimeConnection();
    super.dispose();
  }

  // Handle app lifecycle changes to close socket when app is backgrounded or closed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _closeRealtimeConnection();
    } else if (state == AppLifecycleState.resumed) {
      // Re-subscribe if needed
      if (_realtimeSub == null) {
        _subscribeToRealtime();
        _markMessagesAsRead(); // Mark as read when returning to page
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _createChatInboxOnLoad() async {
    try {
      final inboxDoc = await databases.listDocuments(
        databaseId: '685a90fa0009384c5189',
        collectionId: '687961d1002e17be4c8a',
        queries: [Query.equal('\$id', widget.connectionId)],
      );
      if (inboxDoc.documents.isEmpty) {
        try {
          await databases.createDocument(
            databaseId: '685a90fa0009384c5189',
            collectionId: "687961d1002e17be4c8a",
            documentId: widget.connectionId,
            data: {'is_image': null},
          );
        } on AppwriteException catch (e) {
          debugPrint(
            'Failed to create chat inbox: ${e.message ?? e.toString()}',
          );
        } catch (e) {
          debugPrint('Unexpected error while creating chat inbox: $e');
        }
      }
    } on AppwriteException catch (e) {
      debugPrint('Failed to check chat inbox: ${e.message ?? e.toString()}');
    } catch (e) {
      debugPrint('Unexpected error while checking chat inbox: $e');
    }
  }

  Future<void> _fetchUserInfo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _userErrorMessage = null;
    });
    try {
      const db = '685a90fa0009384c5189',
          uc = '68616ecc00163ed41e57',
          ic = '685aa0ef00090023c8a3';
      final userDocs = await databases.listDocuments(
        databaseId: db,
        collectionId: uc,
        queries: [Query.equal(r'$id', widget.userId)],
      );
      final name = userDocs.documents.isNotEmpty
          ? userDocs.documents.first.data['name'] as String?
          : null;
      if (name == null) throw Exception('User not found in database');
      final imageDocs = await databases.listDocuments(
        databaseId: db,
        collectionId: ic,
        queries: [Query.equal('user', widget.userId)],
      );
      final img = imageDocs.documents.isNotEmpty
          ? imageDocs.documents.first.data['image_1']
          : null;
      setState(() {
        _userName = name ?? 'Unknown';
        _userImageUrl = (img is String && img.isNotEmpty) ? img : null;
        _isLoading = false;
        _hasError = false;
        _userErrorMessage = null;
      });
    } on AppwriteException catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _userErrorMessage = 'Appwrite error: ${e.message ?? e.toString()}';
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _userErrorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _messagesLoading = true;
      _messagesError = false;
      _messagesErrorMessage = null;
    });
    try {
      final jwt = await account.createJWT(), token = jwt.jwt;
      final uri = Uri.parse(
        'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/${widget.connectionId}/messages',
      );
      final req = await HttpClient().getUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');
      final res = await req.close(),
          body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        setState(() {
          _messagesError = true;
          _messagesLoading = false;
          _messagesErrorMessage = 'HTTP error: ${res.statusCode} - $body';
        });
        return;
      }
      final data =
          (jsonDecode(body)['messages'] ?? [])
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort((a, b) {
              final aTime = _getMessageDateTime(a)?.millisecondsSinceEpoch ?? 0;
              final bTime = _getMessageDateTime(b)?.millisecondsSinceEpoch ?? 0;
              return aTime.compareTo(bTime);
            });
      setState(() {
        _messages = data;
        _messagesLoading = false;
        _messagesError = false;
        _messagesErrorMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients)
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
      // Mark as read after fetching messages
      await _markMessagesAsRead();
    } on SocketException catch (e) {
      setState(() {
        _messagesError = true;
        _messagesLoading = false;
        _messagesErrorMessage = 'Network error: ${e.message}';
      });
    } on FormatException catch (e) {
      setState(() {
        _messagesError = true;
        _messagesLoading = false;
        _messagesErrorMessage = 'Invalid response format: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _messagesError = true;
        _messagesLoading = false;
        _messagesErrorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<String?> _uploadImageToAppwriteStorage(File file) async {
    try {
      const bucketId = '686c230b002fb6f5149e';
      final uploaded = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path),
      );
      return 'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/${uploaded.$id}/view?project=685a8d7a001b583de71d&mode=admin';
    } catch (e) {
      debugPrint('Error uploading image to Appwrite: $e');
      return null;
    }
  }

  bool _isAllowedImageFormat(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.png' || ext == '.jpg' || ext == '.jpeg';
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null || !_isAllowedImageFormat(picked.path)) {
        if (picked != null)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only PNG, JPG, or JPEG images are allowed.'),
            ),
          );
        return;
      }

      setState(() => _sendingImage = true);
      final localPath = picked.path;
      final imageUrl = await _uploadImageToAppwriteStorage(File(localPath));
      if (imageUrl == null)
        throw Exception('Failed to upload image to storage');
      final jwt = await account.createJWT(), token = jwt.jwt;
      final res = await http.post(
        Uri.parse('https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/${widget.connectionId}/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': imageUrl, 'messageType': 'image'}),
      );
      if (res.statusCode != 200)
        throw Exception('Failed to send image message: ${res.body}');
      // Locally increment message count on send
      _incrementMessageCount();
      // Do not update _messages here; rely on real-time or fetch
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients)
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending image: $e')));
    } finally {
      setState(() => _sendingImage = false);
    }
  }

  // 2. When sending a message, always add $createdAt (UTC ISO string)
  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sendingText) return;
    setState(() {
      _hasText = false;
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients)
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
    });
    try {
      final jwt = await account.createJWT(), token = jwt.jwt;
      final res = await http.post(
        Uri.parse(
          'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/${widget.connectionId}/messages',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': text, 'messageType': 'text'}),
      );
      if (res.statusCode != 200)
        throw Exception('Failed to send message: ${res.body}');
      // Locally increment message count on send
      _incrementMessageCount();
      // Do not update _messages here; rely on real-time or fetch
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients)
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    } finally {
      setState(() => _sendingText = false);
    }
  }

  // 3. When sending an image, also add $createdAt (similar logic as above)
  // 4. Real-time handler: always add/update and sort by $createdAt
  // 5. In ListView.builder, always use _getMessageDateTime for prevDate and sorting
  // Now messages are aligned: right for current user, left for others
  Widget _buildMessage(
    Map<String, dynamic> m, {
    DateTime? previousMessageDate,
    String? previousDayKey,
  }) {
    String? senderId;
    if (m['senderId'] is Map)
      senderId = m['senderId'][r'$id'] ?? m['senderId']['id'];
    else if (m['senderId'] is String)
      senderId = m['senderId'];
    final isSender = senderId == widget.userId,
        text = m['message'],
        isImage = m['is_image'] == true,
        imageUrl = m['imageUrl'],
        senderName = m['senderId'] is Map
            ? (m['senderId']['name'] ?? 'Unknown')
            : 'Unknown';
    int? ts = m['timestamp'];
    DateTime? md;
    if (ts != null) {
      if (ts < 10000000000) ts *= 1000;
      md = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (m[r'$updatedAt'] != null) {
      try {
        md = DateTime.parse(m[r'$updatedAt']);
      } catch (_) {}
    }
    Widget? dayHeader;
    String? currentDayKey;
    if (md != null) {
      final localD = md.toLocal();
      currentDayKey = '${localD.year}-${localD.month}-${localD.day}';
      if (previousDayKey == null || previousDayKey != currentDayKey) {
        dayHeader = Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEE0F7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _formatDay(md),
                style: const TextStyle(
                  color: Color(0xFF7B3FA3),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        );
      }
    }
    final isOptimistic = m['_optimistic'] == true && isSender;
    Widget messageWidget;

    // Helper for alignment
    MainAxisAlignment alignment = isSender
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
    CrossAxisAlignment crossAxisAlignment = isSender
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    BorderRadius messageBorderRadius;
    Color messageColor;
    Color textColor;
    if (isSender) {
      // Right side (current user)
      messageBorderRadius = const BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(0),
      );
      // Use a much lighter purple for sent messages
      messageColor = isImage
          ? const Color(0xFF7B3FA3)
          : const Color(0xFFF3E9FA); // very light purple
      textColor = isImage ? Colors.white : const Color(0xFF3B2357);
    } else {
      // Left side (other user)
      messageBorderRadius = const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(10),
        bottomLeft: Radius.circular(0),
        bottomRight: Radius.circular(10),
      );
      // Use a more highlighted purple for received messages
      messageColor = isImage
          ? const Color(0xFF9F6BC1)
          : const Color(0xFF9F6BC1); // highlighted purple
      textColor = Colors.white;
    }

    if (isImage && imageUrl != null && imageUrl.isNotEmpty) {
      if (isOptimistic) {
        messageWidget = Row(
          mainAxisAlignment: alignment,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
                width: 200, // slightly reduced width
                height: 220, // slightly reduced height
                decoration: BoxDecoration(
                  borderRadius: messageBorderRadius,
                  color: messageColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: messageBorderRadius,
                  child: !imageUrl.startsWith('http')
                      ? Image.file(
                          File(imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      } else {
        messageWidget = _buildImageMessage(
          imageUrl: imageUrl,
          caption: senderName,
          isSender: isSender,
          time: md,
        );
      }
    } else if (text != null && text.isNotEmpty) {
      if (isOptimistic) {
        messageWidget = Row(
          mainAxisAlignment: alignment,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, // reduced from 18
                  vertical: 8, // reduced from 14
                ),
                decoration: BoxDecoration(
                  color: messageColor,
                  borderRadius: messageBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: crossAxisAlignment,
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15, // slightly reduced
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // reduced from 10
                    if (md != null)
                      Text(
                        _formatTime(md),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 11, // slightly reduced
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      } else {
        messageWidget = Row(
          mainAxisAlignment: alignment,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, // reduced from 18
                  vertical: 8, // reduced from 14
                ),
                decoration: BoxDecoration(
                  color: messageColor,
                  borderRadius: messageBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: crossAxisAlignment,
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15, // slightly reduced
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // reduced from 10
                    if (md != null)
                      Text(
                        _formatTime(md),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 11, // slightly reduced
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    } else if (isImage && (imageUrl == null || imageUrl.isEmpty)) {
      messageWidget = Row(
        mainAxisAlignment: alignment,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: messageColor,
                borderRadius: messageBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.08),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Text(
                '[Image not available]',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ],
      );
    } else {
      messageWidget = const SizedBox.shrink();
    }

    if (dayHeader != null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [dayHeader, messageWidget],
      );
    return messageWidget;
  }

  // Align image messages as well
  Widget _buildImageMessage({
    required String imageUrl,
    required String caption,
    required bool isSender,
    DateTime? time,
  }) {
    final isLocal = !imageUrl.startsWith('http');
    final img = isLocal
        ? Image.file(
            File(imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          )
        : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          );
    final alignment = isSender
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
    final crossAxisAlignment = isSender
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final borderRadius = isSender
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(0),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(10),
          );
    final color = isSender ? const Color(0xFF7B3FA3) : const Color(0xFF9F6BC1);
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 2),
                width: 220,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: color,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A7B3FA3),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(borderRadius: borderRadius, child: img),
              ),
              const SizedBox(height: 4),
              if (time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatTime(time),
                    style: TextStyle(
                      color: const Color(
                        0xFF3B2357,
                      ).withOpacity(0.65), // more visible on both backgrounds
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.purple.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, -2),
        ),
      ],
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: _sendingImage
              ? null
              : () async {
                  await _pickAndSendImage();
                },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3E9FA),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: _sendingImage
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF9F6BC1),
                      ),
                    ),
                  )
                : const Icon(
                    PhosphorIconsRegular.image,
                    color: Color(0xFF9F6BC1),
                    size: 24,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3E9FA),
              borderRadius: BorderRadius.circular(28),
            ),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(
                  color: Color(0xFFBFA2E6),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
              style: const TextStyle(
                color: Color(0xFF3B2357),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              onSubmitted: (_) {
                if (_hasText && !_sendingText) _sendTextMessage();
              },
              enabled: !_sendingText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: (_hasText && !_sendingText)
              ? () {
                  _sendTextMessage();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _hasText && !_sendingText
                  ? const Color(0xFF9F6BC1)
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
              boxShadow: [
                if (_hasText && !_sendingText)
                  BoxShadow(
                    color: const Color(0xFF9F6BC1).withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            width: 44,
            height: 44,
            child: Center(
              child: _sendingText
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFFFFF),
                        ),
                      ),
                    )
                  : Icon(
                      PhosphorIconsFill.paperPlaneRight,
                      color: _hasText && !_sendingText
                          ? Colors.white
                          : Colors.grey,
                      size: 22,
                    ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildAppBarTitle() {
    if (_isLoading) {
      return Row(
        children: const [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFEEE0F7),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          SizedBox(width: 14),
          Text(
            'Loading...',
            style: TextStyle(
              color: Color(0xFF3B2357),
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              fontSize: 18,
            ),
          ),
        ],
      );
    }
    if (_hasError) {
      return Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor:  Color(0xFF3B2357),
            child: Icon(Icons.error, color: Colors.red),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              _userErrorMessage != null ? 'Error: $_userErrorMessage' : 'Error',
              style: const TextStyle(
                color: Color(0xFFEEE0F7),
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 20, // increased avatar size
          backgroundImage: (_userImageUrl != null && _userImageUrl!.isNotEmpty)
              ? NetworkImage(_userImageUrl!)
              : null,
          backgroundColor: const Color(0xFFEEE0F7),
          child: (_userImageUrl == null || _userImageUrl!.isEmpty)
              ? const Icon(Icons.person, color: Color(0xFF9F6BC1), size: 22)
              : null,
        ),
        const SizedBox(width: 10), // smaller gap
        Text(
          _userName ?? 'Unknown',
          style: const TextStyle(
            color: Color(0xFF3B2357),
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageCountCircle() {
    return Tooltip(
      message: "Both users can only send up to 100 messages together.",
      textStyle: const TextStyle(
        color: Color(0xFF3B2357),
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: Color(0xFFF3E9FA),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A7B3FA3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(0),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFF3E9FA),
          child: _messageCountLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF9F6BC1),
                    ),
                  ),
                )
              : Text(
                  "$_messageCount",
                  style: const TextStyle(
                    color: Color(0xFF7B3FA3),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF3B2357), size: 20),
        iconSize: 24,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () {
          _closeRealtimeConnection();
          Navigator.of(context).pop();
        },
      ),
      titleSpacing: 0,
      title: _buildAppBarTitle(),
      actions: [
        _buildMessageCountCircle(),
      ],
    ),
    body: WillPopScope(
      onWillPop: () async {
        _closeRealtimeConnection();
        return true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {},
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A7B3FA3),
                      blurRadius: 16,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _messagesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messagesError
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _messagesErrorMessage != null
                                    ? 'Failed to load messages:\n${_messagesErrorMessage!}'
                                    : 'Failed to load messages',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : (_messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: Color(0xFF9F6BC1),
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 18,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                DateTime? prevDate;
                                String? prevDayKey;
                                if (i > 0) {
                                  var prev = _messages[i - 1],
                                      ts = prev['timestamp'];
                                  if (ts != null) {
                                    if (ts < 10000000000) ts *= 1000;
                                    prevDate =
                                        DateTime.fromMillisecondsSinceEpoch(ts);
                                  } else if (prev[r'$updatedAt'] != null) {
                                    try {
                                      prevDate = DateTime.parse(
                                        prev[r'$updatedAt'],
                                      );
                                    } catch (_) {}
                                  }
                                  if (prevDate != null) {
                                    final localPrev = prevDate.toLocal();
                                    prevDayKey =
                                        '${localPrev.year}-${localPrev.month}-${localPrev.day}';
                                  }
                                }
                                return _buildMessage(
                                  _messages[i],
                                  previousMessageDate: prevDate,
                                  previousDayKey: prevDayKey,
                                );
                              },
                            )),
              ),
            ),
            _buildInputField(),
          ],
        ),
      ),
    ),
  );
}
