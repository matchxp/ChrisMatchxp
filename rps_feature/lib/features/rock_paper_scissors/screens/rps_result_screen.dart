// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Result Screen
//  Outcome: You Win / You Lose / It's a Draw (one line, always)
//  Both emojis float, confetti on win only.
// ─────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import '../data/rps_models.dart';
import '../data/rps_local_match_store.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_intro_screen.dart';

class RPSResultScreen extends StatefulWidget {
  const RPSResultScreen({
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
  State<RPSResultScreen> createState() => _RPSResultScreenState();
}

class _RPSResultScreenState extends State<RPSResultScreen>
    with TickerProviderStateMixin {
  final _store = RPSLocalMatchStore.instance;

  late final AnimationController _float1Ctrl;
  late final AnimationController _float2Ctrl;
  late final Animation<double> _float1;
  late final Animation<double> _float2;
  late final AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();

    _float1Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _float1 = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _float1Ctrl, curve: Curves.easeInOut));

    _float2Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400))
      ..repeat(reverse: true);
    _float2 = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _float2Ctrl, curve: Curves.easeInOut));

    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();

    if (result == RPSResult.win) {
      _confettiCtrl.forward();
    }
  }

  @override
  void dispose() {
    _float1Ctrl.dispose();
    _float2Ctrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  RPSMove get myMove  => _store.moveForPlayer(widget.currentUserId)!;
  RPSMove get oppMove => _store.opponentMoveForPlayer(widget.currentUserId)!;
  RPSResult get result => _store.resultForPlayer(widget.currentUserId)!;

  String get outcomeText {
    switch (result) {
      case RPSResult.win:  return 'You Win';
      case RPSResult.lose: return 'You Lose';
      case RPSResult.draw: return "It's a Draw";
    }
  }

  Color get outcomeColor {
    switch (result) {
      case RPSResult.win:  return RPSTheme.gold;
      case RPSResult.lose: return RPSTheme.purpleLight;
      case RPSResult.draw: return Colors.white;
    }
  }

  String get reasonText {
    switch (result) {
      case RPSResult.win:  return myMove.beatsLabel;
      case RPSResult.lose: return oppMove.beatsLabel;
      case RPSResult.draw: return 'GREAT MINDS THINK ALIKE!';
    }
  }

  void _playAgain() {
    _store.reset();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RPSIntroScreen(
        currentUserId:   widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId:      widget.opponentId,
        opponentName:    widget.opponentName,
      ),
    ));
  }

  void _startChat() {
    _store.reset();
    Navigator.of(context).popUntil((r) => r.isFirst);
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

              // Confetti (win only)
              if (result == RPSResult.win)
                AnimatedBuilder(
                  animation: _confettiCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _ConfettiPainter(_confettiCtrl.value),
                    child: const SizedBox.expand(),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Nav label
                    Text('ROCK PAPER SCISSORS',
                        style: RPSTheme.navLabel),

                    // Gap → outcome
                    const SizedBox(height: 68),

                    // Outcome
                    Text(
                      outcomeText,
                      style: RPSTheme.font(44,
                          fw: FontWeight.w700, color: outcomeColor)
                          .copyWith(shadows: [
                        Shadow(color: outcomeColor.withOpacity(0.5),
                            blurRadius: 28),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(reasonText,
                      style: RPSTheme.font(10,
                          fw: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: RPSTheme.muted)),

                    // Gap → emojis
                    const SizedBox(height: 60),

                    // Emoji VS block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MoveResult(
                          emoji: myMove.emoji,
                          name: widget.currentUserName.toUpperCase(),
                          moveLabel: myMove.labelUpper,
                          isWinner: result == RPSResult.win || result == RPSResult.draw,
                          floatAnim: _float1,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Text(' VS ',
                            style: RPSTheme.font(14,
                                fw: FontWeight.w700, color: RPSTheme.muted)),
                        ),
                        _MoveResult(
                          emoji: oppMove.emoji,
                          name: widget.opponentName.toUpperCase(),
                          moveLabel: oppMove.labelUpper,
                          isWinner: result == RPSResult.lose || result == RPSResult.draw,
                          floatAnim: _float2,
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Buttons
                    RPSPillButton(label: 'Start Chatting', onPressed: _startChat),
                    const SizedBox(height: 10),
                    RPSPillButton(
                        label: 'Play Again',
                        onPressed: _playAgain,
                        isOutlined: true),
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

class _MoveResult extends StatelessWidget {
  const _MoveResult({
    required this.emoji,
    required this.name,
    required this.moveLabel,
    required this.isWinner,
    required this.floatAnim,
  });

  final String emoji;
  final String name;
  final String moveLabel;
  final bool isWinner;
  final Animation<double> floatAnim;

  @override
  Widget build(BuildContext context) {
    final moveColor = isWinner ? RPSTheme.purpleLight : const Color(0xFF06B6D4);
    return Expanded(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: floatAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, floatAnim.value),
              child: Text(emoji, style: const TextStyle(fontSize: 60)),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: RPSTheme.font(10,
              fw: FontWeight.w700, letterSpacing: 1.5, color: RPSTheme.muted)),
          Text(moveLabel, style: RPSTheme.font(13,
              fw: FontWeight.w700, letterSpacing: 1.2, color: moveColor)),
        ],
      ),
    );
  }
}

// ── Confetti painter ─────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);
  final double progress;

  static final _rng = Random(42);
  static final _colours = [
    RPSTheme.gold,
    RPSTheme.purpleLight,
    const Color(0xFF06B6D4),
    const Color(0xFFEC4899),
    const Color(0xFF22C55E),
    const Color(0xFFF97316),
    Colors.white,
  ];
  static final _pieces = List.generate(80, (_) => _Piece(
    x:     _rng.nextDouble(),
    startY: -0.1 - _rng.nextDouble() * 0.3,
    speed:  1.0 + _rng.nextDouble() * 2.4,
    color:  _colours[_rng.nextInt(_colours.length)],
    w: 3 + _rng.nextDouble() * 8,
    h: 2 + _rng.nextDouble() * 5,
    angle:  _rng.nextDouble() * pi * 2,
    spin:   (_rng.nextDouble() - 0.5) * 0.17,
    drift:  (_rng.nextDouble() - 0.5) * 0.75,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final y = (p.startY + progress * p.speed / 4) % 1.1;
      canvas.save();
      canvas.translate(p.x * size.width, y * size.height);
      canvas.rotate(p.angle + progress * p.spin * 10);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
        Paint()..color = p.color.withOpacity(0.85),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Piece {
  const _Piece({
    required this.x, required this.startY, required this.speed,
    required this.color, required this.w, required this.h,
    required this.angle, required this.spin, required this.drift,
  });
  final double x, startY, speed, w, h, angle, spin, drift;
  final Color color;
}
