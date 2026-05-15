// lib/games/word_search/word_search_supabase_wrapper.dart
//
// Bridges the new event-driven WordSearchGameScreen to the existing
// Supabase backend (WordSearchService + word_search_games table).
//
// Drop-in replacement for the old WordSearchGameScreen — accepts
// the same constructor parameters so game_hub_screen.dart needs
// only an import + class-name change.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'word_search_game_screen.dart';
import 'word_search_data.dart';
import 'word_search_service.dart';
import 'word_search_models.dart';

class WordSearchSupabaseWrapper extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback onChatUnlocked;

  const WordSearchSupabaseWrapper({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    required this.onChatUnlocked,
  });

  @override
  State<WordSearchSupabaseWrapper> createState() => _WordSearchSupabaseWrapperState();
}

class _WordSearchSupabaseWrapperState extends State<WordSearchSupabaseWrapper> {
  final _gameKey = GlobalKey<WordSearchGameScreenState>();
  final _svc     = WordSearchService();

  RealtimeChannel? _ch;
  MatchGamesSnapshot _snap = const MatchGamesSnapshot();

  // Track what we've already pushed to the game screen to avoid
  // triggering the done/confetti sequence more than once.
  bool _partnerDataPushed   = false;
  bool _partnerSolvedPushed = false;
  bool _scoreRecorded       = false;

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    if (_ch != null) _svc.unsubscribe(_ch!);
    super.dispose();
  }

  // ── Initialisation ─────────────────────────────────────────

  Future<void> _init() async {
    await _refresh();
    _ch = _svc.subscribeToMatch(
      widget.matchId,
      () { if (mounted) _refresh(); },
      channelSuffix: 'game',
    );
  }

  // ── Snapshot refresh ───────────────────────────────────────

  Future<void> _refresh() async {
    final snap = await _svc.getSnapshot(
      matchId:  widget.matchId,
      myUserId: widget.currentUserId,
    );
    if (!mounted) return;
    setState(() => _snap = snap);
    _recordScoreIfNeeded(snap);
    // Push after the current frame so the game screen widget is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToGameScreen(snap));
  }

  /// Push partner state into the game screen via its public API.
  void _syncToGameScreen(MatchGamesSnapshot snap) {
    final state = _gameKey.currentState;
    if (state == null) return; // screen not mounted yet — retry on next refresh

    // Partner's puzzle that the current user needs to solve.
    if (!_partnerDataPushed && snap.partnerGame != null) {
      final pg = snap.partnerGame!;
      final catIdx = WordSearchData.categories.indexWhere((c) => c.key == pg.topic);
      state.setPartnerData(
        pg.grid,
        pg.word,
        catIdx >= 0 ? catIdx : 0,
      );
      _partnerDataPushed = true;
    }

    // Partner solved MY puzzle.
    if (!_partnerSolvedPushed && snap.myGame?.isSolved == true) {
      state.setPartnerSolved();
      _partnerSolvedPushed = true;
    }
  }

  // ── Score recording ────────────────────────────────────────

  void _recordScoreIfNeeded(MatchGamesSnapshot snap) {
    if (_scoreRecorded) return;
    if (snap.phase != MatchGamePhase.bothSolved) return;
    final pg = snap.partnerGame;
    final mg = snap.myGame;
    if (pg?.solvedAt == null || mg?.solvedAt == null) return;
    final iWon  = pg!.solvedAt!.isBefore(mg!.solvedAt!);
    final isDraw = pg.solvedAt!.isAtSameMomentAs(mg.solvedAt!);
    if (isDraw) return;
    _scoreRecorded = true;
    if (iWon) {
      _svc.recordWinner(
        matchId:  widget.matchId,
        winnerId: widget.currentUserId,
        loserId:  widget.partnerUserId,
      );
    }
  }

  // ── Game event handler ─────────────────────────────────────

  Future<void> _onGameEvent(Map<String, dynamic> event) async {
    final type = event['event'] as String;

    switch (type) {
      case 'puzzleSubmitted':
        await _handlePuzzleSubmitted(event);
        break;

      case 'wordSolved':
        await _handleWordSolved();
        break;

      case 'wordSkipped':
        // Treat skip as solved so both parties can reach the done screen.
        await _handleWordSolved();
        break;

      case 'chatPressed':
        // Ensure matches.chat_unlocked is set — idempotent (only writes if false).
        try {
          final row = await Supabase.instance.client
              .from('matches')
              .select('chat_unlocked')
              .eq('id', widget.matchId)
              .single();
          if (row['chat_unlocked'] != true) {
            await Supabase.instance.client
                .from('matches')
                .update({'chat_unlocked': true})
                .eq('id', widget.matchId);
          }
        } catch (_) {}
        widget.onChatUnlocked();
        break;
    }
  }

  Future<void> _handlePuzzleSubmitted(Map<String, dynamic> event) async {
    final catIdx  = event['catIdx'] as int;
    final topic   = WordSearchData.categories[catIdx].key;
    final word    = event['word'] as String;
    final rawGrid = event['grid'] as List<List<String>>;
    final rawWc   = event['wc']   as List<List<int>>;

    // Convert wc (List<List<int>>) → word_path JSON for Supabase.
    final wordPath = rawWc.map((c) => {'row': c[0], 'col': c[1]}).toList();

    await Supabase.instance.client
        .from('word_search_games')
        .insert({
          'match_id':   widget.matchId,
          'creator_id': widget.currentUserId,
          'solver_id':  widget.partnerUserId,
          'topic':      topic,
          'word':       word.toUpperCase(),
          'grid':       rawGrid,
          'word_path':  wordPath,
          'status':     'waiting',
        });

    // Also update game_sessions so the chat card reflects the correct status.
    try {
      final sessionRow = await Supabase.instance.client
          .from('game_sessions')
          .select('id, player_a_id, player_a_submitted, player_b_submitted')
          .eq('match_id', widget.matchId)
          .eq('game_type', 'word_search')
          .neq('status', 'completed')
          .maybeSingle();

      if (sessionRow != null) {
        final sessionId  = sessionRow['id'] as String;
        final playerAId  = sessionRow['player_a_id'] as String?;
        final iAmPlayerA = playerAId == widget.currentUserId;

        final aAlreadySubmitted = sessionRow['player_a_submitted'] as bool? ?? false;
        final bAlreadySubmitted = sessionRow['player_b_submitted'] as bool? ?? false;

        final newA = iAmPlayerA ? true : aAlreadySubmitted;
        final newB = iAmPlayerA ? bAlreadySubmitted : true;
        final newStatus = (newA && newB) ? 'active' : 'submitted';

        await Supabase.instance.client
            .from('game_sessions')
            .update({
              'status': newStatus,
              if (iAmPlayerA) 'player_a_submitted': true
              else            'player_b_submitted': true,
            })
            .eq('id', sessionId);
      }
    } catch (_) {}

    await _refresh();
  }

  Future<void> _handleWordSolved() async {
    if (_snap.partnerGame == null) return;
    await _svc.markSolved(_snap.partnerGame!.id);
    await _refresh();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WordSearchGameScreen(
      key:          _gameKey,
      partnerName:  widget.partnerName,
      onGameEvent:  _onGameEvent,
      skipWelcome:  true,
    );
  }
}
