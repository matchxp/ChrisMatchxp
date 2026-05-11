// lib/games/word_search/word_search_game_screen.dart
// Restyled to match emoji_charades_package UI — deep cosmic palette,
// GoogleFonts.fredoka, full-screen layout, gradient buttons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'word_search_models.dart';
import 'word_search_service.dart';
import 'word_search_grid_widget.dart';
import 'word_search_word_bank.dart';
import '../../services/matching_service.dart';

// ── Palette — matches emoji_charades_package ──────────────────
const _kBg      = Color(0xFF07060F);
const _kCard    = Color(0xFF14093A);
const _kBorder  = Color(0xFF2E1F5E);
const _kPurple  = Color(0xFF8B5CF6);
const _kPurpleD = Color(0xFF6930C3);
const _kPurpleL = Color(0xFFA78BFA);
const _kGreen   = Color(0xFF39FF14);
const _kRed     = Color(0xFFFF6B6B);
const _kText    = Color(0xFFFFFFFF);
const _kMuted   = Color(0xFF8B7AB8);
const _kAmber   = Color(0xFFFFB800);
const _kCyan    = Color(0xFF00E5FF);

// ── Font helper ───────────────────────────────────────────────
TextStyle _f(double sz, {FontWeight fw = FontWeight.w400, Color c = _kText,
    double ls = 0, double lh = 1.0}) =>
  TextStyle(fontFamily: 'Fredoka', fontSize: sz, fontWeight: fw, color: c,
      letterSpacing: ls, height: lh);

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
  final _svc    = WordSearchService();
  final _msgSvc = MatchingService();
  RealtimeChannel? _ch;

  MatchGamesSnapshot _snap  = const MatchGamesSnapshot();
  bool   _loading           = true;
  String? _error;

  // setup form
  String? _topic;
  final   _wordCtrl = TextEditingController();
  _WState _ws       = _WState.idle;
  bool    _making   = false;

  // waiting pages
  final _waitPageCtrl = PageController();
  int   _waitPage     = 0;

  // solving
  int  _wrong        = 0;
  bool _hint         = false;
  Key  _gridKey      = UniqueKey();

  // score
  bool _scoreRecorded = false;

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
    if (_ch != null) { _svc.unsubscribe(_ch!); _ch = null; }
    setState(() { _loading = true; _error = null; });
    try {
      await _refresh();
      _ch = _svc.subscribeToMatch(
        widget.matchId,
        () { if (mounted) _refresh(); },
        channelSuffix: 'game',
      );
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load game. Check connection.'; _loading = false; });
    }
  }

  Future<void> _refresh() async {
    final snap = await _svc.getSnapshot(matchId: widget.matchId, myUserId: widget.currentUserId);
    if (!mounted) return;
    setState(() { _snap = snap; _loading = false; _error = null; });
    if (snap.phase == MatchGamePhase.bothSolved) _recordScoreIfNeeded(snap);
  }

  void _recordScoreIfNeeded(MatchGamesSnapshot snap) {
    if (_scoreRecorded) return;
    final pg = snap.partnerGame;
    final mg = snap.myGame;
    if (pg?.solvedAt == null || mg?.solvedAt == null) return;
    final iWon   = pg!.solvedAt!.isBefore(mg!.solvedAt!);
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

  Future<void> _doReset() async {
    await _svc.resetGame(widget.matchId);
    if (_waitPageCtrl.hasClients) _waitPageCtrl.jumpToPage(0);
    _wordCtrl.clear();
    setState(() {
      _topic = null; _ws = _WState.idle; _wrong = 0; _hint = false;
      _gridKey = UniqueKey(); _scoreRecorded = false; _waitPage = 0;
    });
    await _refresh();
    if (_snap.phase == MatchGamePhase.bothSolved) {
      throw Exception('Game rows could not be deleted. Please add the DELETE RLS policy.');
    }
  }

  void _onWordChange(String v) {
    final w = v.toUpperCase();
    if (_wordCtrl.text != w) {
      _wordCtrl.value = _wordCtrl.value.copyWith(
        text: w, selection: TextSelection.collapsed(offset: w.length));
    }
    setState(() {
      if (w.length < 3)                      _ws = _WState.idle;
      else if (isValidWord(_topic ?? '', w)) _ws = _WState.valid;
      else                                   _ws = _WState.invalid;
    });
  }

  Future<void> _submitPuzzle() async {
    if (_ws != _WState.valid || _topic == null || _making) return;
    setState(() => _making = true);
    try {
      await _svc.createMyPuzzle(
        matchId: widget.matchId, myUserId: widget.currentUserId,
        partnerUserId: widget.partnerUserId, topic: _topic!,
        word: _wordCtrl.text.toUpperCase(),
      );
      await _msgSvc.sendMessage(widget.matchId, '[GAME_REQUEST] 🎮 sent a Word Search challenge!');
      if (mounted) {
        _wordCtrl.clear();
        setState(() { _ws = _WState.idle; _topic = null; _making = false; });
        await _refresh();
      }
    } catch (e) {
      _snack('Something went wrong. Please try again.');
      if (mounted) setState(() => _making = false);
    }
  }

  Future<void> _onCorrect(List<GridPosition> _) async {
    final pg = _snap.partnerGame;
    if (pg == null) return;
    final updated = await _svc.markSolved(pg.id);
    if (updated != null && mounted) {
      final newSnap = MatchGamesSnapshot(myGame: _snap.myGame, partnerGame: updated);
      setState(() => _snap = newSnap);
      if (newSnap.phase == MatchGamePhase.bothSolved) _recordScoreIfNeeded(newSnap);
    }
  }

  void _onWrong() => setState(() { _wrong++; if (_wrong >= 3) _hint = true; });

  void _resetBoard() => setState(() { _gridKey = UniqueKey(); _wrong = 0; _hint = false; });

  Future<void> _playAgain() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _doReset();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack('Could not start new game — check Supabase DELETE policy.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: _f(13)),
      backgroundColor: _kCard, behavior: SnackBarBehavior.floating));

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _topBar(),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          ),
        ),
        Expanded(child: Center(
          child: RichText(text: const TextSpan(children: [
            TextSpan(text: 'MATCH', style: TextStyle(
              color: Colors.white, fontFamily: 'Fredoka One',
              fontSize: 15, letterSpacing: 1)),
            TextSpan(text: 'XP', style: TextStyle(
              color: _kPurple, fontFamily: 'Fredoka One',
              fontSize: 15, letterSpacing: 1)),
          ])),
        )),
        const SizedBox(width: 36),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kPurple));
    if (_error != null) return _errScreen();
    switch (_snap.phase) {
      case MatchGamePhase.setup:              return _setupScreen();
      case MatchGamePhase.waitingPartnerSetup: return _waitingSetupScreen();
      case MatchGamePhase.solving:            return _solvingScreen();
      case MatchGamePhase.waitingPartnerSolve: return _waitingSolveScreen();
      case MatchGamePhase.bothSolved:         return _bothSolvedScreen();
    }
  }

  // ── SHARED BUTTONS ─────────────────────────────────────────
  Widget _primaryBtn(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: onTap == null
                ? const LinearGradient(colors: [Color(0xFF2A1E48), Color(0xFF362856)])
                : const LinearGradient(colors: [_kPurpleD, _kPurple, _kPurpleL, Color(0xFF7C3AED)]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(child: Text(label,
            style: _f(17, fw: FontWeight.w600,
              c: onTap == null ? const Color(0xFF6B5A90) : _kText))),
        ),
      ),
    );
  }

  Widget _ghostBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0x66AB5CF5), width: 1.5),
        ),
        child: Text(label, style: _f(16, fw: FontWeight.w500, c: const Color(0xFFC4A8FF))),
      ),
    );
  }

  // ── PHASE 1: Setup ─────────────────────────────────────────
  Widget _setupScreen() {
    final hasTopic  = _topic != null;
    final isValid   = _ws == _WState.valid;
    final isInvalid = _ws == _WState.invalid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _badge('🎮  ICE BREAKER GAME'),
        const SizedBox(height: 14),
        RichText(textAlign: TextAlign.center, text: TextSpan(
          children: [
            TextSpan(text: 'Set your ', style: _f(26, fw: FontWeight.w700, lh: 1.2)),
            TextSpan(text: 'puzzle',    style: _f(26, fw: FontWeight.w700, c: _kPurpleL, lh: 1.2)),
          ],
        )),
        const SizedBox(height: 6),
        Text(
          'Create a word for ${widget.partnerName} to find.\n${widget.partnerName} is setting one for you too!',
          textAlign: TextAlign.center,
          style: _f(13, c: _kMuted, lh: 1.5),
        ),

        // Partner status
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder)),
          child: Row(children: [
            _miniAvatar(),
            const SizedBox(width: 10),
            Expanded(child: Text(
              '${widget.partnerName} is also setting a puzzle for you...',
              style: _f(12, c: _kMuted))),
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
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasTopic ? _kPurple : _kBorder, width: 2)),
            child: Row(children: [
              Expanded(child: Text(
                hasTopic ? '${kTopicIcons[_topic!] ?? ''}  $_topic' : 'Tap to pick a topic...',
                style: _f(16, fw: FontWeight.w600, c: hasTopic ? _kText : _kMuted))),
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
          style: _f(22, fw: FontWeight.w700, c: _kText, ls: 5),
          decoration: InputDecoration(
            hintText: hasTopic ? 'Type a ${_topic!.toLowerCase()} word...' : 'Pick a topic first',
            hintStyle: _f(16, c: const Color(0xFF4E3D72), ls: 2),
            counterStyle: _f(11, c: _kMuted),
            filled: true,
            fillColor: _kCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _kBorder, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isValid ? _kGreen : isInvalid ? _kRed : _kBorder, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isValid ? _kGreen : isInvalid ? _kRed : _kPurple, width: 2)),
          ),
        ),
        const SizedBox(height: 2),
        if (isValid)
          Row(children: [
            Icon(Icons.check_circle, color: _kGreen, size: 15),
            const SizedBox(width: 6),
            Text('Perfect — puzzle ready!', style: _f(12, fw: FontWeight.w700, c: _kGreen)),
          ])
        else if (isInvalid)
          Row(children: [
            Icon(Icons.cancel, color: _kRed, size: 15),
            const SizedBox(width: 6),
            Text('Try a different ${_topic?.toLowerCase() ?? 'word'}',
              style: _f(12, fw: FontWeight.w700, c: _kRed)),
          ])
        else
          Text(
            hasTopic ? 'Must be a real ${_topic?.toLowerCase()} (3–12 letters)' : 'Choose a topic first',
            style: _f(12, c: _kMuted)),

        const SizedBox(height: 28),
        _making
            ? const SizedBox(height: 52,
                child: Center(child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2.5)))
            : _primaryBtn(
                'Send puzzle to ${widget.partnerName} 📨',
                (isValid && !_making) ? _submitPuzzle : null),
      ]),
    );
  }

  void _showTopicSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Text('Choose your topic', style: _f(17, fw: FontWeight.w700)),
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
                    color: active ? _kPurple : _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? _kPurpleL : _kBorder, width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(kTopicIcons[t] ?? '•', style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(t, style: _f(14, fw: FontWeight.w700,
                      c: active ? Colors.white : _kText)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  // ── PHASE 2: Waiting for partner setup ─────────────────────
  Widget _waitingSetupScreen() {
    final myGame = _snap.myGame!;
    final pages  = [_wp_myGrid(myGame), _wp_myWord(myGame), _wp_partnerStatus(false), _wp_partnerView()];

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(children: [
            _badge('⏳  YOUR PUZZLE IS SENT'),
            const SizedBox(height: 10),
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
            _dotRow(pages.length),
            const SizedBox(height: 6),
            Text('Swipe · see your puzzle & ${widget.partnerName}\'s status',
              style: _f(11, c: _kMuted)),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ]);
  }

  // ── PHASE 3: Solving ───────────────────────────────────────
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
            Text("${widget.partnerName}'s puzzle", style: _f(11, c: _kMuted)),
          ]),
        ]),
        if (_hint) ...[
          const SizedBox(height: 8),
          _hintPill(
            _wrong >= 6
                ? 'Hint: the word is "${partnerGame.word}"'
                : 'Hint: ${partnerGame.word.length} letters',
          ),
        ],
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
              style: _f(12, fw: FontWeight.w700, c: _kRed)),
          ],
        ]),
        const SizedBox(height: 10),
        _myPuzzleStatusBar(partnerSolvedMine: _snap.myGame?.isSolved ?? false),
        const SizedBox(height: 6),
        Text('Tap letters in order · must be adjacent',
          style: _f(11, c: _kMuted)),
      ]),
    );
  }

  // ── PHASE 4: Waiting for partner to solve ──────────────────
  Widget _waitingSolveScreen() {
    final partnerGame       = _snap.partnerGame!;
    final myGame            = _snap.myGame!;
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
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: partnerSolvedMine
                    ? const Color(0xFF0A2010)
                    : _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: partnerSolvedMine
                      ? _kGreen.withValues(alpha: 0.4)
                      : _kBorder,
                  width: partnerSolvedMine ? 2 : 1.5)),
              child: Row(children: [
                _miniAvatar(),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.partnerName, style: _f(14, fw: FontWeight.w700)),
                  Text(
                    partnerSolvedMine
                        ? '✅ Found your hidden word!'
                        : '${widget.partnerName} is still searching for your word "${myGame.word}"...',
                    style: _f(11, c: partnerSolvedMine ? _kGreen : _kMuted)),
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
            Text('Swipe · see progress & your puzzle', style: _f(11, c: _kMuted)),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ]);
  }

  // ── PHASE 5: Both solved ───────────────────────────────────
  Widget _bothSolvedScreen() {
    final pg    = _snap.partnerGame!;
    final mg    = _snap.myGame!;
    final iWon  = pg.solvedAt != null && mg.solvedAt != null &&
        pg.solvedAt!.isBefore(mg.solvedAt!);
    final isDraw = pg.solvedAt != null && mg.solvedAt != null &&
        pg.solvedAt!.isAtSameMomentAs(mg.solvedAt!);

    final resultColor  = iWon ? _kGreen : isDraw ? _kPurpleL : _kRed;
    final resultEmoji  = isDraw ? '🤝' : iWon ? '🏆' : '😅';
    final resultTitle  = isDraw ? "It's a draw! 🤝"
        : iWon ? 'You won this round! 🏆'
        : '${widget.partnerName} won this round';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(children: [
        // Big result emoji
        _BounceIn(child: Text(resultEmoji, style: const TextStyle(fontSize: 64))),
        const SizedBox(height: 10),

        // Result banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: resultColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: resultColor.withValues(alpha: 0.45), width: 1.5)),
          child: Text(resultTitle, textAlign: TextAlign.center,
            style: _f(18, fw: FontWeight.w700, c: resultColor)),
        ),
        const SizedBox(height: 10),

        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_kPurpleL, Colors.white, _kPurpleL]).createShader(b),
          child: Text('Ice broken!', style: _f(24, fw: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text('You and ${widget.partnerName} solved each other\'s puzzles!',
          textAlign: TextAlign.center, style: _f(13, c: _kMuted)),

        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _wordRevealCard('YOUR WORD', mg.word, mg.topic)),
          const SizedBox(width: 10),
          Expanded(child: _wordRevealCard('${widget.partnerName.toUpperCase()}\'S WORD', pg.word, pg.topic)),
        ]),
        const SizedBox(height: 16),
        WordSearchGridWidget(grid: pg.grid, targetWord: pg.word, isInteractive: false),
        const SizedBox(height: 16),

        // Chat unlocked card
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.06),
            border: Border.all(color: _kGreen.withValues(alpha: 0.35), width: 2),
            borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen.withValues(alpha: 0.12),
                border: Border.all(color: _kGreen, width: 2)),
              child: const Center(child: Text('🔓', style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chat unlocked!', style: _f(16, fw: FontWeight.w700, c: _kGreen)),
              Text('Both you and ${widget.partnerName} solved each other\'s puzzles',
                style: _f(11, c: _kGreen.withValues(alpha: 0.6))),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        _primaryBtn('Chat with ${widget.partnerName} 💬', widget.onChatUnlocked),
        const SizedBox(height: 12),
        _ghostBtn('Play again 🔄', _playAgain),
      ]),
    );
  }

  // ── WAITING PAGE TABS ──────────────────────────────────────

  Widget _wp_myGrid(WordSearchGame g) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text('📋  Your puzzle grid', style: _f(15, fw: FontWeight.w700)),
    const SizedBox(height: 4),
    Text('Exactly what ${widget.partnerName} is looking at',
      style: _f(11, c: _kMuted), textAlign: TextAlign.center),
    const SizedBox(height: 10),
    WordSearchGridWidget(grid: g.grid, targetWord: g.word, isInteractive: false),
    const SizedBox(height: 10),
    _infoRow(true, '${widget.partnerName} can see this grid'),
  ]));

  Widget _wp_myWord(WordSearchGame g) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text('🔑  Your hidden word', style: _f(15, fw: FontWeight.w700)),
    const SizedBox(height: 4),
    Text('In case you forgot — only you can see this!',
      style: _f(11, c: _kMuted), textAlign: TextAlign.center),
    const SizedBox(height: 14),
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPurpleD.withValues(alpha: 0.5), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR HIDDEN WORD', style: _f(10, fw: FontWeight.w700, c: _kMuted, ls: 1)),
        const SizedBox(height: 6),
        Text(g.word, style: _f(28, fw: FontWeight.w700, c: _kPurpleL, ls: 5)),
        const SizedBox(height: 4),
        _topicBadge(g.topic),
      ]),
    ),
    const SizedBox(height: 10),
    _infoRow(false, '${widget.partnerName} cannot see this word'),
  ]));

  Widget _wp_partnerStatus(bool partnerSolvedMine) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text('👀  ${widget.partnerName}\'s live status', style: _f(15, fw: FontWeight.w700)),
    const SizedBox(height: 4),
    Text('Updated in real time', style: _f(11, c: _kMuted)),
    const SizedBox(height: 14),
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: partnerSolvedMine ? _kGreen.withValues(alpha: 0.06) : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: partnerSolvedMine ? _kGreen.withValues(alpha: 0.4) : _kBorder,
          width: partnerSolvedMine ? 2 : 1.5)),
      child: Row(children: [
        _miniAvatar(),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.partnerName, style: _f(15, fw: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            partnerSolvedMine
                ? '✅ Found your hidden word!'
                : '${widget.partnerName} is still looking for your hidden word...',
            style: _f(12, c: partnerSolvedMine ? _kGreen : _kMuted)),
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
          color: _kPurple.withValues(alpha: 0.08),
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline, color: _kPurpleL, size: 16),
          const SizedBox(width: 8),
          Text('Chat unlocks when both puzzles are solved',
            style: _f(12, fw: FontWeight.w700, c: _kPurpleL)),
        ]),
      ),
    ],
  ]));

  Widget _wp_partnerView() => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text("📊  What ${widget.partnerName} can see", style: _f(15, fw: FontWeight.w700)),
    const SizedBox(height: 4),
    Text('What they can and cannot see in your puzzle',
      style: _f(11, c: _kMuted)),
    const SizedBox(height: 12),
    _infoRow(true,  'They can see: the topic hint'),
    const SizedBox(height: 8),
    _infoRow(true,  'They can see: the full grid'),
    const SizedBox(height: 8),
    _infoRow(false, 'They cannot see: your hidden word'),
    const SizedBox(height: 8),
    _infoRow(false, 'They cannot see: the correct path'),
  ]));

  Widget _wp_solved(WordSearchGame pg) => SingleChildScrollView(child: Column(children: [
    const SizedBox(height: 4),
    Text('🎯  You solved ${widget.partnerName}\'s puzzle!',
      style: _f(14, fw: FontWeight.w700)),
    const SizedBox(height: 4),
    Text("${widget.partnerName}'s word was", style: _f(11, c: _kMuted)),
    const SizedBox(height: 4),
    Text(pg.word, style: _f(22, fw: FontWeight.w700, c: _kPurpleL, ls: 4)),
    const SizedBox(height: 10),
    WordSearchGridWidget(grid: pg.grid, targetWord: pg.word, isInteractive: false),
  ]));

  Widget _wp_bothStatus(WordSearchGame pg, WordSearchGame mg, bool partnerSolvedMine) =>
    SingleChildScrollView(child: Column(children: [
      const SizedBox(height: 4),
      Text('📊  Progress summary', style: _f(15, fw: FontWeight.w700)),
      const SizedBox(height: 12),
      _statusRow(label: 'You', sub: 'Found ${widget.partnerName}\'s word ✅', done: true),
      const SizedBox(height: 8),
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
            color: _kPurple.withValues(alpha: 0.08),
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, color: _kPurpleL, size: 14),
            const SizedBox(width: 7),
            Text('Chat unlocks when ${widget.partnerName} finds your word',
              style: _f(12, fw: FontWeight.w700, c: _kPurpleL)),
          ]),
        ),
    ]));

  Widget _statusRow({required String label, required String sub, required bool done}) =>
    Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? _kGreen.withValues(alpha: 0.06) : _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? _kGreen.withValues(alpha: 0.4) : _kBorder,
          width: done ? 2 : 1.5)),
      child: Row(children: [
        Text(done ? '✅' : '⏳', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _f(13, fw: FontWeight.w700)),
          Text(sub, style: _f(11, c: done ? _kGreen : _kMuted)),
        ])),
      ]),
    );

  Widget _myPuzzleStatusBar({required bool partnerSolvedMine}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: partnerSolvedMine ? _kGreen.withValues(alpha: 0.06) : _kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: partnerSolvedMine ? _kGreen.withValues(alpha: 0.4) : _kBorder,
        width: partnerSolvedMine ? 2 : 1)),
    child: Row(children: [
      _miniAvatar(),
      const SizedBox(width: 8),
      Expanded(child: Text(
        partnerSolvedMine
            ? '${widget.partnerName} found your hidden word! ✅'
            : '${widget.partnerName} is also solving your puzzle...',
        style: _f(11, c: partnerSolvedMine ? _kGreen : _kMuted))),
      if (!partnerSolvedMine) const _PulsingDots(),
    ]),
  );

  Widget _wordRevealCard(String label, String word, String topic) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder)),
    child: Column(children: [
      Text(label, style: _f(9, fw: FontWeight.w700, c: _kMuted, ls: 1)),
      const SizedBox(height: 6),
      Text(word, style: _f(16, fw: FontWeight.w700, c: _kPurpleL, ls: 2)),
      const SizedBox(height: 4),
      Text(topic, style: _f(10, c: _kMuted)),
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
          color: _waitPage == i ? _kPurple : _kBorder,
          borderRadius: BorderRadius.circular(4)),
      ),
    )),
  );

  // ── Shared helpers ─────────────────────────────────────────
  Widget _errScreen() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.error_outline, color: _kRed, size: 48),
    const SizedBox(height: 12),
    Text(_error!, style: _f(13, c: _kMuted)),
    const SizedBox(height: 16),
    TextButton(onPressed: _init,
      child: Text('Retry', style: _f(14, fw: FontWeight.w700, c: _kPurple))),
  ]));

  Widget _badge(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: _kPurple.withValues(alpha: 0.1),
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: _f(11, fw: FontWeight.w700, c: _kPurpleL, ls: 0.5)));

  Widget _topicBadge(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_kPurpleD, _kPurple]),
      borderRadius: BorderRadius.circular(20)),
    child: Text('${kTopicIcons[t] ?? '🎯'}  $t',
      style: _f(13, fw: FontWeight.w700)));

  Widget _stepRow(String n, String lbl) => Row(children: [
    Container(width: 28, height: 28,
      decoration: const BoxDecoration(color: _kPurple, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(n, style: _f(13, fw: FontWeight.w700))),
    const SizedBox(width: 10),
    Text(lbl, style: _f(15, fw: FontWeight.w700, c: _kPurpleL)),
  ]);

  Widget _infoRow(bool yes, String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: yes
          ? _kGreen.withValues(alpha: 0.06)
          : _kRed.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: yes ? _kGreen.withValues(alpha: 0.35) : _kRed.withValues(alpha: 0.35))),
    child: Row(children: [
      Text(yes ? '✅' : '🚫', style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 8),
      Text(text, style: _f(12, fw: FontWeight.w700, c: yes ? _kGreen : _kRed)),
    ]));

  Widget _hintPill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: _kPurple.withValues(alpha: 0.1),
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: const BoxDecoration(color: _kPurple, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(t, style: _f(12, fw: FontWeight.w700, c: _kPurpleL)),
    ]));

  Widget _partnerCard({required String sub}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder)),
    child: Row(children: [
      _miniAvatar(),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.partnerName, style: _f(15, fw: FontWeight.w700)),
        Text(sub, style: _f(11, c: _kMuted)),
      ])),
      const _PulsingDots(),
    ]));

  Widget _miniAvatar() {
    final initial = widget.partnerName.isNotEmpty
        ? widget.partnerName[0].toUpperCase() : '?';
    return Container(
      width: 32, height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [_kPurpleD, _kPurple])),
      child: Center(child: Text(initial,
        style: _f(14, fw: FontWeight.w700))),
    );
  }

  Widget _resetBtn() => GestureDetector(
    onTap: _resetBoard,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.08),
        border: Border.all(color: _kRed.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.refresh, color: _kRed, size: 15),
        const SizedBox(width: 5),
        Text('Reset board', style: _f(12, fw: FontWeight.w700, c: _kRed)),
      ])));
}

// ── Helper widget: pulsing dots ────────────────────────────────
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override State<_PulsingDots> createState() => _PulsingDotsState();
}
class _PulsingDotsState extends State<_PulsingDots> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Row(
    children: List.generate(3, (i) => AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: ((_c.value - i * 0.3).clamp(0.0, 1.0) * 0.7 + 0.3),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 7, height: 7,
          decoration: const BoxDecoration(color: _kPurple, shape: BoxShape.circle))))));
}

// ── Helper widget: bounce-in ───────────────────────────────────
class _BounceIn extends StatefulWidget {
  final Widget child;
  const _BounceIn({required this.child});
  @override State<_BounceIn> createState() => _BounceInState();
}
class _BounceInState extends State<_BounceIn> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _s = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _s, builder: (_, child) => Transform.scale(scale: _s.value, child: child),
    child: widget.child,
  );
}
