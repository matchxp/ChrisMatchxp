// lib/games/word_search/word_search_game_screen.dart  — v3
// Fixes: grammar ("are waiting"), rich waiting pages, live partner solve status

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'word_search_models.dart';
import 'word_search_service.dart';
import 'word_search_grid_widget.dart';
import 'word_search_word_bank.dart';
import '../../services/matching_service.dart';

enum _WState { idle, valid, invalid }

class WordSearchGameScreen extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback onChatUnlocked;

  const WordSearchGameScreen({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    required this.onChatUnlocked,
  });

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen> {
  final _svc = WordSearchService();
  final _msgSvc = MatchingService();
  RealtimeChannel? _ch;

  MatchGamesSnapshot _snap = const MatchGamesSnapshot();
  bool _loading = true;
  String? _error;

  // setup form
  String?  _topic;
  final    _wordCtrl = TextEditingController();
  _WState  _ws       = _WState.idle;
  bool     _making   = false;

  // waiting pages controller
  final _waitPageCtrl = PageController();
  int   _waitPage     = 0;

  // solving
  int  _wrong   = 0;
  bool _hint    = false;
  Key  _gridKey = UniqueKey();

  // score recording
  bool _scoreRecorded = false;

  // colours — matched to dating app (MainNavigation / HomeScreen)
  static const _bg  = Color(0xFF0A0A0A);
  static const _s1  = Color(0xFF0A0A0A);
  static const _s2  = Color(0xFF1A1A1A);
  static const _bd  = Color(0x406C3FE8);   // 25% opacity purple for borders
  static const _pu  = Color(0xFF6C3FE8);
  static const _pl  = Color(0xFFBB8DFF);
  static const _pd  = Color(0xFF4A1FAD);
  static const _gn  = Color(0xFF4ADE80);
  static const _rd  = Color(0xFFF87171);
  static const _tx  = Colors.white;
  static const _mt  = Color(0xFF888888);

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() {
    if (_ch != null) _svc.unsubscribe(_ch!);
    _wordCtrl.dispose();
    _waitPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      await _refresh();

      // If a previous round is already complete, auto-reset so the user
      // always lands on a fresh setup screen when they re-enter the game.
      if (_snap.phase == MatchGamePhase.bothSolved) {
        await _svc.resetGame(widget.matchId);
        _wordCtrl.clear();
        setState(() {
          _topic         = null;
          _ws            = _WState.idle;
          _wrong         = 0;
          _hint          = false;
          _gridKey       = UniqueKey();
          _scoreRecorded = false;
        });
        await _refresh();
      }

      _ch = _svc.subscribeToMatch(widget.matchId, () {
        if (mounted) _refresh();
      });
    } catch (e) {
      setState(() { _error = 'Could not load game. Check connection.'; _loading = false; });
    }
  }

  Future<void> _refresh() async {
    final snap = await _svc.getSnapshot(
      matchId: widget.matchId, myUserId: widget.currentUserId);
    if (mounted) setState(() { _snap = snap; _loading = false; _error = null; });
  }

  void _onWordChange(String v) {
    final w = v.toUpperCase();
    if (_wordCtrl.text != w) {
      _wordCtrl.value = _wordCtrl.value.copyWith(
        text: w, selection: TextSelection.collapsed(offset: w.length));
    }
    setState(() {
      if (w.length < 3)                     _ws = _WState.idle;
      else if (isValidWord(_topic ?? '', w)) _ws = _WState.valid;
      else                                   _ws = _WState.invalid;
    });
  }

  Future<void> _submitPuzzle() async {
    if (_ws != _WState.valid || _topic == null || _making) return;
    setState(() => _making = true);
    try {
      await _svc.createMyPuzzle(
        matchId:       widget.matchId,
        myUserId:      widget.currentUserId,
        partnerUserId: widget.partnerUserId,
        topic:         _topic!,
        word:          _wordCtrl.text.toUpperCase(),
      );
      // Post a game-request card into the chat so the partner sees it
      await _msgSvc.sendMessage(
        widget.matchId,
        '[GAME_REQUEST] 🎮 sent a Word Search challenge!',
      );
    } catch (e) {
      _snack('Something went wrong. Please try again.');
    }
    if (mounted) setState(() => _making = false);
  }

  Future<void> _onCorrect(List<GridPosition> _) async {
    final pg = _snap.partnerGame;
    if (pg == null) return;
    final updated = await _svc.markSolved(pg.id);
    if (updated != null && mounted) {
      setState(() => _snap = MatchGamesSnapshot(
        myGame: _snap.myGame, partnerGame: updated));
    }
  }

  void _onWrong() => setState(() { _wrong++; if (_wrong >= 3) _hint = true; });
  void _resetBoard() => setState(() { _gridKey = UniqueKey(); });

  /// Deletes both game rows so a brand-new game can be played.
  Future<void> _playAgain() async {
    setState(() => _loading = true);
    try {
      await _svc.resetGame(widget.matchId);
      // Also post a fresh game-request card to chat
      await _msgSvc.sendMessage(
        widget.matchId,
        '[GAME_REQUEST] 🎮 sent a Word Search challenge!',
      );
      // Reset local UI state
      setState(() {
        _topic         = null;
        _ws            = _WState.idle;
        _wrong         = 0;
        _hint          = false;
        _gridKey       = UniqueKey();
        _scoreRecorded = false;
      });
      _wordCtrl.clear();
      await _refresh();
    } catch (e) {
      _snack('Could not reset game. Try again.');
      if (mounted) setState(() => _loading = false);
    }
  }
  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Fredoka')),
      backgroundColor: _s2, behavior: SnackBarBehavior.floating));

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0, centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(text: const TextSpan(children: [
          TextSpan(text: 'MATCH', style: TextStyle(color: Colors.white, fontFamily: 'Fredoka One', fontSize: 18, letterSpacing: 1)),
          TextSpan(text: 'XP',   style: TextStyle(color: Color(0xFF6C3FE8), fontFamily: 'Fredoka One', fontSize: 18, letterSpacing: 1)),
        ])),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF6C3FE8).withOpacity(0.15))),
      ),
      bottomNavigationBar: _navBar(),
      body: _body(),
    );
  }

  Widget _navBar() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_bg.withOpacity(0.0), _bg]),
    ),
    child: SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _pu.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(color: _pu.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.explore_outlined,            Icons.explore,             false),
            _navItem(Icons.favorite_border_rounded,     Icons.favorite_rounded,    false),
            _navItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, true),
            _navItem(Icons.person_outline_rounded,      Icons.person_rounded,      false),
          ],
        ),
      ),
    ),
  );

  Widget _navItem(IconData icon, IconData activeIcon, bool isSelected) =>
    GestureDetector(
      onTap: () { if (!isSelected) Navigator.of(context).popUntil((r) => r.isFirst); },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)])
              : null,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [BoxShadow(color: _pu.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? Colors.white : _pu.withOpacity(0.6),
          size: 20,
        ),
      ),
    );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _pu));
    if (_error != null) return _errScreen();
    switch (_snap.phase) {
      case MatchGamePhase.setup:             return _setupScreen();
      case MatchGamePhase.waitingPartnerSetup: return _waitingSetupScreen();
      case MatchGamePhase.solving:           return _solvingScreen();
      case MatchGamePhase.waitingPartnerSolve: return _waitingSolveScreen();
      case MatchGamePhase.bothSolved:        return _bothSolvedScreen();
    }
  }

  // ── PHASE 1: Setup ───────────────────────────────────────
  Widget _setupScreen() {
    final hasTopic  = _topic != null;
    final isValid   = _ws == _WState.valid;
    final isInvalid = _ws == _WState.invalid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 4),
        _badge('🎮  ICE BREAKER GAME'),
        const SizedBox(height: 14),
        RichText(textAlign: TextAlign.center, text: const TextSpan(
          style: TextStyle(fontFamily: 'Fredoka One', fontSize: 26, color: _tx, height: 1.2),
          children: [
            TextSpan(text: 'Set your '),
            TextSpan(text: 'puzzle', style: TextStyle(color: _pu)),
          ],
        )),
        const SizedBox(height: 6),
        Text(
          'Create a word for ${widget.partnerName} to find.\n${widget.partnerName} is setting one for you too!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 13, height: 1.5),
        ),

        // Partner status indicator
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(12), border: Border.all(color: _bd)),
          child: Row(children: [
            _miniAvatar(),
            const SizedBox(width: 10),
            Expanded(child: Text(
              '${widget.partnerName} is also setting a puzzle for you...',
              style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 12))),
            const _PulsingDots(),
          ]),
        ),

        const SizedBox(height: 22),
        _stepRow('1', 'CHOOSE A TOPIC'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showTopicSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _s2, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasTopic ? _pu : _bd, width: 2)),
            child: Row(children: [
              Expanded(child: Text(
                hasTopic ? '${kTopicIcons[_topic!] ?? ''}  $_topic' : 'Tap to pick a topic...',
                style: TextStyle(fontFamily: 'Fredoka One', fontSize: 16,
                  color: hasTopic ? _tx : _mt))),
              Text(hasTopic ? '✅' : '▾', style: const TextStyle(fontSize: 20)),
            ]),
          ),
        ),

        const SizedBox(height: 20),
        _stepRow('2', 'ENTER YOUR WORD'),
        const SizedBox(height: 10),
        TextField(
          controller: _wordCtrl,
          enabled: hasTopic,
          onChanged: _onWordChange,
          maxLength: 12,
          style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 22, color: _tx, letterSpacing: 5),
          decoration: InputDecoration(
            hintText: hasTopic ? 'Type a ${_topic!.toLowerCase()} word...' : 'Pick a topic first',
            hintStyle: const TextStyle(color: Color(0xFF555555), fontFamily: 'Fredoka One', fontSize: 16, letterSpacing: 2),
            counterStyle: const TextStyle(color: _mt),
            filled: true, fillColor: _s2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _bd, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isValid ? _gn : isInvalid ? _rd : _bd, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isValid ? _gn : isInvalid ? _rd : _pu, width: 2)),
          ),
        ),
        const SizedBox(height: 2),
        if (isValid)
          const Row(children: [
            Icon(Icons.check_circle, color: _gn, size: 15),
            SizedBox(width: 6),
            Text('Perfect — puzzle ready!',
              style: TextStyle(color: _gn, fontFamily: 'Fredoka', fontSize: 12, fontWeight: FontWeight.w700)),
          ])
        else if (isInvalid)
          Row(children: [
            const Icon(Icons.cancel, color: _rd, size: 15),
            const SizedBox(width: 6),
            Text('Try a different ${_topic?.toLowerCase() ?? 'word'}',
              style: const TextStyle(color: _rd, fontFamily: 'Fredoka', fontSize: 12, fontWeight: FontWeight.w700)),
          ])
        else
          Text(
            hasTopic ? 'Must be a real ${_topic?.toLowerCase()} (3–12 letters)' : 'Choose a topic first',
            style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 12)),

        const SizedBox(height: 26),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, disabledBackgroundColor: _s2,
              foregroundColor: const Color(0xFF16163A), disabledForegroundColor: _mt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            onPressed: (isValid && !_making) ? _submitPuzzle : null,
            child: Text(_making ? 'Sending puzzle...' : 'Send puzzle to ${widget.partnerName} 📨',
              style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 15)),
          )),
      ]),
    );
  }

  void _showTopicSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 4,
            decoration: BoxDecoration(color: _bd, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('Choose your topic',
            style: TextStyle(fontFamily: 'Fredoka One', fontSize: 17, color: _tx)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
            children: kWordBank.keys.map((t) {
              final active = _topic == t;
              return GestureDetector(
                onTap: () {
                  setState(() { _topic = t; _wordCtrl.clear(); _ws = _WState.idle; });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? _pu : _s2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: active ? _pl : _bd, width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(kTopicIcons[t] ?? '•', style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(t, style: TextStyle(fontFamily: 'Fredoka One', fontSize: 14,
                      color: active ? Colors.white : _tx)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  // ── PHASE 2: Waiting for partner to set puzzle ────────────
  // 4 swipeable pages so user remembers their word and sees live status
  Widget _waitingSetupScreen() {
    final myGame   = _snap.myGame!;
    final pages    = [_wp_myGrid(myGame), _wp_myWord(myGame), _wp_partnerStatus(false), _wp_partnerView()];
    final dotCount = pages.length;

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(children: [
            _badge('⏳  YOUR PUZZLE IS SENT'),
            const SizedBox(height: 10),
            // Partner card
            _partnerCard(sub: '${widget.partnerName} is setting their puzzle for you...'),
            const SizedBox(height: 10),
            _topicBadge(myGame.topic),
            const SizedBox(height: 12),
            Expanded(
              child: PageView(
                controller: _waitPageCtrl,
                onPageChanged: (i) => setState(() => _waitPage = i),
                children: pages,
              ),
            ),
            const SizedBox(height: 8),
            _dotRow(dotCount),
            const SizedBox(height: 6),
            Text('Swipe · see your puzzle & ${widget.partnerName}\'s status',
              style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ]);
  }

  // ── PHASE 3: Solving ─────────────────────────────────────
  Widget _solvingScreen() {
    final partnerGame = _snap.partnerGame!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(children: [
        _badge('🔍  FIND ${widget.partnerName.toUpperCase()}\'S WORD'),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _topicBadge(partnerGame.topic),
          Row(children: [
            _miniAvatar(),
            const SizedBox(width: 6),
            Text("${widget.partnerName}'s puzzle",
              style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
          ]),
        ]),
        if (_hint) ...[const SizedBox(height: 8), _hintPill('Hint: ${partnerGame.word.length} letters')],
        const SizedBox(height: 12),
        WordSearchGridWidget(
          key: _gridKey,
          grid: partnerGame.grid,
          targetWord: partnerGame.word,
          isInteractive: true,
          onCorrect: _onCorrect,
          onWrong: _onWrong,
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _resetBtn(),
          if (_wrong > 0) ...[
            const SizedBox(width: 12),
            Text('$_wrong wrong attempt${_wrong == 1 ? '' : 's'}',
              style: const TextStyle(color: _rd, fontFamily: 'Fredoka', fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 10),
        // My puzzle status — is partner solving mine?
        _myPuzzleStatusBar(partnerSolvedMine: _snap.myGame?.isSolved ?? false),
        const SizedBox(height: 6),
        const Text('Tap letters in order · must be adjacent',
          style: TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
      ]),
    );
  }

  // ── PHASE 4: Waiting for partner to solve mine ───────────
  // 4 swipeable pages: solved grid, my word reminder, partner live status, summary
  Widget _waitingSolveScreen() {
    final partnerGame = _snap.partnerGame!;
    final myGame      = _snap.myGame!;
    final partnerSolvedMine = myGame.isSolved;
    final pages = [
      _wp_solved(partnerGame),
      _wp_myWord(myGame),
      _wp_partnerStatus(partnerSolvedMine),
      _wp_bothStatus(partnerGame, myGame, partnerSolvedMine),
    ];

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(children: [
            _badge('✅  YOU FOUND ${widget.partnerName.toUpperCase()}\'S WORD!'),
            const SizedBox(height: 10),
            // Partner live status
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: partnerSolvedMine
                    ? const Color(0xFF0D2B1A)
                    : _s2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: partnerSolvedMine
                      ? const Color(0xFF2A6640)
                      : _bd,
                  width: partnerSolvedMine ? 2 : 1.5)),
              child: Row(children: [
                _miniAvatar(),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.partnerName,
                    style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 14, color: _tx)),
                  Text(
                    partnerSolvedMine
                        ? '✅ Found your hidden word!'
                        : '${widget.partnerName} is still searching for your word "${myGame.word}"...',
                    style: TextStyle(
                      color: partnerSolvedMine ? _gn : _mt,
                      fontFamily: 'Fredoka', fontSize: 11)),
                ])),
                partnerSolvedMine
                    ? const Text('🎉', style: TextStyle(fontSize: 20))
                    : const _PulsingDots(),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: PageView(
                controller: _waitPageCtrl,
                onPageChanged: (i) => setState(() => _waitPage = i),
                children: pages,
              ),
            ),
            const SizedBox(height: 8),
            _dotRow(pages.length),
            const SizedBox(height: 6),
            Text('Swipe · see progress & your puzzle',
              style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ]);
  }

  // ── PHASE 5: Both solved ─────────────────────────────────
  Widget _bothSolvedScreen() {
    final pg = _snap.partnerGame!;
    final mg = _snap.myGame!;

    // Determine winner: whoever solved first wins
    // pg.solvedAt = when I solved; mg.solvedAt = when partner solved
    final iWon = pg.solvedAt != null && mg.solvedAt != null &&
        pg.solvedAt!.isBefore(mg.solvedAt!);
    final isDraw = pg.solvedAt != null && mg.solvedAt != null &&
        pg.solvedAt!.isAtSameMomentAs(mg.solvedAt!);

    // Record winner once — only the winner records to avoid duplicates
    if (!_scoreRecorded && pg.solvedAt != null && mg.solvedAt != null && !isDraw) {
      _scoreRecorded = true;
      if (iWon) {
        _svc.recordWinner(
          matchId:  widget.matchId,
          winnerId: widget.currentUserId,
          loserId:  widget.partnerUserId,
        );
      }
      // loser does NOT call recordWinner; winner's call is the single source of truth
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 12),
        Text(isDraw ? '🤝' : iWon ? '🏆' : '😅',
          style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        // Result banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: iWon
                ? [const Color(0xFF1A5C30), const Color(0xFF0D2B1A)]
                : isDraw
                    ? [const Color(0xFF1A1A1A), const Color(0xFF2A2A1A)]
                    : [const Color(0xFF5C1A1A), const Color(0xFF2B0D0D)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iWon ? _gn : isDraw ? _pl : _rd, width: 1.5)),
          child: Text(
            isDraw ? "It's a draw! 🤝" : iWon ? 'You won this round! 🏆' : '${widget.partnerName} won this round',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka One', fontSize: 18,
              color: iWon ? _gn : isDraw ? _pl : _rd)),
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFBB8DFF), Colors.white, Color(0xFFBB8DFF)]).createShader(b),
          child: const Text('Ice broken!',
            style: TextStyle(fontFamily: 'Fredoka One', fontSize: 24, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text('You and ${widget.partnerName} solved each other\'s puzzles!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 13)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _wordRevealCard('YOUR WORD', mg.word, mg.topic)),
          const SizedBox(width: 10),
          Expanded(child: _wordRevealCard('${widget.partnerName.toUpperCase()}\'S WORD', pg.word, pg.topic)),
        ]),
        const SizedBox(height: 16),
        WordSearchGridWidget(grid: pg.grid, targetWord: pg.word, isInteractive: false),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2B1A),
            border: Border.all(color: const Color(0xFF2A6640), width: 2),
            borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A5C30),
                border: Border.all(color: _gn, width: 2)),
              child: const Center(child: Text('🔓', style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Chat unlocked!',
                style: TextStyle(fontFamily: 'Fredoka One', fontSize: 16, color: _gn)),
              Text('Both you and ${widget.partnerName} solved each other\'s puzzles',
                style: const TextStyle(color: Color(0xFF2A8C50), fontFamily: 'Fredoka', fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _pu, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            onPressed: widget.onChatUnlocked,
            child: Text('Chat with ${widget.partnerName} 💬',
              style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 16)),
          )),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _pl, side: const BorderSide(color: _bd),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _playAgain,
            child: const Text('Play again 🔄',
              style: TextStyle(fontFamily: 'Fredoka One', fontSize: 14)),
          )),
      ]),
    );
  }

  // ── WAITING PAGE TABS ─────────────────────────────────────

  // Page: "Your puzzle grid — what partner sees"
  Widget _wp_myGrid(WordSearchGame g) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    const Text('📋  Your puzzle grid',
      style: TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
    const SizedBox(height: 4),
    Text('Exactly what ${widget.partnerName} is looking at',
      style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11), textAlign: TextAlign.center),
    const SizedBox(height: 10),
    WordSearchGridWidget(grid: g.grid, targetWord: g.word, isInteractive: false),
    const SizedBox(height: 10),
    _infoRow(true, '${widget.partnerName} can see this grid'),
  ]));

  // Page: "Your hidden word — don't forget it!"
  Widget _wp_myWord(WordSearchGame g) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    const Text('🔑  Your hidden word',
      style: TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
    const SizedBox(height: 4),
    const Text('In case you forgot — only you can see this!',
      style: TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11), textAlign: TextAlign.center),
    const SizedBox(height: 14),
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pd.withOpacity(0.5), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR HIDDEN WORD', style: TextStyle(color: _mt, fontFamily: 'Fredoka',
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(g.word, style: const TextStyle(fontFamily: 'Fredoka One',
          fontSize: 28, color: _pl, letterSpacing: 5)),
        const SizedBox(height: 4),
        Row(children: [
          _topicBadge(g.topic),
        ]),
      ]),
    ),
    const SizedBox(height: 10),
    _infoRow(false, '${widget.partnerName} cannot see this word'),
  ]));

  // Page: live partner status — have they solved mine yet?
  Widget _wp_partnerStatus(bool partnerSolvedMine) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text('👀  ${widget.partnerName}\'s live status',
      style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
    const SizedBox(height: 4),
    const Text('Updated in real time',
      style: TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
    const SizedBox(height: 14),
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: partnerSolvedMine ? const Color(0xFF0D2B1A) : _s2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: partnerSolvedMine ? const Color(0xFF2A6640) : _bd,
          width: partnerSolvedMine ? 2 : 1.5)),
      child: Row(children: [
        _miniAvatar(),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.partnerName,
            style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
          const SizedBox(height: 4),
          Text(
            partnerSolvedMine
                ? '✅ Found your hidden word!'
                : '${widget.partnerName} is still looking for your hidden word...',
            style: TextStyle(fontFamily: 'Fredoka', fontSize: 12,
              color: partnerSolvedMine ? _gn : _mt)),
        ])),
        partnerSolvedMine
            ? const Text('🎉', style: TextStyle(fontSize: 28))
            : const _PulsingDots(),
      ]),
    ),
    if (!partnerSolvedMine) ...[
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x206C3FE8),
          border: Border.all(color: const Color(0x406C3FE8)),
          borderRadius: BorderRadius.circular(12)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, color: _pl, size: 16),
          SizedBox(width: 8),
          Text('Chat unlocks when both puzzles are solved',
            style: TextStyle(color: _pl, fontFamily: 'Fredoka',
              fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    ],
  ]));

  // Page: what partner can see (phase 2)
  Widget _wp_partnerView() => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text("📊  What ${widget.partnerName} can see",
      style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
    const SizedBox(height: 4),
    const Text('What they can and cannot see in your puzzle',
      style: TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
    const SizedBox(height: 12),
    _infoRow(true,  'They can see: the topic hint'),
    const SizedBox(height: 8),
    _infoRow(true,  'They can see: the full grid'),
    const SizedBox(height: 8),
    _infoRow(false, 'They cannot see: your hidden word'),
    const SizedBox(height: 8),
    _infoRow(false, 'They cannot see: the correct path'),
  ]));

  // Page: solver solved screen showing the solved grid
  Widget _wp_solved(WordSearchGame pg) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text('🎯  You solved ${widget.partnerName}\'s puzzle!',
      style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 14, color: _tx)),
    const SizedBox(height: 4),
    Text("${widget.partnerName}'s word was",
      style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
    const SizedBox(height: 4),
    Text(pg.word, style: const TextStyle(fontFamily: 'Fredoka One',
      fontSize: 22, color: _pl, letterSpacing: 4)),
    const SizedBox(height: 10),
    WordSearchGridWidget(grid: pg.grid, targetWord: pg.word, isInteractive: false),
  ]));

  // Page: progress summary — two clearly labelled rows, never "You" twice
  Widget _wp_bothStatus(WordSearchGame pg, WordSearchGame mg, bool partnerSolvedMine) =>
    SingleChildScrollView(child: Column(children: [
      const SizedBox(height: 4),
      const Text('📊  Progress summary',
        style: TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
      const SizedBox(height: 12),
      // Row 1: current user — always ✅ (they are on this screen because they solved)
      _statusRow(
        label: 'You',
        sub: 'Found ${widget.partnerName}\'s word ✅',
        done: true),
      const SizedBox(height: 8),
      // Row 2: partner — uses their actual name, never "You"
      _statusRow(
        label: widget.partnerName,
        sub: partnerSolvedMine
            ? 'Found your hidden word ✅'
            : '${widget.partnerName} is still searching for your word "${mg.word}"...',
        done: partnerSolvedMine),
      const SizedBox(height: 14),
      if (!partnerSolvedMine)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x206C3FE8),
            border: Border.all(color: const Color(0x406C3FE8)),
            borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, color: _pl, size: 14),
            const SizedBox(width: 7),
            Text('Chat unlocks when ${widget.partnerName} finds your word',
              style: const TextStyle(color: _pl, fontFamily: 'Fredoka',
                fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]));

  Widget _statusRow({required String label, required String sub, required bool done}) =>
    Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF0D2B1A) : _s2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? const Color(0xFF2A6640) : _bd,
          width: done ? 2 : 1.5)),
      child: Row(children: [
        Text(done ? '✅' : '⏳', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 13, color: _tx)),
          Text(sub, style: TextStyle(fontFamily: 'Fredoka', fontSize: 11,
            color: done ? _gn : _mt)),
        ])),
      ]),
    );

  Widget _myPuzzleStatusBar({required bool partnerSolvedMine}) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: partnerSolvedMine ? const Color(0xFF0D2B1A) : _s2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: partnerSolvedMine ? const Color(0xFF2A6640) : _bd,
        width: partnerSolvedMine ? 2 : 1)),
    child: Row(children: [
      _miniAvatar(),
      const SizedBox(width: 8),
      Expanded(child: Text(
        partnerSolvedMine
            ? '${widget.partnerName} found your hidden word! ✅'
            : '${widget.partnerName} is also solving your puzzle...',
        style: TextStyle(
          color: partnerSolvedMine ? _gn : _mt,
          fontFamily: 'Fredoka', fontSize: 11))),
      if (!partnerSolvedMine) const _PulsingDots(),
    ]),
  );

  Widget _wordRevealCard(String label, String word, String topic) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _s2, borderRadius: BorderRadius.circular(14), border: Border.all(color: _bd)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: _mt, fontFamily: 'Fredoka',
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 6),
      Text(word, style: const TextStyle(fontFamily: 'Fredoka One',
        fontSize: 16, color: _pl, letterSpacing: 2)),
      const SizedBox(height: 4),
      Text(topic, style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 10)),
    ]),
  );

  Widget _dotRow(int count) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(count, (i) => GestureDetector(
      onTap: () => _waitPageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _waitPage == i ? 20 : 7, height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: _waitPage == i ? _pu : _bd,
          borderRadius: BorderRadius.circular(4)),
      ),
    )),
  );

  // ── Shared helpers ────────────────────────────────────────
  Widget _errScreen() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, color: _rd, size: 48),
    const SizedBox(height: 12),
    Text(_error!, style: const TextStyle(color: _mt)),
    const SizedBox(height: 16),
    TextButton(onPressed: _init,
      child: const Text('Retry', style: TextStyle(color: _pu, fontFamily: 'Fredoka One'))),
  ]));

  Widget _badge(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x206C3FE8),
      border: Border.all(color: const Color(0x406C3FE8)),
      borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: const TextStyle(color: _pl, fontFamily: 'Fredoka',
      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .5)));

  Widget _topicBadge(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_pd, _pu]),
      borderRadius: BorderRadius.circular(20)),
    child: Text('${kTopicIcons[t] ?? '🎯'}  $t',
      style: const TextStyle(color: Colors.white, fontFamily: 'Fredoka One', fontSize: 13)));

  Widget _stepRow(String n, String lbl) => Row(children: [
    Container(width: 28, height: 28,
      decoration: const BoxDecoration(color: _pu, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(n, style: const TextStyle(color: Colors.white,
        fontFamily: 'Fredoka One', fontSize: 13))),
    const SizedBox(width: 10),
    Text(lbl, style: const TextStyle(color: _pl, fontFamily: 'Fredoka One', fontSize: 15)),
  ]);

  Widget _infoRow(bool yes, String text) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: yes ? const Color(0xFF0D2B1A) : const Color(0xFF2B0D0D),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: yes ? const Color(0xFF1A5C30) : const Color(0xFF5C1A1A))),
    child: Row(children: [
      Text(yes ? '✅' : '🚫', style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontFamily: 'Fredoka One', fontSize: 12,
        color: yes ? _gn : _rd)),
    ]));

  Widget _hintPill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(color: const Color(0x206C3FE8),
      border: Border.all(color: _pd), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: const BoxDecoration(color: _pu, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(color: _pl, fontFamily: 'Fredoka',
        fontSize: 12, fontWeight: FontWeight.w700)),
    ]));

  Widget _partnerCard({required String sub}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _bd)),
    child: Row(children: [
      _miniAvatar(),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.partnerName,
          style: const TextStyle(fontFamily: 'Fredoka One', fontSize: 15, color: _tx)),
        Text(sub, style: const TextStyle(color: _mt, fontFamily: 'Fredoka', fontSize: 11)),
      ])),
      const _PulsingDots(),
    ]));

  Widget _miniAvatar() => Container(
    width: 32, height: 32,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Color(0xFFAD1F6A), Color(0xFFE55D9B)])),
    child: const Center(child: Text('👩', style: TextStyle(fontSize: 16))));

  Widget _resetBtn() => GestureDetector(
    onTap: _resetBoard,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFF2B0D0D),
        border: Border.all(color: const Color(0xFF5C1A1A)),
        borderRadius: BorderRadius.circular(10)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.refresh, color: _rd, size: 15),
        SizedBox(width: 5),
        Text('Reset board', style: TextStyle(color: _rd, fontFamily: 'Fredoka',
          fontSize: 12, fontWeight: FontWeight.w700)),
      ])));
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override State<_PulsingDots> createState() => _PulsingDotsState();
}
class _PulsingDotsState extends State<_PulsingDots> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Row(children: List.generate(3, (i) =>
    AnimatedBuilder(animation: _c, builder: (_, __) => Opacity(
      opacity: ((_c.value - i * 0.3).clamp(0.0, 1.0) * 0.7 + 0.3),
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 7, height: 7,
        decoration: const BoxDecoration(color: Color(0xFF6C3FE8), shape: BoxShape.circle))))));
}
