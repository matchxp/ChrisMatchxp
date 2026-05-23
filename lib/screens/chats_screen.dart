import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/matching_service.dart';
import '../games/word_search/word_search_service.dart';
import '../games/word_search/word_search_models.dart';
import '../games/word_search/word_search_supabase_wrapper.dart';
import '../games/emoji_charades/emoji_charades_game_screen.dart';
import '../games/rock_paper_scissors/screens/rps_intro_screen.dart';
import '../games/game_hub_screen.dart';
import 'chat_conversation_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  /// Increment this from anywhere to trigger an instant list refresh.
  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final MatchingService _matchingService = MatchingService();
  final WordSearchService _wordSearchService = WordSearchService();
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Each item: { match_id, profile, last_message, unread_count, game_phase }
  List<Map<String, dynamic>> _matchesWithProfiles = [];
  bool _loading = true;

  // ── Online presence ────────────────────────────────────────────────────────
  final Set<String> _onlineUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadMatches();
    ChatsScreen.refreshNotifier.addListener(_onExternalRefresh);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    ChatsScreen.refreshNotifier.removeListener(_onExternalRefresh);
    _searchController.dispose();
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) _loadMatches();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
  }

  Future<void> _loadMatches() async {
    final matches = await _matchingService.getMatchesWithProfiles();

    // For each match fetch last message + unread count + game phase in parallel
    final enriched = await Future.wait(matches.map((m) async {
      final matchId = m['match_id'] as String;
      final last = await _matchingService.getLastMessage(matchId);

      // Fetch unread count
      int unreadCount = 0;
      try {
        final rows = await Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('match_id', matchId)
            .neq('sender_id', _currentUserId)
            .eq('is_read', false);
        unreadCount = (rows as List).length;
      } catch (_) {}

      // Fetch game phase — checks Word Search first, then Emoji Charades
      MatchGamePhase? gamePhase;
      try {
        final snap = await _wordSearchService.getSnapshot(
          matchId: matchId,
          myUserId: _currentUserId,
        );
        gamePhase = snap.phase;
      } catch (_) {}

      // If word search not completed, also check Emoji Charades
      if (gamePhase != MatchGamePhase.bothSolved) {
        try {
          final ecRows = await Supabase.instance.client
              .from('emoji_charades_games')
              .select('solved')
              .eq('match_id', matchId);
          final ecList = List<Map<String, dynamic>>.from(ecRows as List);
          if (ecList.length >= 2 && ecList.every((r) => r['solved'] == true)) {
            gamePhase = MatchGamePhase.bothSolved;
          } else if (ecList.isNotEmpty && gamePhase == null) {
            gamePhase = MatchGamePhase.solving;
          }
        } catch (_) {}
      }

      // Determine chat_unlocked, circle_color, and active session data
      bool chatUnlocked = gamePhase == MatchGamePhase.bothSolved;
      String circleColor = 'grey';
      String? activeSessionId;
      String? activeGameType;
      String? activeSessionStatus;
      if (!chatUnlocked) {
        try {
          final sessions = await Supabase.instance.client
              .from('game_sessions')
              .select('id, challenger_id, status, game_type')
              .eq('match_id', matchId)
              .order('created_at', ascending: false);
          final sessionList =
              List<Map<String, dynamic>>.from(sessions as List);
          chatUnlocked = sessionList.any((s) => s['status'] == 'completed');
          if (!chatUnlocked) {
            final active = sessionList.firstWhere(
              (s) => s['status'] != 'completed',
              orElse: () => <String, dynamic>{},
            );
            if (active.isNotEmpty) {
              final challengerId = active['challenger_id'] as String?;
              activeSessionId = active['id'] as String?;
              activeGameType = active['game_type'] as String?;
              activeSessionStatus = active['status'] as String?;
              if (gamePhase == MatchGamePhase.solving ||
                  gamePhase == MatchGamePhase.waitingPartnerSolve) {
                circleColor = 'purple';
              } else {
                circleColor =
                    challengerId == _currentUserId ? 'green' : 'red';
              }
            }
          }
        } catch (_) {}
      }

      return {
        ...m,
        'last_message': last,
        'unread_count': unreadCount,
        'game_phase': gamePhase,
        'chat_unlocked': chatUnlocked,
        'circle_color': circleColor,
        'active_session_id': activeSessionId,
        'active_game_type': activeGameType,
        'active_session_status': activeSessionStatus,
      };
    }));

    // Fetch online presence via last_seen
    final Set<String> online = {};
    final userIds = enriched
        .map((m) => (m['profile'] as Map<String, dynamic>)['id'] as String?)
        .whereType<String>()
        .toList();
    if (userIds.isNotEmpty) {
      try {
        final rows = await Supabase.instance.client
            .from('profiles')
            .select('id, last_seen')
            .inFilter('id', userIds);
        final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
        for (final row in rows as List) {
          final raw = row['last_seen'] as String?;
          if (raw == null) continue;
          final dt = DateTime.tryParse(raw)?.toLocal();
          if (dt != null && dt.isAfter(cutoff)) {
            online.add(row['id'] as String);
          }
        }
      } catch (_) {}
    }

    // Sort: most recent message first
    enriched.sort((a, b) {
      final aMsg = a['last_message'] as Map<String, dynamic>?;
      final bMsg = b['last_message'] as Map<String, dynamic>?;
      if (aMsg == null && bMsg == null) return 0;
      if (aMsg == null) return 1;
      if (bMsg == null) return -1;
      final aTime = DateTime.tryParse(aMsg['created_at'] as String? ?? '') ?? DateTime(0);
      final bTime = DateTime.tryParse(bMsg['created_at'] as String? ?? '') ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    if (!mounted) return;
    setState(() {
      _matchesWithProfiles = enriched;
      _onlineUserIds
        ..clear()
        ..addAll(online);
      _loading = false;
    });
  }

  void _openConversation(Map<String, dynamic> match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          matchId: match['match_id'] as String,
          otherProfile: match['profile'] as Map<String, dynamic>,
        ),
      ),
    ).then((_) => _loadMatches());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _profilePhoto(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) return photos[0] as String;
    return '';
  }

  String _profileName(Map<String, dynamic> profile) =>
      profile['first_name'] as String? ?? 'Match';

  String _lastMessagePreview(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) return 'Say hello \u{1F44B}';

    // ── Structured message types (new) ────────────────────────────────────────
    final msgType = lastMsg['message_type'] as String? ?? 'text';
    if (msgType == 'game_challenge') {
      final meta     = (lastMsg['meta'] as Map?)?.cast<String, dynamic>() ?? {};
      final gameType = meta['game_type'] as String? ?? 'rps';
      final label    = switch (gameType) {
        'word_search'    => 'Word Search',
        'emoji_charades' => 'Emoji Charades',
        _                => 'Rock Paper Scissors',
      };
      return '\u{1F3AE} $label challenge';
    }
    if (msgType == 'game_result') return '\u{1F3C6} Game finished';

    // ── Legacy content-prefix checks ─────────────────────────────────────────
    final content = lastMsg['content'] as String? ?? '';
    if (content.startsWith('[image]'))        return '\u{1F4F7} Photo';
    if (content.startsWith('[video]'))        return '\u{1F3A5} Video';
    if (content.startsWith('[voice]'))        return '\u{1F3A4} Voice message';
    if (content.startsWith('[GAME_REQUEST]')) return '\u{1F3AE} Game challenge';
    return content;
  }

  String _lastMessageTime(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) return '';
    final raw = lastMsg['created_at'] as String?;
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _matchesWithProfiles;
    return _matchesWithProfiles.where((m) {
      final profile = m['profile'] as Map<String, dynamic>;
      final name = _profileName(profile).toLowerCase();
      final preview = _lastMessagePreview(
              m['last_message'] as Map<String, dynamic>?)
          .toLowerCase();
      return name.contains(_searchQuery) || preview.contains(_searchQuery);
    }).toList();
  }

  // ── Game phase helpers ─────────────────────────────────────────────────────

  String? _gameBadgeLabel(Map<String, dynamic> match) {
    if (match['chat_unlocked'] as bool? ?? false) return null;
    final phase = match['game_phase'] as MatchGamePhase?;
    switch (phase) {
      case MatchGamePhase.setup:
        return 'LOCKED';
      case MatchGamePhase.waitingPartnerSetup:
      case MatchGamePhase.waitingPartnerSolve:
        return 'WAITING';
      case MatchGamePhase.solving:
        return 'SOLVING';
      case MatchGamePhase.bothSolved:
        return null;
      case null:
        return 'LOCKED';
    }
  }

  Color _gameBadgeColor(String label) {
    switch (label) {
      case 'SOLVING':  return const Color(0xFFF59E0B);
      case 'WAITING':  return const Color(0xFF6C3FE8);
      default:         return const Color(0xFF6B7280);
    }
  }

  Color _getCircleBorderColor(String circleColor) {
    switch (circleColor) {
      case 'green':  return const Color(0xFF22C55E);
      case 'red':    return const Color(0xFFEF4444);
      case 'purple': return const Color(0xFF7C3AED);
      default:       return const Color(0xFF4B5563);
    }
  }

  List<Map<String, dynamic>> get _lockedMatches => _matchesWithProfiles
      .where((m) => !(m['chat_unlocked'] as bool? ?? false))
      .toList();

  List<Map<String, dynamic>> get _unlockedFiltered =>
      _filtered.where((m) => m['chat_unlocked'] as bool? ?? false).toList();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C3FE8)),
                    ),
                  )
                else if (_matchesWithProfiles.isEmpty)
                  _buildEmptyState()
                else ...[
                  if (_lockedMatches.isNotEmpty) _buildMatchesSection(),
                  _buildMessagesSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'MATCH',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Text(
                  'XP',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _loadMatches,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh,
                  color: Color(0xFF6C3FE8), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search,
              color: Colors.white.withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search conversations…',
                hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.4)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              child: Icon(Icons.close,
                  size: 18, color: Colors.white.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
              ).createShader(bounds),
              child: const Icon(Icons.favorite_border,
                  size: 64, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'No matches yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Start swiping to find your match!',
              style: TextStyle(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesSection() {
    final list = _lockedMatches;
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
          child: Text(
            'Pending Games',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: list.length,
            itemBuilder: (context, index) => _buildMatchAvatar(list[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchAvatar(Map<String, dynamic> match) {
    final profile = match['profile'] as Map<String, dynamic>;
    final photo = _profilePhoto(profile);
    final name = _profileName(profile);
    final circleColor = match['circle_color'] as String? ?? 'grey';
    final borderColor = _getCircleBorderColor(circleColor);

    return GestureDetector(
      onTap: () => _handleCircleTap(match),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor,
                boxShadow: circleColor != 'grey'
                    ? [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.55),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0A0A),
                ),
                child: ClipOval(
                  child: photo.isNotEmpty
                      ? Image.network(photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarInitial(name))
                      : _avatarInitial(name),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarInitial(String name) {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22),
        ),
      ),
    );
  }

  Widget _buildMessagesSection() {
    final list = _unlockedFiltered;
    final hasLocked = _lockedMatches.isNotEmpty;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchQuery.isEmpty
                      ? 'Messages'
                      : 'Results (${list.length})',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                if (list.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${list.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          if (list.isEmpty && _searchQuery.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No results for "$_searchQuery"',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14),
                ),
              ),
            )
          else if (list.isEmpty && hasLocked)
            Expanded(
              child: Center(
                child: Text(
                  'Play a game to start chatting!',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 14),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                itemBuilder: (context, index) => _buildChatItem(list[index]),
              ),
            ),
        ],
      ),
    );
  }

  bool _isUnread(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) return false;
    final senderId = lastMsg['sender_id'] as String?;
    final isRead = lastMsg['is_read'];
    // FIX BUG-02: use != true so that null is_read (field absent from DB row)
    // is correctly treated as unread, not silently skipped as read.
    return senderId != null &&
        senderId != _currentUserId &&
        isRead != true;
  }

  Widget _buildChatItem(Map<String, dynamic> match) {
    final profile = match['profile'] as Map<String, dynamic>;
    final lastMsg = match['last_message'] as Map<String, dynamic>?;
    final photo = _profilePhoto(profile);
    final name = _profileName(profile);
    final preview = _lastMessagePreview(lastMsg);
    final time = _lastMessageTime(lastMsg);
    final unread = _isUnread(lastMsg);
    final unreadCount = (match['unread_count'] as int?) ?? 0;
    final userId = profile['id'] as String?;
    final isOnline = userId != null && _onlineUserIds.contains(userId);

    return GestureDetector(
      onTap: () => _openConversation(match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread
              ? const Color(0xFF1F1A2E)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: unread
              ? Border.all(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.25),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            // ── Avatar with online dot ───────────────────────────────────
            Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: photo.isNotEmpty
                        ? Image.network(photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarInitial(name))
                        : _avatarInitial(name),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unread
                              ? const Color(0xFF1F1A2E)
                              : const Color(0xFF1A1A1A),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // ── Name + badge + preview ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ── Game status pill ─────────────────────────────
                      Builder(builder: (_) {
                        final badgeLabel = _gameBadgeLabel(match);
                        if (badgeLabel == null) return const SizedBox.shrink();
                        final badgeColor = _gameBadgeColor(badgeLabel);
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: badgeColor.withValues(alpha: 0.5),
                                width: 0.8),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          unread ? FontWeight.w600 : FontWeight.normal,
                      color: unread
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // ── Time + unread badge ─────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: unread
                        ? const Color(0xFF9D70FF)
                        : Colors.white.withValues(alpha: 0.4),
                    fontWeight:
                        unread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (unread && unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else if (unread) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Circle tap routing ─────────────────────────────────────────────────────

  void _handleCircleTap(Map<String, dynamic> match) {
    final color = match['circle_color'] as String? ?? 'grey';
    switch (color) {
      case 'grey':
        _openGameHubForMatch(match);
      case 'green':
        _checkAndNavigate(match);
      case 'red':
        _acceptAndNavigate(match);
      case 'purple':
        _enterGame(match);
      default:
        _openConversation(match);
    }
  }

  // Grey: open GameHub so user can pick and send a challenge
  void _openGameHubForMatch(Map<String, dynamic> match) {
    final profile = match['profile'] as Map<String, dynamic>;
    final matchId = match['match_id'] as String;
    final partnerUserId = profile['id'] as String? ?? '';
    final partnerName = _profileName(profile);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameHubScreen(
          matchId: matchId,
          currentUserId: _currentUserId,
          partnerUserId: partnerUserId,
          partnerName: partnerName,
          onChatUnlocked: () {},
          onGameSelected: (gameType) =>
              _sendChallengeForMatch(matchId, partnerUserId, partnerName, gameType),
        ),
      ),
    );
  }

  Future<void> _sendChallengeForMatch(
      String matchId, String partnerUserId, String partnerName, String gameType) async {
    String? sessionId;
    try {
      sessionId = await Supabase.instance.client.rpc('create_game_challenge', params: {
        'p_match_id': matchId,
        'p_challenged_id': partnerUserId,
        'p_game_type': gameType,
        'p_is_initial': true,
      }) as String?;
      if (sessionId != null) {
        await Supabase.instance.client
            .rpc('accept_game_challenge', params: {'p_session_id': sessionId});
      }
    } catch (_) {}
    if (!mounted) return;
    _loadMatches();
    if (sessionId != null) {
      _enterGame({
        'match_id': matchId,
        'profile': {'id': partnerUserId, 'first_name': partnerName},
        'active_session_id': sessionId,
        'active_game_type': gameType,
      });
    }
  }

  // Green: accept (idempotent) and enter game — challenger re-enters their own session
  Future<void> _checkAndNavigate(Map<String, dynamic> match) async {
    final sessionId = match['active_session_id'] as String?;
    if (sessionId == null) return;

    try {
      await Supabase.instance.client
          .rpc('accept_game_challenge', params: {'p_session_id': sessionId});
    } catch (_) {}
    if (!mounted) return;
    _enterGame(match);
  }

  // Red: accept the challenge then navigate into the game
  Future<void> _acceptAndNavigate(Map<String, dynamic> match) async {
    final sessionId = match['active_session_id'] as String?;
    if (sessionId == null) return;

    try {
      await Supabase.instance.client
          .rpc('accept_game_challenge', params: {'p_session_id': sessionId});
    } catch (_) {}
    if (!mounted) return;
    _enterGame(match);
  }

  // Purple / green-active: navigate straight into the game
  void _enterGame(Map<String, dynamic> match) {
    final sessionId = match['active_session_id'] as String?;
    final gameType = match['active_game_type'] as String? ?? 'word_search';
    if (sessionId == null) return;

    final profile = match['profile'] as Map<String, dynamic>;
    final matchId = match['match_id'] as String;
    final partnerUserId = profile['id'] as String? ?? '';
    final partnerName = _profileName(profile);

    void onUnlock() {
      if (!mounted) return;
      Navigator.of(context).pop();
    }

    void onReturn(_) {
      if (mounted) _loadMatches();
    }

    switch (gameType) {
      case 'word_search':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordSearchSupabaseWrapper(
              matchId: matchId,
              currentUserId: _currentUserId,
              partnerUserId: partnerUserId,
              partnerName: partnerName,
              onChatUnlocked: onUnlock,
              sessionId: sessionId,
            ),
          ),
        ).then(onReturn);
      case 'emoji_charades':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmojiCharadesGameScreen(
              matchId: matchId,
              currentUserId: _currentUserId,
              partnerUserId: partnerUserId,
              partnerName: partnerName,
              onChatUnlocked: onUnlock,
              sessionId: sessionId,
            ),
          ),
        ).then(onReturn);
      case 'rps':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RPSIntroScreen(
              currentUserId: _currentUserId,
              currentUserName: 'You',
              opponentId: partnerUserId,
              opponentName: partnerName,
              sessionId: sessionId,
              popCount: 1,
              onChatUnlocked: () {
                // RPS uses popCount for navigation; just reload on return
                if (mounted) _loadMatches();
              },
            ),
          ),
        );
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameHubScreen(
              matchId: matchId,
              currentUserId: _currentUserId,
              partnerUserId: partnerUserId,
              partnerName: partnerName,
              onChatUnlocked: onUnlock,
            ),
          ),
        ).then(onReturn);
    }
  }
}
