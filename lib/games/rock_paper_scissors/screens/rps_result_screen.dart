// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Result Screen
//  You Win / You Lose / It's a Draw. Confetti on win only.
// ─────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../data/rps_models.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';

class RPSResultScreen extends StatefulWidget {
  const RPSResultScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.opponentId,
    required this.opponentName,
    required this.myMove,
    required this.opponentMove,
    required this.result,
    required this.onChatUnlocked,
    this.sessionId,
    this.popCount = 1,
    this.chatAlreadyUnlocked = false,
  });

  final String currentUserId;
  final String currentUserName;
  final String opponentId;
  final String opponentName;
  final RPSMove myMove;
  final RPSMove opponentMove;
  final RPSResult result;
  final VoidCallback onChatUnlocked;
  final String? sessionId;
  final int popCount;
  final bool chatAlreadyUnlocked;

  @override
  State<RPSResultScreen> createState() => _RPSResultScreenState();
}

class _RPSResultScreenState extends State<RPSResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _float1Ctrl;
  late final AnimationController _float2Ctrl;
  late final Animation<double> _float1;
  late final Animation<double> _float2;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();

    _float1Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _float1 = Tween<double>(begin: 0, end: -10)
        .animate(CurvedAnimation(parent: _float1Ctrl, curve: Curves.easeInOut));

    _float2Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400))
      ..repeat(reverse: true);
    _float2 = Tween<double>(begin: 0, end: -12)
        .animate(CurvedAnimation(parent: _float2Ctrl, curve: Curves.easeInOut));

    _confetti = ConfettiController(duration: const Duration(seconds: 6));
    if (widget.result == RPSResult.win) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _float1Ctrl.dispose();
    _float2Ctrl.dispose();
    _confetti.dispose();
    super.dispose();
  }

  RPSMove get myMove => widget.myMove;
  RPSMove get oppMove => widget.opponentMove;
  RPSResult get result => widget.result;

  String get outcomeText {
    switch (result) {
      case RPSResult.win:
        return 'You Win';
      case RPSResult.lose:
        return 'You Lose';
      case RPSResult.draw:
        return "It's a Draw";
    }
  }

  Color get outcomeColor {
    switch (result) {
      case RPSResult.win:
        return RPSTheme.gold;
      case RPSResult.lose:
        return RPSTheme.purpleLight;
      case RPSResult.draw:
        return Colors.white;
    }
  }

  String get reasonText {
    switch (result) {
      case RPSResult.win:
        return myMove.beatsLabel;
      case RPSResult.lose:
        return oppMove.beatsLabel;
      case RPSResult.draw:
        return 'GREAT MINDS THINK ALIKE!';
    }
  }

  /// Pop back to ChatConversationScreen and fire the unlock callback.
  void _startChat() {
    debugPrint('[RPS] Start Chatting tapped');
    int pops = 0;
    Navigator.of(context).popUntil((_) => pops++ >= widget.popCount);
    widget.onChatUnlocked();
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

              // Confetti raining from the top (win only)
              if (result == RPSResult.win)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confetti,
                      blastDirection: pi / 2,
                      numberOfParticles: 30,
                      gravity: 0.3,
                      colors: const [
                        RPSTheme.gold,
                        RPSTheme.purpleLight,
                        Color(0xFF06B6D4),
                        Color(0xFFEC4899),
                        Color(0xFF22C55E),
                        Color(0xFFF97316),
                        Colors.white,
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RPSNavBar(
                      onBack: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      outcomeText,
                      style: RPSTheme.font(44,
                              fw: FontWeight.w700, color: outcomeColor)
                          .copyWith(shadows: [
                        Shadow(
                          color: outcomeColor.withOpacity(0.5),
                          blurRadius: 28,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reasonText,
                      style: RPSTheme.font(10,
                          fw: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: RPSTheme.muted),
                    ),

                    const SizedBox(height: 60),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MoveResult(
                          emoji: myMove.emoji,
                          name: widget.currentUserName.toUpperCase(),
                          moveLabel: myMove.labelUpper,
                          isWinner: result == RPSResult.win ||
                              result == RPSResult.draw,
                          floatAnim: _float1,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Text(
                            ' VS ',
                            style: RPSTheme.font(14,
                                fw: FontWeight.w700, color: RPSTheme.muted),
                          ),
                        ),
                        _MoveResult(
                          emoji: oppMove.emoji,
                          name: widget.opponentName.toUpperCase(),
                          moveLabel: oppMove.labelUpper,
                          isWinner: result == RPSResult.lose ||
                              result == RPSResult.draw,
                          floatAnim: _float2,
                        ),
                      ],
                    ),

                    const Spacer(),

                    RPSPillButton(
                        label: widget.chatAlreadyUnlocked
                            ? 'Continue Chatting'
                            : 'Start Chatting',
                        onPressed: _startChat),
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
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: floatAnim,
              builder: (_, __) => Transform.translate(
                // Whole-pixel snap keeps the bitmap emoji crisp.
                offset: Offset(0, floatAnim.value.roundToDouble()),
                child: Text(emoji, style: const TextStyle(fontSize: 60)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: RPSTheme.font(10,
                fw: FontWeight.w700, letterSpacing: 1.5, color: RPSTheme.muted),
          ),
          Text(
            moveLabel,
            style: RPSTheme.font(13,
                fw: FontWeight.w700, letterSpacing: 1.2, color: moveColor),
          ),
        ],
      ),
    );
  }
}
