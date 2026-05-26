// lib/games/word_search/word_search_service.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'word_search_models.dart';

class WordSearchService {
  final SupabaseClient _db = Supabase.instance.client;
  static const _table = 'word_search_games';

  // ────────────────────────────────────────────────────────────
  // GRID GENERATION  (DFS — same algorithm as before)
  // ────────────────────────────────────────────────────────────
  static ({List<List<String>> grid, List<GridPosition> path})?
      generateGrid(String word) {
    final w    = word.toUpperCase();
    if (w.isEmpty || w.length > 16) return null;

    const size = 4;
    final rng  = Random();
    const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    final dirs = [
      [-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1],
    ];

    List<T> shuffle<T>(List<T> list) {
      for (var i = list.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = list[i]; list[i] = list[j]; list[j] = tmp;
      }
      return list;
    }

    bool dfs(int idx, int r, int c, List<GridPosition> path, Set<int> vis) {
      if (idx == w.length) return true;
      if (r < 0 || r >= size || c < 0 || c >= size) return false;
      final key = r * size + c;
      if (vis.contains(key)) return false;
      path.add(GridPosition(r, c));
      vis.add(key);
      for (final d in shuffle(dirs.map((e) => List<int>.from(e)).toList())) {
        if (dfs(idx + 1, r + d[0], c + d[1], path, vis)) return true;
      }
      path.removeLast();
      vis.remove(key);
      return false;
    }

    final starts = shuffle(
      [for (var r = 0; r < size; r++) for (var c = 0; c < size; c++) [r, c]],
    );

    for (final s in starts) {
      final path = <GridPosition>[];
      final vis  = <int>{};
      if (dfs(0, s[0], s[1], path, vis)) {
        final grid = List.generate(size, (_) => List.filled(size, ''));
        for (var i = 0; i < w.length; i++) {
          grid[path[i].row][path[i].col] = w[i];
        }
        for (var r = 0; r < size; r++) {
          for (var c = 0; c < size; c++) {
            if (grid[r][c].isEmpty) grid[r][c] = alpha[rng.nextInt(26)];
          }
        }
        return (grid: grid, path: path);
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────
  // FETCH — get both game rows for a match
  // ────────────────────────────────────────────────────────────

  /// Returns a snapshot of both game rows from the perspective of [myUserId].
  /// myGame    = the puzzle I created (I am creator_id)
  /// partnerGame = the puzzle I must solve (I am solver_id)
  Future<MatchGamesSnapshot> getSnapshot({
    required String matchId,
    required String myUserId,
    String? sessionId,
  }) async {
    List<Map<String, dynamic>> rows;

    if (sessionId != null) {
      // Try session-scoped query first.
      rows = await _db
          .from(_table)
          .select()
          .eq('match_id', matchId)
          .eq('session_id', sessionId);

      // Fallback: puzzle rows may have been written without a session_id
      // (e.g. the session RPC failed silently in GameHub). Widen to match-level
      // and accept rows whose session_id is null or matches ours.
      if (rows.isEmpty) {
        final all = await _db.from(_table).select().eq('match_id', matchId);
        rows = all
            .where((r) =>
                r['session_id'] == null || r['session_id'] == sessionId)
            .toList();
        // Last resort: any row for this match (handles legacy data).
        if (rows.isEmpty) rows = all;
      }
    } else {
      rows = await _db.from(_table).select().eq('match_id', matchId);
    }

    WordSearchGame? myGame;
    WordSearchGame? partnerGame;

    for (final row in rows) {
      final g = WordSearchGame.fromJson(row);
      if (g.creatorId == myUserId) {
        myGame = g;
      } else if (g.solverId == myUserId) {
        partnerGame = g;
      }
    }

    return MatchGamesSnapshot(myGame: myGame, partnerGame: partnerGame);
  }

  // ────────────────────────────────────────────────────────────
  // CREATE — submit my puzzle
  // ────────────────────────────────────────────────────────────

  /// Called when the current user submits their puzzle.
  /// Returns the created game row.
  Future<WordSearchGame?> createMyPuzzle({
    required String matchId,
    required String myUserId,
    required String partnerUserId,
    required String topic,
    required String word,
  }) async {
    final result = generateGrid(word);
    if (result == null) return null;

    final payload = {
      'match_id':   matchId,
      'creator_id': myUserId,
      'solver_id':  partnerUserId,
      'topic':      topic,
      'word':       word.toUpperCase(),
      'grid':       result.grid,
      'word_path':  result.path.map((p) => p.toJson()).toList(),
      'status':     'waiting',
    };

    final response = await _db
        .from(_table)
        .insert(payload)
        .select()
        .single();

    return WordSearchGame.fromJson(response);
  }

  // ────────────────────────────────────────────────────────────
  // SOLVE — mark partner's puzzle as solved by me
  // ────────────────────────────────────────────────────────────

  /// Called when the current user successfully finds the word
  /// in their partner's puzzle.
  /// Returns the updated game row.
  Future<WordSearchGame?> markSolved(String gameId) async {
    final response = await _db
        .from(_table)
        .update({
          'status':    'solved',
          'solved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', gameId)
        .select()
        .single();

    return WordSearchGame.fromJson(response);
  }

  Future<WordSearchGame?> markSkipped(String gameId) async {
    final response = await _db
        .from(_table)
        .update({
          'status':    'skipped',
          'solved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', gameId)
        .select()
        .single();

    return WordSearchGame.fromJson(response);
  }

  // ────────────────────────────────────────────────────────────
  // REALTIME
  // Subscribe to ALL changes on both game rows for this match.
  // Any INSERT or UPDATE triggers onRefresh — the screen then
  // re-fetches the snapshot and redraws.
  // ────────────────────────────────────────────────────────────

  /// Subscribe to all changes on both game rows for this match.
  ///
  /// [channelSuffix] lets callers create distinct channel objects for the
  /// same matchId so they don't accidentally share — or clobber — each
  /// other's subscription when multiple screens are listening at once.
  /// e.g. pass 'chat' from ChatConversationScreen and 'game' from the
  /// game screen to avoid a naming collision in Supabase Realtime.
  RealtimeChannel subscribeToMatch(
    String matchId,
    VoidCallback onRefresh, {
    String channelSuffix = '',
  }) {
    final channelName = channelSuffix.isEmpty
        ? 'wsg_match_$matchId'
        : 'wsg_match_${matchId}_$channelSuffix';
    return _db
        .channel(channelName)
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  _table,
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'match_id',
            value:  matchId,
          ),
          callback: (_) => onRefresh(),
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel ch) => _db.removeChannel(ch);

  // ────────────────────────────────────────────────────────────
  // RESET — delete both game rows so a new game can start
  // ────────────────────────────────────────────────────────────

  Future<void> resetGame(String matchId) async {
    await _db.from(_table).delete().eq('match_id', matchId);
  }

  /// Deletes all score rows for a match (full score reset).
  Future<void> resetScores(String matchId) async {
    await _db.from(_scores).delete().eq('match_id', matchId);
  }

  /// Resets both the active game rows AND all score history for a match.
  Future<void> resetAll(String matchId) async {
    await resetGame(matchId);
    await resetScores(matchId);
  }

  // ────────────────────────────────────────────────────────────
  // SCORES — win/loss tracking per match
  // ────────────────────────────────────────────────────────────

  static const _scores = 'game_scores';

  /// Record the winner of a completed round.
  /// Only called by the winner to avoid duplicate rows.
  Future<void> recordWinner({
    required String matchId,
    required String winnerId,
    required String loserId,
  }) async {
    await _db.from(_scores).insert({
      'match_id':  matchId,
      'winner_id': winnerId,
      'loser_id':  loserId,
    });
  }

  /// Return {myWins, partnerWins} for a match.
  Future<Map<String, int>> getScores({
    required String matchId,
    required String myUserId,
    required String partnerUserId,
  }) async {
    final rows = await _db
        .from(_scores)
        .select('winner_id')
        .eq('match_id', matchId);

    int myWins = 0, partnerWins = 0;
    for (final row in rows) {
      if (row['winner_id'] == myUserId) myWins++;
      else if (row['winner_id'] == partnerUserId) partnerWins++;
    }
    return {'myWins': myWins, 'partnerWins': partnerWins};
  }

  /// Subscribe to score changes for a match.
  RealtimeChannel subscribeToScores(String matchId, VoidCallback onRefresh) {
    return _db
        .channel('scores_$matchId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  _scores,
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'match_id',
            value:  matchId,
          ),
          callback: (_) => onRefresh(),
        )
        .subscribe();
  }
}
