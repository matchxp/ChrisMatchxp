// chat_tutorial_sheet.dart
// Show with: showChatTutorial(context);
// Auto-shown first time via SharedPreferences key 'chat_tutorial_seen'

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Colours matching the app background ──────────────────────────────────────
const _bg1   = Color.fromARGB(255, 110, 29, 131);
const _bg2   = Color(0xFF2E0858);
const _bg3   = Color(0xFF180430);
const _bg4   = Color(0xFF0F0B1E);
const _bg5   = Color(0xFF0C0B11);
const _pu    = Color(0xFFAB5CF5);
const _puD   = Color(0xFF6930C3);
const _puM   = Color(0xFF8B5CF6);
const _tx    = Color(0xFFE2D5FF);
const _txM   = Color(0xFF9B8EC0);
const _card  = Color(0xFF140E30);

// ── Public API ────────────────────────────────────────────────────────────────

/// Call this on first open (checks SharedPreferences internally).
Future<void> showChatTutorialIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen  = prefs.getBool('chat_tutorial_seen') ?? false;
  if (!seen && context.mounted) {
    await showChatTutorial(context);
    await prefs.setBool('chat_tutorial_seen', true);
  }
}

/// Always show the tutorial (for the help button).
Future<void> showChatTutorial(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => const _ChatTutorialSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _ChatTutorialSheet extends StatefulWidget {
  const _ChatTutorialSheet();

  @override
  State<_ChatTutorialSheet> createState() => _ChatTutorialSheetState();
}

class _ChatTutorialSheetState extends State<_ChatTutorialSheet> {

  static const _cards = [
    _TutorialCard(
      emoji: '👋',
      title: 'Welcome to\nMatchXP Chat!',
      body: 'Here\'s how connecting with your matches works. Swipe to explore.',
      glowColor: Color(0xFFAB5CF5),
      gradientColors: [Color(0xFF2D0F60), Color(0xFF1A0838), Color(0xFF0C0B11)],
    ),
    _TutorialCard(
      emoji: '💜',
      title: 'The Coloured\nRings',
      body: '🟣  Purple — you sent a game challenge\n🟢  Green — they challenged you, your turn!\n⚪  Grey — no active game right now',
      glowColor: Color(0xFF8B5CF6),
      gradientColors: [Color(0xFF1C0840), Color(0xFF2D1270), Color(0xFF0C0B11)],
    ),
    _TutorialCard(
      emoji: '🎮',
      title: 'Play an\nIcebreaker',
      body: 'Tap a match to start a game — Word Search, Emoji Charades, or Rock Paper Scissors. One of you sends the challenge.',
      glowColor: Color(0xFFA855F7),
      gradientColors: [Color(0xFF200840), Color(0xFF2D1270), Color(0xFF0C0B11)],
    ),
    _TutorialCard(
      emoji: '🔓',
      title: 'Unlock\nYour Chat',
      body: 'Both players complete the game and your chat unlocks! You can\'t message until the ice is broken.',
      glowColor: Color(0xFF39FF14),
      gradientColors: [Color(0xFF0A2010), Color(0xFF0C1A10), Color(0xFF0C0B11)],
    ),
    _TutorialCard(
      emoji: '🏆',
      title: 'Earn\nPoints',
      body: 'Solve the puzzle = +1 point.\nSkip = 0 points.\nBeat your match on the scoreboard!',
      glowColor: Color(0xFFFFB800),
      gradientColors: [Color(0xFF2A1800), Color(0xFF1A1000), Color(0xFF0C0B11)],
    ),
    _TutorialCard(
      emoji: '🔥',
      title: 'Keep\nPlaying',
      body: """
Chat unlocked?
Keep playing games inside the chat to rack up points and stay connected!""",
      glowColor: Color(0xFFFF6B6B),
      gradientColors: [Color(0xFF2A0A08), Color(0xFF1A0808), Color(0xFF0C0B11)],
    ),
  ];

  late final PageController _page;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _cards.length - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _onPageChanged(int i) {
    setState(() => _current = i);
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_current];
    final isLast = _current == _cards.length - 1;
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.82,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _pu.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Skip
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('Skip',
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _txM,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Cards
          SizedBox(
            height: screenH * 0.50,
            child: PageView.builder(
              controller: _page,
              onPageChanged: _onPageChanged,
              itemCount: _cards.length,
              itemBuilder: (_, i) => _buildCard(_cards[i]),
            ),
          ),
          const SizedBox(height: 12),
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_cards.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? card.glowColor : _pu.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _next,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [card.glowColor.withValues(alpha: 0.85), _puD],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: card.glowColor.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isLast ? 'Got it! 🎉' : 'Next',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildCard(_TutorialCard card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: card.gradientColors,
          ),
          border: Border.all(
            color: card.glowColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: card.glowColor.withValues(alpha: 0.2),
              blurRadius: 24,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(card.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text(
              card.title,
              style: GoogleFonts.bebasNeue(
                fontSize: 40,
                color: Colors.white,
                height: 1.05,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 40, height: 2,
              decoration: BoxDecoration(
                color: card.glowColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              card.body,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: _tx.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
    }

// ── Data model ────────────────────────────────────────────────────────────────

class _TutorialCard {
  final String emoji;
  final String title;
  final String body;
  final Color glowColor;
  final List<Color> gradientColors;

  const _TutorialCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.glowColor,
    required this.gradientColors,
  });
}