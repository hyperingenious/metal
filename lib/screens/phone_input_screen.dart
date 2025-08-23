import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../appwrite/appwrite.dart';
import '../services/config_service.dart';
import 'otp_screen.dart';

// Import all ids from ConfigService
final appwriteEndpoint = ConfigService().get('APPWRITE_ENDPOINT');
final projectId = ConfigService().get('PROJECT_ID');
final databaseId = ConfigService().get('DATABASE_ID');
final storageBucketId = ConfigService().get('STORAGE_BUCKET_ID');
final biodataCollectionId = ConfigService().get('BIODATA_COLLECTIONID');
final blockedCollectionId = ConfigService().get('BLOCKED_COLLECTIONID');
final completionStatusCollectionId = ConfigService().get(
  'COMPLETION_STATUS_COLLECTIONID',
);
final connectionsCollectionId = ConfigService().get('CONNECTIONS_COLLECTIONID');
final hasShownCollectionId = ConfigService().get('HAS_SHOWN_COLLECTIONID');
final hobbiesCollectionId = ConfigService().get('HOBBIES_COLLECTIONID');
final imageCollectionId = ConfigService().get('IMAGE_COLLECTIONID');
final locationCollectionId = ConfigService().get('LOCATION_COLLECTIONID');
final messageInboxCollectionId = ConfigService().get(
  'MESSAGE_INBOX_COLLECTIONID',
);
final messagesCollectionId = ConfigService().get('MESSAGES_COLLECTIONID');
final notificationsCollectionId = ConfigService().get(
  'NOTIFICATIONS_COLLECTIONID',
);
final preferenceCollectionId = ConfigService().get('PREFERENCE_COLLECTIONID');
final reportsCollectionId = ConfigService().get('REPORTS_COLLECTIONID');
final usersCollectionId = ConfigService().get('USERS_COLLECTIONID');

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _logout();
  }

  Future<void> _logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
      if (mounted) {
        // Already on PhoneInputScreen, so no need to navigate.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Logout failed")));
      }
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = '+91${_phoneController.text.trim()}';
    setState(() => _isLoading = true);

    try {
      final token = await account.createPhoneToken(
        userId: ID.unique(),
        phone: phone,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: phone, userId: token.userId),
        ),
      );
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send OTP'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // The environment variable panel and tile widgets are removed from the UI
  // to avoid printing IDs in the UI.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.white, // Changed to white background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Modern phone icon with gradient background
                Container(
                  margin: const EdgeInsets.only(top: 32, bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.phone_iphone_rounded,
                    size: 48,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter your phone number",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "We'll send you a verification code",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                        Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                // Card-like phone input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixText: '+91 ',
                        prefixStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        labelText: 'Phone Number',
                        labelStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                        border: InputBorder.none,
                        hintText: '10-digit number',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                        counterText: '',
                      ),
                      maxLength: 10,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                        color: colorScheme.onSurface,
                      ),
                      validator: (v) => (v == null || v.length != 10)
                          ? 'Enter a valid 10-digit phone'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Animated modern button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    gradient: LinearGradient(
                      colors: _isLoading
                          ? [colorScheme.outline, colorScheme.outline]
                          : [colorScheme.primary, colorScheme.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: _isLoading ? null : _sendOtp,
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                  color: colorScheme.onPrimary,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                "Send OTP",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // The environment variables panel is removed from the UI.
                // Terms
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    "By continuing, you agree to our Terms & Privacy Policy.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
