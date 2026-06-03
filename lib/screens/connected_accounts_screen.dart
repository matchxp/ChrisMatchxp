import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/matchxp_background.dart';

class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({Key? key}) : super(key: key);
  @override
  State<ConnectedAccountsScreen> createState() => _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen> {
  static const _bg      = Color(0xFF0C0B11);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  final Map<String, bool> _connected = {
    'google': false, 'apple': false, 'facebook': false,
    'instagram': false, 'spotify': false,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnections();
  }

  Future<void> _checkConnections() async {
    final identities = Supabase.instance.client.auth.currentUser?.identities ?? [];
    final providers = identities.map((i) => i.provider.toLowerCase()).toSet();
    setState(() {
      _connected['google']   = providers.contains('google');
      _connected['apple']    = providers.contains('apple');
      _connected['facebook'] = providers.contains('facebook');
      _isLoading = false;
    });
  }

  Future<void> _toggle(String provider) async {
    HapticFeedback.mediumImpact();
    final isConnected = _connected[provider] ?? false;
    if (isConnected) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1228),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Disconnect ${_name(provider)}?',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Text('You can reconnect at any time.',
              style: GoogleFonts.outfit(color: Colors.white54)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(context, true),
                child: Text('Disconnect',
                    style: GoogleFonts.outfit(color: const Color(0xFFFF3B60)))),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() => _connected[provider] = false);
      _snack('${_name(provider)} disconnected');
    } else {
      _snack('Connecting to ${_name(provider)}…');
      await Future.delayed(const Duration(milliseconds: 900));
      setState(() => _connected[provider] = true);
      _snack('${_name(provider)} connected!', color: _purple);
    }
  }

  String _name(String k) => const {
    'google': 'Google', 'apple': 'Apple', 'facebook': 'Facebook',
    'instagram': 'Instagram', 'spotify': 'Spotify',
  }[k] ?? k;

  IconData _icon(String k) => const {
    'google': Icons.g_mobiledata_rounded, 'apple': Icons.apple,
    'facebook': Icons.facebook, 'instagram': Icons.camera_alt_outlined,
    'spotify': Icons.music_note_rounded,
  }[k] ?? Icons.link;

  Color _color(String k) => {
    'google': const Color(0xFFEA4335), 'apple': Colors.white,
    'facebook': const Color(0xFF1877F2), 'instagram': const Color(0xFFE1306C),
    'spotify': const Color(0xFF1DB954),
  }[k] ?? _purple;

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: color ?? const Color(0xFF1A1228),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: _purple)))
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _purple.withOpacity(0.42)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.link_rounded, color: _purple, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Connect your social accounts to log in faster and share on your profile.',
                              style: GoogleFonts.outfit(
                                  color: Colors.white60, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      _sectionLabel('Social Login'),
                      const SizedBox(height: 10),
                      _accountCard('google'),
                      const SizedBox(height: 10),
                      _accountCard('apple'),
                      const SizedBox(height: 10),
                      _accountCard('facebook'),
                      const SizedBox(height: 24),

                      _sectionLabel('Profile Integrations'),
                      const SizedBox(height: 10),
                      _accountCard('instagram'),
                      const SizedBox(height: 10),
                      _accountCard('spotify'),
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
          child: Text('Connected Accounts', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));

  Widget _accountCard(String provider) {
    final isConnected = _connected[provider] ?? false;
    final color = _color(provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? color.withOpacity(0.5) : _purple.withOpacity(0.42),
          width: isConnected ? 1.5 : 1.0,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon(provider), color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_name(provider), style: GoogleFonts.outfit(color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(isConnected ? 'Connected' : 'Not connected',
              style: GoogleFonts.outfit(
                  color: isConnected ? color.withOpacity(0.8) : Colors.white38,
                  fontSize: 12)),
        ])),
        GestureDetector(
          onTap: () => _toggle(provider),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFFFF3B60).withOpacity(0.1)
                  : _purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isConnected
                    ? const Color(0xFFFF3B60).withOpacity(0.4)
                    : _purple.withOpacity(0.42),
              ),
            ),
            child: Text(isConnected ? 'Disconnect' : 'Connect',
                style: GoogleFonts.outfit(
                    color: isConnected ? const Color(0xFFFF3B60) : _purple,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
