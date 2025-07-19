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

class _ChatScreenState extends State<ChatScreen> {
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

  String _formatDay(DateTime d) {
    final t = DateTime.now(),
        td = DateTime(t.year, t.month, t.day),
        md = DateTime(d.year, d.month, d.day);
    if (md == td) return "Today";
    if (md == td.subtract(const Duration(days: 1))) return "Yesterday";
    return DateFormat('EEEE, MMM d, yyyy').format(d);
  }

  String _formatTime(DateTime d) => DateFormat('h:mma').format(d).toLowerCase();

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _hasText = _controller.text.trim().isNotEmpty),
    );
    _fetchUserInfo();
    _fetchMessages();
    _createChatInboxOnLoad();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    _realtimeSub = realtime
        .subscribe([
          'databases.685a90fa0009384c5189.collections.687961d1002e17be4c8a.documents.${widget.connectionId}',
        ])
        .stream
        .listen((event) {
          final payload = event.payload;
          if (payload == null || payload is! Map) return;
          final message = Map<String, dynamic>.from(payload);
          final messageId = message[r'$id'] as String?;
          if (messageId == null) return;
          setState(() {
            int i = _messages.indexWhere((m) => m[r'$id'] == messageId);
            if (i != -1)
              _messages[i] = message;
            else
              _messages.add(message);
            _messages.sort(
              (a, b) => _extractTimestamp(a).compareTo(_extractTimestamp(b)),
            );
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients)
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent + 100,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
          });
        });
  }

  int _extractTimestamp(Map<String, dynamic> m) {
    if (m['timestamp'] != null) {
      int ts = m['timestamp'];
      if (ts < 10000000000) ts *= 1000;
      return ts;
    }
    if (m[r'$createdAt'] != null) {
      try {
        return DateTime.parse(m[r'$createdAt']).millisecondsSinceEpoch;
      } catch (_) {}
    }
    return 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
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
        'http://localhost:3000/api/v1/chats/${widget.connectionId}/messages',
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
            ..sort(
              (a, b) => ((a['timestamp'] ?? 0) as int).compareTo(
                (b['timestamp'] ?? 0) as int,
              ),
            );
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
      final now = DateTime.now().millisecondsSinceEpoch,
          localPath = picked.path;
      final optimistic = {
        'senderId': {'\$id': widget.userId, 'name': _userName ?? 'You'},
        'message': "[Image]",
        'is_image': true,
        'imageUrl': localPath,
        'timestamp': now,
        '_optimistic': true,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients)
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
      });
      final imageUrl = await _uploadImageToAppwriteStorage(File(localPath));
      if (imageUrl == null)
        throw Exception('Failed to upload image to storage');
      final jwt = await account.createJWT(), token = jwt.jwt;
      final res = await http.post(
        Uri.parse(
          'http://localhost:3000/api/v1/chats/${widget.connectionId}/messages',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': imageUrl, 'messageType': 'image'}),
      );
      if (res.statusCode != 200)
        throw Exception('Failed to send image message: ${res.body}');
      final msg =
          (jsonDecode(res.body)['messageData'] as Map<String, dynamic>?);
      setState(() {
        _messages.remove(optimistic);
        _messages.add(
          msg ?? {...optimistic, 'imageUrl': imageUrl, '_optimistic': false},
        );
      });
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

  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sendingText) return;
    setState(() {
      // _sendingText = true;
      _hasText = false;
    });
    final now = DateTime.now().millisecondsSinceEpoch;
    final optimistic = {
      'senderId': {'\$id': widget.userId, 'name': _userName ?? 'You'},
      'message': text,
      'is_image': false,
      'imageUrl': null,
      'timestamp': now,
      '_optimistic': true,
    };
    setState(() {
      // _messages.add(optimistic);
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
          'http://localhost:3000/api/v1/chats/${widget.connectionId}/messages',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': text, 'messageType': 'text'}),
      );
      if (res.statusCode != 200)
        throw Exception('Failed to send message: ${res.body}');
      final msg =
          (jsonDecode(res.body)['messageData'] as Map<String, dynamic>?);
      setState(() {
        _messages.remove(optimistic);
        _messages.add(msg ?? {...optimistic, '_optimistic': false});
      });
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
      setState(() {
        _messages.remove(optimistic);
      });
    } finally {
      setState(() => _sendingText = false);
    }
  }

  // Now messages are aligned: right for current user, left for others
  Widget _buildMessage(
    Map<String, dynamic> m, {
    DateTime? previousMessageDate,
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
    } else if (m[r'$createdAt'] != null) {
      try {
        md = DateTime.parse(m[r'$createdAt']);
      } catch (_) {}
    }
    Widget? dayHeader;
    if (md != null &&
        (previousMessageDate == null ||
            previousMessageDate.year != md.year ||
            previousMessageDate.month != md.month ||
            previousMessageDate.day != md.day)) {
      dayHeader = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5D3F3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatDay(md),
              style: const TextStyle(
                color: Color(0xFF6D4B86),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }
    final isOptimistic = m['_optimistic'] == true && isSender;
    Widget messageWidget;

    // Remove special loader message UI for optimistic messages

    // Helper for alignment
    MainAxisAlignment alignment = isSender
        ? MainAxisAlignment.start
        : MainAxisAlignment.end;
    CrossAxisAlignment crossAxisAlignment = isSender
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;
    BorderRadius messageBorderRadius;
    Color messageColor;
    Color textColor;
    if (isSender) {
      // Right side (current user)
      messageBorderRadius = const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(0),
      );
      // Change color to red for optimistic (just sent) messages
      if (isOptimistic) {
        messageColor = const Color(0xFFE5D3F3);
        textColor = Colors.white;
      } else {
        messageColor = isImage ? const Color(0xFF552B7A) : Colors.white;
        textColor = isImage ? Colors.white : Colors.black87;
      }
    } else {
      // Left side (other user)
      messageBorderRadius = const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
        bottomLeft: Radius.circular(0),
        bottomRight: Radius.circular(12),
      );
      messageColor = isImage
          ? const Color(0xFF6D4B86)
          : const Color(0xFFE5D3F3);
      textColor = isImage ? Colors.white : Colors.black87;
    }

    if (isImage && imageUrl != null && imageUrl.isNotEmpty) {
      if (isOptimistic) {
        // Just show the image with a slight overlay, no loader
        messageWidget = Row(
          mainAxisAlignment: alignment,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                width: 220,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: messageBorderRadius,
                  color: messageColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 2,
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
        // Just show the message bubble, no loader
        messageWidget = Row(
          mainAxisAlignment: alignment,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: messageColor,
                  borderRadius: messageBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 2,
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
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (md != null)
                      Text(
                        _formatTime(md),
                        style: TextStyle(color: textColor, fontSize: 11),
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
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: messageColor,
                  borderRadius: messageBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: Offset(0, 2),
                      blurRadius: 2,
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
                        style: TextStyle(color: textColor, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (md != null)
                      Text(
                        _formatTime(md),
                        style: TextStyle(color: textColor, fontSize: 11),
                      ),
                    if (m['_optimistic'] == true) const SizedBox.shrink(),
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
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: messageColor,
                borderRadius: messageBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: Offset(0, 2),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                '[Image not available]',
                style: TextStyle(color: Colors.red, fontSize: 15),
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
        ? MainAxisAlignment.start
        : MainAxisAlignment.end;
    final crossAxisAlignment = isSender
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final borderRadius = isSender
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(0),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(12),
          );
    final color = isSender ? const Color(0xFF552B7A) : const Color(0xFF6D4B86);
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 220,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: color,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, 2),
                      blurRadius: 2,
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: const Color(0xFFF3E9FA),
    child: Row(
      children: [
        GestureDetector(
          onTap: _sendingImage ? null : () async => await _pickAndSendImage(),
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
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) {
              if (_hasText && !_sendingText) _sendTextMessage();
            },
            enabled: !_sendingText,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: (_hasText && !_sendingText) ? () => _sendTextMessage() : null,
          child: CircleAvatar(
            backgroundColor: _hasText && !_sendingText
                ? Colors.white
                : Colors.grey.shade300,
            radius: 18,
            child: _sendingText
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
                : Icon(
                    PhosphorIconsFill.paperPlaneRight,
                    color: _hasText && !_sendingText
                        ? const Color(0xFF9F6BC1)
                        : Colors.grey,
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
            radius: 18,
            backgroundColor: Color(0xFFE5D3F3),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    if (_hasError) {
      return Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE5D3F3),
            child: Icon(Icons.error, color: Colors.red),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _userErrorMessage != null ? 'Error: $_userErrorMessage' : 'Error',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
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
          radius: 18,
          backgroundImage: (_userImageUrl != null && _userImageUrl!.isNotEmpty)
              ? NetworkImage(_userImageUrl!)
              : null,
          backgroundColor: const Color(0xFFE5D3F3),
          child: (_userImageUrl == null || _userImageUrl!.isEmpty)
              ? const Icon(Icons.person, color: Color(0xFF6D4B86))
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          _userName ?? 'Unknown',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3E9FA),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF3E9FA),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: _buildAppBarTitle(),
    ),
    body: Column(
      children: [
        Expanded(
          child: _messagesLoading
              ? const Center(child: CircularProgressIndicator())
              : _messagesError
              ? Center(
                  child: Text(
                    _messagesErrorMessage != null
                        ? 'Failed to load messages:\n${_messagesErrorMessage!}'
                        : 'Failed to load messages',
                    style: const TextStyle(
                      color: Colors.red,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : _messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.black54,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    DateTime? prevDate;
                    if (i > 0) {
                      var prev = _messages[i - 1], ts = prev['timestamp'];
                      if (ts != null) {
                        if (ts < 10000000000) ts *= 1000;
                        prevDate = DateTime.fromMillisecondsSinceEpoch(ts);
                      } else if (prev[r'$createdAt'] != null) {
                        try {
                          prevDate = DateTime.parse(prev[r'$createdAt']);
                        } catch (_) {}
                      }
                    }
                    return _buildMessage(
                      _messages[i],
                      previousMessageDate: prevDate,
                    );
                  },
                ),
        ),
        _buildInputField(),
      ],
    ),
  );
}
