import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show appThemeMode;
import 'preferences_screen.dart';
import 'two_factor_screen.dart';
import 'biometrics_screen.dart';
import 'connected_accounts_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'help_centre_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  // ── App colour tokens ─────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0A0A0A);
  static const _card   = Color(0xFF1A1A1A);
  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  // ── State ─────────────────────────────────────────────────────────────────
  bool get _darkMode => appThemeMode.value == ThemeMode.dark;
  bool _notifyPush       = true;
  bool _notifyMatches    = true;
  bool _notifyMessages   = true;
  bool _notifyPromotions = true;

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
          .select('notif_push, notif_matches, notif_messages, notif_promotions')
          .eq('id', uid)
          .maybeSingle();
      if (p == null || !mounted) return;
      setState(() {
        _notifyPush       = (p['notif_push']        as bool?) ?? true;
        _notifyMatches    = (p['notif_matches']      as bool?) ?? true;
        _notifyMessages   = (p['notif_messages']     as bool?) ?? true;
        _notifyPromotions = (p['notif_promotions']   as bool?) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.from('profiles').update({
        'notif_push':       _notifyPush,
        'notif_matches':    _notifyMatches,
        'notif_messages':   _notifyMessages,
        'notif_promotions': _notifyPromotions,
        'updated_at':       DateTime.now().toIso8601String(),
      }).eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Changes saved!'),
          backgroundColor: _purple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: const Color(0xFFFF3B60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  _section('Appearance', [
                    _toggleRow(
                      icon: _darkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      label: _darkMode ? 'Dark Mode' : 'Light Mode',
                      value: _darkMode,
                      onChanged: (v) async {
                        appThemeMode.value =
                            v ? ThemeMode.dark : ThemeMode.light;
                        setState(() {}); // refresh icon/label
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('dark_mode', v);
                      },
                    ),
                  ]),
                  _gap(),

                  _section('Notifications', [
                    _toggleRow(
                      icon: Icons.notifications_outlined,
                      label: 'Push Notifications',
                      value: _notifyPush,
                      onChanged: (v) => setState(() => _notifyPush = v),
                    ),
                    _divider(),
                    _toggleRow(
                      icon: Icons.favorite_outline,
                      label: 'New Matches',
                      value: _notifyMatches,
                      onChanged: (v) => setState(() => _notifyMatches = v),
                    ),
                    _divider(),
                    _toggleRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'New Messages',
                      value: _notifyMessages,
                      onChanged: (v) => setState(() => _notifyMessages = v),
                    ),
                    _divider(),
                    _toggleRow(
                      icon: Icons.local_offer_outlined,
                      label: 'Promotions',
                      value: _notifyPromotions,
                      onChanged: (v) =>
                          setState(() => _notifyPromotions = v),
                    ),
                  ]),
                  _gap(),

                  _section('Account Settings', [
                    _navRow(Icons.security_outlined,
                        'Two Factor Verification', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TwoFactorScreen()));
                    }),
                    _divider(),
                    _navRow(Icons.fingerprint, 'Add Biometrics', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BiometricsScreen()));
                    }),
                    _divider(),
                    _navRow(Icons.link_rounded, 'Connected Accounts', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ConnectedAccountsScreen()));
                    }),
                  ]),
                  _gap(),

                  _section('Discovery', [
                    _navRow(Icons.tune_rounded, 'Preferences', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PreferencesScreen()));
                    }),
                  ]),
                  _gap(),

                  _section('Legal', [
                    _navRow(Icons.shield_outlined, 'Privacy Policy', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()));
                    }),
                    _divider(),
                    _navRow(Icons.description_outlined, 'Terms of Service', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TermsOfServiceScreen()));
                    }),
                  ]),
                  _gap(),

                  _section('Contact and Support', [
                    _navRow(Icons.help_outline_rounded, 'Help Centre', () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const HelpCentreScreen()));
                    }),
                  ]),
                  const SizedBox(height: 28),

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
                        color: const Color(0xFFFF3B60).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: const Color(0xFFFF3B60).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Color(0xFFFF3B60), size: 20),
                          SizedBox(width: 10),
                          Text('Sign Out',
                              style: TextStyle(
                                  color: Color(0xFFFF3B60),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save Changes
                  _saveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 48), // balance back button
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  color: _purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _purple.withOpacity(0.12)),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500))),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: Colors.white,
            activeTrackColor: _purple,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _navRow(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white60, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right,
                color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.06));

  Widget _gap() => const SizedBox(height: 20);

  Widget _saveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : () {
        HapticFeedback.mediumImpact();
        _saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _isSaving
              ? LinearGradient(colors: [
                  _purple.withOpacity(0.5),
                  _purple2.withOpacity(0.5)
                ])
              : const LinearGradient(colors: [_purple, _purple2]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: _purple.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: _isSaving
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              )
            : const Text('Save Changes',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Color(0xFFFF3B60), fontWeight: FontWeight.w700)),
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

  void _soon(String f) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$f coming soon!'),
      backgroundColor: _card,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
