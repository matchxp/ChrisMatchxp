import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/matchxp_background.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({Key? key}) : super(key: key);
  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  static const _bg      = Color(0xFF0C0B11);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  bool _twoFAEnabled = false;
  String _method = 'sms';
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
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: color ?? const Color(0xFF1A1228),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.trim().isEmpty) { _snack('Please enter your phone number'); return; }
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isSaving = false; _codeSent = true; });
    _snack('Verification code sent!', color: _purple);
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length < 6) { _snack('Enter the 6-digit code'); return; }
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isSaving = false; _twoFAEnabled = true; _codeSent = false; });
    _snack('Two-factor authentication enabled!', color: _purple);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: MatchXPBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _statusCard(),
                    const SizedBox(height: 24),
                    if (!_twoFAEnabled) ...[
                      _sectionLabel('Choose a method'),
                      const SizedBox(height: 10),
                      _methodCard(icon: Icons.sms_outlined, title: 'SMS Text Message',
                          subtitle: 'Receive a code via text', value: 'sms'),
                      const SizedBox(height: 10),
                      _methodCard(icon: Icons.qr_code_2_rounded, title: 'Authenticator App',
                          subtitle: 'Use Google Authenticator or similar', value: 'app'),
                      const SizedBox(height: 24),
                      if (_method == 'sms') ...[
                        _sectionLabel('Phone number'),
                        const SizedBox(height: 10),
                        _inputPill(controller: _phoneController, hint: '+1 (555) 000-0000',
                            icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        if (!_codeSent)
                          _actionButton('Send Code', _isSaving ? null : _sendCode)
                        else ...[
                          _sectionLabel('Enter the 6-digit code'),
                          const SizedBox(height: 10),
                          _inputPill(controller: _codeController, hint: '000000',
                              icon: Icons.lock_outline_rounded,
                              keyboardType: TextInputType.number, maxLength: 6),
                          const SizedBox(height: 16),
                          _actionButton('Verify Code', _isSaving ? null : _verifyCode),
                          const SizedBox(height: 12),
                          Center(
                            child: GestureDetector(
                              onTap: () => setState(() => _codeSent = false),
                              child: Text('Resend code',
                                  style: GoogleFonts.outfit(color: _purple,
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ],
                      if (_method == 'app') ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _purple.withOpacity(0.42)),
                          ),
                          child: Column(children: [
                            Container(
                              width: 140, height: 140,
                              decoration: BoxDecoration(color: Colors.white,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Center(child: Icon(Icons.qr_code_2_rounded,
                                  size: 100, color: Colors.black87)),
                            ),
                            const SizedBox(height: 16),
                            Text('Scan this QR code with your\nauthenticator app',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    color: Colors.white70, fontSize: 14, height: 1.5)),
                            const SizedBox(height: 16),
                            _sectionLabel('Enter the 6-digit code'),
                            const SizedBox(height: 10),
                            _inputPill(controller: _codeController, hint: '000000',
                                icon: Icons.lock_outline_rounded,
                                keyboardType: TextInputType.number, maxLength: 6),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        _actionButton('Verify & Enable', _isSaving ? null : _verifyCode),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF00C853).withOpacity(0.4), width: 1.5),
                        ),
                        child: Column(children: [
                          const Icon(Icons.verified_user_rounded,
                              color: Color(0xFF00C853), size: 48),
                          const SizedBox(height: 12),
                          Text('Your account is protected',
                              style: GoogleFonts.outfit(color: Colors.white,
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Two-factor authentication is active',
                              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _twoFAEnabled = false);
                              _snack('Two-factor authentication disabled');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B60).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                    color: const Color(0xFFFF3B60).withOpacity(0.4)),
                              ),
                              child: Text('Disable 2FA',
                                  style: GoogleFonts.outfit(color: const Color(0xFFFF3B60),
                                      fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text('Two-Factor Verification', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _statusCard() {
    final accent = _twoFAEnabled ? const Color(0xFF00C853) : _purple;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.42), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_twoFAEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_twoFAEnabled ? '2FA is On' : '2FA is Off',
              style: GoogleFonts.outfit(
                  color: _twoFAEnabled ? const Color(0xFF00C853) : Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(_twoFAEnabled ? 'Your account has extra protection' : 'Add an extra layer of security',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          child: Text(_twoFAEnabled ? 'Active' : 'Inactive',
              style: GoogleFonts.outfit(color: accent, fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _methodCard({required IconData icon, required String title,
      required String subtitle, required String value}) {
    final sel = _method == value;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _method = value); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: sel ? _purple.withOpacity(0.12) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? _purple : _purple.withOpacity(0.42),
              width: sel ? 2.0 : 1.0),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: sel ? _purple.withOpacity(0.2) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: sel ? _purple : Colors.white54, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(color: Colors.white,
                fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
          ])),
          if (sel)
            Container(width: 18, height: 18,
              decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 11)),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));

  Widget _inputPill({required TextEditingController controller, required String hint,
      required IconData icon, TextInputType? keyboardType, int? maxLength}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _purple.withOpacity(0.42)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: controller, keyboardType: keyboardType, maxLength: maxLength,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            cursorColor: _purple,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
              border: InputBorder.none, counterText: '', isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )),
        ]),
      );

  Widget _actionButton(String label, VoidCallback? onTap) => GestureDetector(
    onTap: () { HapticFeedback.mediumImpact(); onTap?.call(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: onTap == null
            ? [_purple.withOpacity(0.4), _purple2.withOpacity(0.4)]
            : [_purple, _purple2]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: onTap != null
            ? [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))]
            : [],
      ),
      child: _isSaving
          ? const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          : Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ),
  );
}
