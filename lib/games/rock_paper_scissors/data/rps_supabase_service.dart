// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Supabase Service
//  Replaces RPSLocalMatchStore for online multiplayer.
// ─────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import 'rps_models.dart';

class RPSMoveResult {
  final bool waiting;          // true = opponent hasn't submitted yet
  final RPSMove? myMove;
  final RPSMove? opponentMove;
  final RPSResult? result;
  final String? winnerId;

  const RPSMoveResult({
    required this.waiting,
    this.myMove,
    this.opponentMove,
    this.result,
    this.winnerId,
  });
}

class RPSSupabaseService {
  final _client = Supabase.instance.client;
  RealtimeChannel? _movesChannel;
  RealtimeChannel? _sessionChannel;

  // ── Submit move ─────────────────────────────────────────────────────────────
  /// Calls the submit_rps_move Postgres function.
  /// Returns [RPSMoveResult.waiting] = true if the opponent hasn't moved yet.
  Future<RPSMoveResult> submitMove(String sessionId, RPSMove move) async {
    final res = await _client.rpc('submit_rps_move', params: {
      'p_session_id': sessionId,
      'p_move': move.name,          // 'rock' | 'paper' | 'scissors'
    }) as Map<String, dynamic>;

    if (res['waiting'] == true) {
      return const RPSMoveResult(waiting: true);
    }

    final myMove  = RPSMove.values.firstWhere((m) => m.name == res['my_move']);
    final oppMove = RPSMove.values.firstWhere((m) => m.name == res['opponent_move']);
    final result  = computeResult(myMove, oppMove);

    return RPSMoveResult(
      waiting:      false,
      myMove:       myMove,
      opponentMove: oppMove,
      result:       result,
      winnerId:     res['winner_id'] as String?,
    );
  }

  // ── Listen for opponent move (waiting screen) ────────────────────────────────
  /// Subscribe to rps_moves INSERTs for this session.
  /// When the second move lands, fetches both rows and calls [onBothReady].
  void subscribeToMoves(
    String sessionId,
    String currentUserId,
    void Function(RPSMove myMove, RPSMove opponentMove, RPSResult result) onBothReady,
  ) {
    _movesChannel = _client
        .channel('rps_moves:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rps_moves',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'session_id', value: sessionId),
          callback: (_) async {
            // Re-read after insert — RLS now allows reads when both rows exist
            final rows = await _client
                .from('rps_moves')
                .select('player_id, move')
                .eq('session_id', sessionId);

            if ((rows as List).length < 2) return;

            final myRow  = rows.firstWhere((r) => r['player_id'] == currentUserId);
            final oppRow = rows.firstWhere((r) => r['player_id'] != currentUserId);

            final myMove  = RPSMove.values.firstWhere((m) => m.name == myRow['move']);
            final oppMove = RPSMove.values.firstWhere((m) => m.name == oppRow['move']);

            onBothReady(myMove, oppMove, computeResult(myMove, oppMove));
          },
        )
        .subscribe();
  }

  // ── Listen for session completion (for auto-unlock) ──────────────────────────
  void subscribeToSession(String sessionId, void Function(String status) onStatus) {
    _sessionChannel = _client
        .channel('rps_session:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_sessions',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: sessionId),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null) onStatus(status);
          },
        )
        .subscribe();
  }

  // ── Fetch both moves once the session is complete ───────────────────────────
  /// Returns null if fewer than 2 moves exist yet.
  Future<RPSMoveResult?> fetchResult(String sessionId, String currentUserId) async {
    final rows = await _client
        .from('rps_moves')
        .select('player_id, move')
        .eq('session_id', sessionId);

    if ((rows as List).length < 2) return null;

    final List<Map<String, dynamic>> typed = List<Map<String, dynamic>>.from(rows);
    final myRow  = typed.cast<Map<String, dynamic>?>().firstWhere((r) => r!['player_id'] == currentUserId,  orElse: () => null);
    final oppRow = typed.cast<Map<String, dynamic>?>().firstWhere((r) => r!['player_id'] != currentUserId, orElse: () => null);
    if (myRow == null || oppRow == null) return null;

    final myMove  = RPSMove.values.firstWhere((m) => m.name == myRow['move']);
    final oppMove = RPSMove.values.firstWhere((m) => m.name == oppRow['move']);

    return RPSMoveResult(
      waiting:      false,
      myMove:       myMove,
      opponentMove: oppMove,
      result:       computeResult(myMove, oppMove),
      winnerId:     null,
    );
  }

  /// Returns the current user's submitted move for this session, null if not yet submitted.
  Future<RPSMove?> fetchMyMove(String sessionId, String currentUserId) async {
    try {
      final rows = await _client
          .from('rps_moves')
          .select('move')
          .eq('session_id', sessionId)
          .eq('player_id', currentUserId);
      if ((rows as List).isEmpty) return null;
      return RPSMove.values.firstWhere((m) => m.name == rows.first['move'],
          orElse: () => RPSMove.rock);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _movesChannel?.unsubscribe();
    _sessionChannel?.unsubscribe();
  }
}
