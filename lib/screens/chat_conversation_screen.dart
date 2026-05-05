import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../services/matching_service.dart';
import '../games/game_hub_screen.dart';
import '../games/word_search/word_search_service.dart';
import '../games/word_search/word_search_models.dart';

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
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  // Game gate — chat is locked until both players solve the word search
  bool _chatUnlocked = false;
  bool _gameStatusLoading = true;
  RealtimeChannel? _gameChannel;

  // Scoreboard
  int _myWins      = 0;
  int _partnerWins = 0;
  bool _scoresLoaded = false;
  RealtimeChannel? _scoreChannel;

  // ── Reply / quote ──────────────────────────────────────────────────────────
  /// The message being replied to (null = no active reply)
  Map<String, dynamic>? _replyingTo;

  // ── Reactions ──────────────────────────────────────────────────────────────
  /// Map of message id → list of emoji strings reacted by current user
  /// (stored in-memory; persisted via a `message_reactions` table if available)
  final Map<String, List<String>> _reactions = {};

  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];


  @override
  void initState() {
    super.initState();
    // Tell the global listener which chat is open so it suppresses that notif
    ChatConversationScreen.activeChatMatchId = widget.matchId;
    _checkGameStatus();
    _loadMessages();
    _subscribeToMessages();
    _loadScores();
  }

  @override
  void dispose() {
    // Clear the active chat tracking
    if (ChatConversationScreen.activeChatMatchId == widget.matchId) {
      ChatConversationScreen.activeChatMatchId = null;
    }
    _channel?.unsubscribe();
    _matchingService.unsubscribeFromChat(widget.matchId);
    if (_gameChannel != null) _gameService.unsubscribe(_gameChannel!);
    if (_scoreChannel != null) _gameService.unsubscribe(_scoreChannel!);
    _messageController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// Check whether both players have solved the word search.
  Future<void> _checkGameStatus() async {
    try {
      final snapshot = await _gameService.getSnapshot(
        matchId: widget.matchId,
        myUserId: _currentUserId,
      );
      final unlocked = snapshot.phase == MatchGamePhase.bothSolved;
      if (mounted) setState(() {
        if (unlocked) _chatUnlocked = true;
        _gameStatusLoading = false;
      });

      _gameChannel = _gameService.subscribeToMatch(
        widget.matchId,
        () async {
          final updated = await _gameService.getSnapshot(
            matchId: widget.matchId,
            myUserId: _currentUserId,
          );
          if (mounted && updated.phase == MatchGamePhase.bothSolved) {
            setState(() => _chatUnlocked = true);
          }
        },
        channelSuffix: 'chat',
      );
    } catch (e) {
      debugPrint('⚠️ Game status check failed: $e — defaulting to unlocked');
      if (mounted) setState(() { _chatUnlocked = true; _gameStatusLoading = false; });
    }
  }

  Future<void> _resetGame() async {
    try {
      await _gameService.resetGame(widget.matchId);
      if (!mounted) return;
      await _checkGameStatus();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not reset game — check Supabase DELETE policy.')));
      }
    }
  }

  Future<void> _resetAll() async {
    try {
      await _gameService.resetAll(widget.matchId);
      if (!mounted) return;
      setState(() {
        _myWins      = 0;
        _partnerWins = 0;
      });
      await _checkGameStatus();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not reset — check Supabase DELETE policy.')));
      }
    }
  }

  Future<void> _confirmReset({
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
          style: const TextStyle(color: Colors.white,
            fontFamily: 'Fredoka One', fontSize: 17)),
        content: Text(body,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
            fontFamily: 'Fredoka', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                fontFamily: 'Fredoka One'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
              style: TextStyle(color: Color(0xFFF87171),
                fontFamily: 'Fredoka One'))),
        ],
      ),
    );
    if (ok == true) await action();
  }

  Future<void> _loadScores() async {
    try {
      final partnerUserId = widget.otherProfile['id'] as String? ?? '';
      final scores = await _gameService.getScores(
        matchId:       widget.matchId,
        myUserId:      _currentUserId,
        partnerUserId: partnerUserId,
      );
      if (!mounted) return;
      setState(() {
        _myWins      = scores['myWins'] ?? 0;
        _partnerWins = scores['partnerWins'] ?? 0;
        _scoresLoaded = true;
      });

      _scoreChannel = _gameService.subscribeToScores(widget.matchId, () async {
        final updated = await _gameService.getScores(
          matchId:       widget.matchId,
          myUserId:      _currentUserId,
          partnerUserId: partnerUserId,
        );
        if (mounted) setState(() {
          _myWins      = updated['myWins'] ?? 0;
          _partnerWins = updated['partnerWins'] ?? 0;
        });
      });
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    final messages = await _matchingService.getMessages(widget.matchId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
      final hasRealMessages = messages.any((m) =>
          !(m['content'] as String? ?? '').startsWith(_gameRequestTag));
      if (hasRealMessages) _chatUnlocked = true;
    });
    _scrollToBottom();
    _matchingService.markMessagesAsRead(widget.matchId);
  }

  void _subscribeToMessages() {
    _channel = _matchingService.subscribeToMessages(
      widget.matchId,
      (msg) {
        if (!mounted) return;

        final senderId = msg['sender_id'] as String?;
        final content = msg['content'] as String?;

        final msgId = msg['id'] as String?;
        bool alreadyExists = false;

        if (msgId != null) {
          final idxToUpgrade = _messages.indexWhere((m) =>
              m['id'] == null &&
              m['sender_id'] == senderId &&
              m['content'] == content);
          if (idxToUpgrade != -1) {
            setState(() => _messages[idxToUpgrade] =
                {..._messages[idxToUpgrade], ...msg});
            alreadyExists = true;
          } else {
            alreadyExists = _messages.any((m) => m['id'] == msgId);
          }
        } else {
          if (senderId == _currentUserId) {
            alreadyExists = _messages.any((m) =>
                m['id'] == null &&
                m['sender_id'] == senderId &&
                m['content'] == content);
          }
        }

        if (!alreadyExists) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }

        if (senderId != _currentUserId) {
          _matchingService.markMessagesAsRead(widget.matchId);
        }
      },
      onUpdate: (updatedMsg) {
        if (!mounted) return;
        final id = updatedMsg['id'];
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == id);
          if (idx != -1) {
            _messages[idx] = {..._messages[idx], ...updatedMsg};
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

    // Build the message — attach reply metadata if replying
    final Map<String, dynamic> optimistic = {
      'match_id': widget.matchId,
      'sender_id': _currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
    };

    if (_replyingTo != null) {
      optimistic['reply_to_content'] = _replyingTo!['content'];
      optimistic['reply_to_sender'] =
          _replyingTo!['sender_id'] == _currentUserId ? 'You' : _otherName;
    }

    setState(() {
      _messages.add(optimistic);
      _replyingTo = null; // clear reply context
    });
    _scrollToBottom();

    // Persist
    _matchingService.sendMessage(widget.matchId, text);
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
      backgroundColor: const Color(0xFF1A1A1A),
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
              leading: const Icon(Icons.flag_outlined, color: Color(0xFFFBBF24)),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            const Icon(Icons.flag_outlined, color: Color(0xFFFBBF24), size: 20),
            const SizedBox(width: 8),
            Text('Report $_otherName',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => RadioListTile<String>(
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
            )).toList(),
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
          backgroundColor: const Color(0xFF1A1A1A),
          content: Text('Report submitted. We\'ll review $_otherName\'s profile.',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
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
            child: const Text('Block',
                style: TextStyle(color: Color(0xFFF87171))),
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
          backgroundColor: const Color(0xFF1A1A1A),
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
      backgroundColor: const Color(0xFF1A1A1A),
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
                children: _quickEmojis.map((e) => GestureDetector(
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
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded,
                  color: Color(0xFF6C3FE8)),
              title: const Text('Reply',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded,
                  color: Colors.white54),
              title: const Text('Copy text',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(
                    text: msg['content'] as String? ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF1A1A1A),
                    content: Text('Copied',
                        style: TextStyle(color: Colors.white)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_scoresLoaded && (_myWins > 0 || _partnerWins > 0))
            _buildScoreboard(),
          Expanded(child: _loading ? _buildLoader() : _buildMessageList()),
          // Reply banner sits just above the input bar
          if (_replyingTo != null) _buildReplyBanner(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
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
          Column(
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
              Text(
                'Tap to view profile',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
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
              final partnerName   = _otherName;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameHubScreen(
                    matchId:        widget.matchId,
                    currentUserId:  _currentUserId,
                    partnerUserId:  partnerUserId,
                    partnerName:    partnerName,
                    onChatUnlocked: () {
                      if (mounted) setState(() => _chatUnlocked = true);
                    },
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _chatUnlocked
                    ? const Color(0xFF1A1A1A)
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
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.more_vert,
                  color: Colors.white70, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreboard() {
    final total = _myWins + _partnerWins;
    final myPct = total == 0 ? 0.5 : _myWins / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6C3FE8).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FE8).withValues(alpha: 0.10),
            blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.emoji_events_rounded,
              color: Color(0xFF6C3FE8), size: 14),
          const SizedBox(width: 5),
          Text('WORD SEARCH SCOREBOARD',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(children: [
            Text('You',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: 2),
            Text('$_myWins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32, fontWeight: FontWeight.w900,
                fontFamily: 'Fredoka One')),
          ]),

          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              const Text('VS',
                style: TextStyle(color: Color(0xFF6C3FE8),
                  fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: (MediaQuery.of(context).size.width - 32 - 32 - 96) * myPct,
                      color: const Color(0xFF6C3FE8),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: (MediaQuery.of(context).size.width - 32 - 32 - 96) * (1 - myPct),
                      color: const Color(0xFF9D50BB),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                total == 0 ? 'No games yet' :
                _myWins == _partnerWins ? "It's tied! 🤝" :
                _myWins > _partnerWins ? 'You\'re ahead! 🏆' : '$_otherName is ahead! 💪',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10),
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
                fontSize: 32, fontWeight: FontWeight.w900,
                fontFamily: 'Fredoka One')),
          ]),
        ]),

        const SizedBox(height: 8),

        GestureDetector(
          onTap: () {
            final partnerUserId = widget.otherProfile['id'] as String? ?? '';
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => GameHubScreen(
                matchId:       widget.matchId,
                currentUserId: _currentUserId,
                partnerUserId: partnerUserId,
                partnerName:   _otherName,
                onChatUnlocked: () {
                  if (mounted) setState(() => _chatUnlocked = true);
                },
              ),
            )).then((_) => _loadScores());
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6C3FE8).withValues(alpha: 0.3)),
            ),
            child: const Text('🎮  Play Again',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6C3FE8),
                fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(height: 8),

        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _confirmReset(
                title: 'Reset game?',
                body: 'Deletes the current active puzzle so both players can start a new game. Scores are kept.',
                action: _resetGame,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B0D0D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF5C1A1A)),
                ),
                child: const Text('🔄  Reset game',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _confirmReset(
                title: 'Reset everything?',
                body: 'Deletes the active game AND all score history for this match. This cannot be undone.',
                action: _resetAll,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B0D0D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF5C1A1A)),
                ),
                child: const Text('🗑  Reset all',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ]),
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

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF6C3FE8)),
    );
  }

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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg['sender_id'] == _currentUserId;
        final isLastInGroup = index == _messages.length - 1 ||
            _messages[index + 1]['sender_id'] != msg['sender_id'];
        return _buildBubble(msg, isMe, isLastInGroup);
      },
    );
  }

  static const _gameRequestTag = '[GAME_REQUEST]';

  // ── Message content renderer ───────────────────────────────────────────────
  Widget _buildMessageContent(String content, bool isMe) {
    // ── Image ──
    if (content.startsWith('[image]')) {
      final url = content.substring(7); // strip '[image]'
      return ClipRRect(
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
                color: const Color(0xFF1A1A1A),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded,
                color: isMe ? Colors.white : const Color(0xFF9D70FF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Voice message',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontSize: 14,
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

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe, bool showTime) {
    final content = msg['content'] as String? ?? '';

    if (content.startsWith(_gameRequestTag)) {
      return _buildGameRequestBubble(msg, isMe, showTime);
    }

    final isRead = msg['is_read'] == true;
    final msgKey = msg['id'] as String? ?? msg['created_at'] as String? ?? '';
    final myReactions = List<String>.from(_reactions[msgKey] ?? []);

    // Reply context embedded in this message
    final replyContent = msg['reply_to_content'] as String?;
    final replySender  = msg['reply_to_sender'] as String?;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // ── Reply quote strip ──────────────────────────────────────────
            if (replyContent != null && replySender != null)
              Container(
                margin: EdgeInsets.only(
                  bottom: 2,
                  left: isMe ? 48 : 0,
                  right: isMe ? 0 : 48,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                gradient: isMe && !content.startsWith('[image]') &&
                          !content.startsWith('[video]')
                    ? const LinearGradient(
                        colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                      )
                    : null,
                color: (isMe && !content.startsWith('[image]') &&
                        !content.startsWith('[video]'))
                    ? null
                    : content.startsWith('[image]') ||
                      content.startsWith('[video]')
                        ? Colors.transparent
                        : const Color(0xFF1E1E1E),
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
                  children: myReactions.map((e) => GestureDetector(
                    onTap: () => _toggleReaction(msg, e),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C3FE8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF6C3FE8)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(e,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  )).toList(),
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
    );
  }

  // ── Game request bubble ────────────────────────────────────────────────────
  Widget _buildGameRequestBubble(
      Map<String, dynamic> msg, bool isMe, bool showTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_rounded,
                  color: Color(0xFF6C3FE8), size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isMe
                      ? 'You sent a game challenge! 🎮'
                      : '$_otherName challenged you to a game! 🎮',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reply banner (above input bar) ────────────────────────────────────────
  Widget _buildReplyBanner() {
    final replyContent = _replyingTo!['content'] as String? ?? '';
    final replySender = _replyingTo!['sender_id'] == _currentUserId
        ? 'You'
        : _otherName;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
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
              color: const Color(0xFF6C3FE8),
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
                    // Photo
                    _buildMediaOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Photo',
                      color: const Color(0xFF6C3FE8),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final XFile? file = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (file != null && mounted) {
                          _sendMediaMessage(File(file.path), 'image');
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
                    // Game
                    _buildMediaOption(
                      icon: Icons.sports_esports_rounded,
                      label: 'Game',
                      color: const Color(0xFF9D50BB),
                      onTap: () {
                        Navigator.pop(ctx);
                        final partnerUserId =
                            widget.otherProfile['id'] as String? ?? '';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameHubScreen(
                              matchId: widget.matchId,
                              currentUserId: _currentUserId,
                              partnerUserId: partnerUserId,
                              partnerName: _otherName,
                              onChatUnlocked: () {
                                if (mounted) {
                                  setState(() => _chatUnlocked = true);
                                }
                              },
                            ),
                          ),
                        );
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
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
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
      final ext = type == 'video' ? 'mp4' : type == 'voice' ? 'm4a' : 'jpg';
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
          color: const Color(0xFF0A0A0A),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _cancelVoiceRecording,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
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
                    const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                    const SizedBox(width: 8),
                    const Text('Recording...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const Spacer(),
                    Text(
                      _recordingDuration,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
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
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF6C3FE8).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                controller: _messageController,
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
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Locked bar (shown before game is completed) ────────────────────────────
  Widget _buildLockedBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded,
                  size: 14, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(width: 6),
              Text(
                'Play a word search to unlock chat',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final partnerUserId =
                  widget.otherProfile['id'] as String? ?? '';
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
              );
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_esports_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Play Word Search',
                    style: TextStyle(
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
