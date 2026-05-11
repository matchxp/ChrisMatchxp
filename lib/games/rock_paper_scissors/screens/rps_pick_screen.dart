// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Pick Move Screen
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../data/rps_models.dart';
import '../data/rps_local_match_store.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_waiting_screen.dart';

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
    if (_store.moveForPlayer(widget.currentUserId) == null &&
        !_store.bothSubmitted) {
      _store.initGame(
        player1Id: widget.currentUserId,
        player2Id: widget.opponentId,
        player1Name: widget.currentUserName,
        player2Name: widget.opponentName,
      );
    }

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _lockIn() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    _store.submitMove(widget.currentUserId, _selected!);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RPSWaitingScreen(
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RPSNavBar(
                      onBack: () {
                        // Reset any partial move state, then go back to
                        // the Games hub (GameHubScreen is one pop away
                        // because all RPS screens use pushReplacement).
                        _store.reset();
                        Navigator.pop(context);
                      },
                    ),

                    const SizedBox(height: 36),
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) => Text(
                        'Choose your move',
                        textAlign: TextAlign.center,
                        style: RPSTheme.font(44, fw: FontWeight.w700)
                            .copyWith(shadows: [
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
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your pick stays hidden until both submit',
                      style: RPSTheme.font(15,
                          fw: FontWeight.w500, color: RPSTheme.muted),
                    ),

                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RPSMoveCard(
                              emoji: RPSMove.rock.emoji,
                              label: 'ROCK',
                              isSelected: _selected == RPSMove.rock,
                              onTap: () =>
                                  setState(() => _selected = RPSMove.rock),
                              animDelay: Duration.zero,
                              animDuration:
                                  const Duration(milliseconds: 2800),
                            ),
                            const SizedBox(width: 24),
                            RPSMoveCard(
                              emoji: RPSMove.paper.emoji,
                              label: 'PAPER',
                              isSelected: _selected == RPSMove.paper,
                              onTap: () =>
                                  setState(() => _selected = RPSMove.paper),
                              animDelay:
                                  const Duration(milliseconds: 400),
                              animDuration:
                                  const Duration(milliseconds: 3200),
                            ),
                            const SizedBox(width: 24),
                            RPSMoveCard(
                              emoji: RPSMove.scissors.emoji,
                              label: 'SCISSORS',
                              isSelected: _selected == RPSMove.scissors,
                              onTap: () =>
                                  setState(() => _selected = RPSMove.scissors),
                              animDelay:
                                  const Duration(milliseconds: 200),
                              animDuration:
                                  const Duration(milliseconds: 2600),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      height: 44,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _selected != null
                            ? Text(
                                key: ValueKey(_selected),
                                'You chose ${_selected!.label}',
                                style: RPSTheme.font(18,
                                    fw: FontWeight.w600,
                                    color: RPSTheme.purpleLight),
                              )
                            : const SizedBox(),
                      ),
                    ),
                    const SizedBox(height: 22),

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
