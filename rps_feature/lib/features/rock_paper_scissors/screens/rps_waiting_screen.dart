// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Waiting Screen  (v2 — FIXED)
//
//  FIX 4: Status row was double-padded (80px inner + 32px outer
//  = 112 px from screen bottom — too high). Now uses a single
//  SizedBox(height: 48) gap above the row + the 32px screen
//  bottom padding = 80px total from bottom, matching the demo.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../data/rps_local_match_store.dart';
import '../data/rps_models.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_reveal_screen.dart';
import 'rps_pick_screen.dart';

class RPSWaitingScreen extends StatefulWidget {
  const RPSWaitingScreen({
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
  State<RPSWaitingScreen> createState() => _RPSWaitingScreenState();
}

class _RPSWaitingScreenState extends State<RPSWaitingScreen>
    with TickerProviderStateMixin {
  final _store = RPSLocalMatchStore.instance;
  Timer? _poll;

  late final AnimationController _rippleCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _ripple;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _ripple = Tween(begin: 0.88, end: 1.18).animate(
        CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeInOut));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -10).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);

    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_store.bothSubmitted) {
        _poll?.cancel();
        _goReveal();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _rippleCtrl.dispose();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _goReveal() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RPSRevealScreen(
        currentUserId:   widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId:      widget.opponentId,
        opponentName:    widget.opponentName,
      ),
    ));
  }

  bool get _opponentReady => _store.hasSubmitted(widget.opponentId);

  @override
  Widget build(BuildContext context) {
    final myMove = _store.moveForPlayer(widget.currentUserId);

    return Scaffold(
      backgroundColor: RPSTheme.bg,
      body: RPSBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const RPSGlowBlobs(),
              Padding(
                // FIX 4: 32px bottom only — status row uses SizedBox gap below
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    RPSNavBar(
                      onBack: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => RPSPickScreen(
                          currentUserId:   widget.currentUserId,
                          currentUserName: widget.currentUserName,
                          opponentId:      widget.opponentId,
                          opponentName:    widget.opponentName,
                        )),
                      ),
                    ),

                    // 2-line gap before "Move locked in"
                    const SizedBox(height: 36),
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) => Text(
                        'Move locked in',
                        style: RPSTheme.font(28, fw: FontWeight.w700)
                            .copyWith(
                          shadows: [
                            Shadow(
                              color: Colors.white.withOpacity(
                                  0.55 + _glowCtrl.value * 0.45),
                              blurRadius: 8 + _glowCtrl.value * 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ripple + floating emoji
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 120, height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _ripple,
                            builder: (_, __) => Transform.scale(
                              scale: _ripple.value,
                              child: Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: RPSTheme.purple.withOpacity(0.12),
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _float,
                            builder: (_, __) => Transform.translate(
                              offset: Offset(0, _float.value),
                              child: Container(
                                width: 90, height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: RPSTheme.purple.withOpacity(0.5),
                                      width: 2),
                                  color: RPSTheme.purple.withOpacity(0.08),
                                ),
                                child: Center(
                                  child: Text(
                                    myMove?.emoji ?? '✊',
                                    style: const TextStyle(fontSize: 42),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),
                    Text(
                      'You played ${myMove?.label ?? ''}',
                      style: RPSTheme.font(15,
                          fw: FontWeight.w600, color: RPSTheme.purpleLight),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Waiting for ${widget.opponentName}...',
                      style: RPSTheme.font(15,
                          fw: FontWeight.w600, color: Colors.white70),
                    ),

                    // Spacer + 48px gap above status row
                    // Total from screen bottom = 48 + 32 (padding) = 80px ✓
                    const Spacer(),
                    const SizedBox(height: 48),

                    // Status row
                    Row(
                      children: [
                        _StatusBadge(
                          name: widget.currentUserName,
                          isReady: true,
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.only(bottom: 16),
                            color: RPSTheme.dimLine,
                          ),
                        ),
                        _StatusBadge(
                          name: widget.opponentName,
                          isReady: _opponentReady,
                        ),
                      ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.name, required this.isReady});
  final String name;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? RPSTheme.purpleLight : RPSTheme.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            color: isReady ? color.withOpacity(0.12) : Colors.transparent,
          ),
          child: Center(
            child: Icon(
              isReady ? Icons.check_rounded : Icons.hourglass_empty_rounded,
              color: color, size: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name.toUpperCase(),
          style: RPSTheme.font(11,
              fw: FontWeight.w700, letterSpacing: 1, color: color),
        ),
        Text(
          isReady ? 'Ready' : 'Thinking',
          style: RPSTheme.font(10, fw: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
