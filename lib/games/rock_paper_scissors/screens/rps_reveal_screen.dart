// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Reveal Screen
//  Countdown 3 → 2 → 1 → 0, then simultaneous reveal.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../data/rps_models.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_result_screen.dart';

class RPSRevealScreen extends StatefulWidget {
  const RPSRevealScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.opponentId,
    required this.opponentName,
    required this.myMove,
    required this.opponentMove,
    required this.onChatUnlocked,
  });

  final String currentUserId;
  final String currentUserName;
  final String opponentId;
  final String opponentName;
  final RPSMove myMove;
  final RPSMove opponentMove;
  final VoidCallback onChatUnlocked;

  @override
  State<RPSRevealScreen> createState() => _RPSRevealScreenState();
}

class _RPSRevealScreenState extends State<RPSRevealScreen>
    with TickerProviderStateMixin {

  int _count = 3;
  bool _showReveal = false;
  Timer? _cdTimer;

  late final AnimationController _ringCtrl;
  late final Animation<double> _ring;

  late final AnimationController _popCtrl;
  late final Animation<double> _popA;
  late final Animation<double> _popB;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3920));
    _ring = Tween(begin: 0.0, end: 1.0).animate(_ringCtrl);

    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _popA = CurvedAnimation(
        parent: _popCtrl,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut));
    _popB = CurvedAnimation(
        parent: _popCtrl,
        curve: const Interval(0.12, 1.0, curve: Curves.elasticOut));

    _startCountdown();
  }

  @override
  void dispose() {
    _cdTimer?.cancel();
    _ringCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ringCtrl.forward();
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _count--);
      if (_count < 0) {
        t.cancel();
        setState(() => _showReveal = true);
        _popCtrl.forward();
        Future.delayed(const Duration(milliseconds: 2200), _goResult);
      }
    });
  }

  void _goResult() {
    if (!mounted) return;
    final result = computeResult(widget.myMove, widget.opponentMove);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RPSResultScreen(
        currentUserId:   widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId:      widget.opponentId,
        opponentName:    widget.opponentName,
        myMove:          widget.myMove,
        opponentMove:    widget.opponentMove,
        result:          result,
        onChatUnlocked:  widget.onChatUnlocked,
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                child: Column(
                  children: [
                    RPSNavBar(
                      onBack: () {
                        _cdTimer?.cancel();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: _showReveal ? _buildReveal() : _buildCountdown(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'BOTH SUBMITTED!',
          style: RPSTheme.font(10,
              fw: FontWeight.w700,
              letterSpacing: 3,
              color: RPSTheme.muted),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ring,
                builder: (_, __) => SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(
                    value: _ring.value,
                    strokeWidth: 2,
                    backgroundColor: RPSTheme.dimLine,
                    valueColor:
                        const AlwaysStoppedAnimation(RPSTheme.purple),
                  ),
                ),
              ),
              Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    colors: [
                      RPSTheme.purple,
                      const Color(0xFF4C1D95),
                      const Color(0xFF1E0A50),
                      const Color(0xFF0D0528),
                    ],
                    stops: const [0.0, 0.44, 0.78, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: RPSTheme.purple.withOpacity(0.44),
                      blurRadius: 55,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      key: ValueKey(_count),
                      _count >= 0 ? '$_count' : '0',
                      style: RPSTheme.font(88, fw: FontWeight.w700)
                          .copyWith(shadows: [
                        Shadow(
                          color: const Color(0xFFDCB4FF).withOpacity(0.8),
                          blurRadius: 30,
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Get ready for the reveal...',
          style: RPSTheme.font(13, fw: FontWeight.w500, color: RPSTheme.muted),
        ),
      ],
    );
  }

  Widget _buildReveal() {
    final myMove = widget.myMove;
    final oppMove = widget.opponentMove;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ROCK PAPER SCISSORS',
          style: RPSTheme.font(11,
              fw: FontWeight.w700,
              letterSpacing: 2.5,
              color: RPSTheme.purpleLight),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // RepaintBoundary: isolates the scale-pop so it doesn't
            // force a full-screen repaint on every animation frame.
            RepaintBoundary(
              child: ScaleTransition(
                scale: _popA,
                child: Column(children: [
                  RepaintBoundary(
                    child: Text((myMove ?? RPSMove.rock).emoji,
                        style: const TextStyle(fontSize: 66)),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    widget.currentUserName.toUpperCase(),
                    style: RPSTheme.font(13,
                        fw: FontWeight.w700,
                        letterSpacing: 2,
                        color: RPSTheme.purpleLight),
                  ),
                ]),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Text(
                ' VS ',
                style: RPSTheme.font(18,
                    fw: FontWeight.w700, color: RPSTheme.purpleLight),
              ),
            ),

            RepaintBoundary(
              child: ScaleTransition(
                scale: _popB,
                child: Column(children: [
                  RepaintBoundary(
                    child: Text((oppMove ?? RPSMove.rock).emoji,
                        style: const TextStyle(fontSize: 66)),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    widget.opponentName.toUpperCase(),
                    style: RPSTheme.font(13,
                        fw: FontWeight.w700,
                        letterSpacing: 2,
                        color: const Color(0xFF06B6D4)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
