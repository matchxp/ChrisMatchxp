// lib/games/game_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'word_search/word_search_supabase_wrapper.dart';
import 'rock_paper_scissors/screens/rps_intro_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'emoji_charades/emoji_charades_game_screen.dart';
import '../widgets/matchxp_background.dart';

const String _matchSvg = '''
<svg viewBox="0 0 133 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M0 0.660437H10.3689L14.9919 33.7484H15.124L19.7471 0.660437H30.116V46.8911H23.2474V11.8879H23.1153L17.8318 46.8911H11.7558L6.4723 11.8879H6.34021V46.8911H0V0.660437Z" fill="white"/>
  <path d="M41.8114 0.660437H51.652L59.181 46.8911H51.9161L50.5952 37.711V37.8431H42.3398L41.0189 46.8911H34.2824L41.8114 0.660437ZM49.7367 31.569L46.5005 8.71779H46.3684L43.1983 31.569H49.7367Z" fill="white"/>
  <path d="M66.0144 7.26482H58.4194V0.660437H80.8743V7.26482H73.2792V46.8911H66.0144V7.26482Z" fill="white"/>
  <path d="M95.0309 47.5516C91.5526 47.5516 88.8888 46.5609 87.0396 44.5796C85.2344 42.5983 84.3318 39.8024 84.3318 36.192V11.3595C84.3318 7.74914 85.2344 4.95329 87.0396 2.97197C88.8888 0.990658 91.5526 0 95.0309 0C98.5092 0 101.151 0.990658 102.956 2.97197C104.805 4.95329 105.73 7.74914 105.73 11.3595V16.2468H98.8614V10.8972C98.8614 8.03533 97.6506 6.60438 95.229 6.60438C92.8074 6.60438 91.5966 8.03533 91.5966 10.8972V36.7204C91.5966 39.5382 92.8074 40.9472 95.229 40.9472C97.6506 40.9472 98.8614 39.5382 98.8614 36.7204V29.6537H105.73V36.192C105.73 39.8024 104.805 42.5983 102.956 44.5796C101.151 46.5609 98.5092 47.5516 95.0309 47.5516Z" fill="white"/>
  <path d="M110.737 0.660437H118.002V19.4829H125.795V0.660437H133.06V46.8911H125.795V26.0873H118.002V46.8911H110.737V0.660437Z" fill="white"/>
</svg>
''';

const String _xpSvg = '''
<svg viewBox="143.56 0 47.44 47.44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M149.761 0C146.336 0 143.56 2.77642 143.56 6.2013V41.2386C143.56 44.6635 146.336 47.4399 149.761 47.4399H184.799C188.224 47.4399 191 44.6635 191 41.2386V6.2013C191 2.77642 188.224 0 184.799 0H149.761ZM150.036 8.06172L155.574 23.5136L149.761 39.6883H154.522L158.275 28.6642H158.366L162.028 39.6883H167.338L161.525 23.5136L167.063 8.06172H162.303L158.824 18.2726H158.733L155.346 8.06172H150.036ZM177.602 8.06172H170.187V39.6883H175.222V26.8118H177.602C180.104 26.8118 181.981 26.1491 183.232 24.8238C184.483 23.4985 185.109 21.5557 185.109 18.9955V15.878C185.109 13.3178 184.483 11.375 183.232 10.0497C181.981 8.72437 180.104 8.06172 177.602 8.06172ZM179.433 21.616C179.036 22.0678 178.426 22.2937 177.602 22.2937H175.222V12.5798H177.602C178.426 12.5798 179.036 12.8057 179.433 13.2575C179.86 13.7093 180.074 14.4774 180.074 15.5617V19.3118C180.074 20.3961 179.86 21.1642 179.433 21.616Z" fill="#9A45DD"/>
</svg>
''';

