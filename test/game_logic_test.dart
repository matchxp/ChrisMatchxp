// ignore_for_file: prefer_function_declarations_over_variables

/// game_logic_test.dart
///
/// Unit tests for the pure-logic functions used across all game screens
/// (Word Search, Rock Paper Scissors, Emoji Charades) and the chat helper
/// ChatService.formatTimestamp.
///
/// No Supabase / Flutter widget rendering is needed — all tests run as
/// plain unit tests that exercise data models, state transitions, and
/// pure-function helpers.
///
/// Run with:  flutter test test/game_logic_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:matchx_auth/games/word_search/word_search_models.dart';
import 'package:matchx_auth/games/word_search/word_search_data.dart';
import 'package:matchx_auth/games/rock_paper_scissors/data/rps_models.dart';
import 'package:matchx_auth/games/rock_paper_scissors/data/rps_local_match_store.dart';
import 'package:matchx_auth/games/emoji_charades/emoji_charades_data.dart';

// =============================================================================
// ── ChatService.formatTimestamp (copied verbatim — has Supabase dep) ────────
// =============================================================================

/// Mirrors ChatService.formatTimestamp exactly.
String formatTimestamp(String? isoTimestamp) {
  if (isoTimestamp == null) return '';
  final dateTime = DateTime.parse(isoTimestamp).toLocal();
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dateTime.day}/${dateTime.month}';
}

// =============================================================================
// ── Helper: construct a minimal WordSearchGame from a JSON-like map ──────────
// =============================================================================

WordSearchGame _makeGame({
  required String id,
  required String creatorId,
  required String solverId,
  String status = 'waiting',
  String? solvedAt,
}) {
  // Use explicit dynamic lists so WordSearchGame.fromJson casts succeed cleanly.
  return WordSearchGame.fromJson(<String, dynamic>{
    'id': id,
    'match_id': 'match-001',
    'creator_id': creatorId,
    'solver_id': solverId,
    'topic': 'animals',
    'word': 'dog', // intentionally lowercase to verify uppercasing
    'grid': <dynamic>[
      <dynamic>['D', 'O', 'G', 'A'],
      <dynamic>['B', 'C', 'D', 'E'],
      <dynamic>['F', 'G', 'H', 'I'],
      <dynamic>['J', 'K', 'L', 'M'],
    ],
    'word_path': <dynamic>[
      <String, dynamic>{'row': 0, 'col': 0},
      <String, dynamic>{'row': 0, 'col': 1},
      <String, dynamic>{'row': 0, 'col': 2},
    ],
    'status': status,
    'created_at': '2026-05-14T10:00:00.000Z',
    'solved_at': solvedAt,
  });
}

