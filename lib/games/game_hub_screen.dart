// lib/games/game_hub_screen.dart

import 'package:flutter/material.dart';
import 'word_search/word_search_game_screen.dart';

class GameHubScreen extends StatelessWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback onChatUnlocked;

  const GameHubScreen({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    required this.onChatUnlocked,
  });

  // ── App colour palette (matches MainNavigation / HomeScreen) ──
  static const _bg   = Color(0xFF0A0A0A);
  static const _surf = Color(0xFF1A1A1A);
  static const _pu   = Color(0xFF6C3FE8);
  static const _pu2  = Color(0xFF9D50BB);
  static const _pk   = Color(0xFFFF6B8A);
  static const _tx   = Colors.white;
  static const _mt   = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
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
              colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB), Color(0xFFFF6B8A)],
            ).createShader(b),
            child: const Text('Pick a game to play',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fredoka One', fontSize: 24, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Text('Both of you create AND solve a puzzle.\nChat unlocks when you both finish!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),

          Expanded(child: ListView(children: [
            // ── Word Search (active) ──
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => WordSearchGameScreen(
                  matchId:        matchId,
                  currentUserId:  currentUserId,
                  partnerUserId:  partnerUserId,
                  partnerName:    partnerName,
                  onChatUnlocked: () {
                    // Pop exactly 2 routes: WordSearchGameScreen + GameHubScreen.
                    // We must NOT use popUntil((r) => r.isFirst) because that
                    // would also pop ChatConversationScreen, dumping the user on
                    // the home screen instead of the now-unlocked chat.
                    int _pops = 0;
                    Navigator.of(context).popUntil((_) => _pops++ >= 2);
                    onChatUnlocked(); // setState in ChatConversationScreen
                  },
                ),
              )),
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

            // ── Emoji Guess (coming soon) ──
            Opacity(opacity: 0.4, child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surf,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5)),
              child: Row(children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFFAD6A1F), Color(0xFFE5A55D)])),
                  child: const Center(child: Text('😂', style: TextStyle(fontSize: 26)))),
                const SizedBox(width: 14),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Emoji Guess', style: TextStyle(fontFamily: 'Fredoka One',
                      fontSize: 16, color: _tx)),
                    SizedBox(height: 2),
                    Text('Describe a word using only emojis',
                      style: TextStyle(fontFamily: 'Fredoka', fontSize: 11, color: _mt)),
                  ])),
                const Text('🔒', style: TextStyle(fontSize: 18)),
              ]),
            )),

            const SizedBox(height: 20),
            const Center(child: Text('More games coming soon!',
              style: TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 12))),
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
