import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import '../services/matching_service.dart';
import '../games/game_hub_screen.dart';
import '../games/word_search/word_search_service.dart';
import '../games/word_search/word_search_models.dart';
import '../games/word_search/word_search_supabase_wrapper.dart';
import '../games/emoji_charades/emoji_charades_game_screen.dart';
import '../games/rock_paper_scissors/screens/rps_intro_screen.dart';
import '../games/rock_paper_scissors/screens/rps_waiting_screen.dart';
import '../games/rock_paper_scissors/screens/rps_reveal_screen.dart';
import '../games/rock_paper_scissors/data/rps_models.dart';
import 'full_profile_screen.dart';
import '../widgets/matchxp_background.dart';

class ChatConversationScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> otherProfile;

  const ChatConversationScreen({
    super.key,
    required this.matchId,
    required this.otherProfile,
  });

  /// Tracks the currently open match ID so MainNavigation
  /// can suppress notifications for the active conversation.
  static String? activeChatMatchId;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final MatchingService _matchingService = MatchingService();
  final WordSearchService _gameService = WordSearchService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  double _prevKeyboardHeight = 0.0; // track keyboard growth for auto-scroll

  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  // Game gate — chat is locked until EITHER game is completed by both players
  bool _chatUnlocked = false;
  bool _gameStatusLoading = true;
  RealtimeChannel? _gameChannel; // word_search_games realtime
  RealtimeChannel? _ecChannel; // emoji_charades_games realtime
  RealtimeChannel?
      _matchUnlockChannel; // matches table — catches any unlock source

  // Scoreboard
  int _myWins = 0;
  int _partnerWins = 0;
  bool _scoresLoaded = false;
  RealtimeChannel? _scoreChannel;

  // Live game session states — keyed by session id, updated via .stream()
  final Map<String, Map<String, dynamic>> _sessionStates = {};
  RealtimeChannel? _sessionChannel; // kept for legacy disposal safety
  StreamSubscription<List<Map<String, dynamic>>>? _messageStream;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionStream;

  // ── Reply / quote ──────────────────────────────────────────────────────────
  /// The message being replied to (null = no active reply)
  Map<String, dynamic>? _replyingTo;

  // ── Reactions ──────────────────────────────────────────────────────────────
  /// Map of message id → list of emoji strings reacted by current user
  /// (stored in-memory; persisted via a `message_reactions` table if available)
  final Map<String, List<String>> _reactions = {};

  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

  // ── Online status ──────────────────────────────────────────────────────────
  bool? _isOnline;
  DateTime? _lastSeenAt;
  Timer? _onlineTimer;
  Timer? _gameAcceptancePoller;

  // ── Scoreboard collapse ────────────────────────────────────────────────────
  bool _scoreboardExpanded = false;

  // ── Typing indicator ───────────────────────────────────────────────────────
  bool _isPartnerTyping = false;
  Timer? _typingHideTimer;
  Timer? _myTypingDebounce;

  // ── Scroll-to-bottom FAB ───────────────────────────────────────────────────
  bool _showScrollToBottom = false;
  int _unreadWhileScrolled = 0;

  // ── Message GlobalKeys (for reply-tap-to-scroll) ───────────────────────────
  final Map<String, GlobalKey> _messageKeys = {};

  // ── Voice playback ────────────────────────────────────────────────────────
  AudioPlayer? _audioPlayer;
  String? _playingVoiceKey;
  bool _isVoicePlaying = false;
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Tell the global listener which chat is open so it suppresses that notif
    ChatConversationScreen.activeChatMatchId = widget.matchId;
    _checkGameStatus();
    _subscribeMessages(); // replaces _loadMessages + _subscribeToMessages
    _loadScores();
    _subscribeSessionStream(); // replaces _loadSessionStates + _subscribeToSessions
    // _resumePendingChallengePoller(); // disabled — manual rejoin via chat card
    _fetchOnlineStatus();
    _onlineTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _fetchOnlineStatus());
    _scrollController.addListener(_onScrollChanged);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) _scrollToBottom();
    });
    _initAudioPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scroll to the latest message whenever the keyboard grows (each animation
    // frame as it slides up), so messages are never covered by the keyboard.
    final kh = MediaQuery.of(context).viewInsets.bottom;
    if (kh > _prevKeyboardHeight) _scrollToBottom();
    _prevKeyboardHeight = kh;
  }

  @override
  void dispose() {
    // Clear the active chat tracking
    if (ChatConversationScreen.activeChatMatchId == widget.matchId) {
      ChatConversationScreen.activeChatMatchId = null;
    }
    _messageStream?.cancel();
    _sessionStream?.cancel();
    _channel?.unsubscribe();
    _matchingService.unsubscribeFromChat(widget.matchId);
    if (_gameChannel != null) _gameService.unsubscribe(_gameChannel!);
    if (_ecChannel != null) Supabase.instance.client.removeChannel(_ecChannel!);
    if (_scoreChannel != null) _gameService.unsubscribe(_scoreChannel!);
    if (_matchUnlockChannel != null)
      Supabase.instance.client.removeChannel(_matchUnlockChannel!);
    if (_sessionChannel != null)
      Supabase.instance.client.removeChannel(_sessionChannel!);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _onlineTimer?.cancel();
    _gameAcceptancePoller?.cancel();
    _typingHideTimer?.cancel();
    _myTypingDebounce?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Check whether chat is unlocked via ANY of the three games:
  ///   1. Word Search    — word_search_games table (both rows solved)
  ///   2. Emoji Charades — emoji_charades_games table (both rows have solved==true)
  ///   3. RPS            — local/pass-the-phone; no persistent DB record, so the
  ///                        onChatUnlocked() callback handles it at play-time only.
  Future<void> _checkGameStatus() async {
    bool unlocked = false;
    MatchGamesSnapshot? wsSnap;

    // ── 1. Word Search ─────────────────────────────────────────────────────
    try {
      wsSnap = await _gameService.getSnapshot(
        matchId: widget.matchId,
        myUserId: _currentUserId,
      );
      if (wsSnap.phase == MatchGamePhase.bothSolved) unlocked = true;
    } catch (e) {
      debugPrint('Word Search status check failed: $e');
    }

    // ── 2. Emoji Charades ──────────────────────────────────────────────────
    if (!unlocked) {
      try {
        final rows = await Supabase.instance.client
            .from('emoji_charades_games')
            .select('solved')
            .eq('match_id', widget.matchId);
        final list = List<Map<String, dynamic>>.from(rows as List);
        if (list.length >= 2 && list.every((r) => r['solved'] == true)) {
          unlocked = true;
        }
      } catch (e) {
        debugPrint('Emoji Charades status check failed: $e');
      }
    }

    // ── 3. matches.chat_unlocked — covers RPS and any other unlock path ────
    if (!unlocked) {
      try {
        final matchRow = await Supabase.instance.client
            .from('matches')
            .select('chat_unlocked')
            .eq('id', widget.matchId)
            .single();
        if (matchRow['chat_unlocked'] == true) unlocked = true;
      } catch (e) {
        debugPrint('matches.chat_unlocked check failed: $e');
      }
    }

    if (mounted)
      setState(() {
        if (unlocked) _chatUnlocked = true;
        _gameStatusLoading = false;
      });

    // ── Realtime: Word Search changes ──────────────────────────────────────
    _gameChannel = _gameService.subscribeToMatch(
      widget.matchId,
      () async {
        final updated = await _gameService.getSnapshot(
          matchId: widget.matchId,
          myUserId: _currentUserId,
        );
        if (mounted)
          setState(() {
            if (updated.phase == MatchGamePhase.bothSolved)
              _chatUnlocked = true;
          });
      },
      channelSuffix: 'chat',
    );

    // ── Realtime: Emoji Charades changes ───────────────────────────────────
    _ecChannel = Supabase.instance.client
        .channel('ec_chat_${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'emoji_charades_games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (_) async {
            try {
              final rows = await Supabase.instance.client
                  .from('emoji_charades_games')
                  .select('solved')
                  .eq('match_id', widget.matchId);
              final list = List<Map<String, dynamic>>.from(rows as List);
              if (mounted &&
                  list.length >= 2 &&
                  list.every((r) => r['solved'] == true)) {
                setState(() => _chatUnlocked = true);
              }
            } catch (_) {}
          },
        )
        .subscribe();

    // ── Realtime: matches.chat_unlocked — fires for RPS, auto-unlock, any game ──
    // This is the single source of truth for unlock state. Catches all paths:
    // complete_game_session(), auto_unlock_expired_sessions(), etc.
    _matchUnlockChannel = Supabase.instance.client
        .channel('match_unlock_${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.matchId,
          ),
          callback: (payload) {
            final unlocked =
                payload.newRecord['chat_unlocked'] as bool? ?? false;
            if (unlocked && mounted) setState(() => _chatUnlocked = true);
          },
        )
        .subscribe();

    // ── Realtime: messages UPDATE — refreshes challenge card status ─────────
    // When accept_game_challenge or complete_game_session updates meta,
    // we patch the local message list so the card re-renders without a reload.
    Supabase.instance.client
        .channel('msg_updates_${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updated = Map<String, dynamic>.from(payload.newRecord);
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == updated['id']);
              if (idx != -1) _messages[idx] = updated;
            });
          },
        )
        .subscribe();
  }

  // ── Session stream: initial load + live INSERT/UPDATE via .stream() ──────────

  void _subscribeSessionStream() {
    if (_sessionStream != null) return; // guard: don't create duplicates
    _sessionStream = Supabase.instance.client
        .from('game_sessions')
        .stream(primaryKey: ['id'])
        .eq('match_id', widget.matchId)
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _sessionStates.clear();
            for (final row in rows) {
              final id = row['id'] as String?;
              if (id != null) {
                _sessionStates[id] = Map<String, dynamic>.from(row as Map);
              }
            }
          });
        });
  }

  void _refreshSessionStream() {
    _sessionStream?.cancel();
    _sessionStream = null;
    _subscribeSessionStream();
  }

  Future<void> _loadScores() async {
    try {
      final partnerUserId = widget.otherProfile['id'] as String? ?? '';
      final scores = await _gameService.getScores(
        matchId: widget.matchId,
        myUserId: _currentUserId,
        partnerUserId: partnerUserId,
      );
      if (!mounted) return;
      setState(() {
        _myWins = scores['myWins'] ?? 0;
        _partnerWins = scores['partnerWins'] ?? 0;
        _scoresLoaded = true;
      });

      _scoreChannel = _gameService.subscribeToScores(widget.matchId, () async {
        final updated = await _gameService.getScores(
          matchId: widget.matchId,
          myUserId: _currentUserId,
          partnerUserId: partnerUserId,
        );
        if (mounted)
          setState(() {
            _myWins = updated['myWins'] ?? 0;
            _partnerWins = updated['partnerWins'] ?? 0;
          });
      });
    } catch (_) {}
  }

  // ── Online status ──────────────────────────────────────────────────────────
  Future<void> _fetchOnlineStatus() async {
    try {
      final otherUserId = widget.otherProfile['id'] as String?;
      if (otherUserId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('last_seen_at')
          .eq('id', otherUserId)
          .maybeSingle();
      if (!mounted) return;
      final lastSeenStr = data?['last_seen_at'] as String?;
      final lastSeen = lastSeenStr != null
          ? DateTime.tryParse(lastSeenStr)?.toLocal()
          : null;
      setState(() {
        _lastSeenAt = lastSeen;
        _isOnline = lastSeen != null &&
            DateTime.now().difference(lastSeen).inMinutes < 5;
      });
    } catch (_) {}
  }

  String _formatOnlineStatus() {
    if (_isOnline == true) return 'Online';
    final ls = _lastSeenAt;
    if (ls == null) return '';
    final diff = DateTime.now().difference(ls);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Last seen ${ls.day} ${months[ls.month - 1]}';
  }

  // ── Scroll-to-bottom FAB logic ─────────────────────────────────────────────
  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 120;
    if (atBottom && (_showScrollToBottom || _unreadWhileScrolled > 0)) {
      setState(() {
        _showScrollToBottom = false;
        _unreadWhileScrolled = 0;
      });
    } else if (!atBottom && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    }
  }

  // ── Typing broadcast ────────────────────────────────────────────────────────
  void _onTypingChanged() {
    _myTypingDebounce?.cancel();
    _myTypingDebounce = Timer(const Duration(milliseconds: 350), () {
      _matchingService.sendTypingEvent(widget.matchId);
    });
  }

  void _handlePartnerTyping() {
    if (!mounted) return;
    setState(() => _isPartnerTyping = true);
    _typingHideTimer?.cancel();
    _typingHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isPartnerTyping = false);
    });
  }

  // ── Reaction loader (persisted) ────────────────────────────────────────────
  Future<void> _loadReactions() async {
    try {
      final data = await Supabase.instance.client
          .from('message_reactions')
          .select('message_id, emoji')
          .eq('user_id', _currentUserId);
      if (!mounted) return;
      final Map<String, List<String>> loaded = {};
      for (final row in List<Map<String, dynamic>>.from(data as List)) {
        final id = row['message_id'] as String;
        final emoji = row['emoji'] as String;
        loaded.putIfAbsent(id, () => []).add(emoji);
      }
      setState(() => _reactions.addAll(loaded));
    } catch (_) {}
  }

  // ── Reply scroll-to-original ────────────────────────────────────────────────
  void _scrollToMessageByContent(String content) {
    // Find the earliest message whose content matches the quoted snippet
    for (final msg in _messages) {
      final c = msg['content'] as String? ?? '';
      if (c == content || c.startsWith(content)) {
        final key = _messageKeys[
            msg['id'] as String? ?? msg['created_at'] as String? ?? ''];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            alignment: 0.3,
          );
        }
        return;
      }
    }
  }

  // ── Audio player init + playback ───────────────────────────────────────────
  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _voicePosition = pos);
    });
    _audioPlayer!.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _voiceDuration = dur);
    });
    _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isVoicePlaying = false;
          _voicePosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _playVoice(String url, String msgKey) async {
    if (_audioPlayer == null) return;
    if (_playingVoiceKey == msgKey && _isVoicePlaying) {
      await _audioPlayer!.pause();
      setState(() => _isVoicePlaying = false);
      return;
    }
    if (_playingVoiceKey == msgKey && !_isVoicePlaying) {
      await _audioPlayer!.resume();
      setState(() => _isVoicePlaying = true);
      return;
    }
    // New track
    setState(() {
      _playingVoiceKey = msgKey;
      _isVoicePlaying = false;
      _voicePosition = Duration.zero;
      _voiceDuration = Duration.zero;
    });
    await _audioPlayer!.stop();
    await _audioPlayer!.play(UrlSource(url));
    setState(() => _isVoicePlaying = true);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Date separator helpers ─────────────────────────────────────────────────
  String? _getDateLabel(String? isoString) {
    if (isoString == null) return null;
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
  }

  bool _isSameGroup(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['sender_id'] != b['sender_id']) return false;
    final aTime = DateTime.tryParse(a['created_at'] as String? ?? '');
    final bTime = DateTime.tryParse(b['created_at'] as String? ?? '');
    if (aTime == null || bTime == null) return false;
    return bTime.difference(aTime).inSeconds.abs() <= 60;
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child: Divider(
                color: const Color(0xFF6C3FE8).withValues(alpha: 0.2),
                thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
            child: Divider(
                color: const Color(0xFF6C3FE8).withValues(alpha: 0.2),
                thickness: 1)),
      ]),
    );
  }

  Future<void> _loadMessages() async {
    final messages = await _matchingService.getMessages(widget.matchId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
      // Unlock if there are real text messages — exclude old game-request tags
      // AND the new structured game_challenge / game_result system messages.
      final gameTypes = {'game_challenge', 'game_result'};
      final hasRealMessages = messages.any((m) {
        final type = m['message_type'] as String? ?? 'text';
        if (gameTypes.contains(type)) return false;
        return !(m['content'] as String? ?? '').startsWith(_gameRequestTag);
      });
      if (hasRealMessages) _chatUnlocked = true;
    });
    _scrollToBottom();
    _matchingService.markMessagesAsRead(widget.matchId);
    _loadReactions();
  }

  // ── Message stream: initial load + live delivery via .stream() ───────────────
  // The broadcast channel (via subscribeToMessages) is kept solely for:
  //   • typing indicators (_handlePartnerTyping)
  //   • the send path (sendMessage uses the stored broadcast channel)
  //   • instant read-receipt patches (onUpdate)
  // Message *delivery* is fully handled by the .stream() listener below.

  // Starts (or restarts) only the .stream() subscription.
  // Safe to call multiple times — cancels the old one first.
  // Does NOT touch _channel (broadcast/typing) so there are no duplicates.
  void _restartMessageStream() {
    _messageStream?.cancel();
    _messageStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', widget.matchId)
        .order('created_at', ascending: true)
        .listen(_onMessageStreamRows);
  }

  void _onMessageStreamRows(List<Map<String, dynamic>> rows) {
    if (!mounted) return;

    final serverMsgs = List<Map<String, dynamic>>.from(rows);
    final wasEmpty = _messages.isEmpty;
    final prevServerCount = _messages.where((m) => m['id'] != null).length;

    setState(() {
      // Preserve pending optimistic messages (id == null) that haven't
      // been confirmed by the server yet.
      final pending = _messages.where((m) {
        if (m['id'] != null) return false; // already confirmed
        final msgType = m['message_type'] as String? ?? 'text';
        final sender = m['sender_id'] as String?;
        final optTime = DateTime.tryParse(m['created_at'] as String? ?? '');

        if (msgType == 'game_challenge') {
          // game_challenge rows all have content:'', so we can't dedup by content.
          // Only evict this optimistic when a server row with the same game_type
          // appears within 5 s — that's the real DB confirmation of THIS invite.
          final gameType = (m['meta'] as Map?)?['game_type'] as String?;
          return !serverMsgs.any((s) {
            if (s['message_type'] != 'game_challenge') return false;
            if (s['sender_id'] != sender) return false;
            final sMeta = (s['meta'] as Map?)?.cast<String, dynamic>();
            if (sMeta?['game_type'] != gameType) return false;
            if (optTime != null) {
              final svrTime =
                  DateTime.tryParse(s['created_at'] as String? ?? '');
              if (svrTime != null &&
                  optTime.difference(svrTime).inSeconds.abs() > 5) {
                return false;
              }
            }
            return true;
          });
        }

        // Regular messages: match by sender + content, within 60 s.
        final content = m['content'] as String? ?? '';
        return !serverMsgs.any((s) {
          if (s['sender_id'] != sender || s['content'] != content) return false;
          if (optTime != null) {
            final svrTime = DateTime.tryParse(s['created_at'] as String? ?? '');
            if (svrTime != null &&
                optTime.difference(svrTime).inSeconds.abs() > 60) {
              return false;
            }
          }
          return true;
        });
      }).toList();

      _messages = [...serverMsgs, ...pending];
      _messages.sort((a, b) {
        final ta = a['created_at'] as String? ?? '';
        final tb = b['created_at'] as String? ?? '';
        return ta.compareTo(tb);
      });
      _loading = false;

      // Unlock chat if server list contains real (non-game) messages.
      if (!_chatUnlocked) {
        const gameTypes = {'game_challenge', 'game_result'};
        if (serverMsgs.any((m) {
          final type = m['message_type'] as String? ?? 'text';
          if (gameTypes.contains(type)) return false;
          return !(m['content'] as String? ?? '').startsWith(_gameRequestTag);
        })) {
          _chatUnlocked = true;
        }
      }

      // Also unlock immediately when a game_result arrives.
      if (!_chatUnlocked &&
          serverMsgs.any((m) => m['message_type'] == 'game_result')) {
        _chatUnlocked = true;
      }
    });

    if (wasEmpty) {
      // Initial load — jump to bottom and run one-time side effects.
      _scrollToBottom();
      _matchingService.markMessagesAsRead(widget.matchId);
      _loadReactions();
    } else if (serverMsgs.length > prevServerCount) {
      // New message(s) arrived.
      final newMsgs = serverMsgs.sublist(prevServerCount);
      final hasPartnerMsg =
          newMsgs.any((m) => m['sender_id'] != _currentUserId);
      if (hasPartnerMsg) {
        _matchingService.markMessagesAsRead(widget.matchId);
      }
      if (_showScrollToBottom && hasPartnerMsg) {
        // User is scrolled up — show badge instead of jumping.
        setState(() => _unreadWhileScrolled++);
      } else {
        _scrollToBottom();
      }
      // Refresh scoreboard when a game result arrives (partner's screen update).
      if (newMsgs.any((m) => m['message_type'] == 'game_result')) {
        _loadScores();
      }
    }
  }

  void _subscribeMessages() {
    if (_messageStream != null) return; // guard: don't create duplicates

    // 1. Stream: initial load + every INSERT/UPDATE fires a full list update.
    _restartMessageStream();

    // 2. Broadcast channel: typing events, send path, and instant read-receipt
    //    patches. On any incoming message broadcast, restart the stream so the
    //    partner's new message is fetched from DB and added to the list.
    _channel = _matchingService.subscribeToMessages(
      widget.matchId,
      (msg) {
        // game_accepted: partner accepted our challenge.
        // No auto-navigation — challenger enters the game by tapping the card.
        // Just refresh the message stream so the card status updates.
        if (msg['event_type'] == 'game_accepted') {
          debugPrint('[onMessage] game_accepted — refreshing card status');
          if (mounted) _restartMessageStream();
          return;
        }
        // Only refresh on messages from the partner — our own broadcasts
        // (game challenges, text) are already in _messages via setState.
        final senderId = msg['sender_id'] as String?;
        if (senderId == _currentUserId) return;
        if (mounted) _restartMessageStream();
      },
      onTyping: _handlePartnerTyping,
      onReadReceipt: () {
        // Partner opened chat and marked our messages as read.
        // Patch every outgoing message to is_read:true so the double-tick
        // shows immediately — no stream restart needed.
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < _messages.length; i++) {
            if (_messages[i]['sender_id'] == _currentUserId &&
                _messages[i]['is_read'] != true) {
              _messages[i] = {..._messages[i], 'is_read': true};
            }
          }
        });
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    // Capture reply context before clearing it
    final replyContent = _replyingTo?['content'] as String?;
    final replySender = _replyingTo == null
        ? null
        : (_replyingTo!['sender_id'] == _currentUserId ? 'You' : _otherName);

    // Build the optimistic message — attach reply metadata if replying
    final Map<String, dynamic> optimistic = {
      'match_id': widget.matchId,
      'sender_id': _currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      if (replyContent != null) 'reply_to_content': replyContent,
      if (replySender != null) 'reply_to_sender': replySender,
    };

    setState(() {
      _messages.add(optimistic);
      _replyingTo = null; // clear reply context
    });
    _scrollToBottom();

    // Persist — include reply metadata so the partner sees the quote strip too
    _matchingService.sendMessage(
      widget.matchId,
      text,
      replyToContent: replyContent,
      replyToSender: replySender,
    );
  }

  Future<void> _sendGameChallenge(String gameType) async {
    final db = Supabase.instance.client;
    final partnerUserId = widget.otherProfile['id'] as String? ?? '';
    final now = DateTime.now().toUtc().toIso8601String();

    final optimistic = <String, dynamic>{
      'id': null,
      'match_id': widget.matchId,
      'sender_id': _currentUserId,
      'content': '[GAME_CHALLENGE]',
      'message_type': 'game_challenge',
      'meta': {'game_type': gameType, 'status': 'pending'},
      'created_at': now,
      'is_read': false,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      await db.rpc('create_game_challenge', params: {
        'p_match_id': widget.matchId,
        'p_challenged_id': partnerUserId,
        'p_game_type': gameType,
        'p_is_initial': false,
      });

      final rows = await db
          .from('messages')
          .select()
          .eq('match_id', widget.matchId)
          .eq('message_type', 'game_challenge')
          .eq('sender_id', _currentUserId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) throw Exception('challenge message not found');
      final realMsg = Map<String, dynamic>.from(rows.first as Map);

      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) =>
            m['id'] == null &&
            m['message_type'] == 'game_challenge' &&
            (m['meta'] as Map?)?['game_type'] == gameType);
        _messages.add(realMsg);
        _messages.sort((a, b) => (a['created_at'] as String? ?? '')
            .compareTo(b['created_at'] as String? ?? ''));
      });

      _matchingService.broadcastMessage(widget.matchId, realMsg);

      // No auto-navigation after sending — challenger enters via the card tap.
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) =>
          m['id'] == null &&
          m['message_type'] == 'game_challenge' &&
          (m['meta'] as Map?)?['game_type'] == gameType));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF160C2A),
        content: Text('Could not send challenge: $e',
            style: const TextStyle(color: Colors.white)),
      ));
    }
  }

  Future<void> _acceptChallenge(Map<String, dynamic> msg) async {
    final rawMeta = msg['meta'];
    final meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};
    final sessionId = meta['session_id'] as String?;
    final gameType = meta['game_type'] as String?;
    if (sessionId == null || gameType == null) return;

    try {
      // RPC validates challenged_id == auth.uid() and is idempotent if already active
      await Supabase.instance.client.rpc('accept_game_challenge', params: {
        'p_session_id': sessionId,
      });
    } catch (e) {
      debugPrint('[AcceptChallenge] RPC error (proceeding anyway): $e');
    }

    // Notify the challenger so their poll + broadcast both resolve quickly.
    _matchingService.broadcastMessage(widget.matchId, {
      'event_type': 'game_accepted',
      'session_id': sessionId,
      'game_type': gameType,
      'accepted_by': _currentUserId,
    });
    debugPrint(
        '[AcceptChallenge] broadcast sent session=$sessionId game=$gameType');

    if (!mounted) return;
    _navigateToGame(gameType, sessionId);
  }

  // On app restart, resume the challenger navigation for any in-progress session.
  // Case 1 — still pending: restart poller so we catch acceptance.
  // Case 2 — already active: navigate immediately (accepted while we were offline).
  // On chat open, auto-rejoin any in-progress game session for this match.
  // Covers both roles: challenger (pending/active) and challenged (active only).
  Future<void> _resumePendingChallengePoller() async {
    if (_currentUserId.isEmpty) return;
    try {
      // Fetch recent non-completed sessions for this match — filter by
      // participant role in code so we catch both challenger and challenged.
      final rows = await Supabase.instance.client
          .from('game_sessions')
          .select('id, game_type, status, created_at, challenger_id, challenged_id')
          .eq('match_id', widget.matchId)
          .inFilter('status', ['pending', 'active'])
          .order('created_at', ascending: false)
          .limit(5);

      // Find the most recent session where I am a participant.
      final row = rows.where((r) {
        return r['challenger_id'] == _currentUserId ||
            r['challenged_id'] == _currentUserId;
      }).firstOrNull;

      if (row == null || !mounted) return;

      final sessionId = row['id'] as String;
      final gameType = row['game_type'] as String;
      final status = row['status'] as String;
      final isChallenger = row['challenger_id'] == _currentUserId;
      final createdAt =
          DateTime.tryParse(row['created_at'] as String? ?? '');

      // Skip sessions older than 24 hours — treat as expired, no auto-nav.
      if (createdAt != null &&
          DateTime.now().toUtc().difference(createdAt.toUtc()) >
              const Duration(hours: 24)) {
        debugPrint('[Resume] session expired, skipping session=$sessionId');
        return;
      }

      if (status == 'active') {
        // Both challenger and challenged rejoin an active session.
        debugPrint('[Resume] active session found, navigating session=$sessionId');
        _navigateToGame(gameType, sessionId);
      } else if (isChallenger) {
        // Only challenger waits for a pending session to be accepted.
        debugPrint('[Resume] pending challenge found, restarting poller session=$sessionId');
        _pollForGameAcceptance(sessionId, gameType);
      }
    } catch (e) {
      debugPrint('[Resume] error: $e');
    }
  }

  // Polls game_sessions every 2 s for up to 60 s waiting for partner to accept.
  // Fallback for when the broadcast doesn't reach the challenger in time.
  void _pollForGameAcceptance(String sessionId, String gameType) {
    _gameAcceptancePoller?.cancel();
    int attempts = 0;
    _gameAcceptancePoller =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 30 || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final row = await Supabase.instance.client
            .from('game_sessions')
            .select('status')
            .eq('id', sessionId)
            .maybeSingle();
        debugPrint('[Poll] session $sessionId status=${row?['status']}');
        if (row != null && row['status'] == 'active') {
          timer.cancel();
          if (mounted) _navigateToGame(gameType, sessionId);
        }
      } catch (e) {
        debugPrint('[Poll] error: $e');
      }
    });
  }

  Future<void> _navigateToGame(String gameType, String sessionId,
      {bool isRejoin = false}) async {
    _gameAcceptancePoller?.cancel();
    _gameAcceptancePoller = null;
    final partnerUserId = widget.otherProfile['id'] as String? ?? '';

    void onUnlock() {
      if (!mounted) return;
      setState(() => _chatUnlocked = true);
      Navigator.of(context).pop();
    }

    void onRpsUnlock() {
      if (!mounted) return;
      setState(() => _chatUnlocked = true);
      _restartMessageStream();
      _refreshSessionStream();
      _loadScores();
    }

    void refresh(_) {
      if (!mounted) return;
      _restartMessageStream();
      _refreshSessionStream();
      // _loadScores() is intentionally omitted here — game_scores is in the
      // supabase_realtime publication so subscribeToScores() fires as soon as
      // a score row is inserted, updating the board exactly once. Calling it
      // again here would cause a visible double-update.
    }

    // ── RPS rejoin: check DB to resume at the right screen ────────────
    if (gameType == 'rps' && isRejoin) {
      final db = Supabase.instance.client;
      try {
        final myRows = await db
            .from('rps_moves')
            .select('move')
            .eq('session_id', sessionId)
            .eq('player_id', _currentUserId);
        if (!mounted) return;

        if (myRows.isEmpty) {
          // Haven't picked yet — show intro first (user hasn't started the game).
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RPSIntroScreen(
                  currentUserId: _currentUserId,
                  currentUserName: 'You',
                  opponentId: partnerUserId,
                  opponentName: _otherName,
                  sessionId: sessionId,
                  popCount: 1,
                  chatAlreadyUnlocked: _chatUnlocked,
                  onChatUnlocked: onRpsUnlock,
                ),
              )).then(refresh);
        } else {
          final myMoveStr = myRows.first['move'] as String;
          final myMove = RPSMove.values.firstWhere(
              (m) => m.name == myMoveStr,
              orElse: () => RPSMove.rock);

          final allRows = await db
              .from('rps_moves')
              .select('player_id, move')
              .eq('session_id', sessionId);
          if (!mounted) return;

          if (allRows.length >= 2) {
            // Both picked — go to reveal.
            final oppRow = allRows.firstWhere(
                (r) => r['player_id'] != _currentUserId,
                orElse: () => allRows.first);
            final oppMove = RPSMove.values.firstWhere(
                (m) => m.name == (oppRow['move'] as String),
                orElse: () => RPSMove.rock);
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RPSRevealScreen(
                    currentUserId: _currentUserId,
                    currentUserName: 'You',
                    opponentId: partnerUserId,
                    opponentName: _otherName,
                    myMove: myMove,
                    opponentMove: oppMove,
                    popCount: 1,
                    chatAlreadyUnlocked: _chatUnlocked,
                    onChatUnlocked: onRpsUnlock,
                  ),
                )).then(refresh);
          } else {
            // Only I picked — resume on waiting screen.
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RPSWaitingScreen(
                    currentUserId: _currentUserId,
                    currentUserName: 'You',
                    opponentId: partnerUserId,
                    opponentName: _otherName,
                    sessionId: sessionId,
                    myMove: myMove,
                    popCount: 1,
                    chatAlreadyUnlocked: _chatUnlocked,
                    onChatUnlocked: onRpsUnlock,
                  ),
                )).then(refresh);
          }
        }
      } catch (e) {
        debugPrint('[RejoinRPS] error: $e — falling back to intro');
        if (!mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RPSIntroScreen(
                currentUserId: _currentUserId,
                currentUserName: 'You',
                opponentId: partnerUserId,
                opponentName: _otherName,
                sessionId: sessionId,
                popCount: 1,
                chatAlreadyUnlocked: _chatUnlocked,
                onChatUnlocked: onRpsUnlock,
              ),
            )).then(refresh);
      }
      return;
    }

    switch (gameType) {
      case 'word_search':
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordSearchSupabaseWrapper(
                matchId: widget.matchId,
                currentUserId: _currentUserId,
                partnerUserId: partnerUserId,
                partnerName: _otherName,
                onChatUnlocked: onUnlock,
                sessionId: sessionId,
                skipWelcome: isRejoin,
                chatAlreadyUnlocked: _chatUnlocked,
              ),
            )).then(refresh);
      case 'emoji_charades':
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmojiCharadesGameScreen(
                matchId: widget.matchId,
                currentUserId: _currentUserId,
                partnerUserId: partnerUserId,
                partnerName: _otherName,
                onChatUnlocked: onUnlock,
                sessionId: sessionId,
                skipIntro: isRejoin,
                chatAlreadyUnlocked: _chatUnlocked,
              ),
            )).then(refresh);
      case 'rps':
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RPSIntroScreen(
                currentUserId: _currentUserId,
                currentUserName: 'You',
                opponentId: partnerUserId,
                opponentName: _otherName,
                sessionId: sessionId,
                popCount: 1,
                chatAlreadyUnlocked: _chatUnlocked,
                onChatUnlocked: onRpsUnlock,
              ),
            )).then(refresh);
      default:
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameHubScreen(
                matchId: widget.matchId,
                currentUserId: _currentUserId,
                partnerUserId: partnerUserId,
                partnerName: _otherName,
                onChatUnlocked: onUnlock,
                chatAlreadyUnlocked: _chatUnlocked,
              ),
            )).then(refresh);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.day}/${dt.month}';
  }

  String get _otherName =>
      widget.otherProfile['first_name'] as String? ?? 'Match';

  String get _otherPhoto {
    final photos = widget.otherProfile['photos'];
    if (photos is List && photos.isNotEmpty) return photos[0] as String;
    return '';
  }

  // ── Report / Block ─────────────────────────────────────────────────────────
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF160C2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.flag_outlined, color: Color(0xFFFBBF24)),
              title: Text('Report $_otherName',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0xFFF87171)),
              title: Text('Block $_otherName',
                  style: const TextStyle(color: Color(0xFFF87171))),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.heart_broken_outlined,
                  color: Color(0xFFFF4D6D)),
              title: Text('Unmatch $_otherName',
                  style: const TextStyle(color: Color(0xFFFF4D6D))),
              onTap: () {
                Navigator.pop(context);
                _showUnmatchDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Unmatch ────────────────────────────────────────────────────────────────
  void _showUnmatchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0D3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Unmatch?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You will no longer be matched with $_otherName. '
          'All messages and game history will be deleted permanently.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              await _doUnmatch();
            },
            child: const Text(
              'Unmatch',
              style: TextStyle(
                  color: Color(0xFFFF4D6D), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doUnmatch() async {
    try {
      await _matchingService.deleteMatch(widget.matchId);
      if (!mounted) return;
      // Pop back to chats list — the match no longer exists
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not unmatch: $e'),
          backgroundColor: const Color(0xFFFF4D6D),
        ),
      );
    }
  }

  void _showReportDialog() {
    String? _selectedReason;
    final reasons = [
      'Inappropriate content',
      'Harassment or abuse',
      'Fake profile',
      'Spam',
      'Other',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF160C2A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            const Icon(Icons.flag_outlined, color: Color(0xFFFBBF24), size: 20),
            const SizedBox(width: 8),
            Text('Report $_otherName',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      groupValue: _selectedReason,
                      activeColor: const Color(0xFF6C3FE8),
                      title: Text(r,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14)),
                      onChanged: (v) => setS(() => _selectedReason = v),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
            TextButton(
              onPressed: _selectedReason == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _submitReport(_selectedReason!);
                    },
              child: const Text('Submit',
                  style: TextStyle(color: Color(0xFFFBBF24))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': _currentUserId,
        'reported_id': widget.otherProfile['id'],
        'match_id': widget.matchId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF160C2A),
          content: Text(
              'Report submitted. We\'ll review $_otherName\'s profile.',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF160C2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Icon(Icons.block, color: Color(0xFFF87171), size: 20),
          const SizedBox(width: 8),
          Text('Block $_otherName',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Text(
          'You won\'t see $_otherName\'s profile and they won\'t be able to message you. This cannot be undone.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
            },
            child:
                const Text('Block', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      await Supabase.instance.client.from('blocks').insert({
        'blocker_id': _currentUserId,
        'blocked_id': widget.otherProfile['id'],
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context); // go back to chats list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF160C2A),
          content: Text('$_otherName has been blocked.',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // ── Delete / unsend message ────────────────────────────────────────────────
  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    HapticFeedback.mediumImpact();
    final msgId = msg['id'] as String?;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF160C2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Emoji reaction row ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickEmojis
                    .map((e) => GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _toggleReaction(msg, e);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child:
                                  Text(e, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading:
                  const Icon(Icons.reply_rounded, color: Color(0xFF6C3FE8)),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white54),
              title: const Text('Copy text',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(
                    ClipboardData(text: msg['content'] as String? ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF1A1A1A),
                    content:
                        Text('Copied', style: TextStyle(color: Colors.white)),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (isMe && msgId != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
                title: const Text('Delete message',
                    style: TextStyle(color: Color(0xFFF87171))),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msgId);
                },
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String msgId) async {
    // Optimistic remove
    setState(() => _messages.removeWhere((m) => m['id'] == msgId));
    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', msgId)
          .eq('sender_id', _currentUserId);
    } catch (e) {
      // Reload if delete fails
      _loadMessages();
    }
  }

  // ── Reactions ──────────────────────────────────────────────────────────────
  void _toggleReaction(Map<String, dynamic> msg, String emoji) {
    final msgId = msg['id'] as String? ?? msg['created_at'] as String? ?? '';
    setState(() {
      final list = List<String>.from(_reactions[msgId] ?? []);
      if (list.contains(emoji)) {
        list.remove(emoji);
      } else {
        list.add(emoji);
      }
      _reactions[msgId] = list;
    });
    HapticFeedback.lightImpact();

    // Persist to Supabase if available (best-effort)
    _persistReaction(msg['id'] as String?, emoji);
  }

  Future<void> _persistReaction(String? msgId, String emoji) async {
    if (msgId == null) return;
    try {
      // Upsert — no error if table doesn't exist
      await Supabase.instance.client.from('message_reactions').upsert({
        'message_id': msgId,
        'user_id': _currentUserId,
        'emoji': emoji,
      });
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      // Disable the Scaffold's built-in resize so the gradient background
      // always covers the full screen (including behind the keyboard).
      // We push the content up manually via the Padding below.
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: MatchXPBackground(
        child: Padding(
          // Shift the entire content area above the keyboard.
          // When keyboard is hidden (keyboardHeight == 0), still pad by the
          // system nav bar height so the input bar is never hidden behind it
          // on Samsung devices and other phones with on-screen navigation bars.
          padding: EdgeInsets.only(
            bottom: math.max(
              keyboardHeight,
              MediaQuery.of(context).padding.bottom,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                  if (_scoresLoaded && _chatUnlocked)
                    _buildScoreboard(),
                  Expanded(child: _loading ? _buildLoader() : _buildMessageList()),
                  // Typing indicator sits just above reply banner / input
                  if (_isPartnerTyping) _buildTypingIndicator(),
                  if (_replyingTo != null) _buildReplyBanner(),
                  _buildInputBar(),
                ],
              ),
              // Scroll-to-bottom FAB
              if (_showScrollToBottom)
                Positioned(
                  bottom: 90,
                  right: 16,
                  child: _buildScrollToBottomButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Typing indicator row ───────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          if (_otherPhoto.isNotEmpty)
            ClipOval(
              child: Image.network(_otherPhoto,
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 22, height: 22)),
            )
          else
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
              ),
            ),
          const SizedBox(width: 8),
          const _TypingBubble(),
        ],
      ),
    );
  }

  // ── Scroll-to-bottom FAB ───────────────────────────────────────────────────
  Widget _buildScrollToBottomButton() {
    return GestureDetector(
      onTap: () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
        setState(() {
          _showScrollToBottom = false;
          _unreadWhileScrolled = 0;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1129),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white70, size: 24),
          ),
          if (_unreadWhileScrolled > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _unreadWhileScrolled > 9 ? '9+' : '$_unreadWhileScrolled',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              _otherPhoto.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _otherPhoto,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarFallback(),
                      ),
                    )
                  : _avatarFallback(),
            ],
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullProfileScreen(profile: widget.otherProfile),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                // ── Live online status ────────────────────────────────
                if (_isOnline == true)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (_lastSeenAt != null || _isOnline == false)
                  Text(
                    _formatOnlineStatus(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Game hub button
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              final partnerUserId = widget.otherProfile['id'] as String? ?? '';
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameHubScreen(
                      matchId: widget.matchId,
                      currentUserId: _currentUserId,
                      partnerUserId: partnerUserId,
                      partnerName: _otherName,
                      chatAlreadyUnlocked: _chatUnlocked,
                      onChatUnlocked: () {
                        if (mounted) setState(() => _chatUnlocked = true);
                      },
                      onGameSelected: _sendGameChallenge,
                    ),
                  )).then((_) {
                if (mounted) {
                  _restartMessageStream();
                  _refreshSessionStream();
                  _checkGameStatus();
                  _loadScores();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chatUnlocked
                    ? const Color(0xFF160C2A)
                    : const Color(0xFF6C3FE8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: _chatUnlocked
                    ? null
                    : Border.all(color: const Color(0xFF6C3FE8), width: 1),
              ),
              child: Icon(
                Icons.sports_esports,
                color: _chatUnlocked
                    ? const Color(0xFF6C3FE8)
                    : const Color(0xFF9D50BB),
                size: 20,
              ),
            ),
          ),
        ),
        // ── More menu (report / block) ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: _showMoreMenu,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF160C2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.more_vert, color: Colors.white70, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  // ── Scoreboard — collapsed pill + expanded card ───────────────────────────
  Widget _buildScoreboard() {
    final total = _myWins + _partnerWins;
    final myPct = total == 0 ? 0.5 : _myWins / total;
    final statusText = total == 0
        ? "It's tied! 🤝"
        : _myWins == _partnerWins
            ? "It's tied! 🤝"
            : _myWins > _partnerWins
                ? 'You\'re ahead! 🏆'
                : '$_otherName is ahead! 💪';

    // ── Collapsed pill ──────────────────────────────────────────────────────
    if (!_scoreboardExpanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _scoreboardExpanded = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0D3A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.5),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    'You $_myWins – $_partnerWins $_otherName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Fredoka One',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.45), size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Expanded card (no reset buttons — those live in ⋮ menu) ────────────
    return GestureDetector(
      onTap: () => setState(() => _scoreboardExpanded = false),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF160C2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.3),
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF6C3FE8).withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Title centred regardless of the collapse icon width
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFF6C3FE8), size: 14),
                  const SizedBox(width: 5),
                  Text('GAME SCOREBOARD',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
              // Collapse arrow pinned to the right
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.expand_less_rounded,
                    color: Colors.white.withValues(alpha: 0.35), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(children: [
              Text('You',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11)),
              const SizedBox(height: 2),
              Text('$_myWins',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Fredoka One')),
            ]),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                const Text('VS',
                    style: TextStyle(
                        color: Color(0xFF6C3FE8),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (_, constraints) {
                    final barWidth = constraints.maxWidth;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            width: barWidth * myPct,
                            color: Colors.transparent,
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            width: barWidth * (1 - myPct),
                            color: Colors.transparent,
                          ),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ]),
            )),
            Column(children: [
              Text(_otherName,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$_partnerWins',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Fredoka One')),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
        ),
      ),
      child: Center(
        child: Text(
          _otherName.isNotEmpty ? _otherName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() => const _ChatShimmer();

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
              ).createShader(bounds),
              child: const Icon(Icons.favorite, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              "You matched with $_otherName!",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello 👋',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Build a flat list of widgets: date separators + message bubbles
    final widgets = <Widget>[];
    String? lastDateLabel;

    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final isMe = msg['sender_id'] == _currentUserId;

      // ── Date separator ──────────────────────────────────────────────────
      final dateLabel = _getDateLabel(msg['created_at'] as String?);
      if (dateLabel != null && dateLabel != lastDateLabel) {
        widgets.add(_buildDateSeparator(dateLabel));
        lastDateLabel = dateLabel;
      }

      // ── Grouping ────────────────────────────────────────────────────────
      final isLastInGroup =
          i == _messages.length - 1 || !_isSameGroup(msg, _messages[i + 1]);
      final isGrouped = i > 0 && _isSameGroup(_messages[i - 1], msg);

      widgets.add(_buildBubble(msg, isMe, isLastInGroup, isGrouped));
    }

    return ListView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: widgets,
    );
  }

  static const _gameRequestTag = '[GAME_REQUEST]';

  // ── Full-screen photo viewer ───────────────────────────────────────────────
  void _openFullScreenPhoto(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (photoCtx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(photoCtx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C3FE8), strokeWidth: 2));
                },
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white38,
                    size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Message content renderer ───────────────────────────────────────────────
  Widget _buildMessageContent(String content, bool isMe) {
    // ── Image ──
    if (content.startsWith('[image]')) {
      final url = content.substring(7); // strip '[image]'
      return GestureDetector(
        onTap: () => _openFullScreenPhoto(url),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          child: Image.network(
            url,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 180,
                color: const Color(0xFF2A2A2A),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C3FE8),
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (ctx, _, __) => Container(
              width: 220,
              height: 80,
              color: const Color(0xFF2A2A2A),
              child: const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: Colors.white38, size: 32),
              ),
            ),
          ),
        ),
      );
    }

    // ── Video ──
    if (content.startsWith('[video]')) {
      final url = content.substring(7);
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open video'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 160,
                color: const Color(0xFF160C2A),
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.white24, size: 48),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
      );
    }

    // ── Voice ──
    if (content.startsWith('[voice]')) {
      final url = content.substring(7);
      // Use a unique key based on content URL so each bubble has its own key
      final vKey = url.hashCode.toString();
      final isThisPlaying = _playingVoiceKey == vKey && _isVoicePlaying;
      final isThisActive = _playingVoiceKey == vKey;

      // Fixed waveform bar heights for visual variety
      const barHeights = [
        10.0,
        16.0,
        22.0,
        14.0,
        26.0,
        18.0,
        12.0,
        20.0,
        24.0,
        16.0,
        22.0,
        14.0,
        18.0,
        26.0,
        12.0,
        20.0,
        16.0,
        22.0,
        14.0,
        18.0,
      ];
      final progressFraction =
          (isThisActive && _voiceDuration.inMilliseconds > 0)
              ? _voicePosition.inMilliseconds / _voiceDuration.inMilliseconds
              : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play / Pause button
            GestureDetector(
              onTap: () => _playVoice(url, vKey),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFF6C3FE8).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isThisPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: isMe ? Colors.white : const Color(0xFF9D70FF),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Waveform bars
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(barHeights.length, (i) {
                final active = (i / barHeights.length) < progressFraction;
                return Container(
                  width: 3,
                  height: barHeights[i] * 0.65,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? (isMe ? Colors.white : const Color(0xFF6C3FE8))
                        : (isMe
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.22)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(width: 10),
            // Duration / position
            Text(
              isThisActive && _voiceDuration.inSeconds > 0
                  ? _formatDuration(_voicePosition)
                  : 'Voice',
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.white60,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    // ── Plain text ──
    return Text(
      content,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        height: 1.4,
      ),
    );
  }

  Widget _buildBubble(
      Map<String, dynamic> msg, bool isMe, bool showTime, bool isGrouped) {
    final content = msg['content'] as String? ?? '';

    // ── Structured game messages ────────────────────────────────────────────
    final msgType = msg['message_type'] as String? ?? 'text';
    if (msgType == 'game_result') return _buildGameResultBubble(msg, showTime);
    if (msgType == 'game_challenge')
      return _buildGameChallengeBubble(msg, isMe, showTime);

    // ── Skip legacy game-request tag messages ───────────────────────────────
    if (content.startsWith(_gameRequestTag)) return const SizedBox.shrink();

    final isRead = msg['is_read'] == true;
    final msgKey = msg['id'] as String? ?? msg['created_at'] as String? ?? '';
    final myReactions = List<String>.from(_reactions[msgKey] ?? []);

    // Reply context embedded in this message
    final replyContent = msg['reply_to_content'] as String?;
    final replySender = msg['reply_to_sender'] as String?;

    // Assign a stable GlobalKey so reply-strips can scroll here
    _messageKeys.putIfAbsent(msgKey, () => GlobalKey());

    return Padding(
      // Grouped messages (same sender, <60s apart) get tighter top spacing
      padding: EdgeInsets.only(top: isGrouped ? 1.0 : 8.0),
      child: GestureDetector(
        key: _messageKeys[msgKey],
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // ── Reply quote strip ──────────────────────────────────────────
              if (replyContent != null && replySender != null)
                GestureDetector(
                  onTap: () => _scrollToMessageByContent(replyContent),
                  child: Container(
                    margin: EdgeInsets.only(
                      bottom: 2,
                      left: isMe ? 48 : 0,
                      right: isMe ? 0 : 48,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: Color(0xFF6C3FE8), width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replySender,
                          style: const TextStyle(
                              color: Color(0xFF9D70FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyContent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Message bubble ─────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                // Images/videos need no inner padding; text messages do
                padding: (content.startsWith('[image]') ||
                        content.startsWith('[video]') ||
                        content.startsWith('[voice]'))
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                decoration: BoxDecoration(
                  gradient: isMe &&
                          !content.startsWith('[image]') &&
                          !content.startsWith('[video]')
                      ? const LinearGradient(
                          colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                        )
                      : null,
                  color: (isMe &&
                          !content.startsWith('[image]') &&
                          !content.startsWith('[video]'))
                      ? null
                      : content.startsWith('[image]') ||
                              content.startsWith('[video]')
                          ? Colors.transparent
                          : const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                ),
                child: _buildMessageContent(content, isMe),
              ),

              // ── Reactions strip ────────────────────────────────────────────
              if (myReactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: myReactions
                        .map((e) => GestureDetector(
                              onTap: () => _toggleReaction(msg, e),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C3FE8)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF6C3FE8)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ))
                        .toList(),
                  ),
                ),

              // ── Timestamp + read receipt ───────────────────────────────────
              if (showTime)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg['created_at'] as String?),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 13,
                          color: isRead
                              ? const Color(0xFF00D4AA)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ), // end Padding (grouping top margin)
    );
  }

  // ── Game challenge bubble (message_type = 'game_challenge') ──────────────
  static const _kInviteExpiry = Duration(hours: 24);

  Widget _buildGameChallengeBubble(
      Map<String, dynamic> msg, bool isMe, bool showTime) {
    final meta = (msg['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final gameType = meta['game_type'] as String? ?? 'word_search';
    final sessionId = meta['session_id'] as String?;
    final metaStatus = meta['status'] as String? ?? 'pending';

    // 'completed' in message meta is a terminal state written by complete_game_session —
    // trust it over _sessionStates which can be stale (game_sessions not published).
    final sessionEntry = sessionId != null ? _sessionStates[sessionId] : null;
    final sessionStateStatus = sessionEntry?['status'] as String?;
    final liveStatus = metaStatus == 'completed'
        ? 'completed'
        : (sessionStateStatus ?? metaStatus);

    // Sessions expire after _kInviteExpiry — purely visual, no DB change.
    // Covers both pending invites and active (in-progress) games.
    final createdAt =
        DateTime.tryParse(msg['created_at'] as String? ?? '')?.toUtc();
    final isExpired = (liveStatus == 'pending' || liveStatus == 'active') &&
        createdAt != null &&
        DateTime.now().toUtc().difference(createdAt) > _kInviteExpiry;

    final gameName = switch (gameType) {
      'word_search' => 'Word Search',
      'emoji_charades' => 'Emoji Charades',
      'rps' => 'Rock Paper Scissors',
      _ => gameType,
    };
    final gameEmoji = switch (gameType) {
      'word_search' => '🔍',
      'emoji_charades' => '🎭',
      'rps' => '✂️',
      _ => '🎮',
    };

    final canAccept =
        !isMe && liveStatus == 'pending' && sessionId != null && !isExpired;
    // 'active'    = both players accepted / both submitted their puzzles — normal rejoin
    // 'submitted' = one player already submitted their puzzle (Word Search / EC)
    // 'pending' + isMe = challenger sent the challenge and can enter immediately
    //                    (new flow: sender plays before receiver accepts)
    final canRejoin = ((liveStatus == 'pending' && isMe) ||
            liveStatus == 'active' ||
            liveStatus == 'submitted') &&
        sessionId != null &&
        !isExpired;
    final isDone = liveStatus == 'completed' || isExpired;

    // Once a game is finished or expired, hide it entirely — no clutter in chat.
    if (isDone) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: canAccept
                ? () => _acceptChallenge(msg)
                : canRejoin
                    ? () => _navigateToGame(gameType, sessionId, isRejoin: true)
                    : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D0F60), Color(0xFF1A0D3A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.75),
                  width: 1.5,
                ),
                boxShadow: [
                  // tight inner glow
                  BoxShadow(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.65),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                  // mid halo
                  BoxShadow(
                    color: const Color(0xFF9D50BB).withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  // outer bloom
                  BoxShadow(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.18),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gameEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(gameName,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.4,
                      )),
                ],
              ),
            ),
          ),
          if (showTime) ...[
            const SizedBox(height: 3),
            Text(
              _formatTime(msg['created_at'] as String?),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  // ── Game result bubble (message_type = 'game_result') ─────────────────────
  Widget _buildGameResultBubble(Map<String, dynamic> msg, bool showTime) {
    // Game result messages (including the "Chat unlocked" unlock moment) are
    // intentionally hidden — the chat just opens cleanly after the game ends.
    return const SizedBox.shrink();
  }

  // ── Reply banner (above input bar) ────────────────────────────────────────
  Widget _buildReplyBanner() {
    final replyContent = _replyingTo!['content'] as String? ?? '';
    final replySender =
        _replyingTo!['sender_id'] == _currentUserId ? 'You' : _otherName;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF160C2A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replySender,
                  style: const TextStyle(
                    color: Color(0xFF9D70FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyContent.length > 80
                      ? '${replyContent.substring(0, 80)}…'
                      : replyContent,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: Colors.white.withValues(alpha: 0.4), size: 18),
            onPressed: () => setState(() => _replyingTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Voice recording ────────────────────────────────────────────────────────
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordingPath;

  Future<void> _startVoiceRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: _recordingPath!,
      );
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null && _recordSeconds > 0) {
        await _sendMediaMessage(File(path), 'voice');
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelVoiceRecording() {
    _recordTimer?.cancel();
    _recordTimer = null;
    _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  String get _recordingDuration {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Media picker bottom sheet ──────────────────────────────────────────────
  void _showMediaPicker() {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Photo (multi-select)
                    _buildMediaOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Photo',
                      color: const Color(0xFF7B6CF6),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final List<XFile> files =
                            await picker.pickMultiImage(imageQuality: 85);
                        for (final xf in files) {
                          if (!mounted) break;
                          await _sendMediaMessage(File(xf.path), 'image');
                        }
                      },
                    ),
                    // Camera
                    _buildMediaOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF00C2A8),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final XFile? file = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 85,
                        );
                        if (file != null && mounted) {
                          _sendMediaMessage(File(file.path), 'image');
                        }
                      },
                    ),
                    // Video
                    _buildMediaOption(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      color: const Color(0xFFFF6B8A),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final XFile? file = await picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        if (file != null && mounted) {
                          _sendMediaMessage(File(file.path), 'video');
                        }
                      },
                    ),
                    // Voice note
                    _buildMediaOption(
                      icon: Icons.mic_rounded,
                      label: 'Voice',
                      color: const Color(0xFFFF9800),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startVoiceRecording();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(File file, String type) async {
    try {
      final ext = type == 'video'
          ? 'mp4'
          : type == 'voice'
              ? 'm4a'
              : 'jpg';
      final fileName =
          '${type}_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('user-photos')
          .upload(fileName, file);

      final url = Supabase.instance.client.storage
          .from('user-photos')
          .getPublicUrl(fileName);

      // Send the URL as a message with a type prefix so the UI can render it
      final content = '[$type]$url';

      final optimistic = {
        'match_id': widget.matchId,
        'sender_id': _currentUserId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'id': null,
      };

      setState(() {
        _messages.add(optimistic);
        if (!_chatUnlocked) _chatUnlocked = true;
      });
      _scrollToBottom();

      await _matchingService.sendMessage(widget.matchId, content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send media: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    if (!_chatUnlocked) return _buildLockedBar();

    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
              top: BorderSide(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _cancelVoiceRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.red, size: 14),
                    const SizedBox(width: 8),
                    const Text('Recording...',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const Spacer(),
                    Text(
                      _recordingDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _stopAndSendVoice,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0B11),
        border: Border(
          top: BorderSide(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          GestureDetector(
            onTap: _showMediaPicker,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF160C2A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.25),
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (_) => _onTypingChanged(),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: hasText
                        ? const LinearGradient(
                            colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                          )
                        : null,
                    color: hasText ? null : const Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                    boxShadow: hasText
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6C3FE8)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: hasText ? Colors.white : Colors.white24,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Locked bar (shown before game is completed) ────────────────────────────

  /// Scans _messages for a game_challenge card whose session is still
  /// active or submitted (i.e. in-progress, not expired, not completed).
  /// Returns {gameType, sessionId} if found, or null.
  ({String gameType, String sessionId})? _findRejoinableChallenge() {
    for (final msg in _messages.reversed) {
      if (msg['message_type'] != 'game_challenge') continue;
      final meta = (msg['meta'] as Map?)?.cast<String, dynamic>() ?? {};
      final sessionId = meta['session_id'] as String?;
      if (sessionId == null) continue;
      final metaStatus = meta['status'] as String? ?? 'pending';
      final sessionStateStatus =
          (_sessionStates[sessionId]?['status'] as String?);
      final liveStatus = metaStatus == 'completed'
          ? 'completed'
          : (sessionStateStatus ?? metaStatus);
      if (liveStatus == 'completed') continue;
      // Check expiry
      final createdAt =
          DateTime.tryParse(msg['created_at'] as String? ?? '')?.toUtc();
      final isExpired = (liveStatus == 'pending' ||
              liveStatus == 'active' ||
              liveStatus == 'submitted') &&
          createdAt != null &&
          DateTime.now().toUtc().difference(createdAt) > _kInviteExpiry;
      if (isExpired) continue;
      final isSentByMe = msg['sender_id'] == _currentUserId;
      // Active/submitted = anyone can rejoin.
      // Pending + I sent it = challenger re-enters their own game before
      // receiver accepts (new sender-plays-first flow).
      if (liveStatus == 'active' ||
          liveStatus == 'submitted' ||
          (liveStatus == 'pending' && isSentByMe)) {
        final gameType = meta['game_type'] as String? ?? 'word_search';
        return (gameType: gameType, sessionId: sessionId);
      }
    }
    return null;
  }

  Widget _buildLockedBar() {
    // While game status is still loading, show a soft loading state so
    // users who already completed the game don't see a locked flash.
    if (_gameStatusLoading) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
              top: BorderSide(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: Colors.white.withValues(alpha: 0.3),
                strokeWidth: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Text('Checking game status…',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
          ],
        ),
      );
    }

    final partnerUserId = widget.otherProfile['id'] as String? ?? '';

    // If there's already an in-progress game, offer a Resume button instead
    // of sending the user to GameHub to start a new one.
    final rejoinable = _findRejoinableChallenge();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0B11),
        border: Border(
          top: BorderSide(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_esports_rounded,
                  size: 14, color: Color(0xFF6C3FE8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  rejoinable != null
                      ? 'A game is in progress — pick up where you left off 🎮'
                      : 'Play a game to unlock chat 🎮',
                  style:
                      const TextStyle(color: Color(0xFF6C3FE8), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              if (rejoinable != null) {
                // Jump back into the existing game at the correct step.
                _navigateToGame(rejoinable.gameType, rejoinable.sessionId,
                    isRejoin: true);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameHubScreen(
                      matchId: widget.matchId,
                      currentUserId: _currentUserId,
                      partnerUserId: partnerUserId,
                      partnerName: _otherName,
                      onChatUnlocked: () {
                        if (mounted) setState(() => _chatUnlocked = true);
                      },
                    ),
                  ),
                ).then((_) {
                    // Refresh messages + sessions so the game_challenge card
                    // created by GameHub's RPC appears in _messages.
                    // Without this, _findRejoinableChallenge returns null and
                    // the locked bar keeps showing "Play a Game" instead of
                    // "Resume Game", trapping the user in a duplicate-guard loop.
                    if (mounted) {
                      _restartMessageStream();
                      _refreshSessionStream();
                      _checkGameStatus();
                    }
                  });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    rejoinable != null
                        ? Icons.play_arrow_rounded
                        : Icons.sports_esports_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rejoinable != null ? 'Resume Game' : 'Play a Game',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator bubble ───────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3;
              final t = (_ctrl.value - delay).clamp(0.0, 1.0);
              final opacity = 0.3 + 0.7 * (math.sin(t * 2 * math.pi) + 1) / 2;
              return Container(
                margin: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Shimmer placeholder (shown while messages are loading) ────────────────────
class _ChatShimmer extends StatefulWidget {
  const _ChatShimmer();

  @override
  State<_ChatShimmer> createState() => _ChatShimmerState();
}

class _ChatShimmerState extends State<_ChatShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor = Color.lerp(
          const Color(0xFF1A1129),
          const Color(0xFF333333),
          _anim.value,
        )!;
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          itemBuilder: (_, i) {
            final isMe = i.isEven;
            final width = 100.0 + (i % 3) * 60.0;
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                width: width,
                height: 40,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
