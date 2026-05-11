// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – LocalMatchStore (singleton)
//  In-memory store for pass-and-play / same-device matches.
//  Replace submitMove / polling with Supabase real-time
//  when wiring online multiplayer.
// ─────────────────────────────────────────────────────────────

import 'rps_models.dart';

class RPSLocalMatchStore {
  RPSLocalMatchStore._();
  static final RPSLocalMatchStore instance = RPSLocalMatchStore._();

  String? _player1Id;
  String? _player2Id;
  String? _player1Name;
  String? _player2Name;
  RPSMove? _player1Move;
  RPSMove? _player2Move;

  // ── Setup ────────────────────────────────────────────────

  void initGame({
    required String player1Id,
    required String player2Id,
    required String player1Name,
    required String player2Name,
  }) {
    _player1Id   = player1Id;
    _player2Id   = player2Id;
    _player1Name = player1Name;
    _player2Name = player2Name;
    _player1Move = null;
    _player2Move = null;
  }

  // ── Move submission ──────────────────────────────────────

  /// Returns false if the game has not been initialised.
  bool submitMove(String playerId, RPSMove move) {
    if (_player1Id == null) return false;
    if (playerId == _player1Id) {
      _player1Move = move;
    } else {
      _player2Move = move;
    }
    return true;
  }

  // ── Queries ──────────────────────────────────────────────

  bool get bothSubmitted => _player1Move != null && _player2Move != null;

  bool hasSubmitted(String playerId) =>
      playerId == _player1Id ? _player1Move != null : _player2Move != null;

  RPSMove? moveForPlayer(String playerId) =>
      playerId == _player1Id ? _player1Move : _player2Move;

  RPSMove? opponentMoveForPlayer(String playerId) =>
      playerId == _player1Id ? _player2Move : _player1Move;

  String opponentNameForPlayer(String playerId) =>
      playerId == _player1Id
          ? (_player2Name ?? 'Opponent')
          : (_player1Name ?? 'Opponent');

  RPSResult? resultForPlayer(String playerId) {
    if (!bothSubmitted) return null;
    final mine   = moveForPlayer(playerId)!;
    final theirs = opponentMoveForPlayer(playerId)!;
    return computeResult(mine, theirs);
  }

  // ── Reset ────────────────────────────────────────────────

  void reset() {
    _player1Id = _player2Id = _player1Name = _player2Name = null;
    _player1Move = _player2Move = null;
  }
}
