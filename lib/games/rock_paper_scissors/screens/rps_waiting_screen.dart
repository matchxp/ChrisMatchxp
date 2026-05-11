// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Waiting Screen
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../data/rps_models.dart';
import '../data/rps_local_match_store.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import 'rps_reveal_screen.dart';

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

    // Poll every 500 ms — in a real app replace with Supabase real-time
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
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
        opponentId: widget.opponentId,
        opponentName: widget.opponentName,
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RPSNavBar(
                      onBack: () {
                        // Cancel the opponent-poll, reset game state,
                        // then pop once to land back on GameHubScreen.
                        _poll?.cancel();
                        _store.reset();
                        Navigator.pop(context);
                      },
                    ),

                    const SizedBox(height: 48),
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) => Text(
                        'Move locked in',
                        style: RPSTheme.font(38, fw: FontWeight.w700)
                            .copyWith(shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(
                                0.55 + _glowCtrl.value * 0.45),
                            blurRadius: 8 + _glowCtrl.value * 10,
                          ),
                        ]),
                      ),
                    ),

                    // Ripple + floating emoji
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _ripple,
                            builder: (_, __) => Transform.scale(
                              scale: _ripple.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      RPSTheme.purple.withOpacity(0.12),
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _float,
                            builder: (_, __) => Transform.translate(
                              // Round to whole pixels so the emoji
                              // glyph isn't sub-pixel resampled.
                              offset:
                                  Offset(0, _float.value.roundToDouble()),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: RPSTheme.purple.withOpacity(0.5),
                                    width: 2,
                                  ),
                                  color: RPSTheme.purple.withOpacity(0.08),
                                ),
                                child: Center(
                                  child: RepaintBoundary(
                                    child: Text(
                                      (myMove ?? RPSMove.rock).emoji,
                                      style:
                                          const TextStyle(fontSize: 60),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text(
                      myMove != null ? 'You played ${myMove.label}' : '',
                      style: RPSTheme.font(20,
                          fw: FontWeight.w600, color: RPSTheme.purpleLight),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Waiting for ${widget.opponentName}...',
                      style: RPSTheme.font(18,
                          fw: FontWeight.w600, color: Colors.white70),
                    ),

                    // Status avatars right below the "Waiting for…" line,
                    // with a dotted line connecting the two circles.
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RPSStatusAvatar(
                            name: 'You',
                            initial: _initialOf(widget.currentUserName),
                            isMe: true,
                            done: true,
                          ),
                          // Dotted connector lines up with the centre of the
                          // 64-px avatar circles (avatar top + 32).
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 31),
                              child: _DottedLine(
                                color: _opponentReady
                                    ? _kGreen.withOpacity(0.6)
                                    : RPSTheme.purple.withOpacity(0.5),
                              ),
                            ),
                          ),
                          _RPSStatusAvatar(
                            name: widget.opponentName,
                            initial: _initialOf(widget.opponentName),
                            isMe: false,
                            done: _opponentReady,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
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

String _initialOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

const _kGreen = Color(0xFF39FF14);

/// Emoji-Charades–style status avatar. Big circle with an initial,
/// green ring + glow when done, pulsing dots while waiting.
class _RPSStatusAvatar extends StatelessWidget {
  const _RPSStatusAvatar({
    required this.name,
    required this.initial,
    required this.isMe,
    required this.done,
  });

  final String name;
  final String initial;
  final bool isMe;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isMe
                ? const LinearGradient(
                    colors: [Color(0xFF6930C3), Color(0xFF8B5CF6)])
                : null,
            color: isMe ? null : RPSTheme.bgCard,
            border: Border.all(
              color: done ? _kGreen : RPSTheme.purple.withOpacity(0.3),
              width: 3,
            ),
            boxShadow: done
                ? [BoxShadow(color: _kGreen.withOpacity(0.5), blurRadius: 16)]
                : null,
          ),
          child: Center(
            child: Text(initial,
                style: RPSTheme.font(26,
                    fw: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        done
            ? Text('✓',
                style: RPSTheme.font(18, fw: FontWeight.w700, color: _kGreen))
            : const _PulseDots(),
        const SizedBox(height: 6),
        Text(isMe ? 'You' : name,
            style: RPSTheme.font(15,
                fw: FontWeight.w500, color: RPSTheme.muted)),
      ],
    );
  }
}

class _PulseDots extends StatelessWidget {
  const _PulseDots();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => _PulseDot(delay: Duration(milliseconds: i * 280)),
        ),
      );
}

/// Horizontal dotted connector that fills its parent's width.
class _DottedLine extends StatelessWidget {
  const _DottedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          const dot = 3.0;
          const gap = 6.0;
          final count = (c.maxWidth / (dot + gap)).floor().clamp(1, 200);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          );
        },
      );
}

class _PulseDot extends StatefulWidget {
  final Duration delay;
  const _PulseDot({required this.delay});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFAB5CF5)
                .withOpacity(0.2 + 0.8 * _c.value),
          ),
        ),
      );
}
