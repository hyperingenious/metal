import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../appwrite/appwrite.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String userId;

  const OtpScreen({super.key, required this.phone, required this.userId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _canResend = false;
  int _secondsRemaining = 30;
  Timer? _timer;

  void _startTimer() {
    _canResend = false;
    _secondsRemaining = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a 6-digit OTP')));
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await account.createSession(userId: widget.userId, secret: code);

      Navigator.pushReplacementNamed(context, '/main');
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'OTP verification failed')),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    try {
      await account.createPhoneToken(
        userId: widget.userId,
        phone: widget.phone,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP resent')));
      _startTimer();
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to resend OTP')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Modern lock icon with gradient background
                Container(
                  margin: const EdgeInsets.only(top: 32, bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A85F1), Color(0xFF1FD1F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Verify your phone",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF222B45),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Code sent to",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.phone,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222B45),
                  ),
                ),
                const SizedBox(height: 32),
                // Card-like OTP input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222B45),
                    ),
                    decoration: InputDecoration(
                      counterText: "",
                      border: InputBorder.none,
                      hintText: "● ● ● ● ● ●",
                      hintStyle: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 28,
                        letterSpacing: 18,
                      ),
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
                      colors: _isVerifying
                          ? [Colors.grey, Colors.grey]
                          : [const Color(0xFF6A85F1), const Color(0xFF1FD1F9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A85F1).withOpacity(0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: _isVerifying ? null : _verifyOtp,
                      child: Center(
                        child: _isVerifying
                            ? const SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Verify",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Resend row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _canResend
                          ? "Didn't get the code?"
                          : "Resend in $_secondsRemaining s",
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _canResend ? _resendOtp : null,
                      style: TextButton.styleFrom(
                        foregroundColor: _canResend
                            ? const Color(0xFF6A85F1)
                            : Colors.grey[400],
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Resend'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Terms
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    "By verifying, you agree to our Terms & Privacy Policy.",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
