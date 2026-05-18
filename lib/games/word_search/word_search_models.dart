// lib/games/word_search/word_search_models.dart

enum GameStatus { waiting, solved, skipped }

/// The current phase of the game FROM THE PERSPECTIVE of the current user.
/// Both users progress through these phases independently.
enum MatchGamePhase {
  /// I haven't submitted my puzzle yet
  setup,

  /// I submitted mine, waiting for partner to submit theirs
  waitingPartnerSetup,

  /// Both puzzles submitted — I need to solve my partner's puzzle
  solving,

  /// I solved my partner's puzzle, waiting for them to solve mine
  waitingPartnerSolve,

  /// Both puzzles solved — chat unlocks!
  bothSolved,
}

class GridPosition {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  factory GridPosition.fromJson(Map<String, dynamic> json) =>
      GridPosition(json['row'] as int, json['col'] as int);

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  bool isAdjacentTo(GridPosition other) {
    return (row - other.row).abs() <= 1 &&
        (col - other.col).abs() <= 1 &&
        !(row == other.row && col == other.col);
  }

  @override
  bool operator ==(Object other) =>
      other is GridPosition && row == other.row && col == other.col;

  @override
  int get hashCode => row * 10 + col;
}

/// A single puzzle row in Supabase.
/// Two of these exist per match (one per user as creator).
class WordSearchGame {
  final String id;
  final String matchId;
  final String? sessionId;
  final String creatorId;  // the user who SET this puzzle
  final String solverId;   // the user who must SOLVE this puzzle
  final String topic;
  final String word;
  final List<List<String>> grid;
  final List<GridPosition> wordPath;
  final GameStatus status;
  final DateTime createdAt;
  final DateTime? solvedAt;

  const WordSearchGame({
    required this.id,
    required this.matchId,
    this.sessionId,
    required this.creatorId,
    required this.solverId,
    required this.topic,
    required this.word,
    required this.grid,
    required this.wordPath,
    required this.status,
    required this.createdAt,
    this.solvedAt,
  });

  factory WordSearchGame.fromJson(Map<String, dynamic> json) {
    final rawGrid = json['grid'] as List<dynamic>;
    final grid = rawGrid
        .map((r) => (r as List<dynamic>).map((c) => c as String).toList())
        .toList();

    final rawPath = json['word_path'] as List<dynamic>;
    final wordPath = rawPath
        .map((p) => GridPosition.fromJson(p as Map<String, dynamic>))
        .toList();

    return WordSearchGame(
      id:        json['id'] as String,
      matchId:   json['match_id'] as String,
      sessionId: json['session_id'] as String?,
      creatorId: json['creator_id'] as String,
      solverId:  json['solver_id'] as String,
      topic:     json['topic'] as String,
      word:      (json['word'] as String).toUpperCase(),
      grid:      grid,
      wordPath:  wordPath,
      status:    switch (json['status'] as String) {
                   'solved'  => GameStatus.solved,
                   'skipped' => GameStatus.skipped,
                   _         => GameStatus.waiting,
                 },
      createdAt: DateTime.parse(json['created_at'] as String),
      solvedAt:  json['solved_at'] != null
                   ? DateTime.parse(json['solved_at'] as String)
                   : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'match_id':   matchId,
    'creator_id': creatorId,
    'solver_id':  solverId,
    'topic':      topic,
    'word':       word.toUpperCase(),
    'grid':       grid,
    'word_path':  wordPath.map((p) => p.toJson()).toList(),
    'status':     'waiting',
  };

  // True when the puzzle is "done" (either solved or skipped) — used by phase logic.
  bool get isSolved  => status == GameStatus.solved || status == GameStatus.skipped;
  bool get isSkipped => status == GameStatus.skipped;
}

/// Snapshot of both game rows for a match, from one user's perspective.
class MatchGamesSnapshot {
  /// The puzzle THIS user created (null if not created yet)
  final WordSearchGame? myGame;

  /// The puzzle THIS user must solve (null if partner hasn't created yet)
  final WordSearchGame? partnerGame;

  const MatchGamesSnapshot({this.myGame, this.partnerGame});

  /// Determines the current phase for this user
  MatchGamePhase get phase {
    if (myGame == null) return MatchGamePhase.setup;
    if (partnerGame == null) return MatchGamePhase.waitingPartnerSetup;

    final iSolved       = partnerGame!.isSolved; // I solved the partner's puzzle
    final partnerSolved = myGame!.isSolved;       // partner solved my puzzle

    if (iSolved && partnerSolved) return MatchGamePhase.bothSolved;
    if (iSolved)                  return MatchGamePhase.waitingPartnerSolve;
    return MatchGamePhase.solving;
  }
}
