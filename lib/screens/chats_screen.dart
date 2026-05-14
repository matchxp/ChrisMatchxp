import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/matching_service.dart';
import '../games/word_search/word_search_service.dart';
import '../games/word_search/word_search_models.dart';
import 'chat_conversation_screen.dart';
import 'game_status_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  /// Increment this from anywhere to trigger an instant list refresh.
  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with TickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  final WordSearchService _wordSearchService = WordSearchService();
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late AnimationController _matchAnimationController;
  bool _showMatchPopup = false;
  Map<String, dynamic>? _selectedMatch;

  // Each item: { match_id, profile, last_message, unread_count, game_phase }
  List<Map<String, dynamic>> _matchesWithProfiles = [];
  bool _loading = true;

  // ── Current user's own profile photo (for match popup) ────────────────────
  String _myPhoto = '';

  // ── Online presence ────────────────────────────────────────────────────────
  final Set<String> _onlineUserIds = {};

  @override
  void initState() {
    super.initState();
    _matchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadMatches();
    _loadMyPhoto();
    ChatsScreen.refreshNotifier.addListener(_onExternalRefresh);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    ChatsScreen.refreshNotifier.removeListener(_onExternalRefresh);
    _matchAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) _loadMatches();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
  }

  Future<void> _loadMyPhoto() async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('photos')
          .eq('id', _currentUserId)
          .maybeSingle();
      final photos = row?['photos'];
      if (photos is List && photos.isNotEmpty && mounted) {
        setState(() => _myPhoto = photos[0] as String);
      }
    } catch (_) {}
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

      return {
        ...m,
        'last_message': last,
        'unread_count': unreadCount,
        'game_phase': gamePhase,
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

  void _showMatchDialog(Map<String, dynamic> match) {
    setState(() {
      _selectedMatch = match;
      _showMatchPopup = true;
    });
    _matchAnimationController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _closeMatchPopup() {
    setState(() {
      _showMatchPopup = false;
      _selectedMatch = null;
    });
    _matchAnimationController.reverse();
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

  String _matchSection(Map<String, dynamic> match) {
    final phase = match['game_phase'] as MatchGamePhase?;
    if (phase == MatchGamePhase.bothSolved) return 'unlocked';
    if (phase == null || phase == MatchGamePhase.setup) return 'locked';
    return 'inProgress';
  }

  String? _gameBadgeLabel(Map<String, dynamic> match) {
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
                  _buildMatchesSection(),
                  _buildMessagesSection(),
                ],
              ],
            ),
          ),
          if (_showMatchPopup && _selectedMatch != null) _buildMatchPopup(),
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
          Row(
            children: [
              // ── Game status notification button ───────────────────────
              GestureDetector(
                onTap: _showGameStatusPage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sports_esports_rounded,
                      color: Color(0xFF6C3FE8), size: 20),
                ),
              ),
              const SizedBox(width: 8),
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
    final list = _filtered;
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: list.length,
          itemBuilder: (context, index) => _buildMatchAvatar(list[index]),
        ),
      ),
    );
  }

  Widget _buildMatchAvatar(Map<String, dynamic> match) {
    final profile = match['profile'] as Map<String, dynamic>;
    final photo = _profilePhoto(profile);
    final name = _profileName(profile);
    final userId = profile['id'] as String?;
    final isOnline = userId != null && _onlineUserIds.contains(userId);

    return GestureDetector(
      onTap: () => _showMatchDialog(match),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C3FE8).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0A0A0A), width: 3),
                    ),
                    child: ClipOval(
                      child: photo.isNotEmpty
                          ? Image.network(photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarInitial(name))
                          : _avatarInitial(name),
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0A0A0A), width: 2),
                      ),
                    ),
                  ),
              ],
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
    final list = _filtered;

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

  // ── Game status page ────────────────────────────────────────────────────────
  void _showGameStatusPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameStatusScreen(
          matches: _matchesWithProfiles,
          currentUserId: _currentUserId,
          onOpenMatch: _openConversation,
        ),
      ),
    );
  }

  // ── Match popup ─────────────────────────────────────────────────────────────
  Widget _buildMatchPopup() {
    final profile = _selectedMatch!['profile'] as Map<String, dynamic>;
    final photo = _profilePhoto(profile);
    final name = _profileName(profile);

    return GestureDetector(
      onTap: _closeMatchPopup,
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _matchAnimationController,
              curve: Curves.elasticOut,
            ),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF6C3FE8),
                          Color(0xFF9D50BB),
                          Color(0xFFFF6B8A)
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        "IT'S A MATCH!",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You and $name liked each other!',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.7)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _popupAvatar(_myPhoto.isNotEmpty ? _myPhoto : null,
                                const Color(0xFF6C3FE8)),
                            const SizedBox(width: 40),
                            _popupAvatar(photo, const Color(0xFFFF6B8A)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6C3FE8),
                                Color(0xFFFF6B8A)
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C3FE8)
                                    .withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite,
                              color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _closeMatchPopup();
                              _openConversation(_selectedMatch!);
                            },
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C3FE8),
                                    Color(0xFF9D50BB)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C3FE8)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_rounded,
                                      color: Colors.white, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'SEND MESSAGE',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _closeMatchPopup,
                            child: Text(
                              'Keep Swiping',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupAvatar(String? photo, Color borderColor) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
              color: borderColor.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2)
        ],
      ),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? Image.network(photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person,
                        size: 60, color: Colors.white54)))
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person,
                    size: 60, color: Colors.white54)),
      ),
    );
  }
}
