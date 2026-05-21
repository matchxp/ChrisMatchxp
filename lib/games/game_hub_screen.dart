// lib/games/game_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'word_search/word_search_supabase_wrapper.dart';
import 'rock_paper_scissors/screens/rps_intro_screen.dart';
import 'emoji_charades/emoji_charades_game_screen.dart';

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
  // ── App colour palette (matches MainNavigation / HomeScreen) ──
  static const _bg   = Color(0xFF0A0A0A);
  static const _surf = Color(0xFF1A1A1A);
  static const _pu   = Color(0xFF6C3FE8);
  static const _pu2  = Color(0xFF9D50BB);
  static const _pk   = Color(0xFFFF6B8A);
  static const _tx   = Colors.white;
  static const _mt   = Color(0xFF888888);

  bool _loading = false;

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
            backgroundColor: _surf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Game in progress',
                style: const TextStyle(color: _tx, fontFamily: 'Fredoka One')),
            content: Text(
              'A $gameLabel game is already in progress! Check your chat to continue.',
              style: const TextStyle(color: _mt, fontFamily: 'Fredoka'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: _pu, fontFamily: 'Fredoka One')),
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
    final matchId       = widget.matchId;
    final currentUserId = widget.currentUserId;
    final partnerUserId = widget.partnerUserId;
    final partnerName   = widget.partnerName;
    final onChatUnlocked = widget.onChatUnlocked;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(context),
      bottomNavigationBar: _pillNavBar(context),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Header badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: _pu.withOpacity(0.12),
              border: Border.all(color: _pu.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('🕹  CHOOSE YOUR ICE BREAKER',
              style: TextStyle(color: _pu2, fontFamily: 'Fredoka',
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5)),
          ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
            ).createShader(b),
            child: const Text('Pick a game to play',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fredoka One', fontSize: 24, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
            ).createShader(b),
            child: const Text('Both of you create AND solve a puzzle.\nChat unlocks when you both finish!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontFamily: 'Fredoka', fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 20),

          Expanded(child: ListView(children: [
            // ── Word Search (active) ──
            GestureDetector(
              onTap: () async {
                if (widget.onGameSelected != null) {
                  Navigator.pop(context);
                  widget.onGameSelected!('word_search');
                  return;
                }
                if (_loading) return;
                setState(() => _loading = true);
                try {
                  if (await _duplicateGuard('word_search', 'Word Search')) return;
                  String? sessionId;
                  try {
                    sessionId = await Supabase.instance.client
                        .rpc('create_game_challenge', params: {
                      'p_match_id':      matchId,
                      'p_challenged_id': partnerUserId,
                      'p_game_type':     'word_search',
                      'p_is_initial':    true,
                    }) as String?;
                    if (sessionId != null) {
                      await Supabase.instance.client
                          .rpc('accept_game_challenge', params: {'p_session_id': sessionId});
                    }
                  } catch (_) {}
                  if (!context.mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WordSearchSupabaseWrapper(
                      matchId:              matchId,
                      currentUserId:        currentUserId,
                      partnerUserId:        partnerUserId,
                      partnerName:          partnerName,
                      sessionId:            sessionId,
                      chatAlreadyUnlocked:  widget.chatAlreadyUnlocked,
                      onChatUnlocked: () {
                        int pops = 0;
                        Navigator.of(context).popUntil((_) => pops++ >= 2);
                        onChatUnlocked();
                      },
                    ),
                  ));
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surf,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _pu.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _pu.withOpacity(0.12),
                      blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF4A1FAD), Color(0xFF6C3FE8)])),
                    child: const Center(child: Text('🔡', style: TextStyle(fontSize: 26)))),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Word Search', style: TextStyle(fontFamily: 'Fredoka One',
                        fontSize: 16, color: _tx)),
                      SizedBox(height: 2),
                      Text('Both create a puzzle · both solve · chat unlocks',
                        style: TextStyle(fontFamily: 'Fredoka', fontSize: 11, color: _mt)),
                    ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _pu.withOpacity(0.4), blurRadius: 12)]),
                    child: const Text('PLAY', style: TextStyle(color: Colors.white,
                      fontFamily: 'Fredoka', fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),



            const SizedBox(height: 12),
            // ── Rock Paper Scissors ──
            GestureDetector(
              onTap: () async {
                if (widget.onGameSelected != null) {
                  Navigator.pop(context);
                  widget.onGameSelected!('rps');
                  return;
                }
                if (_loading) return;
                setState(() => _loading = true);
                try {
                  if (await _duplicateGuard('rps', 'Rock Paper Scissors')) return;
                  final sessionId = await Supabase.instance.client
                      .rpc('create_game_challenge', params: {
                    'p_match_id':      matchId,
                    'p_challenged_id': partnerUserId,
                    'p_game_type':     'rps',
                    'p_is_initial':    true,
                  }) as String;
                  await Supabase.instance.client
                      .rpc('accept_game_challenge', params: {'p_session_id': sessionId});

                  if (!context.mounted) return;

                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RPSIntroScreen(
                      currentUserId:        currentUserId,
                      currentUserName:      'You',
                      opponentId:           partnerUserId,
                      opponentName:         partnerName,
                      sessionId:            sessionId,
                      popCount:             2,
                      onChatUnlocked:       onChatUnlocked,
                      chatAlreadyUnlocked:  widget.chatAlreadyUnlocked,
                    ),
                  ));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not start game: $e')),
                  );
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surf,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.12),
                      blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF3B1580), Color(0xFF7C3AED)])),
                    child: const Center(child: Text('✊', style: TextStyle(fontSize: 26)))),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Rock Paper Scissors', style: TextStyle(fontFamily: 'Fredoka One',
                        fontSize: 16, color: _tx)),
                      SizedBox(height: 2),
                      Text('Pass the phone · both pick secretly · reveal together',
                        style: TextStyle(fontFamily: 'Fredoka', fontSize: 11, color: _mt)),
                    ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 12)]),
                    child: const Text('PLAY', style: TextStyle(color: Colors.white,
                      fontFamily: 'Fredoka', fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),

            const SizedBox(height: 12),
            // ── Emoji Charades ──
            GestureDetector(
              onTap: () async {
                if (widget.onGameSelected != null) {
                  Navigator.pop(context);
                  widget.onGameSelected!('emoji_charades');
                  return;
                }
                if (_loading) return;
                setState(() => _loading = true);
                try {
                  if (await _duplicateGuard('emoji_charades', 'Emoji Charades')) return;
                  String? sessionId;
                  try {
                    sessionId = await Supabase.instance.client
                        .rpc('create_game_challenge', params: {
                      'p_match_id':      matchId,
                      'p_challenged_id': partnerUserId,
                      'p_game_type':     'emoji_charades',
                      'p_is_initial':    true,
                    }) as String?;
                    if (sessionId != null) {
                      await Supabase.instance.client
                          .rpc('accept_game_challenge', params: {'p_session_id': sessionId});
                    }
                  } catch (_) {}
                  if (!context.mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EmojiCharadesGameScreen(
                      matchId:              matchId,
                      currentUserId:        currentUserId,
                      partnerUserId:        partnerUserId,
                      partnerName:          partnerName,
                      sessionId:            sessionId,
                      skipIntro:            true,
                      chatAlreadyUnlocked:  widget.chatAlreadyUnlocked,
                      onChatUnlocked: () {
                        // Navigate immediately — don't block on Supabase.
                        int pops = 0;
                        Navigator.of(context).popUntil((_) => pops++ >= 2);
                        onChatUnlocked();
                        // Best-effort: persist chat_unlocked in background.
                        Supabase.instance.client
                            .from('matches')
                            .update({'chat_unlocked': true})
                            .eq('id', matchId)
                            .catchError((_) {});
                      },
                    ),
                  ));
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surf,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.10),
                      blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF3B1580), Color(0xFF7C3AED)])),
                    child: const Center(child: Text('😂', style: TextStyle(fontSize: 26)))),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Emoji Charades', style: TextStyle(fontFamily: 'Fredoka One',
                        fontSize: 16, color: _tx)),
                      SizedBox(height: 2),
                      Text('Turn a phrase into emojis · partner guesses · chat unlocks',
                        style: TextStyle(fontFamily: 'Fredoka', fontSize: 11, color: _mt)),
                    ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.4), blurRadius: 12)]),
                    child: const Text('PLAY', style: TextStyle(color: Colors.white,
                      fontFamily: 'Fredoka', fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),

          ])),
        ]),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) => AppBar(
    backgroundColor: _bg,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
      onPressed: () => Navigator.pop(context),
    ),
    title: RichText(text: const TextSpan(children: [
      TextSpan(text: 'MATCH', style: TextStyle(color: Colors.white,
        fontFamily: 'Fredoka One', fontSize: 18, letterSpacing: 1)),
      TextSpan(text: 'XP', style: TextStyle(color: Color(0xFF6C3FE8),
        fontFamily: 'Fredoka One', fontSize: 18, letterSpacing: 1)),
    ])),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: const Color(0xFF6C3FE8).withOpacity(0.15))),
  );

  Widget _pillNavBar(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_bg.withOpacity(0.0), _bg]),
    ),
    child: SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _pu.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(color: _pu.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, Icons.explore_outlined,           Icons.explore,             0),
            _navItem(context, Icons.favorite_border_rounded,    Icons.favorite_rounded,    1),
            _navItem(context, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 2),
            _navItem(context, Icons.person_outline_rounded,     Icons.person_rounded,      3),
          ],
        ),
      ),
    ),
  );

  Widget _navItem(BuildContext context, IconData icon, IconData activeIcon, int index) {
    final isSelected = index == 2; // Games are under Chats
    return GestureDetector(
      onTap: () { if (!isSelected) Navigator.of(context).popUntil((r) => r.isFirst); },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)])
              : null,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [BoxShadow(color: _pu.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]
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
