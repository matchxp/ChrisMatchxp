import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({Key? key}) : super(key: key);

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  static const _bg     = Color(0xFF0A0A0A);
  static const _card   = Color(0xFF1A1A1A);
  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  bool _twoFAEnabled = false;
  String _method = 'sms'; // 'sms' or 'app'
  final _phoneController = TextEditingController();
  bool _isSaving = false;
  bool _codeSent = false;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? _card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.trim().isEmpty) {
      _snack('Please enter your phone number');
      return;
    }
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isSaving = false; _codeSent = true; });
    _snack('Verification code sent!', color: _purple);
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length < 6) {
      _snack('Enter the 6-digit code');
      return;
    }
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isSaving = false; _twoFAEnabled = true; _codeSent = false; });
    _snack('Two-factor authentication enabled!', color: _purple);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Status card
                  _statusCard(),
                  const SizedBox(height: 24),

                  if (!_twoFAEnabled) ...[
                    // Method selector
                    _sectionLabel('Choose a method'),
                    const SizedBox(height: 10),
                    _methodCard(
                      icon: Icons.sms_outlined,
                      title: 'SMS Text Message',
                      subtitle: 'Receive a code via text',
                      value: 'sms',
                    ),
                    const SizedBox(height: 10),
                    _methodCard(
                      icon: Icons.qr_code_2_rounded,
                      title: 'Authenticator App',
                      subtitle: 'Use Google Authenticator or similar',
                      value: 'app',
                    ),
                    const SizedBox(height: 24),

                    if (_method == 'sms') ...[
                      _sectionLabel('Phone number'),
                      const SizedBox(height: 10),
                      _inputField(
                        controller: _phoneController,
                        hint: '+1 (555) 000-0000',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      if (!_codeSent)
                        _actionButton('Send Code', _isSaving ? null : _sendCode)
                      else ...[
                        _sectionLabel('Enter the 6-digit code'),
                        const SizedBox(height: 10),
                        _inputField(
                          controller: _codeController,
                          hint: '000000',
                          icon: Icons.lock_outline_rounded,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        const SizedBox(height: 16),
                        _actionButton('Verify Code', _isSaving ? null : _verifyCode),
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() => _codeSent = false),
                            child: const Text('Resend code',
                                style: TextStyle(
                                    color: _purple,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ],

                    if (_method == 'app') ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _purple.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.qr_code_2_rounded,
                                    size: 100, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Scan this QR code with your\nauthenticator app',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                            const SizedBox(height: 16),
                            _sectionLabel('Enter the 6-digit code'),
                            const SizedBox(height: 10),
                            _inputField(
                              controller: _codeController,
                              hint: '000000',
                              icon: Icons.lock_outline_rounded,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _actionButton('Verify & Enable', _isSaving ? null : _verifyCode),
                    ],
                  ] else ...[
                    // Already enabled — show disable option
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF00C853).withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              color: Color(0xFF00C853), size: 48),
                          const SizedBox(height: 12),
                          const Text('Your account is protected',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text('Two-factor authentication is active',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _twoFAEnabled = false);
                              _snack('Two-factor authentication disabled');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B60).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: const Color(0xFFFF3B60).withValues(alpha: 0.4)),
                              ),
                              child: const Text('Disable 2FA',
                                  style: TextStyle(
                                      color: Color(0xFFFF3B60),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text('Two-Factor Verification',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _statusCard() {
    final accentColor = _twoFAEnabled ? const Color(0xFF00C853) : _purple;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _twoFAEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _twoFAEnabled ? '2FA is On' : '2FA is Off',
                  style: TextStyle(
                      color: _twoFAEnabled ? const Color(0xFF00C853) : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _twoFAEnabled
                      ? 'Your account has extra protection'
                      : 'Add an extra layer of security',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _twoFAEnabled ? 'Active' : 'Inactive',
              style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _method = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _purple.withValues(alpha: 0.12) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _purple : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? _purple.withValues(alpha: 0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: selected ? _purple : Colors.white54, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: _purple, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(text,
        style: const TextStyle(
            color: _purple,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6)),
  );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          filled: true,
          fillColor: _card,
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _purple, width: 1.5),
          ),
        ),
      );

  Widget _actionButton(String label, VoidCallback? onTap) => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      onTap?.call();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onTap == null
              ? [_purple.withValues(alpha: 0.4), _purple2.withValues(alpha: 0.4)]
              : [_purple, _purple2],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: onTap != null
            ? [BoxShadow(
                color: _purple.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5))]
            : [],
      ),
      child: _isSaving
          ? const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          : Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
    ),
  );
}
