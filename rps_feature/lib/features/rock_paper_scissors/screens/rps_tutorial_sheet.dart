// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Tutorial Bottom Sheet
//  Slides up from the bottom. Three numbered steps,
//  GOT IT pill button closes it.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';

class RPSTutorialSheet extends StatelessWidget {
  const RPSTutorialSheet({super.key});

  static const _steps = [
    (color: Color(0xFF06B6D4), text: 'Pick your move secretly'),
    (color: Color(0xFFEC4899), text: 'Wait for your match to submit theirs'),
    (color: Color(0xFF22C55E), text: 'Both moves reveal at the same time!'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RPSTheme.bgPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: RPSTheme.dimLine)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 34, height: 3,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: RPSTheme.dimLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            'HOW TO PLAY',
            style: RPSTheme.font(11,
                fw: FontWeight.w700,
                color: RPSTheme.purpleLight,
                letterSpacing: 2),
          ),
          const SizedBox(height: 14),

          // Steps
          ..._steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: e.value.color, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: RPSTheme.font(14,
                          fw: FontWeight.w700, color: e.value.color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.value.text,
                    style: RPSTheme.font(14,
                        fw: FontWeight.w600,
                        color: const Color(0xFFE2D9F3),
                        height: 1.3),
                  ),
                ),
              ],
            ),
          )),

          const SizedBox(height: 8),

          RPSPillButton(
            label: 'GOT IT',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
