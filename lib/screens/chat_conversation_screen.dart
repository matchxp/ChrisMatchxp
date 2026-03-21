import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    super.dispose();
  }

  /// Check whether both players have solved the word search.
  /// Also subscribes to real-time updates so the input bar unlocks automatically.
  Future<void> _checkGameStatus() async {
    try {
      final snapshot = await _gameService.getSnapshot(
        matchId: widget.matchId,
        myUserId: _currentUserId,
      );
      final unlocked = snapshot.phase == MatchGamePhase.bothSolved;
      if (mounted) setState(() { _chatUnlocked = unlocked; _gameStatusLoading = false; });

      // Subscribe so the input bar unlocks the moment both players finish
      _gameChannel = _gameService.subscribeToMatch(widget.matchId, () async {
        final updated = await _gameService.getSnapshot(
          matchId: widget.matchId,
          myUserId: _currentUserId,
        );
        if (mounted && updated.phase == MatchGamePhase.bothSolved) {
          setState(() => _chatUnlocked = true);
        }
      });
    } catch (e) {
      // If the game table doesn't exist yet, default to unlocked so chat still works
      debugPrint('⚠️ Game status check failed: $e — defaulting to unlocked');
      if (mounted) setState(() { _chatUnlocked = true; _gameStatusLoading = false; });
    }
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

      // Subscribe for live score updates
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
    } catch (_) {
      // Scores table may not exist yet — silently skip
    }
  }

  Future<void> _loadMessages() async {
    final messages = await _matchingService.getMessages(widget.matchId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
      // If they've already been chatting, bypass the game gate entirely
      if (messages.isNotEmpty) _chatUnlocked = true;
    });
    _scrollToBottom();
    // Mark incoming messages as read now that the chat is open
    _matchingService.markMessagesAsRead(widget.matchId);
  }

  void _subscribeToMessages() {
    _channel = _matchingService.subscribeToMessages(
      widget.matchId,
      (msg) {
        if (!mounted) return;

        final senderId = msg['sender_id'] as String?;
        final content = msg['content'] as String?;

        // Deduplicate: if we already have this message (optimistic or real), skip it
        final alreadyExists = _messages.any((m) =>
            m['sender_id'] == senderId && m['content'] == content);

        if (!alreadyExists) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }

        // Mark as read immediately when receiving in open chat
        if (senderId != _currentUserId) {
          _matchingService.markMessagesAsRead(widget.matchId);
        }
      },
      onUpdate: (updatedMsg) {
        // Read receipt: find the message and update its is_read status
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

    // Clear input immediately
    _messageController.clear();

    // Add to UI instantly — no pending state, no waiting for network
    setState(() {
      _messages.add({
        'match_id': widget.matchId,
        'sender_id': _currentUserId,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    });
    _scrollToBottom();

    // Send in background — broadcast to receiver + persist to DB
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
        Padding(
          padding: const EdgeInsets.only(right: 16),
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
        // Label
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

        // Score row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          // Me
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

          // VS + progress bar
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
                    // My bar (purple)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: (MediaQuery.of(context).size.width - 32 - 32 - 96) * myPct,
                      color: const Color(0xFF6C3FE8),
                    ),
                    // Partner bar (pink)
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

          // Partner
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

        // Play game button
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
        // Show timestamp at the end of each sender group
        final isLastInGroup = index == _messages.length - 1 ||
            _messages[index + 1]['sender_id'] != msg['sender_id'];
        return _buildBubble(msg, isMe, isLastInGroup);
      },
    );
  }

  static const _gameRequestTag = '[GAME_REQUEST]';

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe, bool showTime) {
    final content = msg['content'] as String? ?? '';

    // Game request card — shown inline in the chat
    if (content.startsWith(_gameRequestTag)) {
      return _buildGameRequestBubble(msg, isMe, showTime);
    }

    final isRead = msg['is_read'] == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                    )
                  : null,
              color: isMe ? null : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                    _buildReadReceipt(isRead),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Inline game-request card — appears when a puzzle is sent
  Widget _buildGameRequestBubble(
      Map<String, dynamic> msg, bool isMe, bool showTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.5),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A1FAD), Color(0xFF6C3FE8)]),
                  ),
                  child: const Center(
                      child: Text('🔡', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      isMe
                          ? 'You sent a Word Search!'
                          : '$_otherName sent a Word Search!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Fredoka One',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMe
                          ? 'Waiting for $_otherName to play...'
                          : 'Tap to play and unlock chat!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ]),
                ),
              ]),
              if (!isMe) ...[
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
                            if (mounted)
                              setState(() => _chatUnlocked = true);
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '🎮  Play Now',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Fredoka One',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 20, bottom: 12),
              child: Text(
                _formatTime(msg['created_at'] as String?),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Single tick (sent) or double purple tick (read)
  Widget _buildReadReceipt(bool isRead) {
    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 14,
      color: isRead
          ? const Color(0xFF9D50BB)            // purple double tick = read
          : Colors.white.withValues(alpha: 0.4), // gray single tick = sent
    );
  }

  Widget _buildInputBar() {
    // While both game status AND messages are still loading, show nothing
    if (_gameStatusLoading && _loading) return const SizedBox.shrink();

    // Game not yet won — and no prior messages — show locked banner
    if (!_chatUnlocked) return _buildLockedBanner();

    // Normal chat input
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message $_otherName...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
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
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown instead of the text field until both players complete the word search.
  Widget _buildLockedBanner() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: const Color(0xFF6C3FE8).withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFF6C3FE8), size: 16),
              const SizedBox(width: 6),
              Text(
                'Complete the word search to chat with $_otherName',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final partnerUserId = widget.otherProfile['id'] as String? ?? '';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameHubScreen(
                    matchId:        widget.matchId,
                    currentUserId:  _currentUserId,
                    partnerUserId:  partnerUserId,
                    partnerName:    _otherName,
                    onChatUnlocked: () {
                      if (mounted) setState(() => _chatUnlocked = true);
                    },
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎮', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Play Word Search to Unlock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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
