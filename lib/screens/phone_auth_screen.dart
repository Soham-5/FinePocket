import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();

  String _phoneNumber = '';
  String _currentVerificationId = '';
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Phase 1: Send OTP
  // ──────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack('Please enter a phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _phoneNumber = phone;
    });

    // Client-side validation: strip to raw digits and check length
    final rawDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Remove leading country code 91 if present
    final digits = rawDigits.startsWith('91') && rawDigits.length > 10
        ? rawDigits.substring(rawDigits.length - 10)
        : rawDigits;

    if (digits.length != 10) {
      setState(() => _isLoading = false);
      _showSnack('Looks like you mistyped the number. Try rewriting it!');
      return;
    }

    // Always send with +91 prefix to Firebase
    final formattedPhone = '+91$digits';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution on Android
          await _auth.signInWithCredential(credential);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnack(e.message ?? 'Verification failed. Try again.');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
              _otpSent = true;
              _isLoading = false;
            });
            // Auto-focus the pin field
            Future.delayed(const Duration(milliseconds: 300), () {
              _pinFocus.requestFocus();
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _currentVerificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error: $e');
      }
    }
  }

  // ──────────────────────────────────────────────
  // Phase 2: Verify OTP
  // ──────────────────────────────────────────────
  Future<void> _verifyOtp(String smsCode) async {
    if (_currentVerificationId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _otpController.clear();
        _showSnack('Invalid code. Please try again.');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {
            if (_otpSent) {
              setState(() {
                _otpSent = false;
                _otpController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // ── Header ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _otpSent
                    ? Column(
                        key: const ValueKey('otp_header'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verify Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-digit code sent to $_phoneNumber',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        key: ValueKey('phone_header'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'We\'ll send a verification code to your number.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 48),

              // ── Phase 1: Phone Input ──
              if (!_otpSent) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: '+91 99999 99999',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.tealAccent),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.tealAccent.shade700.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Send Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],

              // ── Phase 2: OTP Input (Pinput) ──
              if (_otpSent) ...[
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _otpController,
                    focusNode: _pinFocus,
                    enabled: !_isLoading,
                    onCompleted: _verifyOtp,
                    defaultPinTheme: PinTheme(
                      width: 52,
                      height: 56,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.shade700),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 52,
                      height: 56,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent, width: 2),
                      ),
                    ),
                    submittedPinTheme: PinTheme(
                      width: 52,
                      height: 56,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.shade700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.tealAccent,
                    ),
                  ),
                if (!_isLoading)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _otpSent = false;
                          _otpController.clear();
                        });
                      },
                      child: Text(
                        'Wrong number? Go back',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
