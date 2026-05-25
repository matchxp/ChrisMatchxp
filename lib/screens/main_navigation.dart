import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/matching_service.dart';
import 'home_screen.dart';
import 'matches_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'chat_conversation_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final MatchingService _matchingService = MatchingService();

  // One broadcast channel per match, for notification listening
  final List<RealtimeChannel> _notifChannels = [];
  final Set<String> _subscribedMatchIds = {};

  // Cached matches so we can look up sender name/photo for notifications
  List<Map<String, dynamic>> _matchesCache = [];

  // Poll for new matches (catches the case where User A liked first and
  // never got the "It's a Match!" popup because the broadcast was missed)
  Timer? _matchPollTimer;
  final Set<String> _knownMatchIds = {};
  bool _initialMatchLoadDone =
      false; // set to true after first load; poll only fires popups after this

  // Notification banner state
  OverlayEntry? _notifOverlay;
  // Each banner controls its own animation; we use a notifier to signal dismiss
  ValueNotifier<bool>? _dismissRequested;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MatchesScreenPremium(),
    const ChatsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadMatchesAndSubscribe();
    _matchPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollForNewMatches();
    });
  }

  @override
  void dispose() {
    _matchPollTimer?.cancel();
    for (final ch in _notifChannels) {
      ch.unsubscribe();
    }
    _notifChannels.clear();
    _notifOverlay?.remove();
    super.dispose();
  }

  // ── Poll for new matches (so User A gets the popup too) ──────────────────

  Future<void> _pollForNewMatches() async {
    final matches = await _matchingService.getMatchesWithProfiles();
    if (!mounted) return;

    for (final match in matches) {
      final matchId = match['match_id'] as String;
      if (_initialMatchLoadDone && !_knownMatchIds.contains(matchId)) {
        // New match detected — show the "It's a Match!" banner
        final profile = match['profile'] as Map<String, dynamic>?;
        if (profile != null) {
          final name = profile['first_name'] as String? ?? 'Someone';
          _showNotificationBanner(
            matchId: matchId,
            senderName: "It's a Match! 🎉",
            senderPhoto: _firstPhoto(profile),
            message: 'You and $name liked each other! Tap to play.',
            matchEntry: match,
          );
        }
      }
      _knownMatchIds.add(matchId);
    }
  }

  // ── Load matches + subscribe to each for notifications ────────────────────

  Future<void> _loadMatchesAndSubscribe() async {
    final matches = await _matchingService.getMatchesWithProfiles();
    if (!mounted) return;

    setState(() => _matchesCache = matches);

    for (final match in matches) {
      final matchId = match['match_id'] as String;
      if (!_initialMatchLoadDone) _knownMatchIds.add(matchId);
      if (_subscribedMatchIds.contains(matchId)) continue;
      _subscribedMatchIds.add(matchId);

      final channel = _matchingService.subscribeToMatchBroadcast(
        matchId,
        (msg) => _onBroadcastMessage(msg, matchId, match),
      );
      _notifChannels.add(channel);
    }

    _initialMatchLoadDone = true;
  }

  void _onBroadcastMessage(
    Map<String, dynamic> msg,
    String matchId,
    Map<String, dynamic> matchEntry,
  ) {
    if (!mounted) return;

    final senderId = msg['sender_id'] as String?;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Ignore own messages
    if (senderId == null || senderId == currentUserId) return;

    // Suppress only if the user is currently viewing THIS exact chat
    if (matchId == ChatConversationScreen.activeChatMatchId) return;

    final profile = matchEntry['profile'] as Map<String, dynamic>?;
    if (profile == null) return;

    // Notify ChatsScreen to refresh its list in real-time
    ChatsScreen.refreshNotifier.value++;

    // Clean up system-tag messages before showing in the banner
    String displayMessage = msg['content'] as String? ?? '';
    if (displayMessage.startsWith('[GAME_REQUEST]')) {
      displayMessage = '🎮 Sent a Word Search challenge!';
    }

    _showNotificationBanner(
      matchId: matchId,
      senderName: profile['first_name'] as String? ?? 'Match',
      senderPhoto: _firstPhoto(profile),
      message: displayMessage,
      matchEntry: matchEntry,
    );
  }

  String _firstPhoto(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) return photos[0] as String;
    return '';
  }

  // ── Notification overlay banner ────────────────────────────────────────────

  void _showNotificationBanner({
    required String matchId,
    required String senderName,
    required String senderPhoto,
    required String message,
    Map<String, dynamic>? matchEntry,
  }) {
    // Signal any existing banner to dismiss itself first
    _dismissNotification();

    // Use ROOT navigator overlay — this sits above ALL routes including
    // ChatConversationScreen, so the banner is always visible everywhere.
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;

    // Fresh dismiss notifier for this banner instance
    final dismissNotifier = ValueNotifier<bool>(false);
    _dismissRequested = dismissNotifier;

    _notifOverlay = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        senderName: senderName,
        senderPhoto: senderPhoto,
        message: message,
        dismissNotifier: dismissNotifier,
        onRemove: () {
          _notifOverlay?.remove();
          _notifOverlay = null;
        },
        onTap: () => _handleNotificationTap(matchId, matchEntry),
        onDismiss: _dismissNotification,
      ),
    );

    overlay.insert(_notifOverlay!);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), _dismissNotification);
  }

  Future<void> _handleNotificationTap(
      String matchId, Map<String, dynamic>? matchEntry) async {
    _dismissNotification();
    if (matchEntry == null) {
      if (mounted) setState(() => _currentIndex = 2);
      return;
    }
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);

    // Check if chat is unlocked before deciding where to navigate
    bool chatUnlocked = false;
    try {
      final row = await Supabase.instance.client
          .from('matches')
          .select('chat_unlocked')
          .eq('id', matchId)
          .maybeSingle();
      chatUnlocked = row?['chat_unlocked'] as bool? ?? false;
    } catch (_) {}

    if (!mounted) return;
    if (chatUnlocked) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            matchId: matchId,
            otherProfile: matchEntry['profile'] as Map<String, dynamic>,
          ),
        ),
      ).then((_) {
        _loadMatchesAndSubscribe();
        setState(() => _currentIndex = 2);
      });
    } else {
      // Chat still locked — go to Chats tab so user sees the pending game circle
      setState(() => _currentIndex = 2);
    }
  }

  void _dismissNotification() {
    // Signal the banner to play its reverse animation and remove itself
    _dismissRequested?.value = true;
    _dismissRequested = null;
    // _notifOverlay is cleared by the banner's onRemove callback
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A2E),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF6C3FE8).withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    index: 0),
                _buildNavItem(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    index: 1),
                _buildNavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    index: 2),
                _buildNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    index: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C3FE8).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF888888),
          size: 24,
        ),
      ),
    );
  }
}

