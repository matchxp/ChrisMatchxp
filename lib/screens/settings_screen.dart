import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/matchxp_background.dart';
import 'preferences_screen.dart';
import 'two_factor_screen.dart';
import 'biometrics_screen.dart';
import 'connected_accounts_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'help_centre_screen.dart';
import 'login_screen.dart' hide MatchXPBackground;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  // ── Colour tokens — match onboarding / preferences ────────────────────────
  static const _bg      = Color(0xFF0C0B11);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  // ── Notification state ────────────────────────────────────────────────────
  bool _notifyPush     = true;
  bool _notifyMatches  = true;
  bool _notifyMessages = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final p = await _supabase
          .from('profiles')
          .select('notif_push, notif_matches, notif_messages')
          .eq('id', uid)
          .maybeSingle();
      if (p == null || !mounted) return;
      setState(() {
        _notifyPush     = (p['notif_push']    as bool?) ?? true;
        _notifyMatches  = (p['notif_matches'] as bool?) ?? true;
        _notifyMessages = (p['notif_messages'] as bool?) ?? true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load settings: $e', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFFF3B60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _saveSettings() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.from('profiles').update({
        'notif_push':     _notifyPush,
        'notif_matches':  _notifyMatches,
        'notif_messages': _notifyMessages,
        'updated_at':     DateTime.now().toIso8601String(),
      }).eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_purple, _purple2],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: _purple.withOpacity(0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Changes saved!',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    )),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          width: 220,
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
          dismissDirection: DismissDirection.horizontal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFFF3B60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),

                    _section('NOTIFICATIONS', [
                      _toggleRow(
                        icon: Icons.notifications_outlined,
                        label: 'Push Notifications',
                        value: _notifyPush,
                        onChanged: (v) => setState(() => _notifyPush = v),
                      ),
                      _toggleRow(
                        icon: Icons.favorite_outline,
                        label: 'New Matches',
                        value: _notifyMatches,
                        onChanged: (v) => setState(() => _notifyMatches = v),
                      ),
                      _toggleRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'New Messages',
                        value: _notifyMessages,
                        onChanged: (v) => setState(() => _notifyMessages = v),
                      ),
                    ]),
                    _gap(),

                    _section('ACCOUNT', [
                      _navRow(Icons.security_outlined,
                          'Two Factor Verification', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const TwoFactorScreen()));
                      }),
                      _navRow(Icons.fingerprint, 'Add Biometrics', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const BiometricsScreen()));
                      }),
                      _navRow(Icons.link_rounded, 'Connected Accounts', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const ConnectedAccountsScreen()));
                      }),
                    ]),
                    _gap(),

                    _section('DISCOVERY', [
                      _navRow(Icons.tune_rounded, 'Preferences', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const PreferencesScreen()));
                      }),
                    ]),
                    _gap(),

                    _section('LEGAL', [
                      _navRow(Icons.shield_outlined, 'Privacy Policy', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen()));
                      }),
                      _navRow(Icons.description_outlined, 'Terms of Service', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen()));
                      }),
                    ]),
                    _gap(),

                    _section('SUPPORT', [
                      _navRow(Icons.help_outline_rounded, 'Help Centre', () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const HelpCentreScreen()));
                      }),
                    ]),
                    const SizedBox(height: 32),

                    // Sign Out
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _signOut();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B60).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: const Color(0xFFFF3B60).withOpacity(0.45)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                color: Color(0xFFFF3B60), size: 18),
                            const SizedBox(width: 10),
                            Text('Sign Out',
                                style: GoogleFonts.outfit(
                                    color: const Color(0xFFFF3B60),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Delete Account
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _deleteAccount();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                color: Colors.white.withOpacity(0.4), size: 18),
                            const SizedBox(width: 10),
                            Text('Delete Account',
                                style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Save Changes
                    _saveButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar — matches preferences/onboarding style ────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: _purple, strokeWidth: 2.5),
            ),
          )
        else
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _saveSettings();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purple2]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ── Page header — matches onboarding/preferences header ───────────────────
  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        'Settings',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Manage your account and preferences',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: Colors.white.withOpacity(0.50),
        ),
      ),
    ],
  );

  // ── Section — label + individual pill cards per row ──────────────────────
  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Text(title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
        ),
        ...rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: row,
        )),
      ],
    );
  }

  // ── Toggle row — individual pill card ─────────────────────────────────────
  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 19),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeThumbColor: Colors.white,
            activeTrackColor: _purple,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  // ── Nav row — individual pill card ────────────────────────────────────────
  Widget _navRow(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 19),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 20);

  // ── Save button — matches preferences apply button ────────────────────────
  Widget _saveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : () {
        HapticFeedback.mediumImpact();
        _saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: _isSaving
              ? LinearGradient(colors: [
                  _purple.withOpacity(0.5),
                  _purple2.withOpacity(0.5),
                ])
              : const LinearGradient(colors: [_purple, _purple2]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: _isSaving
              ? []
              : [
                  BoxShadow(
                      color: _purple.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
        ),
        child: _isSaving
            ? const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              )
            : Text('Save Changes',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
      ),
    );
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1228),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF3B60),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1228),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
            'This will permanently delete your account and all your data. This cannot be undone.',
            style: GoogleFonts.outfit(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF3B60),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.rpc('delete_user_account');
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete account: $e',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: const Color(0xFFFF3B60),
        ));
      }
    }
  }
}
