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
  });

  final String currentUserId;
  final String currentUserName;
  final String opponentId;
  final String opponentName;

  @override
  State<RPSIntroScreen> createState() => _RPSIntroScreenState();
}

class _RPSIntroScreenState extends State<RPSIntroScreen>
    with TickerProviderStateMixin {
  final List<String> _emojis = ['✊', '🖐️', '✌️'];
  List<int> _order = [0, 1, 2];
  Timer? _shuffleTimer;

  late final List<AnimationController> _floatCtrls;
  late final List<Animation<double>> _floats;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _floatCtrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2800 + i * 400),
      )..repeat(reverse: true),
    );
    _floats = List.generate(
      3,
      (i) => Tween<double>(begin: 0, end: -13).animate(
        CurvedAnimation(parent: _floatCtrls[i], curve: Curves.easeInOut),
      ),
    );
    _scheduleNextShuffle();
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    for (final c in _floatCtrls) c.dispose();
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
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId: widget.opponentId,
        opponentName: widget.opponentName,
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

                    // Floating hand emojis
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _floats[i],
                                builder: (_, __) => Transform.translate(
                                  // Snap to whole pixels — sub-pixel
                                  // offsets cause bitmap-emoji blur.
                                  offset: Offset(
                                      0, _floats[i].value.roundToDouble()),
                                  child: Text(
                                    _emojis[_order[i]],
                                    style: TextStyle(
                                        fontSize: i == 1 ? 80 : 70),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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
