import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════
// SHARED BACKGROUND WIDGET
// ═══════════════════════════════════════════════════════
class MatchXPBackground extends StatelessWidget {
  final Widget child;
  const MatchXPBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: [0.0, 0.18, 0.38, 0.60, 0.82, 1.0],
              colors: [
                Color.fromARGB(255, 110, 29, 131),
                Color(0xFF2E0858),
                Color(0xFF180430),
                Color(0xFF0F0B1E),
                Color(0xFF0D0B14),
                Color(0xFF0C0B11),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.12, 0.22, 0.30],
              colors: [
                Color(0xCC0C0A12),
                Color(0x550C0A12),
                Color(0x110C0A12),
                Color(0x000C0A12),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
