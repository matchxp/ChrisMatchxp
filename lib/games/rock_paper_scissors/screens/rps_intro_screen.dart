// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Intro Screen
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_pick_screen.dart';
import 'rps_tutorial_sheet.dart';

class RPSIntroScreen extends StatefulWidget {
  const RPSIntroScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.opponentId,
    required this.opponentName,
    required this.sessionId,
    required this.onChatUnlocked,
    this.popCount = 1,
  });

  final String currentUserId;
  final String currentUserName;
  final String opponentId;
  final String opponentName;
  final String sessionId;
  final VoidCallback onChatUnlocked;
  final int popCount;

  @override
  State<RPSIntroScreen> createState() => _RPSIntroScreenState();
}

class _RPSIntroScreenState extends State<RPSIntroScreen>
    with TickerProviderStateMixin {
  final List<String> _emojis = ['✊', '🖐️', '✌️'];
  List<int> _order = [0, 1, 2];
  Timer? _shuffleTimer;

  // Three staggered controllers — same pattern as Word Search welcome screen.
  // All use 2s easeInOut repeating, started 600ms apart so they float
  // independently while staying silky smooth.
  late final AnimationController _fc0, _fc1, _fc2;
  late final Animation<double>   _fa0, _fa1, _fa2;

  // Amplitude (px) per emoji slot
  static const _amps = [18.0, 22.0, 15.0];

  final _rng = Random();

  @override
  void initState() {
    super.initState();

    Animation<double> _make(AnimationController c) =>
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut));

    _fc0 = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat(reverse: true);
    _fc1 = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _fc2 = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);

    _fa0 = _make(_fc0);
    _fa1 = _make(_fc1);
    _fa2 = _make(_fc2);

    // Stagger starts so they are offset from each other
    Future.delayed(const Duration(milliseconds: 600),  () { if (mounted) _fc1.repeat(reverse: true); });
    Future.delayed(const Duration(milliseconds: 1200), () { if (mounted) _fc2.repeat(reverse: true); });

    _scheduleNextShuffle();
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _fc0.dispose(); _fc1.dispose(); _fc2.dispose();
    super.dispose();
  }

  void _scheduleNextShuffle() {
    _shuffleTimer = Timer(const Duration(seconds: 3), _doShuffle);
  }

  void _doShuffle() {
    if (!mounted) return;
    List<int> next;
    do {
      next = [..._order]..shuffle(_rng);
    } while (next.join() == _order.join());
    setState(() => _order = next);
    _scheduleNextShuffle();
  }

  void _openTutorial() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RPSTutorialSheet(),
    );
  }

  void _play() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RPSPickScreen(
        currentUserId:   widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId:      widget.opponentId,
        opponentName:    widget.opponentName,
        sessionId:       widget.sessionId,
        onChatUnlocked:  widget.onChatUnlocked,
        popCount:        widget.popCount,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RPSTheme.bg,
      body: RPSBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const RPSGlowBlobs(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 64, 22, 32),
                child: Column(
                  children: [
                    RPSNavBar(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 16),

                    // Title — same font/weight/size as Emoji Charades.
                    Text('ROCK',
                        style: RPSTheme.font(62,
                            fw: FontWeight.w700, color: RPSTheme.gold)),
                    Text('PAPER',
                        style: RPSTheme.font(62,
                            fw: FontWeight.w700, color: Colors.white)),
                    Text('SCISSORS',
                        style: RPSTheme.font(62,
                            fw: FontWeight.w700, color: RPSTheme.gold)),

                    // Floating hand emojis — smooth easeInOut, staggered
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: AnimatedBuilder(
                                animation: [_fa0, _fa1, _fa2][i],
                                builder: (_, __) => Transform.translate(
                                  offset: Offset(0, [_fa0, _fa1, _fa2][i].value * -_amps[i]),
                                  child: Text(
                                    _emojis[_order[i]],
                                    style: TextStyle(fontSize: i == 1 ? 80 : 70),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    GestureDetector(
                      onTap: _openTutorial,
                      child: Text(
                        'View tutorial',
                        style: RPSTheme.font(15,
                          fw: FontWeight.w500,
                          color: const Color(0xFFC8AAFF),
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFC8AAFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),

                    RPSPillButton(label: 'Play now', onPressed: _play),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
