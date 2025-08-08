import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:async';
import 'profile_check.dart' as profile_check;

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
  String? _currentUserId;

  // For expanding the action menu
  bool _showActionMenu = false;

  // Message count state
  int _messageCount = 0;
  bool _messageCountLoading = true;

  // For proposal accept feedback
  Map<String, bool> _acceptedProposals = {};

  // For caching date proposal status per connectionId
  Map<String, String?> _dateProposalStatusCache = {};

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

  // Store the dateProposalStatus for this chat's connection
  String? _dateProposalStatus;
  bool _dateProposalStatusLoading = false;
  String? _dateProposalStatusError;

  // Track locally deleted messages (by document id)
  Set<String> _locallyDeletedMessageIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(
      () => setState(() => _hasText = _controller.text.trim().isNotEmpty),
    );
    _fetchCurrentUserId();
    _fetchUserInfo();
    _fetchMessages();
    _createChatInboxOnLoad();
    _subscribeToRealtime();
    _markMessagesAsRead();
    _fetchMessageCount();
    _fetchDateProposalStatus();
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      final user = await account.get();
      setState(() {
        _currentUserId = user.$id;
      });
    } catch (e) {
      setState(() {
        _currentUserId = null;
      });
    }
  }

  Future<void> _fetchMessageCount() async {
    setState(() {
      _messageCountLoading = true;
    });
    try {
      // Fetch the connection document to get messageCount
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: connectionsCollectionId,
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
      final result = await databases.listDocuments(
        databaseId: databaseId,
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
              databaseId: databaseId,
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
    _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  void _subscribeToRealtime() {
    if (_realtimeSub != null) return;
    _realtimeSub = realtime
        .subscribe([
          // Subscribe to messages collection for this connection
          'databases.$databaseId.collections.$messagesCollectionId.documents',
        ])
        .stream
        .listen((event) async {
          final payload = event.payload;

          if (payload == null || payload is! Map) return;

          final message = Map<String, dynamic>.from(payload);

          // Only process messages for this connection
          if (message['connectionId'] != widget.connectionId) return;

          // Only process messages that are not from the current user (to avoid duplicates)
          String? messageSenderId;
          if (message['senderId'] is Map) {
            messageSenderId =
                message['senderId'][r'$id'] ?? message['senderId']['id'];
          } else if (message['senderId'] is String) {
            messageSenderId = message['senderId'];
          }

          if (messageSenderId == _currentUserId) {
            // This is a message from the current user, check if we have an optimistic message to replace
            setState(() {
              bool replacedOptimistic = false;
              for (int i = 0; i < _messages.length; i++) {
                if (_messages[i]['_optimistic'] == true) {
                  // For date proposals, match by messageType and tempId
                  if (message['messageType'] == 'date_proposal' &&
                      _messages[i]['messageType'] == 'date_proposal' &&
                      _messages[i]['_tempId'] == message['_tempId']) {
                    _messages[i] = message;
                    replacedOptimistic = true;
                    break;
                  }
                  // For other messages, match by content
                  else if (_messages[i]['message'] == message['message']) {
                    _messages[i] = message;
                    replacedOptimistic = true;
                    break;
                  }
                }
              }

              // If not replacing optimistic message, add as new
              if (!replacedOptimistic) {
                _messages.add(message);
              }

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
            });
          } else {
            // This is a message from another user, add it
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
            });
          }

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
          // Also refresh proposal status in case of real-time update
          await _fetchDateProposalStatus();
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
      _fetchDateProposalStatus();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _createChatInboxOnLoad() async {
    try {
      final inboxDoc = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: messageInboxCollectionId,
        queries: [Query.equal(r'$id', widget.connectionId)],
      );
      if (inboxDoc.documents.isEmpty) {
        try {
          await databases.createDocument(
            databaseId: databaseId,
            collectionId: messageInboxCollectionId,
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
      final userDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [Query.equal(r'$id', widget.userId)],
      );
      final name = userDocs.documents.isNotEmpty
          ? userDocs.documents.first.data['name'] as String?
          : null;
      if (name == null) throw Exception('User not found in database');
      final imageDocs = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: imageCollectionId,
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

  // Fetch the dateProposalStatus from the connection document
  Future<void> _fetchDateProposalStatus() async {
    setState(() {
      _dateProposalStatusLoading = true;
      _dateProposalStatusError = null;
    });
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: connectionsCollectionId,
        documentId: widget.connectionId,
      );
      String? status;
      if (doc.data != null && doc.data['dateProposalStatus'] != null) {
        status = doc.data['dateProposalStatus'] as String?;
      }
      setState(() {
        _dateProposalStatus = status;
        _dateProposalStatusLoading = false;
        _dateProposalStatusError = null;
      });
    } catch (e) {
      setState(() {
        _dateProposalStatus = null;
        _dateProposalStatusLoading = false;
        _dateProposalStatusError = e.toString();
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
      // Fetch proposal status after loading messages
      await _fetchDateProposalStatus();
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
      final uploaded = await storage.createFile(
        bucketId: storageBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path),
      );
      return 'https://fra.cloud.appwrite.io/v1/storage/buckets/$storageBucketId/files/${uploaded.$id}/view?project=$projectId&mode=admin';
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
    String? imageUrl;
    String? tempId;

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
      imageUrl = await _uploadImageToAppwriteStorage(File(localPath));
      if (imageUrl == null)
        throw Exception('Failed to upload image to storage');

      // Create optimistic image message
      tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final optimisticMessage = {
        'message': imageUrl, // Store the image URL in the message field
        'imageUrl': imageUrl,
        'senderId': _currentUserId,
        'is_image': true,
        'messageType': 'image',
        '_optimistic': true, // Mark as optimistic
        '_tempId': tempId, // Temporary ID
        r'$updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      // Add optimistic message to UI immediately
      setState(() {
        _messages.add(optimisticMessage);
        // Sort messages
        _messages.sort((a, b) {
          final aTime = a[r'$updatedAt'] != null
              ? DateTime.tryParse(a[r'$updatedAt'])?.millisecondsSinceEpoch ?? 0
              : 0;
          final bTime = b[r'$updatedAt'] != null
              ? DateTime.tryParse(b[r'$updatedAt'])?.millisecondsSinceEpoch ?? 0
              : 0;
          return aTime.compareTo(bTime);
        });
      });

      // Auto-scroll to show the new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      final jwt = await account.createJWT(), token = jwt.jwt;
      final res = await http.post(
        Uri.parse(
          'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/${widget.connectionId}/messages',
        ),
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

      // Don't remove optimistic message here - let it stay until we get the real message
      // The real-time update will handle replacing it when the real message comes back

      // Auto-scroll again after successful send
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      // Remove optimistic message on error
      if (tempId != null) {
        setState(() {
          _messages.removeWhere((m) => m['_tempId'] == tempId);
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending image: $e')));
    } finally {
      setState(() => _sendingImage = false);
    }
  }

  // --- Message Deletion Logic ---

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    print(message);

    // Try multiple ways to get the document ID
    String? docId = message[r'$id'] ?? message['id'];
    final String? tempId = message['_tempId'];
    final bool isOptimistic = message['_optimistic'] == true;

    // Remove optimistic message from local state first
    if (isOptimistic || tempId != null) {
      setState(() {
        if (tempId != null) {
          _messages.removeWhere((m) => m['_tempId'] == tempId);
        } else {
          // Remove by content and senderId for optimistic messages without tempId
          _messages.removeWhere(
            (m) =>
                m['_optimistic'] == true &&
                m['message'] == message['message'] &&
                m['senderId'] == message['senderId'],
          );
        }
      });
    }

    // If we still don't have a document ID, we need to find the message in the database
    if (docId == null) {
      try {
        // Query the database to find the message by its content and senderId
        final result = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: messagesCollectionId,
          queries: [
            Query.equal('connectionId', widget.connectionId),
            // Handle both text and image messages
            message['is_image'] == true
                ? Query.equal(
                    'imageUrl',
                    message['imageUrl'] ?? message['message'],
                  )
                : Query.equal('message', message['message']),
            Query.equal('senderId', message['senderId']),
            Query.orderDesc(r'$createdAt'),
            Query.limit(1),
          ],
        );

        if (result.documents.isNotEmpty) {
          docId = result.documents.first.$id;
        }
      } catch (e) {
        debugPrint('Failed to find message in database: $e');
      }
    }

    // For real messages (including optimistic ones that might have been saved), try to delete from database
    if (docId != null) {
      try {
        // Update the message document in Appwrite to set is_deleted: true
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: messagesCollectionId,
          documentId: docId,
          data: {'is_deleted': true},
        );
        // Mark as deleted locally for immediate UI feedback
        setState(() {
          _locallyDeletedMessageIds.add(docId!);
          // Also update the message in _messages to reflect is_deleted
          for (var m in _messages) {
            if ((m[r'$id'] ?? m['id']) == docId) {
              m['is_deleted'] = true;
            }
          }
        });
      } catch (e) {
        // If database deletion fails, still show success since we removed from local state
        debugPrint('Failed to delete message from database: $e');
      }
    } else {
      // If we couldn't find the document ID, just remove from local state
      setState(() {
        _messages.removeWhere(
          (m) =>
              (message['is_image'] == true
                  ? (m['imageUrl'] == message['imageUrl'] ||
                        m['message'] == message['message'])
                  : m['message'] == message['message']) &&
              m['senderId'] == message['senderId'],
        );
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
  }

  _showDeleteMessageDialog(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteMessage(message);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Show proposal form dialog
  void _showProposalFormDialog() {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    TextEditingController placeController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    String? successMessage;

    void sendProposal(StateSetter setState) async {
      if (selectedDate == null ||
          selectedTime == null ||
          placeController.text.trim().isEmpty) {
        setState(() {
          errorMessage = "Please select date, time, and enter a place.";
        });
        return;
      }
      setState(() {
        isLoading = true;
        errorMessage = null;
        successMessage = null;
      });

      // Create optimistic proposal message
      final DateTime combinedDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      final proposalText =
          "Date: ${DateFormat('MMM d, yyyy').format(combinedDateTime)} at ${selectedTime!.format(context)}\nPlace: ${placeController.text.trim()}";

      final optimisticMessage = {
        'message': proposalText,
        'senderId': _currentUserId,
        'is_image': false,
        'messageType': 'date_proposal',
        '_optimistic': true,
        '_tempId': DateTime.now().millisecondsSinceEpoch.toString(),
        r'$updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      // Add optimistic message to UI immediately
      setState(() {
        _messages.add(optimisticMessage);
        // Sort messages
        _messages.sort((a, b) {
          final aTime = a[r'$updatedAt'] != null
              ? DateTime.tryParse(a[r'$updatedAt'])?.millisecondsSinceEpoch ?? 0
              : 0;
          final bTime = b[r'$updatedAt'] != null
              ? DateTime.tryParse(b[r'$updatedAt'])?.millisecondsSinceEpoch ?? 0
              : 0;
          return aTime.compareTo(bTime);
        });
      });

      // Auto-scroll to show the new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      try {
        final jwt = await account.createJWT();
        final token = jwt.jwt;
        final res = await http.post(
          Uri.parse(
            'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/${widget.connectionId}/propose-date',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'date': combinedDateTime.toIso8601String(),
            'place': placeController.text.trim(),
          }),
        );
        if (res.statusCode == 200) {
          setState(() {
            isLoading = false;
            successMessage = "Date proposal sent successfully.";
          });
          await Future.delayed(const Duration(seconds: 1));
          Navigator.of(context).pop();
          // After sending proposal, refresh proposal status
          await _fetchDateProposalStatus();
        } else {
          // Remove optimistic message on error
          setState(() {
            _messages.removeWhere(
              (m) => m['_tempId'] == optimisticMessage['_tempId'],
            );
          });
          setState(() {
            isLoading = false;
            errorMessage =
                jsonDecode(res.body)['error'] ?? 'Failed to send proposal.';
          });
        }
      } catch (e) {
        // Remove optimistic message on error
        setState(() {
          _messages.removeWhere(
            (m) => m['_tempId'] == optimisticMessage['_tempId'],
          );
        });
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Send Proposal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 20),
                      label: Text(
                        selectedDate == null
                            ? 'Select date'
                            : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    // Time picker
                    TextButton.icon(
                      icon: const Icon(Icons.access_time, size: 20),
                      label: Text(
                        selectedTime == null
                            ? 'Select time'
                            : selectedTime!.format(context),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedTime = picked;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    // Place input
                    TextField(
                      controller: placeController,
                      decoration: const InputDecoration(
                        labelText: 'Place',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          successMessage!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () => sendProposal(setState),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2. When sending a message, always add $createdAt (UTC ISO string)
  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sendingText) return;

    // Create optimistic message
    final optimisticMessage = {
      'message': text,
      'senderId': _currentUserId,
      'is_image': false,
      'messageType': 'text',
      '_optimistic': true, // Mark as optimistic
      '_tempId': DateTime.now().millisecondsSinceEpoch
          .toString(), // Temporary ID
      r'$updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _hasText = false;
      _controller.clear();
      _messages.add(optimisticMessage);
      // Sort messages
      _messages.sort((a, b) {
        final aTime = a[r'$updatedAt'] != null
            ? DateTime.tryParse(a[r'$updatedAt'])?.millisecondsSinceEpoch ?? 0
            : 0;
        final bTime = b[r'$updatedAt'] != null
            ? DateTime.tryParse(b[r'$updatedAt'])?.millisecondsSinceEpoch ?? 0
            : 0;
        return aTime.compareTo(bTime);
      });
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

      // Don't remove optimistic message here - let it stay until we get the real message
      // The real-time update will handle replacing it when the real message comes back

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients)
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      // Remove optimistic message on error
      setState(() {
        _messages.removeWhere(
          (m) => m['_tempId'] == optimisticMessage['_tempId'],
        );
      });
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

    // --- Deletion logic: check if message is deleted (either from server or locally) ---
    final String? docId = m[r'$id'] ?? m['id'];
    final bool isDeleted =
        (m['is_deleted'] == true) ||
        (docId != null && _locallyDeletedMessageIds.contains(docId));

    Widget messageWidget;

    // If message is deleted, show deleted message UI
    if (isDeleted) {
      messageWidget = Row(
        mainAxisAlignment: isSender
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: isSender
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
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.06),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, color: Colors.grey.shade500, size: 18),
                const SizedBox(width: 8),
                Text(
                  'This message was deleted',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      if (dayHeader != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [dayHeader, messageWidget],
        );
      }
      return messageWidget;
    }

    // Special handling for date proposal messages
    if (m['messageType'] == 'date_proposal') {
      // Gradient background
      final gradient = LinearGradient(
        colors: isSender
            ? [const Color(0xFFBFA2E6), const Color(0xFF9F6BC1)]
            : [const Color(0xFF9F6BC1), const Color(0xFF7B3FA3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      // Determine if current user is the sender of the proposal
      String? msgSenderId;
      if (m['senderId'] is Map) {
        msgSenderId =
            m['senderId']['\$id'] ??
            m['senderId']['id'] ??
            m['senderId']['_id'];
      } else if (m['senderId'] is String) {
        msgSenderId = m['senderId'];
      }
      final userId = (_currentUserId ?? '').trim();
      final senderIdStr = msgSenderId?.toString().trim();

      // Only show buttons if the current user is NOT the sender of the proposal
      final bool showProposalButtons = senderIdStr != userId;

      // For accept feedback
      final proposalId =
          m[r'$id'] ??
          m['id'] ??
          m['timestamp']?.toString() ??
          m.hashCode.toString();
      final bool accepted = _acceptedProposals[proposalId] == true;

      // Use the fetched dateProposalStatus for this chat
      String? proposalStatus = _dateProposalStatus;
      bool loadingStatus = _dateProposalStatusLoading;
      String? statusError = _dateProposalStatusError;

      Widget statusWidget = const SizedBox.shrink();

      if (loadingStatus) {
        statusWidget = Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
          child: Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                "Checking proposal status...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        );
      } else if (statusError != null) {
        statusWidget = Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
          child: Text(
            "Failed to load proposal status",
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        );
      } else if (proposalStatus == "proposed") {
        // Show accept/reject/modify buttons
        if (showProposalButtons) {
          statusWidget = _buildDateProposalButtons(
            m,
            showAcceptReject: true,
            showModify: true,
            onAccepted: () {
              setState(() {
                _acceptedProposals[proposalId] = true;
              });
              _fetchDateProposalStatus();
            },
          );
        } else {
          statusWidget = Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text(
              "Proposal sent. Waiting for response.",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          );
        }
      } else if (proposalStatus == "accepted") {
        statusWidget = Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
          child: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
              SizedBox(width: 8),
              Text(
                "Proposal Accepted",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      } else if (proposalStatus == "rejected") {
        statusWidget = Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
          child: Row(
            children: const [
              Icon(Icons.cancel, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text(
                "Proposal Rejected",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      } else if (proposalStatus == "modified") {
        statusWidget = Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
          child: Row(
            children: const [
              Icon(Icons.edit, color: Color(0xFF7B3FA3), size: 22),
              SizedBox(width: 8),
              Text(
                "Proposal Modified",
                style: TextStyle(
                  color: Color(0xFF7B3FA3),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }

      messageWidget = Row(
        mainAxisAlignment: isSender
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: isSender
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
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.08),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Date Proposal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (text != null && text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                statusWidget,
                if (md != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _formatTime(md),
                      style: const TextStyle(
                        color: Colors.white70,
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
      if (dayHeader != null)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [dayHeader, messageWidget],
        );
      return messageWidget;
    }

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

    Widget contentWidget;
    if (isImage && imageUrl != null && imageUrl.isNotEmpty) {
      final img = imageUrl.startsWith('http')
          ? Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            )
          : Image.file(
              File(imageUrl),
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            );
      contentWidget = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 290, maxHeight: 290),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
      );
    } else if (text != null && text.isNotEmpty) {
      if (isOptimistic) {
        contentWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (md != null)
              Text(
                _formatTime(md),
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        );
      } else {
        contentWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (md != null)
              Text(
                _formatTime(md),
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        );
      }
    } else if (isImage && (imageUrl == null || imageUrl.isEmpty)) {
      contentWidget = const Text(
        '[Image not available]',
        style: TextStyle(color: Colors.red, fontSize: 14),
      );
    } else {
      contentWidget = const SizedBox.shrink();
    }

    // --- Add long-press to show delete popup for own messages ---
    Widget messageContainer = GestureDetector(
      onLongPress: !isSender && !isDeleted
          ? () {
              _showDeleteMessageDialog(m);
            }
          : null,
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
            padding: isImage
                ? null
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: isImage && !isOptimistic ? null : null,
            decoration: BoxDecoration(
              color: isImage ? messageColor : messageColor,
              borderRadius: messageBorderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.08),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: contentWidget,
          ),
        ],
      ),
    );

    if (dayHeader != null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [dayHeader, messageContainer],
      );
    return messageContainer;
  }

  // Align image messages as well, with proper image fit and box sizing
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
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          )
        : Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          );

    // Add margin so images don't touch each other
    return Row(
      mainAxisAlignment: isSender
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290, maxHeight: 290),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: img,
            ),
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
        // Action menu button (right arrow)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: _showActionMenu ? 160 : 52,
          height: 52,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showActionMenu = !_showActionMenu;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E9FA),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _showActionMenu
                        ? Icons.close
                        : Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF9F6BC1),
                    size: 24,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _showActionMenu ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Row(
                  children: [
                    if (_showActionMenu) ...[
                      const SizedBox(width: 8),
                      // Image icon
                      GestureDetector(
                        onTap: _sendingImage
                            ? null
                            : () async {
                                setState(() {
                                  _showActionMenu = false;
                                });
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
                      const SizedBox(width: 8),
                      // Proposal icon
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showActionMenu = false;
                          });
                          _showProposalFormDialog();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E9FA),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: Color(0xFF9F6BC1),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
            backgroundColor: Color(0xFF3B2357),
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
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    profile_check.ProfileCheck(userId: widget.userId),
              ),
            );
          },
          child: CircleAvatar(
            radius: 20, // increased avatar size
            backgroundImage:
                (_userImageUrl != null && _userImageUrl!.isNotEmpty)
                ? NetworkImage(_userImageUrl!)
                : null,
            backgroundColor: const Color(0xFFEEE0F7),
            child: (_userImageUrl == null || _userImageUrl!.isEmpty)
                ? const Icon(Icons.person, color: Color(0xFF9F6BC1), size: 22)
                : null,
          ),
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

  Widget _buildDateProposalButtons(
    Map<String, dynamic> m, {
    bool showAcceptReject = true,
    bool showModify = true,
    VoidCallback? onAccepted,
  }) {
    bool isLoading = false;
    String? errorMessage;

    void respond(
      String responseType, {
      DateTime? newDate,
      String? newPlace,
    }) async {
      if (isLoading) return;
      isLoading = true;
      errorMessage = null;

      try {
        // Validate responseType
        const allowedTypes = ['accept', 'reject', 'modify'];
        if (!allowedTypes.contains(responseType)) {
          errorMessage = "Invalid response type.";
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid response type.')),
          );
          return;
        }

        // Validate modify fields
        if (responseType == 'modify') {
          if (newDate == null || newPlace == null || newPlace.trim().isEmpty) {
            errorMessage =
                "Please provide both a new date and place to modify.";
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please provide both a new date and place to modify.',
                ),
              ),
            );
            return;
          }
        }

        // JWT creation
        dynamic jwt;
        try {
          jwt = await account.createJWT();
        } catch (e) {
          errorMessage = "Authentication failed. Please try again.";
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage!)));
          return;
        }
        final token = jwt.jwt;
        final Map<String, dynamic> body = {'responseType': responseType};
        if (responseType == 'modify') {
          body['newDetails'] = {
            'date': newDate!.toIso8601String(),
            'place': newPlace!.trim(),
          };
        }

        http.Response res;
        try {
          res = await http.post(
            Uri.parse(
              'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/chats/${widget.connectionId}/respond-date',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          );
        } catch (e) {
          errorMessage = "Network error. Please check your connection.";
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage!)));
          return;
        }

        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Date proposal ${responseType}ed successfully.'),
            ),
          );
          if (responseType == 'accept' && onAccepted != null) {
            onAccepted();
          }
          // After responding, refresh proposal status
          await _fetchDateProposalStatus();
        } else {
          // Try to parse error from response
          String serverError = 'Failed to respond.';
          try {
            final data = jsonDecode(res.body);
            if (data is Map && data['error'] != null) {
              serverError = data['error'].toString();
            }
          } catch (_) {
            serverError = 'Failed to respond. Server error.';
          }
          errorMessage = serverError;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage!)));
        }
      } catch (e, stack) {
        // Log error for debugging
        debugPrint('Error in respond: $e\n$stack');
        errorMessage = "An unexpected error occurred. Please try again.";
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage!)));
      } finally {
        isLoading = false;
      }
    }

    void showModifyDialog() {
      DateTime? selectedDate;
      TimeOfDay? selectedTime;
      TextEditingController placeController = TextEditingController();
      bool localLoading = false;

      String? localError;
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Modify Proposal'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: Text(
                          selectedDate == null
                              ? 'Select date'
                              : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                        ),
                        onPressed: localLoading
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time, size: 20),
                        label: Text(
                          selectedTime == null
                              ? 'Select time'
                              : selectedTime!.format(context),
                        ),
                        onPressed: localLoading
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedTime = picked;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: placeController,
                        decoration: const InputDecoration(
                          labelText: 'Place',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !localLoading,
                      ),
                      const SizedBox(height: 12),
                      if (localError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            localError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: localLoading
                        ? null
                        : () async {
                            if (selectedDate == null ||
                                selectedTime == null ||
                                placeController.text.trim().isEmpty) {
                              setState(() {
                                localError =
                                    "Please select date, time, and enter a place.";
                              });
                              return;
                            }
                            setState(() {
                              localLoading = true;
                              localError = null;
                            });
                            final DateTime combinedDateTime = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );
                            respond(
                              'modify',
                              newDate: combinedDateTime,
                              newPlace: placeController.text.trim(),
                            );
                            Navigator.of(context).pop();
                          },
                    child: localLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (showAcceptReject) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B3FA3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          respond('accept');
                          if (onAccepted != null) {
                            onAccepted();
                          }
                        },
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFA2E6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: isLoading ? null : () => respond('reject'),
                  child: const Text('Reject'),
                ),
              ],
              if (showModify) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3E9FA),
                    foregroundColor: const Color(0xFF7B3FA3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: isLoading ? null : showModifyDialog,
                  child: const Text('Modify'),
                ),
              ],
            ],
          ),
        ),
      ],
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
      actions: [_buildMessageCountCircle()],
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
                                return Column(
                                  children: [
                                    _buildMessage(
                                      _messages[i],
                                      previousMessageDate: prevDate,
                                      previousDayKey: prevDayKey,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
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