// =============================================================================
// ── Tests ─────────────────────────────────────────────────────────────────────
// =============================================================================

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — Word Search: GridPosition
  // ═══════════════════════════════════════════════════════════════════════════

  group('GridPosition', () {
    // -------------------------------------------------------------------------
    // TC-WS-01  Horizontal neighbour
    // -------------------------------------------------------------------------
    test('TC-WS-01 · isAdjacentTo returns true for a horizontal neighbour', () {
      const a = GridPosition(2, 2);
      const b = GridPosition(2, 3);
      expect(a.isAdjacentTo(b), isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-02  Vertical neighbour
    // -------------------------------------------------------------------------
    test('TC-WS-02 · isAdjacentTo returns true for a vertical neighbour', () {
      const a = GridPosition(1, 1);
      const b = GridPosition(2, 1);
      expect(a.isAdjacentTo(b), isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-03  Diagonal neighbour
    // -------------------------------------------------------------------------
    test('TC-WS-03 · isAdjacentTo returns true for a diagonal neighbour', () {
      const a = GridPosition(0, 0);
      const b = GridPosition(1, 1);
      expect(a.isAdjacentTo(b), isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-04  Same cell is NOT adjacent to itself
    // -------------------------------------------------------------------------
    test('TC-WS-04 · isAdjacentTo returns false when both positions are the same cell', () {
      const a = GridPosition(2, 2);
      expect(a.isAdjacentTo(a), isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-WS-05  Two steps away is NOT adjacent
    // -------------------------------------------------------------------------
    test('TC-WS-05 · isAdjacentTo returns false when cells are 2 apart', () {
      const a = GridPosition(0, 0);
      const b = GridPosition(0, 2);
      expect(a.isAdjacentTo(b), isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-WS-06  Equality — same position
    // -------------------------------------------------------------------------
    test('TC-WS-06 · == returns true for two GridPositions with the same row and col', () {
      const a = GridPosition(1, 3);
      const b = GridPosition(1, 3);
      expect(a, equals(b));
    });

    // -------------------------------------------------------------------------
    // TC-WS-07  Equality — different position
    // -------------------------------------------------------------------------
    test('TC-WS-07 · == returns false for GridPositions with different row or col', () {
      const a = GridPosition(1, 3);
      const b = GridPosition(1, 2);
      expect(a, isNot(equals(b)));
    });

    // -------------------------------------------------------------------------
    // TC-WS-08  toJson / fromJson round-trip
    // -------------------------------------------------------------------------
    test('TC-WS-08 · GridPosition survives a toJson → fromJson round-trip', () {
      const original = GridPosition(3, 1);
      final roundTripped = GridPosition.fromJson(original.toJson());
      expect(roundTripped, equals(original));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — Word Search: WordSearchGame.fromJson / isSolved
  // ═══════════════════════════════════════════════════════════════════════════

  group('WordSearchGame', () {
    // -------------------------------------------------------------------------
    // TC-WS-09  'waiting' status → isSolved is false
    // -------------------------------------------------------------------------
    test('TC-WS-09 · isSolved is false when status is "waiting"', () {
      final game = _makeGame(id: 'g1', creatorId: 'u1', solverId: 'u2');
      expect(game.isSolved, isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-WS-10  'solved' status → isSolved is true
    // -------------------------------------------------------------------------
    test('TC-WS-10 · isSolved is true when status is "solved"', () {
      final game = _makeGame(
        id: 'g2',
        creatorId: 'u1',
        solverId: 'u2',
        status: 'solved',
        solvedAt: '2026-05-14T11:00:00.000Z',
      );
      expect(game.isSolved, isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-11  Word is stored uppercase regardless of input case
    // -------------------------------------------------------------------------
    test('TC-WS-11 · fromJson uppercases the word field', () {
      final game = _makeGame(id: 'g3', creatorId: 'u1', solverId: 'u2');
      expect(game.word, equals('DOG'));
    });

    // -------------------------------------------------------------------------
    // TC-WS-12  wordPath length matches word length
    // -------------------------------------------------------------------------
    test('TC-WS-12 · fromJson produces a wordPath with one position per letter', () {
      final game = _makeGame(id: 'g4', creatorId: 'u1', solverId: 'u2');
      expect(game.wordPath.length, equals(game.word.length));
    });

    // -------------------------------------------------------------------------
    // TC-WS-13  solvedAt is null when not solved
    // -------------------------------------------------------------------------
    test('TC-WS-13 · solvedAt is null for a waiting game', () {
      final game = _makeGame(id: 'g5', creatorId: 'u1', solverId: 'u2');
      expect(game.solvedAt, isNull);
    });

    // -------------------------------------------------------------------------
    // TC-WS-14  solvedAt is parsed correctly when present
    // -------------------------------------------------------------------------
    test('TC-WS-14 · solvedAt is non-null and parses correctly when present', () {
      final game = _makeGame(
        id: 'g6',
        creatorId: 'u1',
        solverId: 'u2',
        status: 'solved',
        solvedAt: '2026-05-14T11:30:00.000Z',
      );
      expect(game.solvedAt, isNotNull);
      expect(game.solvedAt!.year, equals(2026));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — Word Search: MatchGamesSnapshot.phase
  // ═══════════════════════════════════════════════════════════════════════════

  group('MatchGamesSnapshot.phase', () {
    const myId      = 'user-me';
    const partnerId = 'user-partner';

    // -------------------------------------------------------------------------
    // TC-WS-15  No puzzle submitted yet → setup
    // -------------------------------------------------------------------------
    test('TC-WS-15 · phase is setup when myGame is null', () {
      const snap = MatchGamesSnapshot(myGame: null, partnerGame: null);
      expect(snap.phase, equals(MatchGamePhase.setup));
    });

    // -------------------------------------------------------------------------
    // TC-WS-16  I submitted, partner hasn't yet → waitingPartnerSetup
    // -------------------------------------------------------------------------
    test('TC-WS-16 · phase is waitingPartnerSetup when only myGame exists', () {
      final myGame = _makeGame(
        id: 'my-game', creatorId: myId, solverId: partnerId,
      );
      final snap = MatchGamesSnapshot(myGame: myGame, partnerGame: null);
      expect(snap.phase, equals(MatchGamePhase.waitingPartnerSetup));
    });

    // -------------------------------------------------------------------------
    // TC-WS-17  Both submitted, neither solved → solving
    // -------------------------------------------------------------------------
    test('TC-WS-17 · phase is solving when both games exist and neither is solved', () {
      final myGame = _makeGame(
        id: 'my-game', creatorId: myId, solverId: partnerId,
      );
      // partnerGame: created by partner, solved BY ME (solver_id = myId)
      final partnerGame = _makeGame(
        id: 'partner-game', creatorId: partnerId, solverId: myId,
      );
      final snap = MatchGamesSnapshot(myGame: myGame, partnerGame: partnerGame);
      expect(snap.phase, equals(MatchGamePhase.solving));
    });

    // -------------------------------------------------------------------------
    // TC-WS-18  I solved partner's puzzle, partner hasn't solved mine → waitingPartnerSolve
    // -------------------------------------------------------------------------
    test('TC-WS-18 · phase is waitingPartnerSolve when I solved but partner has not', () {
      final myGame = _makeGame(
        id: 'my-game', creatorId: myId, solverId: partnerId,
        // partnerSolved = myGame.isSolved → partner solved MY game → still false
        status: 'waiting',
      );
      final partnerGame = _makeGame(
        id: 'partner-game', creatorId: partnerId, solverId: myId,
        // iSolved = partnerGame.isSolved → I solved PARTNER'S game → true
        status: 'solved',
        solvedAt: '2026-05-14T12:00:00.000Z',
      );
      final snap = MatchGamesSnapshot(myGame: myGame, partnerGame: partnerGame);
      expect(snap.phase, equals(MatchGamePhase.waitingPartnerSolve));
    });

    // -------------------------------------------------------------------------
    // TC-WS-19  Both solved → bothSolved
    // -------------------------------------------------------------------------
    test('TC-WS-19 · phase is bothSolved when both games are marked solved', () {
      final myGame = _makeGame(
        id: 'my-game', creatorId: myId, solverId: partnerId,
        status: 'solved', solvedAt: '2026-05-14T12:00:00.000Z',
      );
      final partnerGame = _makeGame(
        id: 'partner-game', creatorId: partnerId, solverId: myId,
        status: 'solved', solvedAt: '2026-05-14T12:05:00.000Z',
      );
      final snap = MatchGamesSnapshot(myGame: myGame, partnerGame: partnerGame);
      expect(snap.phase, equals(MatchGamePhase.bothSolved));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4 — Word Search: WordSearchData grid generation & helpers
  // ═══════════════════════════════════════════════════════════════════════════

  group('WordSearchData.generateGrid', () {
    // -------------------------------------------------------------------------
    // TC-WS-20  Generated grid is 4×4
    // -------------------------------------------------------------------------
    test('TC-WS-20 · generateGrid returns a 4×4 grid', () {
      final result = WordSearchData.generateGrid('DOG');
      expect(result.grid.length, equals(4));
      for (final row in result.grid) {
        expect(row.length, equals(4));
      }
    });

    // -------------------------------------------------------------------------
    // TC-WS-21  Word cells list length equals word length
    // -------------------------------------------------------------------------
    test('TC-WS-21 · wc (word cell path) length equals the word length', () {
      const word = 'LION';
      final result = WordSearchData.generateGrid(word);
      expect(result.wc.length, equals(word.length));
    });

    // -------------------------------------------------------------------------
    // TC-WS-22  Grid has no empty cells
    // -------------------------------------------------------------------------
    test('TC-WS-22 · every cell in the generated grid is non-empty', () {
      final result = WordSearchData.generateGrid('CAT');
      for (final row in result.grid) {
        for (final cell in row) {
          expect(cell.isNotEmpty, isTrue,
              reason: 'Found an empty cell in the generated grid');
        }
      }
    });

    // -------------------------------------------------------------------------
    // TC-WS-23  Word letters appear at their declared wc positions
    // -------------------------------------------------------------------------
    test('TC-WS-23 · each letter of the word appears at its wc position in the grid', () {
      const word = 'BEAR';
      final result = WordSearchData.generateGrid(word);
      for (int i = 0; i < word.length; i++) {
        final r = result.wc[i][0];
        final c = result.wc[i][1];
        expect(result.grid[r][c], equals(word[i]),
            reason: 'Letter ${word[i]} not found at wc[$i] = ($r, $c)');
      }
    });

    // -------------------------------------------------------------------------
    // TC-WS-24  Consecutive wc positions are adjacent in the grid
    // -------------------------------------------------------------------------
    test('TC-WS-24 · consecutive word-cell positions are adjacent (≤1 step apart)', () {
      final result = WordSearchData.generateGrid('WOLF');
      for (int i = 1; i < result.wc.length; i++) {
        final a = result.wc[i - 1];
        final b = result.wc[i];
        expect(WordSearchData.isAdjacent(a, b), isTrue,
            reason: 'wc[$i - 1]=$a and wc[$i]=$b are not adjacent');
      }
    });

    // -------------------------------------------------------------------------
    // TC-WS-25  Single-letter word produces a path of length 1
    // -------------------------------------------------------------------------
    test('TC-WS-25 · single-letter word produces a wc path of length 1', () {
      final result = WordSearchData.generateGrid('A');
      expect(result.wc.length, equals(1));
    });
  });

  group('WordSearchData.isValid', () {
    // -------------------------------------------------------------------------
    // TC-WS-26  Known word in its category → valid
    // -------------------------------------------------------------------------
    test('TC-WS-26 · isValid returns true for a word in its category', () {
      expect(WordSearchData.isValid('DOG', 'animals'), isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-27  Word not in category → invalid
    // -------------------------------------------------------------------------
    test('TC-WS-27 · isValid returns false for a word absent from its category', () {
      expect(WordSearchData.isValid('PIZZA', 'animals'), isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-WS-28  isValid is case-insensitive
    // -------------------------------------------------------------------------
    test('TC-WS-28 · isValid accepts lowercase input', () {
      expect(WordSearchData.isValid('dog', 'animals'), isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-29  Unknown category → invalid
    // -------------------------------------------------------------------------
    test('TC-WS-29 · isValid returns false for an unknown category key', () {
      expect(WordSearchData.isValid('DOG', 'nonexistent_category'), isFalse);
    });
  });

  group('WordSearchData.isAdjacent', () {
    // -------------------------------------------------------------------------
    // TC-WS-30  Same cell is NOT adjacent
    // -------------------------------------------------------------------------
    test('TC-WS-30 · isAdjacent returns false when both lists point to the same cell', () {
      expect(WordSearchData.isAdjacent([1, 1], [1, 1]), isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-WS-31  Diagonal neighbour is adjacent
    // -------------------------------------------------------------------------
    test('TC-WS-31 · isAdjacent returns true for a diagonal neighbour', () {
      expect(WordSearchData.isAdjacent([0, 0], [1, 1]), isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-WS-32  Two steps away is NOT adjacent
    // -------------------------------------------------------------------------
    test('TC-WS-32 · isAdjacent returns false when cells are 2 or more steps apart', () {
      expect(WordSearchData.isAdjacent([0, 0], [0, 2]), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5 — Rock Paper Scissors: computeResult
  // ═══════════════════════════════════════════════════════════════════════════

  group('computeResult — all nine move combinations', () {
    // -------------------------------------------------------------------------
    // TC-RPS-01  Draws
    // -------------------------------------------------------------------------
    test('TC-RPS-01 · rock vs rock → draw', () {
      expect(computeResult(RPSMove.rock, RPSMove.rock), equals(RPSResult.draw));
    });

    test('TC-RPS-02 · paper vs paper → draw', () {
      expect(computeResult(RPSMove.paper, RPSMove.paper), equals(RPSResult.draw));
    });

    test('TC-RPS-03 · scissors vs scissors → draw', () {
      expect(computeResult(RPSMove.scissors, RPSMove.scissors),
          equals(RPSResult.draw));
    });

    // -------------------------------------------------------------------------
    // TC-RPS-04 to TC-RPS-06  Wins
    // -------------------------------------------------------------------------
    test('TC-RPS-04 · rock vs scissors → win', () {
      expect(computeResult(RPSMove.rock, RPSMove.scissors), equals(RPSResult.win));
    });

    test('TC-RPS-05 · paper vs rock → win', () {
      expect(computeResult(RPSMove.paper, RPSMove.rock), equals(RPSResult.win));
    });

    test('TC-RPS-06 · scissors vs paper → win', () {
      expect(computeResult(RPSMove.scissors, RPSMove.paper), equals(RPSResult.win));
    });

    // -------------------------------------------------------------------------
    // TC-RPS-07 to TC-RPS-09  Losses
    // -------------------------------------------------------------------------
    test('TC-RPS-07 · rock vs paper → lose', () {
      expect(computeResult(RPSMove.rock, RPSMove.paper), equals(RPSResult.lose));
    });

    test('TC-RPS-08 · paper vs scissors → lose', () {
      expect(computeResult(RPSMove.paper, RPSMove.scissors), equals(RPSResult.lose));
    });

    test('TC-RPS-09 · scissors vs rock → lose', () {
      expect(computeResult(RPSMove.scissors, RPSMove.rock), equals(RPSResult.lose));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6 — Rock Paper Scissors: RPSMove extensions
  // ═══════════════════════════════════════════════════════════════════════════

  group('RPSMove extensions', () {
    // -------------------------------------------------------------------------
    // TC-RPS-10  Emoji values
    // -------------------------------------------------------------------------
    test('TC-RPS-10 · rock.emoji is ✊', () {
      expect(RPSMove.rock.emoji, equals('✊'));
    });

    test('TC-RPS-11 · paper.emoji is 🖐️', () {
      expect(RPSMove.paper.emoji, equals('🖐️'));
    });

    test('TC-RPS-12 · scissors.emoji is ✌️', () {
      expect(RPSMove.scissors.emoji, equals('✌️'));
    });

    // -------------------------------------------------------------------------
    // TC-RPS-13  Label / labelUpper
    // -------------------------------------------------------------------------
    test('TC-RPS-13 · label values are title-cased move names', () {
      expect(RPSMove.rock.label, equals('Rock'));
      expect(RPSMove.paper.label, equals('Paper'));
      expect(RPSMove.scissors.label, equals('Scissors'));
    });

    test('TC-RPS-14 · labelUpper equals label.toUpperCase()', () {
      for (final move in RPSMove.values) {
        expect(move.labelUpper, equals(move.label.toUpperCase()));
      }
    });

    // -------------------------------------------------------------------------
    // TC-RPS-15  beats relationships
    // -------------------------------------------------------------------------
    test('TC-RPS-15 · rock.beats is scissors', () {
      expect(RPSMove.rock.beats, equals(RPSMove.scissors));
    });

    test('TC-RPS-16 · paper.beats is rock', () {
      expect(RPSMove.paper.beats, equals(RPSMove.rock));
    });

    test('TC-RPS-17 · scissors.beats is paper', () {
      expect(RPSMove.scissors.beats, equals(RPSMove.paper));
    });

    // -------------------------------------------------------------------------
    // TC-RPS-18  beatsLabel contains the correct move names
    // -------------------------------------------------------------------------
    test('TC-RPS-18 · beatsLabel for each move mentions both the winner and loser', () {
      expect(RPSMove.rock.beatsLabel, contains('ROCK'));
      expect(RPSMove.rock.beatsLabel, contains('SCISSORS'));

      expect(RPSMove.paper.beatsLabel, contains('PAPER'));
      expect(RPSMove.paper.beatsLabel, contains('ROCK'));

      expect(RPSMove.scissors.beatsLabel, contains('SCISSORS'));
      expect(RPSMove.scissors.beatsLabel, contains('PAPER'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7 — Rock Paper Scissors: RPSLocalMatchStore
  // ═══════════════════════════════════════════════════════════════════════════

  group('RPSLocalMatchStore', () {
    const p1 = 'player-1';
    const p2 = 'player-2';

    setUp(() {
      // Always start from a clean state so tests are independent
      RPSLocalMatchStore.instance.reset();
    });

    // -------------------------------------------------------------------------
    // TC-RPS-19  submitMove returns false before initGame
    // -------------------------------------------------------------------------
    test('TC-RPS-19 · submitMove returns false before the game is initialised', () {
      expect(
        RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    // TC-RPS-20  Only player1 submitted → bothSubmitted is false
    // -------------------------------------------------------------------------
    test('TC-RPS-20 · bothSubmitted is false after only player1 submits', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock);
      expect(RPSLocalMatchStore.instance.bothSubmitted, isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-RPS-21  Both submitted → bothSubmitted is true
    // -------------------------------------------------------------------------
    test('TC-RPS-21 · bothSubmitted is true after both players submit', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock);
      RPSLocalMatchStore.instance.submitMove(p2, RPSMove.scissors);
      expect(RPSLocalMatchStore.instance.bothSubmitted, isTrue);
    });

    // -------------------------------------------------------------------------
    // TC-RPS-22  hasSubmitted reflects individual submission state
    // -------------------------------------------------------------------------
    test('TC-RPS-22 · hasSubmitted is false for a player who has not yet submitted', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      expect(RPSLocalMatchStore.instance.hasSubmitted(p1), isFalse);
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.paper);
      expect(RPSLocalMatchStore.instance.hasSubmitted(p1), isTrue);
      expect(RPSLocalMatchStore.instance.hasSubmitted(p2), isFalse);
    });

    // -------------------------------------------------------------------------
    // TC-RPS-23  resultForPlayer is null until both submit
    // -------------------------------------------------------------------------
    test('TC-RPS-23 · resultForPlayer returns null when only one player has submitted', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock);
      expect(RPSLocalMatchStore.instance.resultForPlayer(p1), isNull);
    });

    // -------------------------------------------------------------------------
    // TC-RPS-24  resultForPlayer returns correct win after both submit
    // -------------------------------------------------------------------------
    test('TC-RPS-24 · resultForPlayer returns win for rock when opponent picked scissors', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock);
      RPSLocalMatchStore.instance.submitMove(p2, RPSMove.scissors);
      expect(
        RPSLocalMatchStore.instance.resultForPlayer(p1),
        equals(RPSResult.win),
      );
    });

    // -------------------------------------------------------------------------
    // TC-RPS-25  resultForPlayer returns draw when moves match
    // -------------------------------------------------------------------------
    test('TC-RPS-25 · resultForPlayer returns draw when both players pick the same move', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.paper);
      RPSLocalMatchStore.instance.submitMove(p2, RPSMove.paper);
      expect(
        RPSLocalMatchStore.instance.resultForPlayer(p1),
        equals(RPSResult.draw),
      );
    });

    // -------------------------------------------------------------------------
    // TC-RPS-26  Results are symmetric: p1's win == p2's loss
    // -------------------------------------------------------------------------
    test('TC-RPS-26 · results are symmetric — p1 win means p2 lose', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.scissors);
      RPSLocalMatchStore.instance.submitMove(p2, RPSMove.paper);

      expect(RPSLocalMatchStore.instance.resultForPlayer(p1), equals(RPSResult.win));
      expect(RPSLocalMatchStore.instance.resultForPlayer(p2), equals(RPSResult.lose));
    });

    // -------------------------------------------------------------------------
    // TC-RPS-27  opponentNameForPlayer returns the correct name
    // -------------------------------------------------------------------------
    test('TC-RPS-27 · opponentNameForPlayer returns the opposing player name', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      expect(
        RPSLocalMatchStore.instance.opponentNameForPlayer(p1),
        equals('Bob'),
      );
      expect(
        RPSLocalMatchStore.instance.opponentNameForPlayer(p2),
        equals('Alice'),
      );
    });

    // -------------------------------------------------------------------------
    // TC-RPS-28  reset clears all state
    // -------------------------------------------------------------------------
    test('TC-RPS-28 · reset clears moves so bothSubmitted is false and '
        'submitMove returns false', () {
      RPSLocalMatchStore.instance.initGame(
        player1Id: p1, player2Id: p2,
        player1Name: 'Alice', player2Name: 'Bob',
      );
      RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock);
      RPSLocalMatchStore.instance.submitMove(p2, RPSMove.rock);
      expect(RPSLocalMatchStore.instance.bothSubmitted, isTrue); // sanity check

      RPSLocalMatchStore.instance.reset();

      expect(RPSLocalMatchStore.instance.bothSubmitted, isFalse);
      // After reset _player1Id is null → submitMove should return false
      expect(
        RPSLocalMatchStore.instance.submitMove(p1, RPSMove.rock),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 8 — Emoji Charades: data integrity
  // ═══════════════════════════════════════════════════════════════════════════

  group('Emoji Charades data', () {
    // -------------------------------------------------------------------------
    // TC-EC-01  Category keys are unique
    // -------------------------------------------------------------------------
    test('TC-EC-01 · all category keys are unique', () {
      final keys = kEcCategories.map((c) => c.key).toList();
      final uniqueKeys = keys.toSet();
      expect(keys.length, equals(uniqueKeys.length),
          reason: 'Duplicate category key detected');
    });

    // -------------------------------------------------------------------------
    // TC-EC-02  kEcPhrases has an entry for every category key
    // -------------------------------------------------------------------------
    test('TC-EC-02 · kEcPhrases contains an entry for every category key', () {
      for (final cat in kEcCategories) {
        expect(kEcPhrases.containsKey(cat.key), isTrue,
            reason: 'No phrase list found for category "${cat.key}"');
      }
    });

    // -------------------------------------------------------------------------
    // TC-EC-03  Each phrase list is non-empty
    // -------------------------------------------------------------------------
    test('TC-EC-03 · each phrase list has at least one phrase', () {
      for (final entry in kEcPhrases.entries) {
        expect(entry.value.isNotEmpty, isTrue,
            reason: 'Phrase list for "${entry.key}" is empty');
      }
    });

    // -------------------------------------------------------------------------
    // TC-EC-04  No phrase list has duplicate entries
    // -------------------------------------------------------------------------
    test('TC-EC-04 · no phrase list contains duplicate phrases', () {
      for (final entry in kEcPhrases.entries) {
        final unique = entry.value.toSet();
        expect(entry.value.length, equals(unique.length),
            reason: 'Duplicate phrase found in "${entry.key}"');
      }
    });

    // -------------------------------------------------------------------------
    // TC-EC-05  kIntroSets entries all have exactly 3 emojis
    // -------------------------------------------------------------------------
    test('TC-EC-05 · every intro set contains exactly 3 emojis', () {
      for (int i = 0; i < kIntroSets.length; i++) {
        expect(kIntroSets[i].length, equals(3),
            reason: 'kIntroSets[$i] does not have exactly 3 entries');
      }
    });

    // -------------------------------------------------------------------------
    // TC-EC-06  Every category has both key and non-empty label / icon
    // -------------------------------------------------------------------------
    test('TC-EC-06 · every category has a non-empty key, label, and icon', () {
      for (final cat in kEcCategories) {
        expect(cat.key.isNotEmpty, isTrue);
        expect(cat.label.isNotEmpty, isTrue);
        expect(cat.icon.isNotEmpty, isTrue);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 9 — ChatService.formatTimestamp
  // ═══════════════════════════════════════════════════════════════════════════

  group('ChatService.formatTimestamp', () {
    // -------------------------------------------------------------------------
    // TC-CS-01  Null input → empty string
    // -------------------------------------------------------------------------
    test('TC-CS-01 · returns empty string for null input', () {
      expect(formatTimestamp(null), equals(''));
    });

    // -------------------------------------------------------------------------
    // TC-CS-02  < 60 seconds ago → 'now'
    // -------------------------------------------------------------------------
    test('TC-CS-02 · returns "now" for a timestamp under 60 seconds ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(seconds: 30))
          .toUtc()
          .toIso8601String();
      expect(formatTimestamp(ts), equals('now'));
    });

    // -------------------------------------------------------------------------
    // TC-CS-03  Just past the 1-minute boundary → 'Xm'
    // -------------------------------------------------------------------------
    test('TC-CS-03 · returns "1m" for a timestamp 61 seconds ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(seconds: 61))
          .toUtc()
          .toIso8601String();
      expect(formatTimestamp(ts), equals('1m'));
    });

    // -------------------------------------------------------------------------
    // TC-CS-04  59 minutes ago → '59m'
    // -------------------------------------------------------------------------
    test('TC-CS-04 · returns "59m" for a timestamp 59 minutes ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(minutes: 59))
          .toUtc()
          .toIso8601String();
      expect(formatTimestamp(ts), equals('59m'));
    });

    // -------------------------------------------------------------------------
    // TC-CS-05  2 hours ago → '2h'
    // -------------------------------------------------------------------------
    test('TC-CS-05 · returns "2h" for a timestamp 2 hours ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(hours: 2))
          .toUtc()
          .toIso8601String();
      expect(formatTimestamp(ts), equals('2h'));
    });

    // -------------------------------------------------------------------------
    // TC-CS-06  23 hours ago → '23h'
    // -------------------------------------------------------------------------
    test('TC-CS-06 · returns "23h" for a timestamp 23 hours ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(hours: 23))
          .toUtc()
          .toIso8601String();
      expect(formatTimestamp(ts), equals('23h'));
    });

    // -------------------------------------------------------------------------
    // TC-CS-07  3 days ago → '3d'
    // -------------------------------------------------------------------------
    test('TC-CS-07 · returns "3d" for a timestamp 3 days ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(days: 3))
          .toUtc()
          .toIso8601String();
      expect(formatTimestamp(ts), equals('3d'));
    });

    // -------------------------------------------------------------------------
    // TC-CS-08  7+ days ago → 'day/month' format
    // -------------------------------------------------------------------------
    test('TC-CS-08 · returns "day/month" for a timestamp 7 or more days ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 10));
      final ts = dt.toUtc().toIso8601String();
      final result = formatTimestamp(ts);
      // e.g. "4/5" for 4 May — we just check the pattern
      expect(result, matches(RegExp(r'^\d+/\d+$')),
          reason: 'Expected "d/M" format but got "$result"');
    });

    // -------------------------------------------------------------------------
    // TC-CS-09  BUG note: boundary at exactly 60 seconds
    //           inSeconds == 60 is NOT < 60, so returns '1m' — document this.
    // -------------------------------------------------------------------------
    test('TC-CS-09 · returns "1m" (not "now") for a timestamp exactly 60 seconds ago', () {
      final ts = DateTime.now()
          .subtract(const Duration(seconds: 60))
          .toUtc()
          .toIso8601String();
      // At the 60-second boundary diff.inSeconds == 60 → falls into the minutes branch
      expect(formatTimestamp(ts), equals('1m'));
    });
  });
}
