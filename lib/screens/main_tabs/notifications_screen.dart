import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import '../../appwrite/appwrite.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile_check.dart';

// Import all ids from .env using String.fromEnvironment
const String appwriteDatabaseId = String.fromEnvironment('DATABASE_ID');
const String appwriteNotificationsCollectionId = String.fromEnvironment('NOTIFICATIONS_COLLECTIONID');
const String appwriteUsersCollectionId = String.fromEnvironment('USERS_COLLECTIONID');
const String appwriteImagesCollectionId = String.fromEnvironment('IMAGE_COLLECTIONID');
const String appwriteConnectionsCollectionId = String.fromEnvironment('CONNECTIONS_COLLECTIONID');

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
        final List<Map<String, dynamic>> notifications = decoded.cast<Map<String, dynamic>>();
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
        databaseId: appwriteDatabaseId,
        collectionId: appwriteNotificationsCollectionId,
        queries: [Query.equal('to', userId)],
      );

      final List<Map<String, dynamic>> notifications = [];

      for (final doc in result?.documents ?? []) {
        // Add comprehensive null safety checks
        final fromData = doc.data['from'];
        final toData = doc.data['to'];
        
        // Skip documents with missing or null from/to data
        if (fromData == null || toData == null) {
          debugPrint('Skipping notification with null from/to data: ${doc.$id}');
          continue;
        }
        
        // Check if fromData and toData are Maps and have the required $id field
        if (fromData is! Map || toData is! Map) {
          debugPrint('Skipping notification with invalid from/to data structure: ${doc.$id}');
          continue;
        }
        
        final fromUserId = fromData['\$id'];
        final toUserId = toData['\$id'];
        
        // Skip if any required ID is null or empty
        if (fromUserId == null || toUserId == null || 
            fromUserId.toString().isEmpty || toUserId.toString().isEmpty) {
          debugPrint('Skipping notification with null/empty user IDs: ${doc.$id}');
          continue;
        }
        
        await databases.updateDocument(
          databaseId: appwriteDatabaseId,
          collectionId: appwriteNotificationsCollectionId,
          documentId: doc.data['\$id'],
          data: {'is_read': true},
        );

        dynamic fromUserDoc;
        try {
          fromUserDoc = await databases.getDocument(
            databaseId: appwriteDatabaseId,
            collectionId: appwriteUsersCollectionId,
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
            databaseId: appwriteDatabaseId,
            collectionId: appwriteImagesCollectionId,
            queries: [Query.equal('user', fromUserId)],
          );
        } catch (_) {
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
            databaseId: appwriteDatabaseId,
            collectionId: appwriteConnectionsCollectionId,
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
        databaseId: appwriteDatabaseId,
        collectionId: appwriteConnectionsCollectionId,
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
              databaseId: appwriteDatabaseId,
              collectionId: appwriteUsersCollectionId,
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
              databaseId: appwriteDatabaseId,
              collectionId: appwriteImagesCollectionId,
              queries: [Query.equal('user', receiverId)],
            );
            debugPrint(
              'Fetched imgDoc for receiverId $receiverId: ${imgDoc.documents.map((d) => d.data).toList()}',
            );
            if (imgDoc.documents.isNotEmpty) {
              receiverImg = imgDoc.documents[0].data['image_1'];
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

  Future<void> _handleAcceptInvitation({
    required BuildContext context,
    required String connectionId,
  }) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
    });
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      pageBuilder: (context, anim1, anim2) {
        return const Center(child: CircularProgressIndicator());
      },
    );
    try {
      final jwt = await account.createJWT();
      final token = jwt.jwt;
      final uri = Uri.parse(
        'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/notification/invitations/accept',
      );
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode({'connectionId': connectionId}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to accept invitation',
        );
      }
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation accepted')));
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      pageBuilder: (context, anim1, anim2) {
        return const Center(child: CircularProgressIndicator());
      },
    );
    try {
      final jwt = await account.createJWT();
      final token = jwt.jwt;
      final uri = Uri.parse(
        'https://stormy-brook-18563-016c4b3b4015.herokuapp.com/api/v1/notification/invitations/decline',
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
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to decline invitation',
        );
      }
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation declined')));
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
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
        databaseId: appwriteDatabaseId,
        collectionId: appwriteConnectionsCollectionId,
        documentId: connectionId,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation removed')));
      await _fetchSentInvitations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove invitation: $e')),
      );
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
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: AppBar(
            backgroundColor: Colors.white,
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
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF3B2357),
                size: 22,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              splashRadius: 22,
            ),
            bottom: const TabBar(
              labelColor: Color(0xFF3B2357),
              unselectedLabelColor: Color(0xFF6D4B86),
              indicatorColor: Color(0xFF6D4B86),
              labelStyle: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              tabs: [
                Tab(text: 'Received'),
                Tab(text: 'Sent'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // --- Received Tab ---
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _notifications.isEmpty
                        ? const Center(
                            child: Text(
                              'No notifications yet.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                                color: Color(0xFF6D4B86),
                              ),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final activeNotifications = _notifications.where((notif) {
                                if (notif['type'] == 'invite' &&
                                    (notif['inviteStatus'] == 'declined' ||
                                        notif['inviteStatus'] == 'chat_active')) {
                                  return false;
                                }
                                return true;
                              }).toList();

                              if (activeNotifications.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                                    child: Text(
                                      "No notifications.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Color(0xFF6D4B86),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return RefreshIndicator(
                                onRefresh: () async {
                                  await _fetchNotifications();
                                },
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(top: 8),
                                  itemCount: activeNotifications.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                                  itemBuilder: (context, index) {
                                    final notif = activeNotifications[index];

                                    // Wrap the card in InkWell to make the whole card clickable
                                    return InkWell(
                                      onTap: () {
                                        final userId = notif['fromUserId'];
                                        if (userId != null && userId.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProfileCheck(userId: userId),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        color: notif['highlight'] == true
                                            ? const Color(0xFFD6BEEA)
                                            : Colors.transparent,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 0,
                                            vertical: 0,
                                          ),
                                          child: Column(
                                            children: [
                                              ListTile(
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 20,
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
                                                      padding: const EdgeInsets.all(8),
                                                      child: PhosphorIcon(
                                                        _iconFromString(
                                                          notif['icon'] as String,
                                                        ),
                                                        color: Colors.white,
                                                        size: 22,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundImage: (notif['userImg'] is String)
                                                          ? NetworkImage(
                                                              notif['userImg'] as String,
                                                            )
                                                          : null,
                                                      child: notif['userImg'] == null
                                                          ? const Icon(
                                                              Icons.person,
                                                              color: Color(0xFF6D4B86),
                                                            )
                                                          : null,
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
                                                // Remove onTap from ListTile, handled by InkWell
                                              ),
                                              if (notif['type'] == 'invite' &&
                                                  notif['inviteStatus'] == 'pending')
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    left: 92,
                                                    right: 20,
                                                    bottom: 8,
                                                    top: 0,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      TextButton(
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: const Color(
                                                            0xFF388E3C,
                                                          ),
                                                          textStyle: const TextStyle(
                                                            fontFamily: 'Poppins',
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 6,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                        ),
                                                        onPressed: _actionInProgress
                                                            ? null
                                                            : () {
                                                                final connectionId = notif['connectionId'];
                                                                if (connectionId != null) {
                                                                  _handleAcceptInvitation(
                                                                    context: context,
                                                                    connectionId: connectionId,
                                                                  );
                                                                }
                                                              },
                                                        child: const Text('Accept'),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      TextButton(
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: const Color(
                                                            0xFFB85C5C,
                                                          ),
                                                          textStyle: const TextStyle(
                                                            fontFamily: 'Poppins',
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 6,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                        ),
                                                        onPressed: _actionInProgress
                                                            ? null
                                                            : () {
                                                                final connectionId = notif['connectionId'];
                                                                final receiverUserId = notif['fromUserId'];
                                                                if (connectionId != null && receiverUserId != null) {
                                                                  _handleRejectInvitation(
                                                                    context: context,
                                                                    connectionId: connectionId,
                                                                    receiverUserId: receiverUserId,
                                                                  );
                                                                }
                                                              },
                                                        child: const Text('Reject'),
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
                ? const Center(child: CircularProgressIndicator())
                : _errorSent != null
                    ? Center(
                        child: Text(
                          _errorSent!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _sentInvitations.isEmpty
                        ? const Center(
                            child: Text(
                              'No notifications sent.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                                color: Color(0xFF6D4B86),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _fetchSentInvitations();
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _sentInvitations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 2),
                              itemBuilder: (context, index) {
                                final sent = _sentInvitations[index];
                                // Make the whole card clickable for profile
                                return InkWell(
                                  onTap: () {
                                    final userId = sent['receiverId'];
                                    if (userId != null && userId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileCheck(userId: userId),
                                        ),
                                      );
                                    }
                                  },
                                  onLongPress: () async {
                                    final shouldDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Remove Invitation?'),
                                        content: const Text(
                                          'Do you want to remove this invitation?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (shouldDelete == true) {
                                      final connectionId = sent['connectionId'];
                                      if (connectionId != null && connectionId.isNotEmpty) {
                                        await _deleteSentInvitation(
                                          connectionId,
                                          context,
                                        );
                                      }
                                    }
                                  },
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: (sent['receiverImg'] is String)
                                          ? NetworkImage(sent['receiverImg'])
                                          : null,
                                      child: sent['receiverImg'] == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Color(0xFF6D4B86),
                                            )
                                          : null,
                                    ),
                                    title: (sent['receiverName'] as String).isNotEmpty
                                        ? Text(
                                            sent['receiverName'] as String,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: Color(0xFF3B2357),
                                            ),
                                          )
                                        : null,
                                    subtitle: Text(
                                      'Status: ${sent['status']}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        color: Color(0xFF6D4B86),
                                      ),
                                    ),
                                    trailing: Text(
                                      sent['time'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 11,
                                        color: Color(0xFF6D4B86),
                                      ),
                                    ),
                                    // Remove onLongPress from ListTile, handled by InkWell
                                  ),
                                );
                              },
                            ),
                          ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFromString(String iconName) {
  switch (iconName) {
    case 'mailbox':
      return PhosphorIconsFill.mailbox;
    // add more cases as needed
    default:
      return Icons.notifications;
  }
}