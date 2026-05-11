// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Pick Move Screen
//  "Choose your move" glowing title, three floating hand
//  emojis centred on screen, "You chose X" reveal,
//  Lock in move button (disabled until pick made).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../data/rps_models.dart';
import '../data/rps_local_match_store.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_waiting_screen.dart';
import 'rps_intro_screen.dart';

class RPSPickScreen extends StatefulWidget {
  const RPSPickScreen({
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
  State<RPSPickScreen> createState() => _RPSPickScreenState();
}

class _RPSPickScreenState extends State<RPSPickScreen>
    with SingleTickerProviderStateMixin {
  RPSMove? _selected;
  bool _submitting = false;
  late final AnimationController _glowCtrl;

  final _store = RPSLocalMatchStore.instance;

  @override
  void initState() {
    super.initState();
    // Ensure game is initialised
    if (_store.moveForPlayer(widget.currentUserId) == null &&
        !_store.bothSubmitted) {
      _store.initGame(
        player1Id:   widget.currentUserId,
        player2Id:   widget.opponentId,
        player1Name: widget.currentUserName,
        player2Name: widget.opponentName,
      );
    }

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _glowCtrl.dispose(); super.dispose(); }

  Future<void> _lockIn() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    _store.submitMove(widget.currentUserId, _selected!);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RPSWaitingScreen(
        currentUserId:   widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId:      widget.opponentId,
        opponentName:    widget.opponentName,
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Nav
                    RPSNavBar(
                      onBack: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => RPSIntroScreen(
                          currentUserId:   widget.currentUserId,
                          currentUserName: widget.currentUserName,
                          opponentId:      widget.opponentId,
                          opponentName:    widget.opponentName,
                        )),
                      ),
                    ),

                    // "Choose your move" — glowing white
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) => Text(
                        'Choose your move',
                        textAlign: TextAlign.center,
                        style: RPSTheme.font(
                          32,
                          fw: FontWeight.w700,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: Colors.white.withOpacity(
                                  0.55 + _glowCtrl.value * 0.45),
                              blurRadius: 8 + _glowCtrl.value * 10,
                            ),
                            Shadow(
                              color: RPSTheme.purpleLight.withOpacity(
                                  0.3 + _glowCtrl.value * 0.3),
                              blurRadius: 20 + _glowCtrl.value * 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your pick stays hidden until both submit',
                      style: RPSTheme.font(12,
                          fw: FontWeight.w500, color: RPSTheme.muted),
                    ),

                    // Move cards — centred in remaining space
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RPSMoveCard(
                              emoji: RPSMove.rock.emoji,
                              label: 'ROCK',
                              isSelected: _selected == RPSMove.rock,
                              onTap: () => setState(() => _selected = RPSMove.rock),
                              animDelay: Duration.zero,
                              animDuration: const Duration(milliseconds: 2800),
                            ),
                            const SizedBox(width: 14),
                            RPSMoveCard(
                              emoji: RPSMove.paper.emoji,
                              label: 'PAPER',
                              isSelected: _selected == RPSMove.paper,
                              onTap: () => setState(() => _selected = RPSMove.paper),
                              animDelay: const Duration(milliseconds: 400),
                              animDuration: const Duration(milliseconds: 3200),
                            ),
                            const SizedBox(width: 14),
                            RPSMoveCard(
                              emoji: RPSMove.scissors.emoji,
                              label: 'SCISSORS',
                              isSelected: _selected == RPSMove.scissors,
                              onTap: () => setState(() => _selected = RPSMove.scissors),
                              animDelay: const Duration(milliseconds: 200),
                              animDuration: const Duration(milliseconds: 2600),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // "You chose X"
                    SizedBox(
                      height: 36,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _selected != null
                            ? Text(
                                key: ValueKey(_selected),
                                'You chose ${_selected!.label}',
                                style: RPSTheme.font(15,
                                    fw: FontWeight.w600,
                                    color: RPSTheme.purpleLight),
                              )
                            : const SizedBox(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Lock in button
                    RPSPillButton(
                      label: 'Lock in move',
                      onPressed: _selected != null ? _lockIn : null,
                      isLoading: _submitting,
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
}
