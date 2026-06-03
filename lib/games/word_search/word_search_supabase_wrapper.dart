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
import '../game_hub_screen.dart';

class WordSearchSupabaseWrapper extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback onChatUnlocked;
  final String? sessionId;
  final bool chatAlreadyUnlocked;
  final bool skipWelcome;

  const WordSearchSupabaseWrapper({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    required this.onChatUnlocked,
    this.sessionId,
    this.chatAlreadyUnlocked = false,
    this.skipWelcome = false,
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
  bool _completionSent      = false;
  bool _stepRestored        = false; // true once resumeFrom() has been called
  // True until the first _refresh() completes when skipWelcome=true — hides
  // the category screen from flashing before resumeFrom() restores the step.
  bool _initialized         = false;

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
    if (mounted) setState(() => _initialized = true);
    _ch = _svc.subscribeToMatch(
      widget.matchId,
      () { if (mounted) _refresh(); },
      channelSuffix: 'game',
    );
  }

  // ── Snapshot refresh ───────────────────────────────────────

  Future<void> _refresh() async {
    final snap = await _svc.getSnapshot(
      matchId:   widget.matchId,
      myUserId:  widget.currentUserId,
      sessionId: widget.sessionId,
    );
    if (!mounted) return;
    setState(() {
      _snap = snap;
    });
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

    // Partner finished MY puzzle (solved or skipped).
    if (!_partnerSolvedPushed && snap.myGame?.isSolved == true) {
      if (snap.myGame!.isSkipped) {
        state.setPartnerSkipped();
      } else {
        state.setPartnerSolved();
      }
      _partnerSolvedPushed = true;
    }

    // On rejoin (skipWelcome=true), restore the step from the DB phase.
    // Called after partner data so the solve screen has the grid ready.
    if (widget.skipWelcome && !_stepRestored) {
      _stepRestored = true;
      final step = switch (snap.phase) {
        MatchGamePhase.setup               => WSStep.category,
        MatchGamePhase.waitingPartnerSetup => WSStep.wait,
        MatchGamePhase.solving             => WSStep.solve,
        MatchGamePhase.waitingPartnerSolve => WSStep.waitPartner,
        MatchGamePhase.bothSolved          => WSStep.done,
      };
      if (step != WSStep.category) {
        // Also restore MY word + category so the wait/waitPartner/done screens
        // can display them correctly (they read from _me.word / _me.catIdx).
        final mg = snap.myGame;
        if (mg != null) {
          final catIdx = WordSearchData.categories.indexWhere((c) => c.key == mg.topic);
          state.resumeFrom(step,
              myWord: mg.word,
              myCatIdx: catIdx >= 0 ? catIdx : 0,
              mySolved: snap.partnerGame?.isSkipped == false && snap.partnerGame?.isSolved == true,
              mySkipped: snap.partnerGame?.isSkipped == true,
              partnerSolved: snap.myGame?.isSkipped == false && snap.myGame?.isSolved == true,
              partnerSkipped: snap.myGame?.isSkipped == true);
        } else {
          state.resumeFrom(step);
        }
      }
    }
  }

  // ── Score recording ────────────────────────────────────────
  //
  // Mirrors the Emoji Charades pattern exactly (which is proven to work):
  //   • Both solved   → result_label='both_solved', winnerId=null
  //                     complete_game_session inserts +1 for each player server-side
  //   • I won         → result_label='completed',   winnerId=me
  //   • I lost        → result_label='completed',   winnerId=partner
  //   • Both skipped  → result_label='both_skipped', winnerId=null
  //
  // pg = partnerGame = the row where I am solver_id  (the puzzle I need to solve)
  // mg = myGame      = the row where I am creator_id (the puzzle partner needs to solve)
  //
  //   Did I solve?       → pg.isSolved && !pg.isSkipped
  //   Did partner solve? → mg.isSolved && !mg.isSkipped

  void _recordScoreIfNeeded(MatchGamesSnapshot snap) {
    if (_scoreRecorded) return;
    if (snap.phase != MatchGamePhase.bothSolved) return;
    final pg = snap.partnerGame;
    final mg = snap.myGame;
    if (pg == null || mg == null) return;

    final iSolved       = pg.isSolved && !pg.isSkipped;
    final partnerSolved = mg.isSolved && !mg.isSkipped;

    debugPrint('[WordSearch] recordScore: iSolved=$iSolved partnerSolved=$partnerSolved sessionId=${widget.sessionId}');

    _scoreRecorded = true;
    debugPrint('[WordSearch] OUTCOME: iSolved=$iSolved partnerSolved=$partnerSolved myId=${widget.currentUserId} partnerId=${widget.partnerUserId}');

    // Only insert a score row if I actually solved the puzzle.
    // Each player runs this independently on their own device.
    // RPC is still called to mark the session completed — but we
    // never rely on it for score insertion.
    if (iSolved) {
      _insertMyScoreDirectly();
    }
    final resultLabel = (iSolved && partnerSolved) ? 'both_solved'
        : iSolved ? 'completed'
        : partnerSolved ? 'completed'
        : 'both_skipped';
    _sendCompletion(winnerId: null, resultLabel: resultLabel);
  }

  /// Each player calls this for themselves in the both-solved case.
  /// Inserts directly into game_scores rather than relying on the RPC,
  /// because the RPC is idempotent — only the first caller gets a row.
  /// _scoreRecorded is set to true before this is called, so it can
  /// only ever run once per device per round — no dedup query needed.
  Future<void> _insertMyScoreDirectly() async {
    try {
      final recent = await Supabase.instance.client
          .from('game_scores')
          .select('id')
          .eq('match_id', widget.matchId)
          .eq('winner_id', widget.currentUserId)
          .gte('created_at', DateTime.now().subtract(const Duration(seconds: 60)).toUtc().toIso8601String())
          .maybeSingle();
      if (recent != null) {
        debugPrint('[WordSearch] Score already inserted recently, skipping.');
        return;
      }
      await Supabase.instance.client.from('game_scores').insert({
        'match_id':  widget.matchId,
        'winner_id': widget.currentUserId,
        'loser_id':  widget.partnerUserId,
      });
      debugPrint('[WordSearch] Inserted both_solved score for ${widget.currentUserId}');
    } catch (e) {
      debugPrint('[WordSearch] _insertMyScoreDirectly error: $e');
    }
  }

  void _sendCompletion({required String? winnerId, required String resultLabel}) {
    if (_completionSent || widget.sessionId == null) return;
    _completionSent = true;
    debugPrint('[WordSearch] complete_game_session sessionId=${widget.sessionId} winnerId=$winnerId label=$resultLabel');
    Supabase.instance.client.rpc('complete_game_session', params: {
      'p_session_id':   widget.sessionId,
      'p_winner_id':    winnerId,
      'p_result_label': resultLabel,
    }).catchError((e) {
      debugPrint('[WordSearch] complete_game_session error: $e');
    });
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
        await _handleWordSkipped();
        break;

      case 'playAgain':
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameHubScreen(
                matchId: widget.matchId,
                currentUserId: widget.currentUserId,
                partnerUserId: widget.partnerUserId,
                partnerName: widget.partnerName,
                chatAlreadyUnlocked: widget.chatAlreadyUnlocked,
                onChatUnlocked: widget.onChatUnlocked,
              ),
            ),
          );
        }
        break;

      case 'chatPressed':
        // Navigate immediately — don't block on Supabase.
        widget.onChatUnlocked();
        // Best-effort: persist chat_unlocked flag in background.
        Supabase.instance.client
            .from('matches')
            .update({'chat_unlocked': true})
            .eq('id', widget.matchId)
            .catchError((_) {});
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
          if (widget.sessionId != null) 'session_id': widget.sessionId,
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

  Future<void> _handleWordSkipped() async {
    if (_snap.partnerGame == null) return;
    await _svc.markSkipped(_snap.partnerGame!.id);
    await _refresh();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // On re-entry (skipWelcome=true) hide everything until the first _refresh()
    // completes and resumeFrom() can jump straight to the right step —
    // prevents the category/welcome screen from flashing.
    if (!_initialized && widget.skipWelcome) {
      return const Scaffold(
        backgroundColor: Color(0xFF120D2E),
        body: SizedBox.expand(),
      );
    }
    // Only skip the welcome screen if the user has actually started this game
    // (has a row in word_search_games). If they haven't done anything yet
    // (e.g. sender tapping their own challenge card), show welcome as normal.
    final effectiveSkipWelcome = widget.skipWelcome && _snap.myGame != null;
    return WordSearchGameScreen(
      key:                  _gameKey,
      partnerName:          widget.partnerName,
      onGameEvent:          _onGameEvent,
      skipWelcome:          effectiveSkipWelcome,
      chatAlreadyUnlocked:  widget.chatAlreadyUnlocked,
      currentUserId:        widget.currentUserId,
      partnerUserId:        widget.partnerUserId,
    );
  }
}