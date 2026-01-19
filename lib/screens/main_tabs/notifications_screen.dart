import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import '../../appwrite/appwrite.dart';
import '../../services/config_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import '../profile_check.dart';

// Import all ids from config service
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final notificationsCollectionId = ConfigService().get(
  'NOTIFICATIONS_COLLECTIONID',
);
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID');
final imagesCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');

// Brand colors
const Color _kPrimary = Color(0xFF3B2357);
const Color _kAccent = Color(0xFF6D4B86);
const Color _kSurface = Colors.white;
const Color _kPillBg = Color(0xFFEFE3F7);
const Color _kCardTint = Color(0xFFF6EFFB);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _sentInvitations = [];
  bool _loading = true;
  bool _loadingSent = true;
  String? _error;
  String? _errorSent;
  bool _actionInProgress = false;

  static const String _cacheKey = 'cached_notifications';

  @override
  void initState() {
    super.initState();
    _loadCachedNotifications();
    _fetchNotificationsInBackground();
    _fetchSentInvitations();
  }

  Future<void> _loadCachedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        final List<Map<String, dynamic>> notifications = decoded
            .cast<Map<String, dynamic>>();
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      } catch (_) {
        setState(() {
          _loading = true;
        });
      }
    } else {
      setState(() {
        _loading = true;
      });
    }
  }

  Future<void> _cacheNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(notifications));
  }

  void _fetchNotificationsInBackground() {
    _fetchNotifications(showLoading: false);
  }

  Future<void> _fetchNotifications({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      final user = await account.get();
      final userId = user?.$id;
      if (userId == null) throw Exception('User not found or not logged in.');

      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: notificationsCollectionId,
        queries: [Query.equal('to', userId)],
      );

      final List<Map<String, dynamic>> notifications = [];

      for (final doc in result?.documents ?? []) {
        final fromData = doc.data['from'];
        final toData = doc.data['to'];

        if (fromData == null || toData == null) {
          debugPrint(
            'Skipping notification with null from/to data: ${doc.$id}',
          );
          continue;
        }

        if (fromData is! Map || toData is! Map) {
          debugPrint(
            'Skipping notification with invalid from/to data structure: ${doc.$id}',
          );
          continue;
        }

        final fromUserId = fromData['\$id'];
        final toUserId = toData['\$id'];

        if (fromUserId == null ||
            toUserId == null ||
            fromUserId.toString().isEmpty ||
            toUserId.toString().isEmpty) {
          debugPrint(
            'Skipping notification with null/empty user IDs: ${doc.$id}',
          );
          continue;
        }

        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: notificationsCollectionId,
          documentId: doc.data['\$id'],
          data: {'is_read': true},
        );

        dynamic fromUserDoc;
        try {
          fromUserDoc = await databases.getDocument(
            databaseId: usersCollectionId,
            collectionId: usersCollectionId,
            documentId: fromUserId,
            queries: [
              Query.select(['name']),
            ],
          );
        } catch (_) {
          fromUserDoc = appwrite_models.Document(
            $id: 'unknown',
            $collectionId: 'unknown',
            $databaseId: 'unknown',
            $createdAt: '',
            $updatedAt: '',
            $permissions: [],
            data: {'name': 'Unknown'},
          );
        }

        dynamic fromUserImage;
        try {
          fromUserImage = await databases.listDocuments(
            databaseId: databaseId,
            collectionId: imagesCollectionId,
            queries: [Query.equal('user', fromUserId)],
          );
        } catch (e) {
          debugPrint('Error fetching fromUser image for $fromUserId: $e');
          fromUserImage = appwrite_models.DocumentList(total: 0, documents: []);
        }

        String _formatTime(String iso) {
          try {
            final dt = DateTime.parse(iso).toLocal();
            int h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final m = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour >= 12 ? 'pm' : 'am';
            return '$h:$m$ampm';
          } catch (_) {
            return '';
          }
        }

        final userName =
            (fromUserDoc != null && fromUserDoc is appwrite_models.Document)
            ? fromUserDoc.data['name']
            : 'Unknown';
        final userImg = (fromUserImage.documents.isNotEmpty)
            ? fromUserImage.documents[0].data['image_1']
            : null;

        dynamic connectionsDoc;

        try {
          connectionsDoc = await databases.listDocuments(
            databaseId: databaseId,
            collectionId: connectionsCollectionId,
            queries: [
              Query.equal('senderId', fromUserId),
              Query.equal('receiverId', toUserId),
            ],
          );
        } catch (_) {
          connectionsDoc = appwrite_models.DocumentList(
            total: 0,
            documents: [],
          );
        }

        if (connectionsDoc.documents.isEmpty) {
          continue;
        }

        notifications.add({
          'inviteStatus': connectionsDoc.documents.isNotEmpty
              ? connectionsDoc.documents[0].data['status']
              : null,
          'connectionId': connectionsDoc.documents.isNotEmpty
              ? connectionsDoc.documents[0].$id
              : null,
          'fromUserId': fromUserId,
          'type': doc.data['type'],
          'icon': 'mailbox',
          'iconBg': 0xFF6D4B86,
          'userImg': userImg,
          'userName': userName,
          'message': doc.data['payload']?.toString() ?? '',
          'time': _formatTime(doc.$createdAt ?? ''),
          'highlight': !(doc.data['is_read'] == true),
        });
      }

      setState(() {
        _notifications = notifications;
        _loading = false;
      });
      await _cacheNotifications(notifications);
    } catch (e) {
      debugPrint('Notification fetch error: $e');
      setState(() {
        _error = e is AppwriteException
            ? 'Appwrite error: ${e.message ?? e.toString()}'
            : 'Error fetching notifications: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchSentInvitations() async {
    setState(() {
      _loadingSent = true;
      _errorSent = null;
    });

    try {
      final user = await account.get();
      final userId = user?.$id;
      debugPrint('Current userId: $userId');
      if (userId == null) throw Exception('User not found or not logged in.');

      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: connectionsCollectionId,
        queries: [
          Query.equal('status', 'pending'),
          Query.equal('senderId', userId),
        ],
      );

      debugPrint('Fetched sent invitations: ${result?.documents.length}');
      if (result?.documents == null || result!.documents.isEmpty) {
        debugPrint('No sent invitations found.');
        setState(() {
          _sentInvitations = [];
          _loadingSent = false;
        });
        return;
      }

      final List<Map<String, dynamic>> sentInvitations = [];

      for (final doc in result.documents) {
        final receiverObj = doc.data['receiverId'];
        String receiverId = '';
        String receiverName = '';

        if (receiverObj is Map) {
          receiverId = receiverObj[r'$id'] ?? '';
          receiverName = receiverObj['name'] ?? '';
          debugPrint('ReceiverId from doc: $receiverId, name: $receiverName');
        }

        if (receiverName.isEmpty && receiverId.isNotEmpty) {
          try {
            final userDoc = await databases.getDocument(
              databaseId: usersCollectionId,
              collectionId: usersCollectionId,
              documentId: receiverId,
              queries: [
                Query.select(['name']),
              ],
            );
            debugPrint(
              'Fetched userDoc for receiverId $receiverId: ${userDoc?.data}',
            );
            if (userDoc != null && userDoc.data['name'] != null) {
              receiverName = userDoc.data['name'];
            }
          } catch (e) {
            debugPrint('Error fetching user name for $receiverId: $e');
          }
        }

        String? receiverImg;
        if (receiverId.isNotEmpty) {
          try {
            final imgDoc = await databases.listDocuments(
              databaseId: databaseId,
              collectionId: imagesCollectionId,
              queries: [Query.equal('user', receiverId)],
            );
            debugPrint(
              'Fetched imgDoc for receiverId $receiverId: ${imgDoc.documents.map((d) => d.data).toList()}',
            );
            if (imgDoc.documents.isNotEmpty) {
              receiverImg = imgDoc.documents[0].data['image_1'];
              debugPrint('Found receiverImg: $receiverImg');
            }
          } catch (e) {
            debugPrint('Error fetching user image for $receiverId: $e');
          }
        }

        String _formatTime(String iso) {
          try {
            final dt = DateTime.parse(iso).toLocal();
            int h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final m = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour >= 12 ? 'pm' : 'am';
            return '$h:$m$ampm';
          } catch (_) {
            return '';
          }
        }

        final invitation = {
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverImg': receiverImg,
          'status': doc.data['status'],
          'time': _formatTime(doc.$createdAt ?? ''),
          'connectionId': doc.$id,
        };
        debugPrint('Final invitation object: $invitation');
        sentInvitations.add(invitation);
      }

      setState(() {
        _sentInvitations = sentInvitations;
        _loadingSent = false;
      });
      debugPrint('All sentInvitations: $_sentInvitations');
    } catch (e) {
      debugPrint('Error in _fetchSentInvitations: $e');
      setState(() {
        _errorSent = 'Error fetching sent invitations: $e';
        _loadingSent = false;
      });
    }
  }

  // ---------- UI helpers ----------
  void _showSnack(BuildContext context, String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: success
            ? const Color(0xFF2E7D32)
            : const Color(0xFFB85C5C),
      ),
    );
  }

  void _showLoadingOverlay(
    BuildContext context, {
    String message = 'Please wait...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: _BlurDialog(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoadingOverlay(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<bool?> _showDeleteConfirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _BlurDialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: _kAccent,
                size: 32,
              ),
              const SizedBox(height: 10),
              const Text(
                'Remove Invitation?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _kPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Do you want to remove this invitation?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: _kAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kAccent,
                        side: const BorderSide(color: _kAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFCE9E9),
                        foregroundColor: const Color(0xFFB85C5C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Actions ----------
  Future<void> _handleAcceptInvitation({
    required BuildContext context,
    required String connectionId,
  }) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
    });
    _showLoadingOverlay(context, message: 'Accepting...');
    try {
      final jwt = await account.createJWT();
      final token = jwt.jwt;
      final uri = Uri.parse(
        '${ConfigService.baseUrl}/api/v1/notification/invitations/accept',
      );
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode({'connectionId': connectionId}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        _hideLoadingOverlay(context);
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to accept invitation',
        );
      }
      if (!mounted) return;
      _hideLoadingOverlay(context);
      _showSnack(context, 'Invitation accepted', success: true);
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        _hideLoadingOverlay(context);
        _showSnack(context, 'Failed to accept: $e', success: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  Future<void> _handleRejectInvitation({
    required BuildContext context,
    required String connectionId,
    required String receiverUserId,
  }) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
    });
    _showLoadingOverlay(context, message: 'Declining...');
    try {
      final jwt = await account.createJWT();
      final token = jwt.jwt;
      final uri = Uri.parse(
        '${ConfigService.baseUrl}/api/v1/notification/invitations/decline',
      );
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');
      request.write(
        jsonEncode({
          'connectionId': connectionId,
          'receiverUserId': receiverUserId,
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        _hideLoadingOverlay(context);
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to decline invitation',
        );
      }
      if (!mounted) return;
      _hideLoadingOverlay(context);
      _showSnack(context, 'Invitation declined', success: true);
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        _hideLoadingOverlay(context);
        _showSnack(context, 'Failed to decline: $e', success: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  Future<void> _deleteSentInvitation(
    String connectionId,
    BuildContext context,
  ) async {
    setState(() {
      _actionInProgress = true;
    });
    try {
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: connectionsCollectionId,
        documentId: connectionId,
      );
      _showSnack(context, 'Invitation removed', success: true);
      await _fetchSentInvitations();
    } catch (e) {
      _showSnack(context, 'Failed to remove invitation: $e', success: false);
    } finally {
      setState(() {
        _actionInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F3FA), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(120),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: const Text(
                'Notifications',
                style: TextStyle(
                  color: _kPrimary,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _kPrimary,
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                splashRadius: 22,
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kPillBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: _kAccent,
                      indicator: BoxDecoration(
                        color: _kAccent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x336D4B86),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      labelStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      tabs: const [
                        Tab(text: 'Received'),
                        Tab(text: 'Sent'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            children: [
              // --- Received Tab ---
              _loading
                  ? const _LoadingList()
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final activeNotifications = _notifications.where((
                          notif,
                        ) {
                          if (notif['type'] == 'invite' &&
                              (notif['inviteStatus'] == 'declined' ||
                                  notif['inviteStatus'] == 'chat_active')) {
                            return false;
                          }
                          return true;
                        }).toList();

                        if (activeNotifications.isEmpty) {
                          return const _EmptyState(
                            icon: PhosphorIconsDuotone.bellSimpleSlash,
                            title: 'No notifications',
                            subtitle: 'You’ll see new activity here.',
                          );
                        }

                        return RefreshIndicator.adaptive(
                          onRefresh: () async {
                            await _fetchNotifications();
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                            itemCount: activeNotifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final notif = activeNotifications[index];
                              final highlighted = notif['highlight'] == true;

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  final userId = notif['fromUserId'];
                                  if (userId != null && userId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProfileCheck(userId: userId),
                                      ),
                                    );
                                  }
                                },
                                child: Card(
                                  color: highlighted ? _kCardTint : _kSurface,
                                  elevation: highlighted ? 3 : 1,
                                  shadowColor: const Color(0x22000000),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: highlighted
                                        ? const BorderSide(
                                            color: _kAccent,
                                            width: 0.6,
                                          )
                                        : BorderSide.none,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                          leading: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Color(
                                                    notif['iconBg'] as int,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: PhosphorIcon(
                                                  _iconFromString(
                                                    notif['icon'] as String,
                                                  ),
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              CircleAvatar(
                                                radius: 35,
                                                backgroundImage:
                                                    (notif['userImg'] is String)
                                                    ? NetworkImage(
                                                        notif['userImg']
                                                            as String,
                                                      )
                                                    : null,
                                                child: notif['userImg'] == null
                                                    ? const Icon(
                                                        Icons.person,
                                                        color: _kAccent,
                                                        size: 40,
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                          title: Text(
                                            notif['userName'] as String,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: _kPrimary,
                                            ),
                                          ),
                                          subtitle: Text(
                                            notif['message'] as String,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12.5,
                                              color: _kAccent,
                                            ),
                                          ),
                                          trailing: Text(
                                            notif['time'] as String,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11.5,
                                              color: _kAccent,
                                            ),
                                          ),
                                          horizontalTitleGap: 12,
                                          minLeadingWidth: 0,
                                        ),
                                        if (notif['type'] == 'invite' &&
                                            notif['inviteStatus'] == 'pending')
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              12,
                                              12,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                FilledButton.tonalIcon(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFE6F4EA),
                                                    foregroundColor:
                                                        const Color(0xFF2E7D32),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                  onPressed: _actionInProgress
                                                      ? null
                                                      : () {
                                                          final connectionId =
                                                              notif['connectionId'];
                                                          if (connectionId !=
                                                              null) {
                                                            _handleAcceptInvitation(
                                                              context: context,
                                                              connectionId:
                                                                  connectionId,
                                                            );
                                                          }
                                                        },
                                                  icon: const Icon(
                                                    Icons.check_rounded,
                                                  ),
                                                  label: const Text(
                                                    'Accept',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        const Color(0xFFB85C5C),
                                                    side: const BorderSide(
                                                      color: Color(0xFFB85C5C),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                  onPressed: _actionInProgress
                                                      ? null
                                                      : () {
                                                          final connectionId =
                                                              notif['connectionId'];
                                                          final receiverUserId =
                                                              notif['fromUserId'];
                                                          if (connectionId !=
                                                                  null &&
                                                              receiverUserId !=
                                                                  null) {
                                                            _handleRejectInvitation(
                                                              context: context,
                                                              connectionId:
                                                                  connectionId,
                                                              receiverUserId:
                                                                  receiverUserId,
                                                            );
                                                          }
                                                        },
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                  ),
                                                  label: const Text(
                                                    'Reject',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
              // --- Sent Tab ---
              _loadingSent
                  ? const _LoadingList()
                  : _errorSent != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorSent!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _sentInvitations.isEmpty
                  ? const _EmptyState(
                      icon: PhosphorIconsDuotone.paperPlaneTilt,
                      title: 'No sent invitations',
                      subtitle: 'Your outgoing invitations will appear here.',
                    )
                  : RefreshIndicator.adaptive(
                      onRefresh: () async {
                        await _fetchSentInvitations();
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: _sentInvitations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sent = _sentInvitations[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              final userId = sent['receiverId'];
                              if (userId != null && userId.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileCheck(userId: userId),
                                  ),
                                );
                              }
                            },
                            onLongPress: () async {
                              final shouldDelete = await _showDeleteConfirm(
                                context,
                              );
                              if (shouldDelete == true) {
                                final connectionId = sent['connectionId'];
                                if (connectionId != null &&
                                    connectionId.isNotEmpty) {
                                  await _deleteSentInvitation(
                                    connectionId,
                                    context,
                                  );
                                }
                              }
                            },
                            child: Card(
                              color: _kSurface,
                              elevation: 1,
                              shadowColor: const Color(0x22000000),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 35,
                                  backgroundImage:
                                      (sent['receiverImg'] is String)
                                      ? NetworkImage(sent['receiverImg'])
                                      : null,
                                  child: sent['receiverImg'] == null
                                      ? const Icon(
                                          Icons.person,
                                          color: _kAccent,
                                          size: 40,
                                        )
                                      : null,
                                ),
                                title:
                                    (sent['receiverName'] as String).isNotEmpty
                                    ? Text(
                                        sent['receiverName'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: _kPrimary,
                                        ),
                                      )
                                    : null,
                                subtitle: Text(
                                  'Status: ${sent['status']}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12.5,
                                    color: _kAccent,
                                  ),
                                ),
                                trailing: Text(
                                  sent['time'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11.5,
                                    color: _kAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurDialog extends StatelessWidget {
  final Widget child;
  const _BlurDialog({required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: _kAccent),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _kPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
                color: _kAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemBuilder: (_, __) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const _ShimmerPlaceholder(),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: 6,
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder();

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          children: [
            const SizedBox(width: 12),
            _bar(width: 40, height: 40, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 140, height: 12, radius: 6),
                  const SizedBox(height: 8),
                  _bar(width: 220, height: 10, radius: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        );
      },
    );
  }

  Widget _bar({
    required double width,
    required double height,
    required double radius,
  }) {
    final t = _controller.value;
    final base = const Color(0xFFEDE7F3);
    final hi = const Color(0xFFF6EFFB);
    final color = Color.lerp(base, hi, (t * 2).clamp(0.0, 1.0))!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

IconData _iconFromString(String iconName) {
  switch (iconName) {
    case 'mailbox':
      return PhosphorIconsFill.mailbox;
    default:
      return Icons.notifications;
  }
}
