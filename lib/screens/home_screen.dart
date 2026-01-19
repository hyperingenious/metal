import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../appwrite/appwrite.dart';
import '../services/config_service.dart';
import '../providers/scroll_visibility_provider.dart';
import 'main_tabs/profile_screen.dart';
import 'main_tabs/explore_screen.dart';
import 'main_tabs/notifications_screen.dart';
import 'main_tabs/chats_screen.dart';
import 'package:appwrite/appwrite.dart';

// Use ConfigService to get configuration values
final configService = ConfigService();
final String kDatabaseId = configService.get('DATABASE_ID') ?? '';
final String kNotificationsCollectionId =
    configService.get('NOTIFICATIONS_COLLECTIONID') ?? '';
final String kConnectionsCollectionId =
    configService.get('CONNECTIONS_COLLECTIONID') ?? '';
final String kMessagesCollectionId =
    configService.get('MESSAGES_COLLECTIONID') ?? '';

/// InheritedWidget to provide scroll visibility state to child screens
class ScrollVisibilityScope extends InheritedNotifier<ScrollVisibilityProvider> {
  const ScrollVisibilityScope({
    super.key,
    required ScrollVisibilityProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static ScrollVisibilityProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScrollVisibilityScope>();
    return scope!.notifier!;
  }

  static ScrollVisibilityProvider? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScrollVisibilityScope>();
    return scope?.notifier;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  int _unreadChats = 0;
  bool _loadingNotifications = false;
  bool _loadingChats = false;
  late final PageController _pageController;
  
  // Scroll visibility provider
  final ScrollVisibilityProvider _scrollVisibilityProvider = ScrollVisibilityProvider();

  final List<Widget> _pages = const [
    ProfileScreen(),
    ExploreScreen(),
    NotificationsScreen(),
    ChatsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _fetchUnreadNotifications();
    _fetchUnreadChats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollVisibilityProvider.dispose();
    super.dispose();
  }

  Future<void> _fetchUnreadNotifications() async {
    setState(() {
      _loadingNotifications = true;
    });
    try {
      // Get current user
      final user = await account.get();
      final String userId = user.$id;

      // Query notifications where userId matches and is_read == false
      final result = await databases.listDocuments(
        databaseId: kDatabaseId,
        collectionId: kNotificationsCollectionId,
        queries: [Query.equal('to', userId), Query.equal('is_read', false)],
      );

      setState(() {
        _unreadNotifications = result.documents.length;
        _loadingNotifications = false;
      });
    } catch (e) {
      setState(() {
        _unreadNotifications = 0;
        _loadingNotifications = false;
      });
    }
  }

  Future<void> _fetchUnreadChats() async {
    setState(() {
      _loadingChats = true;
    });
    try {
      // Get current user
      final user = await account.get();
      final String userId = user.$id;

      // 1. Get all connectionIds where senderId or receiverId == userId
      final connectionsResult = await databases.listDocuments(
        databaseId: kDatabaseId,
        collectionId: kConnectionsCollectionId, // from .env
        queries: [
          Query.or([
            Query.equal('senderId', userId),
            Query.equal('receiverId', userId),
          ]),
        ],
      );

      final List<String> connectionIds = connectionsResult.documents
          .map((doc) => doc.data['\$id'] ?? doc.data['id'] ?? doc.$id)
          .whereType<String>()
          .toList();

      int unreadCount = 0;

      // 2. For each connectionId, count unread messages (is_read == false)
      if (connectionIds.isNotEmpty) {
        // Appwrite does not support Query._in, so we need to fetch for each connectionId
        int totalUnread = 0;
        for (final connId in connectionIds) {
          final messagesResult = await databases.listDocuments(
            databaseId: kDatabaseId,
            collectionId: kMessagesCollectionId, // from .env
            queries: [
              Query.equal('connectionId', connId),
              Query.equal('is_read', false),
              Query.notEqual('senderId', user.$id),
            ],
          );
          totalUnread += messagesResult.documents.length;
        }
        unreadCount = totalUnread;
      }
      setState(() {
        _unreadChats = unreadCount;
        _loadingChats = false;
      });
    } catch (e) {
      setState(() {
        _unreadChats = 0;
        _loadingChats = false;
      });
    }
  }

  void _onTabTapped(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
    // Show bars when changing tabs
    _scrollVisibilityProvider.show();
    // Optionally refresh notifications/chats
    if (idx == 2) _fetchUnreadNotifications();
    if (idx == 3) _fetchUnreadChats();
  }

  void _onPageChanged(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    // Show bars when changing pages
    _scrollVisibilityProvider.show();
    // Optionally refresh notifications/chats
    if (idx == 2) _fetchUnreadNotifications();
    if (idx == 3) _fetchUnreadChats();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return ScrollVisibilityScope(
      provider: _scrollVisibilityProvider,
      child: ListenableBuilder(
        listenable: _scrollVisibilityProvider,
        builder: (context, child) {
          return Scaffold(
            body: Stack(
              children: [
                // Main content
                Positioned.fill(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: _pages,
                    physics: const BouncingScrollPhysics(),
                  ),
                ),
                // Floating bottom navigation bar
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  bottom: _scrollVisibilityProvider.isVisible ? 0 : -(80 + bottomPadding),
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _scrollVisibilityProvider.isVisible ? 1.0 : 0.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: BottomNavigationBar(
                          currentIndex: _currentIndex,
                          onTap: _onTabTapped,
                          selectedItemColor: const Color(0xFF412758),
                          unselectedItemColor: const Color(0xFF412758),
                          type: BottomNavigationBarType.fixed,
                          backgroundColor: Colors.white,
                          elevation: 0,
                          items: [
                            BottomNavigationBarItem(
                              icon: _currentIndex == 0
                                  ? const PhosphorIcon(
                                      PhosphorIconsFill.user,
                                      color: Color(0xFF412758),
                                      size: 30.0,
                                    )
                                  : const PhosphorIcon(
                                      PhosphorIconsRegular.user,
                                      color: Color(0xFF412758),
                                      size: 30.0,
                                    ),
                              label: "Profile",
                            ),
                            BottomNavigationBarItem(
                              icon: _currentIndex == 1
                                  ? const PhosphorIcon(
                                      PhosphorIconsFill.magnifyingGlass,
                                      color: Color(0xFF412758),
                                      size: 30.0,
                                    )
                                  : const PhosphorIcon(
                                      PhosphorIconsRegular.magnifyingGlass,
                                      color: Color(0xFF412758),
                                      size: 30.0,
                                    ),
                              label: "Explore",
                            ),
                            BottomNavigationBarItem(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _currentIndex == 2
                                      ? const PhosphorIcon(
                                          PhosphorIconsFill.bell,
                                          color: Color(0xFF412758),
                                          size: 30.0,
                                        )
                                      : const PhosphorIcon(
                                          PhosphorIconsRegular.bell,
                                          color: Color(0xFF412758),
                                          size: 30.0,
                                        ),
                                  if (_unreadNotifications > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _unreadNotifications > 99
                                                ? '99+'
                                                : '$_unreadNotifications',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: "Notifications",
                            ),
                            BottomNavigationBarItem(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _currentIndex == 3
                                      ? const PhosphorIcon(
                                          PhosphorIconsFill.chatsCircle,
                                          color: Color(0xFF412758),
                                          size: 30.0,
                                        )
                                      : const PhosphorIcon(
                                          PhosphorIconsRegular.chatsCircle,
                                          color: Color(0xFF412758),
                                          size: 30.0,
                                        ),
                                  if (_unreadChats > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _unreadChats > 99 ? '99+' : '$_unreadChats',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: "Chats",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
