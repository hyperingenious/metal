import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import '../../appwrite/appwrite.dart';
import 'dart:convert';
import 'dart:io';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await account.get();
      final userId = user?.$id;
      if (userId == null) throw Exception('User not found or not logged in.');

      final result = await databases.listDocuments(
        databaseId: '685a90fa0009384c5189',
        collectionId: '685aae0300185620e41d',
        queries: [Query.equal('to', userId)],
      );

      final List<Map<String, dynamic>> notifications = [];

      for (final doc in result?.documents ?? []) {
        final fromUserId = doc.data['from']['\$id'];
        final toUserId = doc.data['to']['\$id'];
        if (fromUserId == null) continue;
        await databases.updateDocument(
          databaseId: '685a90fa0009384c5189',
          collectionId: '685aae0300185620e41d',
          documentId: doc.data['\$id'],
          data: {'is_read': true},
        );

        dynamic fromUserDoc;
        try {
          fromUserDoc = await databases.getDocument(
            databaseId: '685a90fa0009384c5189',
            collectionId: '68616ecc00163ed41e57',
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
            databaseId: '685a90fa0009384c5189',
            collectionId: '685aa0ef00090023c8a3',
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
            databaseId: '685a90fa0009384c5189',
            collectionId: '685a95f5001cadd0cfc3',
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
        // print(connectionsDoc.documents[0]);

        notifications.add({
          'inviteStatus': connectionsDoc.documents.isNotEmpty
              ? connectionsDoc.documents[0].data['status']
              : null,
          'connectionId': connectionsDoc.documents.isNotEmpty
              ? connectionsDoc.documents[0].$id
              : null,
          'fromUserId': fromUserId,
          'type': doc.data['type'],
          'icon': PhosphorIconsFill.mailbox,
          'iconBg': const Color(0xFF6D4B86),
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

  // --- Accept Invitation logic ---
  Future<void> _handleAcceptInvitation({
    required BuildContext context,
    required String connectionId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      // Get JWT for authentication
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
        Navigator.of(context).pop();
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to accept invitation',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // remove dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation accepted')));
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
      }
    }
  }
  // ------------------------------------------------------------

  // --- Moved and fixed the onPressed for Reject button here ---
  Future<void> _handleRejectInvitation({
    required BuildContext context,
    required String connectionId,
    required String receiverUserId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      // Get JWT for authentication
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
        Navigator.of(context).pop();
        throw Exception(
          jsonDecode(body)['error'] ?? 'Failed to decline invitation',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // remove dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation declined')));
      await _fetchNotifications();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
      }
    }
  }
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF3B2357),
              size: 22,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            splashRadius: 22,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
                // Filter out notifications that should not be shown
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
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
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

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: activeNotifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final notif = activeNotifications[index];

                    return Container(
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
                                    backgroundImage:
                                        (notif['userImg'] is String)
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
                              onTap: () {},
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
                                        ), // pastel green text
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        final connectionId =
                                            notif['connectionId'];
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
                                        ), // pastel red text
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        final connectionId =
                                            notif['connectionId'];
                                        final receiverUserId =
                                            notif['fromUserId'];
                                        if (connectionId != null &&
                                            receiverUserId != null) {
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
                    );
                  },
                );
              },
            ),
    );
  }
}
