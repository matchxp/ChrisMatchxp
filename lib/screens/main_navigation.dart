import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/matching_service.dart';
import 'home_screen.dart';
import 'matches_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'chat_conversation_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  // Match IDs already shown via the full popup (User B) — skip the banner for these.
  static final Set<String> _popupShownIds = {};
  static void suppressBannerFor(String matchId) => _popupShownIds.add(matchId);

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
  // Cancellable auto-dismiss timer — prevents the old 4s delay from firing and
  // dismissing a NEWER banner that replaced the previous one mid-flight.
  Timer? _autoDismissTimer;

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
    _matchPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollForNewMatches();
    });
  }

  @override
  void dispose() {
    _matchPollTimer?.cancel();
    _autoDismissTimer?.cancel();
    for (final ch in _notifChannels) {
      ch.unsubscribe();
    }
    _notifChannels.clear();
    _notifOverlay?.remove();
    super.dispose();
  }

  // ── Poll for new matches — notifies User A (first liker) with a banner ─────
  // User A does NOT get the full match popup (only User B does, inline after
  // their like creates the match). User A gets a notification banner instead.

  Future<void> _pollForNewMatches() async {
    final matches = await _matchingService.getMatchesWithProfiles();
    if (!mounted) return;

    for (final match in matches) {
      final matchId = match['match_id'] as String;
      if (_initialMatchLoadDone && !_knownMatchIds.contains(matchId)) {
        // New match detected — only show banner for User A (first liker).
        // User B already saw the full popup, so skip the banner for them.
        if (!MainNavigation._popupShownIds.contains(matchId)) {
          final profile = match['profile'] as Map<String, dynamic>?;
          if (profile != null) {
            _showNotificationBanner(
              matchId: matchId,
              senderName: "It's a Match!",
              senderPhoto: _firstPhoto(profile),
              message: 'Tap to play!',
              matchEntry: match,
            );
          }
        }
      }
      _knownMatchIds.add(matchId);
    }
  }

  // ── Load matches + subscribe to each for notifications ────────────────────

  Future<void> _loadMatchesAndSubscribe() async {
    final matches = await _matchingService.getMatchesWithProfiles();
    if (!mounted) return;

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

    // Capture a direct reference so onRemove always removes THIS specific
    // entry — not whatever _notifOverlay happens to point to at call time
    // (which may have been replaced by a newer banner).
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        senderName: senderName,
        senderPhoto: senderPhoto,
        message: message,
        dismissNotifier: dismissNotifier,
        onRemove: () {
          entry.remove();
          if (_notifOverlay == entry) _notifOverlay = null;
        },
        onTap: () => _handleNotificationTap(matchId, matchEntry),
        onDismiss: _dismissNotification,
      ),
    );
    _notifOverlay = entry;

    overlay.insert(entry);

    // Auto-dismiss after 4 seconds.
    // Use a cancellable Timer so that if a new notification arrives before the
    // 4 s window elapses, the old timer is cancelled (see _dismissNotification)
    // and can't accidentally dismiss the new banner.
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 4), _dismissNotification);
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
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    if (_dismissRequested != null) {
      // Normal path: signal the banner to reverse-animate then remove itself.
      _dismissRequested!.value = true;
      _dismissRequested = null;
    } else if (_notifOverlay != null) {
      // Fallback: _dismissRequested was already cleared (e.g. auto-dismiss
      // fired before the user tapped X) but the overlay entry is still alive
      // because onRemove was never called. Force-remove it immediately.
      _notifOverlay!.remove();
      _notifOverlay = null;
    }
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
          ), // Row
        ), // Padding
      ), // SafeArea
    ); // outer Container
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
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.15)
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
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
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
                // Pill-shaped banner — tap area and X are sibling GestureDetectors
                // so they never compete in the gesture arena.
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D1060), Color(0xFF160830)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.60),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C3FE8).withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        // ── Avatar ───────────────────────────────────────────────
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFA78BFA), Color(0xFF6C3FE8)],
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
                        const SizedBox(width: 10),
                        // ── Name + message — tappable ─────────────────────────────
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onTap,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.senderName,
                                      style: GoogleFonts.fredoka(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.message,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.65),
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // ── X button — sibling so it never competes with onTap ───
                        GestureDetector(
                          onTap: widget.onDismiss,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.60),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ), // Material
            ), // AnimatedBuilder
          ), // SizedBox
        ), // Align
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
