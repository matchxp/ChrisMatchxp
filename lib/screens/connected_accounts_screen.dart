import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({Key? key}) : super(key: key);

  @override
  State<ConnectedAccountsScreen> createState() =>
      _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen> {
  static const _bg     = Color(0xFF0A0A0A);
  static const _card   = Color(0xFF1A1A1A);
  static const _purple = Color(0xFF6C3FE8);

  // Track connected state for each provider
  final Map<String, bool> _connected = {
    'google':    false,
    'apple':     false,
    'facebook':  false,
    'instagram': false,
    'spotify':   false,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnections();
  }

  Future<void> _checkConnections() async {
    // Check if the current user signed in via Google (Supabase identity)
    final identities =
        Supabase.instance.client.auth.currentUser?.identities ?? [];
    final providers =
        identities.map((i) => i.provider?.toLowerCase() ?? '').toSet();
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
      // Show disconnect confirm
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Disconnect ${_providerName(provider)}?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You can reconnect at any time.',
            style: const TextStyle(color: Colors.white54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disconnect',
                  style: TextStyle(color: Color(0xFFFF3B60))),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() => _connected[provider] = false);
      _snack('${_providerName(provider)} disconnected');
    } else {
      // Simulate OAuth connect
      _snack('Connecting to ${_providerName(provider)}…');
      await Future.delayed(const Duration(milliseconds: 900));
      setState(() => _connected[provider] = true);
      _snack('${_providerName(provider)} connected!', color: _purple);
    }
  }

  String _providerName(String key) {
    switch (key) {
      case 'google':    return 'Google';
      case 'apple':     return 'Apple';
      case 'facebook':  return 'Facebook';
      case 'instagram': return 'Instagram';
      case 'spotify':   return 'Spotify';
      default: return key;
    }
  }

  IconData _providerIcon(String key) {
    switch (key) {
      case 'google':    return Icons.g_mobiledata_rounded;
      case 'apple':     return Icons.apple;
      case 'facebook':  return Icons.facebook;
      case 'instagram': return Icons.camera_alt_outlined;
      case 'spotify':   return Icons.music_note_rounded;
      default: return Icons.link;
    }
  }

  Color _providerColor(String key) {
    switch (key) {
      case 'google':    return const Color(0xFFEA4335);
      case 'apple':     return Colors.white;
      case 'facebook':  return const Color(0xFF1877F2);
      case 'instagram': return const Color(0xFFE1306C);
      case 'spotify':   return const Color(0xFF1DB954);
      default: return _purple;
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? _card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: _purple),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _purple.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.link_rounded,
                              color: _purple, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Connect your social accounts to log in faster and share on your profile.',
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

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
          child: Text('Connected Accounts',
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

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(text,
        style: const TextStyle(
            color: _purple,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7)),
  );

  Widget _accountCard(String provider) {
    final isConnected = _connected[provider] ?? false;
    final color = _providerColor(provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? color.withOpacity(0.35) : Colors.white12,
          width: isConnected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_providerIcon(provider), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_providerName(provider),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  isConnected ? 'Connected' : 'Not connected',
                  style: TextStyle(
                      color: isConnected
                          ? color.withOpacity(0.8)
                          : Colors.white38,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggle(provider),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isConnected
                    ? const Color(0xFFFF3B60).withOpacity(0.1)
                    : _purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isConnected
                      ? const Color(0xFFFF3B60).withOpacity(0.4)
                      : _purple.withOpacity(0.4),
                ),
              ),
              child: Text(
                isConnected ? 'Disconnect' : 'Connect',
                style: TextStyle(
                    color: isConnected
                        ? const Color(0xFFFF3B60)
                        : _purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