class GameHubScreen extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback onChatUnlocked;

  /// When provided, PLAY buttons call this with the game type and pop back
  /// instead of launching the game directly. Used for in-chat challenges.
  final void Function(String gameType)? onGameSelected;

  final bool chatAlreadyUnlocked;

  const GameHubScreen({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    required this.onChatUnlocked,
    this.onGameSelected,
    this.chatAlreadyUnlocked = false,
  });

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  // ── App colour palette (matches chat page purple vibe) ──
  static const _bg = Color(0xFF1A0D38);
  static const _pu = Color(0xFF6C3FE8);
  static const _pu2 = Color(0xFF9D50BB);
  static const _tx = Colors.white;

  bool _loading = false;
  // Infinite loop — start in the middle of a huge list so user can swipe both ways
  static const _kLoopBase = 3000; // divisible by 3
  int _currentPage = _kLoopBase;
  late final PageController _pageController;

  static const _games = [
    {'type': 'word_search', 'name': 'Word Search', 'emoji': '🔍'},
    {'type': 'rps', 'name': 'Rock Paper Scissors', 'emoji': '✂️'},
    {'type': 'emoji_charades', 'name': 'Emoji Charades', 'emoji': '🎭'},
  ];

  // Per-game card colour schemes — all purple universe, each slightly distinct
  static const _cardGradients = {
    'word_search': [Color(0xFF1C0840), Color(0xFF2D1270)],
    'rps': [Color(0xFF150A38), Color(0xFF2D1270)],
    'emoji_charades': [Color(0xFF200840), Color(0xFF2D1270)],
  };
  static const _cardGlows = {
    'word_search': Color(0xFF6C3FE8),
    'rps': Color(0xFF8B5CF6),
    'emoji_charades': Color(0xFFA855F7),
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.68,
      initialPage: _kLoopBase,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Returns true if an active (non-completed) session already exists for
  /// this match + game type. Shows an alert and returns true so the caller
  /// can bail out early.
  Future<bool> _duplicateGuard(String gameType, String gameLabel) async {
    try {
      final existing = await Supabase.instance.client
          .from('game_sessions')
          .select('id')
          .eq('match_id', widget.matchId)
          .eq('game_type', gameType)
          .neq('status', 'completed')
          .maybeSingle();

      if (existing != null && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF160C2A),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Game in progress',
                style: const TextStyle(color: _tx, fontFamily: 'Fredoka One')),
            content: Text(
              'A $gameLabel game is already in progress! Check your chat to continue.',
              style: const TextStyle(
                  color: Color(0xFF9B8EC0), fontFamily: 'Fredoka'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK',
                    style: TextStyle(color: _pu, fontFamily: 'Fredoka One')),
              ),
            ],
          ),
        );
        return true;
      }
    } catch (_) {
      // If the check fails, allow the flow to continue.
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final matchId = widget.matchId;
    final currentUserId = widget.currentUserId;
    final partnerUserId = widget.partnerUserId;
    final partnerName = widget.partnerName;
    final onChatUnlocked = widget.onChatUnlocked;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _appBar(context),
      bottomNavigationBar: _pillNavBar(context),
      body: MatchXPBackground(child: Column(children: [
        SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
        Text(
          'PICK A GAME TO PLAY',
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
              fontSize: 42, color: Colors.white, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          '',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
              letterSpacing: 1.2),
        ),
        const SizedBox(height: 24),

        // ── Swipeable game cards (infinite loop) ─────────────────────
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: null, // infinite
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final gameIndex = index % _games.length;
              final game = _games[gameIndex];
              return _buildGameCard(
                context: context,
                pageIndex: index,
                gameType: game['type']!,
                gameName: game['name']!,
                gameEmoji: game['emoji']!,
                matchId: matchId,
                currentUserId: currentUserId,
                partnerUserId: partnerUserId,
                partnerName: partnerName,
                onChatUnlocked: onChatUnlocked,
              );
            },
          ),
        ),

        // ── Page dots ─────────────────────────────────────────────────
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_games.length, (i) {
            final active = i == (_currentPage % _games.length);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _pu : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
      ])),
    );
  }

  // ── Individual swipeable game card ────────────────────────────────────────
  Widget _buildGameCard({
    required BuildContext context,
    required int pageIndex,
    required String gameType,
    required String gameName,
    required String gameEmoji,
    required String matchId,
    required String currentUserId,
    required String partnerUserId,
    required String partnerName,
    required VoidCallback onChatUnlocked,
  }) {
    final gradColors =
        _cardGradients[gameType] ?? _cardGradients['word_search']!;
    final glowColor = _cardGlows[gameType] ?? _cardGlows['word_search']!;

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double scale = 0.88;
        if (_pageController.position.haveDimensions) {
          final diff = (_pageController.page! - pageIndex).abs();
          scale = (1.0 - diff * 0.12).clamp(0.88, 1.0);
        }
        return Transform.scale(scale: scale, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: GestureDetector(
          onTap: () async {
            if (widget.onGameSelected != null) {
              Navigator.pop(context);
              widget.onGameSelected!(gameType);
              return;
            }
            if (_loading) return;
            setState(() => _loading = true);
            try {
              if (await _duplicateGuard(gameType, gameName)) return;

              if (gameType == 'rps') {
                final rpcRps = await Supabase.instance.client
                    .rpc('create_game_challenge', params: {
                  'p_match_id': matchId,
                  'p_challenged_id': partnerUserId,
                  'p_game_type': 'rps',
                  'p_is_initial': true,
                });
                final sessionId =
                    (rpcRps is String ? rpcRps : rpcRps?.toString()) ?? '';
                if (sessionId.isEmpty) throw Exception('Failed to create RPS session');
                await Supabase.instance.client.rpc('accept_game_challenge',
                    params: {'p_session_id': sessionId});
                if (!context.mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RPSIntroScreen(
                        currentUserId: currentUserId,
                        currentUserName: 'You',
                        opponentId: partnerUserId,
                        opponentName: partnerName,
                        sessionId: sessionId,
                        popCount: 2,
                        onChatUnlocked: onChatUnlocked,
                        chatAlreadyUnlocked: widget.chatAlreadyUnlocked,
                      ),
                    ));
              } else if (gameType == 'word_search') {
                String? sessionId;
                try {
                  final rpcResult = await Supabase.instance.client
                      .rpc('create_game_challenge', params: {
                    'p_match_id': matchId,
                    'p_challenged_id': partnerUserId,
                    'p_game_type': 'word_search',
                    'p_is_initial': true,
                  });
                  // RPC returns a UUID; use is-check instead of as-cast so a
                  // non-String return (e.g. wrapped in a map) doesn't silently
                  // null the id and cause puzzle rows to be written without it.
                  sessionId = rpcResult is String
                      ? rpcResult
                      : rpcResult?.toString();
                  if (sessionId != null) {
                    await Supabase.instance.client.rpc('accept_game_challenge',
                        params: {'p_session_id': sessionId});
                  }
                } catch (_) {}
                if (!context.mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WordSearchSupabaseWrapper(
                        matchId: matchId,
                        currentUserId: currentUserId,
                        partnerUserId: partnerUserId,
                        partnerName: partnerName,
                        sessionId: sessionId,
                        chatAlreadyUnlocked: widget.chatAlreadyUnlocked,
                        onChatUnlocked: () {
                          int pops = 0;
                          Navigator.of(context).popUntil((_) => pops++ >= 2);
                          onChatUnlocked();
                        },
                      ),
                    ));
              } else if (gameType == 'emoji_charades') {
                String? sessionId;
                try {
                  final rpcResult = await Supabase.instance.client
                      .rpc('create_game_challenge', params: {
                    'p_match_id': matchId,
                    'p_challenged_id': partnerUserId,
                    'p_game_type': 'emoji_charades',
                    'p_is_initial': true,
                  });
                  sessionId = rpcResult is String
                      ? rpcResult
                      : rpcResult?.toString();
                  if (sessionId != null) {
                    await Supabase.instance.client.rpc('accept_game_challenge',
                        params: {'p_session_id': sessionId});
                  }
                } catch (_) {}
                if (!context.mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmojiCharadesGameScreen(
                        matchId: matchId,
                        currentUserId: currentUserId,
                        partnerUserId: partnerUserId,
                        partnerName: partnerName,
                        sessionId: sessionId,
                        skipIntro: true,
                        chatAlreadyUnlocked: widget.chatAlreadyUnlocked,
                        onChatUnlocked: () {
                          int pops = 0;
                          Navigator.of(context).popUntil((_) => pops++ >= 2);
                          onChatUnlocked();
                          Supabase.instance.client
                              .from('matches')
                              .update({'chat_unlocked': true})
                              .eq('id', matchId)
                              .catchError((_) {});
                        },
                      ),
                    ));
              }
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not start game: $e')),
              );
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.62, // portrait playing-card proportions
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: glowColor.withValues(alpha: 0.7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: glowColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 0),
                    BoxShadow(
                        color: glowColor.withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 3),
                    BoxShadow(
                        color: glowColor.withValues(alpha: 0.12),
                        blurRadius: 48,
                        spreadRadius: 6),
                  ],
                ),
                child: Stack(
                  children: [
                    // ── Main card content ────────────────────────────
                    Column(
                      children: [
                        const Spacer(flex: 3),
                        Text(gameEmoji, style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            gameName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.bebasNeue(
                                fontSize: 38,
                                color: Colors.white,
                                letterSpacing: 2),
                          ),
                        ),
                        const Spacer(flex: 2),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              glowColor,
                              _pu2,
                            ]),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                  color: glowColor.withValues(alpha: 0.5),
                                  blurRadius: 16),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _loading ? 'Starting…' : 'PLAY',
                              style: GoogleFonts.bebasNeue(
                                  fontSize: 20,
                                  color: Colors.white,
                                  letterSpacing: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),

                    // ── Info bubble (top-right) ──────────────────────
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _showGameInfo(
                            context, gameType, gameName, gameEmoji),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Center(
                            child: Text('i',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ), // Padding
      ), // AnimatedBuilder child
    ); // AnimatedBuilder
  }

  // ── Game info bottom sheet ─────────────────────────────────────────────────
  void _showGameInfo(BuildContext context, String gameType, String gameName,
      String gameEmoji) {
    final steps = switch (gameType) {
      'word_search' => [
          '📝  You create a word puzzle for your match',
          '🔍  They solve yours — you solve theirs',
          '💬  Chat unlocks when both of you finish',
        ],
      'rps' => [
          '📱  Pass the phone to your match',
          '🤫  Each of you secretly picks Rock, Paper, or Scissors',
          '🎉  Reveal at the same time and see who wins',
          '💬  Chat unlocks after the reveal',
        ],
      'emoji_charades' => [
          '🎭  Turn a secret phrase into emojis — no letters!',
          '🤔  Your match has to guess what you\'re describing',
          '💬  Chat unlocks when both of you have finished',
        ],
      _ => <String>[],
    };
    final tip = switch (gameType) {
      'word_search' => 'Pick tricky words — make them work for it!',
      'rps' => 'Best of one — no rematches, no excuses.',
      'emoji_charades' => 'The weirder the phrase, the more fun it is.',
      _ => '',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0D3A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
              width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(gameEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Text(gameName,
                  style: GoogleFonts.bebasNeue(
                      fontSize: 28, color: Colors.white, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 20),
            ...steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(step,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14, height: 1.4)),
                )),
            if (tip.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF6C3FE8).withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(tip,
                          style: TextStyle(
                            color:
                                const Color(0xFFA78BFA).withValues(alpha: 0.9),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ))),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                    child: Text('Got it',
                        style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            color: Colors.white,
                            letterSpacing: 1.5))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) => AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(_matchSvg, height: 22),
            const SizedBox(width: 6),
            SvgPicture.string(_xpSvg, height: 22),
          ],
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
                height: 1, color: const Color(0xFF6C3FE8).withOpacity(0.15))),
      );

  Widget _pillNavBar(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg.withOpacity(0.0), _bg]),
        ),
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF160C2A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _pu.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _pu.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, Icons.explore_outlined, Icons.explore, 0),
                _navItem(context, Icons.favorite_border_rounded,
                    Icons.favorite_rounded, 1),
                _navItem(context, Icons.chat_bubble_outline_rounded,
                    Icons.chat_bubble_rounded, 2),
                _navItem(context, Icons.person_outline_rounded,
                    Icons.person_rounded, 3),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(
      BuildContext context, IconData icon, IconData activeIcon, int index) {
    final isSelected = index == 2; // Games are under Chats
    return GestureDetector(
      onTap: () {
        if (!isSelected) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)])
              : null,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: _pu.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? Colors.white : _pu.withOpacity(0.6),
          size: 20,
        ),
      ),
    );
  }
}
