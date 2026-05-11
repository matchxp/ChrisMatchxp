// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Shared Widgets
// ─────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../rps_theme.dart';

// ── Background (radial gradient) ─────────────────────────────────────────────

class RPSBackground extends StatelessWidget {
  const RPSBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: RPSTheme.bgDecoration,
        child: child,
      );
}

// ── Pill button ───────────────────────────────────────────────────────────────

class RPSPillButton extends StatelessWidget {
  const RPSPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: disabled ? 0.32 : 1.0,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: RPSTheme.pillRadius,
            gradient: isOutlined ? null : RPSTheme.pillGradient,
            border: isOutlined
                ? Border.all(color: RPSTheme.dimLine, width: 1.5)
                : null,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    label,
                    style: RPSTheme.font(
                      20,
                      fw: FontWeight.w700,
                      color: isOutlined ? RPSTheme.purpleLight : Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Nav bar ───────────────────────────────────────────────────────────────────

class RPSNavBar extends StatelessWidget {
  const RPSNavBar({
    super.key,
    this.onBack,
    this.title = 'ROCK PAPER SCISSORS',
  });
  final VoidCallback? onBack;
  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onBack,
                  child: const Icon(Icons.chevron_left,
                      color: RPSTheme.purpleLight, size: 26),
                ),
              ),
            Text(title, style: RPSTheme.navLabel),
          ],
        ),
      );
}

// ── Move card (floating hand emoji) ──────────────────────────────────────────
//  Float delay is applied via Future.delayed so each card starts its
//  repeat animation at a slightly different phase.

class RPSMoveCard extends StatefulWidget {
  const RPSMoveCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.animDelay = Duration.zero,
    this.animDuration = const Duration(milliseconds: 2800),
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animDelay;
  final Duration animDuration;

  @override
  State<RPSMoveCard> createState() => _RPSMoveCardState();
}

class _RPSMoveCardState extends State<RPSMoveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.animDuration);
    _float = Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Start repeat only AFTER the delay so cards float out of phase
    Future.delayed(widget.animDelay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates this card so its float animation never
    // triggers a repaint of siblings (other cards, glow blobs, etc.).
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _float,
          builder: (_, child) => Transform.translate(
            offset: widget.isSelected
                ? Offset.zero
                // Round to whole pixels — bitmap emojis blur when
                // they get sub-pixel-positioned by Transform.translate.
                : Offset(0, _float.value.roundToDouble()),
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: widget.isSelected ? 1.22 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: RepaintBoundary(
                  child: Text(
                    widget.emoji,
                    style: TextStyle(
                      fontSize: 78,
                      shadows: widget.isSelected
                          ? [
                              const Shadow(
                                  color: Colors.white70, blurRadius: 20),
                              Shadow(
                                color: RPSTheme.purpleLight.withOpacity(0.7),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: RPSTheme.font(
                  15,
                  fw: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: widget.isSelected
                      ? RPSTheme.purpleLight
                      : RPSTheme.muted,
                ),
                child: Text(widget.label),
              ),
            ],
          ),        // Column
        ),          // AnimatedBuilder
      ),            // GestureDetector
    );              // RepaintBoundary
  }
}

// ── Glow blobs ────────────────────────────────────────────────────────────────

class RPSGlowBlobs extends StatelessWidget {
  const RPSGlowBlobs({super.key});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned(
            top: -34,
            left: 0,
            right: 0,
            child: Center(
              child: _Blob(
                width: 170,
                height: 170,
                color: RPSTheme.blob1,
                ms: 4000,
                sigma: 38,
              ),
            ),
          ),
          Positioned(
            top: 190,
            left: 8,
            child: _Blob(
              width: 100,
              height: 100,
              color: RPSTheme.blob2,
              ms: 5000,
              sigma: 32,
            ),
          ),
          Positioned(
            top: 200,
            right: 8,
            child: _Blob(
              width: 90,
              height: 90,
              color: RPSTheme.blob3,
              ms: 4500,
              sigma: 30,
            ),
          ),
        ],
      );
}

class _Blob extends StatefulWidget {
  const _Blob({
    required this.width,
    required this.height,
    required this.color,
    required this.ms,
    required this.sigma,
  });
  final double width, height, sigma;
  final Color color;
  final int ms;

  @override
  State<_Blob> createState() => _BlobState();
}

class _BlobState extends State<_Blob> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: widget.ms))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 0.8)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The blur filter is constant — create it once in the `child` slot so it
    // is never rebuilt on animation frames. Only the Opacity value changes.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Opacity(opacity: _anim.value, child: child),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: widget.sigma,
            sigmaY: widget.sigma,
            tileMode: TileMode.decal,
          ),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