// ── Notification Banner Widget ─────────────────────────────────────────────
// Stateful so it owns its AnimationController.  The banner is rendered inside
// the root Navigator's Overlay which is always active — its ticker is never
// paused by a pushed route, so the slide-in animation always plays correctly
// even when the user is deep inside ChatConversationScreen.

class _NotificationBanner extends StatefulWidget {
  final String senderName;
  final String senderPhoto;
  final String message;
  final ValueNotifier<bool> dismissNotifier;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.senderName,
    required this.senderPhoto,
    required this.message,
    required this.dismissNotifier,
    required this.onRemove,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim.forward();
    widget.dismissNotifier.addListener(_onDismissRequested);
  }

  void _onDismissRequested() {
    if (widget.dismissNotifier.value && mounted) {
      _anim.reverse().then((_) {
        if (mounted) widget.onRemove();
      }).catchError((_) {
        if (mounted) widget.onRemove();
      });
    }
  }

  @override
  void dispose() {
    widget.dismissNotifier.removeListener(_onDismissRequested);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, -1.2),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _anim,
              curve: Curves.easeOutCubic,
            ));
            final fade = CurvedAnimation(
              parent: _anim,
              curve: Curves.easeIn,
            );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6C3FE8).withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar with purple ring + dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipOval(
                            child: widget.senderPhoto.isNotEmpty
                                ? Image.network(
                                    widget.senderPhoto,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _initials(widget.senderName),
                                  )
                                : _initials(widget.senderName),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C3FE8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF1E1E1E), width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Name + message
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(bottom: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C3FE8),
                                      Color(0xFF9D50BB)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'MATCHXP',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'now',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.senderName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ), // Material
        ), // AnimatedBuilder
      ), // SafeArea
    ); // Positioned
  }

  Widget _initials(String name) {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
