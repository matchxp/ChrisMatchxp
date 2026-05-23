/// word_search_logic_test.dart
///
/// 5 unit tests for Word Search game logic — word validation and win/loss/draw
/// outcomes. No Supabase / widget context needed.
///
/// Run with:  flutter test test/word_search_logic_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:matchx_auth/games/word_search/word_search_data.dart';
import 'package:matchx_auth/games/word_search/word_search_models.dart';

// ── Logic mirrored from word_search_supabase_wrapper.dart ─────────────────
// _recordScoreIfNeeded outcome computation (pure logic, no widget needed).
({bool iWon, bool isDraw}) computeOutcome(MatchGamesSnapshot snap) {
  final pg = snap.partnerGame!;
  final mg = snap.myGame!;
  final iSkipped       = pg.isSkipped; // I skipped partner's puzzle
  final partnerSkipped = mg.isSkipped; // partner skipped my puzzle
  final iWon  = !iSkipped && partnerSkipped;
  final isDraw = iSkipped == partnerSkipped;
  return (iWon: iWon, isDraw: isDraw);
}

// Helper: minimal WordSearchGame with a given status
WordSearchGame _game(GameStatus status) => WordSearchGame(
      id:        'g',
      matchId:   'm',
      creatorId: 'a',
      solverId:  'b',
      topic:     'animals',
      word:      'DOG',
      grid:      List.generate(4, (_) => List.filled(4, 'X')),
      wordPath:  [const GridPosition(0, 0)],
      status:    status,
      createdAt: DateTime(2026),
    );

void main() {
  // TC-01: Valid word recognised in its category
  test('TC-01 · valid word returns true for correct category', () {
    expect(WordSearchData.isValid('DOG', 'animals'), isTrue);
  });

  // TC-02: I solved partner's puzzle, partner skipped mine → I win
  test('TC-02 · user wins when they solved and partner skipped', () {
    final snap = MatchGamesSnapshot(
      myGame:      _game(GameStatus.skipped), // partner skipped my puzzle
      partnerGame: _game(GameStatus.solved),  // I solved partner's puzzle
    );
    final result = computeOutcome(snap);
    expect(result.iWon, isTrue);
    expect(result.isDraw, isFalse);
  });

  // TC-03: I skipped, partner solved → I lose
  test('TC-03 · user loses when they skipped and partner solved', () {
    final snap = MatchGamesSnapshot(
      myGame:      _game(GameStatus.solved),  // partner solved my puzzle
      partnerGame: _game(GameStatus.skipped), // I skipped partner's puzzle
    );
    final result = computeOutcome(snap);
    expect(result.iWon, isFalse);
    expect(result.isDraw, isFalse);
  });

  // TC-04: Both skip → draw
  test('TC-04 · draw when both players skip', () {
    final snap = MatchGamesSnapshot(
      myGame:      _game(GameStatus.skipped),
      partnerGame: _game(GameStatus.skipped),
    );
    final result = computeOutcome(snap);
    expect(result.isDraw, isTrue);
  });

  // TC-05: Both solve → draw
  test('TC-05 · draw when both players solve', () {
    final snap = MatchGamesSnapshot(
      myGame:      _game(GameStatus.solved),
      partnerGame: _game(GameStatus.solved),
    );
    final result = computeOutcome(snap);
    expect(result.isDraw, isTrue);
  });
}
