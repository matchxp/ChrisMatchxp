/// emoji_charades_game_test.dart
///
/// Unit tests for Emoji Charades game logic — submission flags and
/// win/loss/draw outcomes.  No Supabase / widget context needed.
///
/// Run with:  flutter test test/emoji_charades_game_test.dart

import 'package:flutter_test/flutter_test.dart';

// ── Outcome enum (mirrors _Outcome in emoji_charades_game_screen.dart) ──────
enum EcOutcome { bothSolved, iSolvedTheySkipped, iSkippedTheySolved, bothSkipped }

// ── Minimal state model (mirrors _State getters) ─────────────────────────────
class EcGameState {
  bool iSubmitted;
  bool iSolved;
  bool iSkipped;
  Map<String, dynamic>? partnerRow;

  EcGameState({
    this.iSubmitted = false,
    this.iSolved    = false,
    this.iSkipped   = false,
    this.partnerRow,
  });

  bool get partnerSubmitted => partnerRow?['submitted'] == true;
  bool get partnerSolved    => partnerRow?['solved']    == true;
  bool get partnerSkipped   => partnerRow?['skipped']   == true;
  bool get partnerFinished  => partnerSolved || partnerSkipped;
  bool get bothSubmitted    => iSubmitted && partnerSubmitted;

  EcOutcome get outcome {
    if (iSolved  && partnerSolved)   return EcOutcome.bothSolved;
    if (iSolved  && partnerSkipped)  return EcOutcome.iSolvedTheySkipped;
    if (iSkipped && partnerSolved)   return EcOutcome.iSkippedTheySolved;
    return EcOutcome.bothSkipped;
  }

  void reset() {
    iSubmitted  = false;
    iSolved     = false;
    iSkipped    = false;
    partnerRow  = null;
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────
void main() {
  // TC-01: Submitted emojis are stored and reflected in bothSubmitted flag
  test('TC-01: Submitted emojis are stored and reflected in bothSubmitted flag', () {
    final state = EcGameState(
      iSubmitted: true,
      partnerRow: {'submitted': true, 'solved': false, 'skipped': false},
    );
    expect(state.iSubmitted,      isTrue);
    expect(state.partnerSubmitted, isTrue);
    expect(state.bothSubmitted,    isTrue);
  });

  // TC-02: p2 submits first → only p2 is marked submitted
  test('TC-02: p2 submits first → only p2 is marked submitted', () {
    final state = EcGameState(
      iSubmitted: false,
      partnerRow: {'submitted': true, 'solved': false, 'skipped': false},
    );
    expect(state.iSubmitted,      isFalse);
    expect(state.partnerSubmitted, isTrue);
    expect(state.bothSubmitted,    isFalse);
  });

  // TC-03: Both players solve → outcome is bothSolved
  test('TC-03: Both players solve → outcome is bothSolved', () {
    final state = EcGameState(
      iSolved:    true,
      partnerRow: {'submitted': true, 'solved': true, 'skipped': false},
    );
    expect(state.outcome, equals(EcOutcome.bothSolved));
  });

  // TC-04: p1 solves, p2 skips → outcome is iSolvedTheySkipped
  test('TC-04: p1 solves, p2 skips → outcome is iSolvedTheySkipped', () {
    final state = EcGameState(
      iSolved:    true,
      partnerRow: {'submitted': true, 'solved': false, 'skipped': true},
    );
    expect(state.outcome, equals(EcOutcome.iSolvedTheySkipped));
  });

  // TC-05: reset() clears all state so a new game starts clean
  test('TC-05: reset() clears all state so a new game starts clean', () {
    final state = EcGameState(
      iSubmitted: true,
      iSolved:    true,
      partnerRow: {'submitted': true, 'solved': true, 'skipped': false},
    );
    state.reset();
    expect(state.iSubmitted,   isFalse);
    expect(state.iSolved,      isFalse);
    expect(state.iSkipped,     isFalse);
    expect(state.partnerRow,   isNull);
    expect(state.bothSubmitted, isFalse);
  });
}
