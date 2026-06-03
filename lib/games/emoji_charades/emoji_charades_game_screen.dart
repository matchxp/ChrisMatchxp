// ============================================================
//  emoji_charades_game_screen.dart
//  Full Emoji Charades game — all 8 screens in one file.
//  lib/games/emoji_charades/
//
//  pubspec.yaml — add if not already present:
//    google_fonts: ^6.1.0
//    confetti: ^0.7.0
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matchx_auth/games/game_hub_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import 'emoji_charades_data.dart';
import '../word_search/word_search_service.dart';

// ── Palette ──────────────────────────────────────────────────
const _kBgMid = Color(0xFF120D2E);
const _kPurple = Color(0xFF8B5CF6);
const _kPurpleD = Color(0xFF6930C3); //use for noti color
const _kPurpleL = Color(0xFFA78BFA);
const _kAmber = Color(0xFFFFB800);
const _kCyan = Color(0xFF00E5FF);
const _kGreen = Color(0xFF39FF14);
const _kPink = Color(0xFFFF2D78);
const _kText = Color(0xFFFFFFFF);
const _kSub = Color(0xFF8B7AB8);
const _kCard = Color(0xFF14093A);
const _kBorder = Color(0xFF2E1F5E);
const _kRed = Color(0xFFFF9999);

// ── Text style shorthand ─────────────────────────────────────
TextStyle _f(double sz,
        {FontWeight fw = FontWeight.w400,
        Color c = _kText,
        double ls = 0,
        double lh = 1.0}) =>
    GoogleFonts.fredoka(
        fontSize: sz, fontWeight: fw, color: c, letterSpacing: ls, height: lh);

// ── Game phase ───────────────────────────────────────────────
enum _Phase { intro, category, phrase, create, waiting, solve, waitSolve, done }

// ── Final screen outcome ─────────────────────────────────────
enum _Outcome {
  bothSolved,
  iSolvedTheySkipped,
  iSkippedTheySolved,
  bothSkipped
}

// ── Particle data ────────────────────────────────────────────
class _Particle {
  final String emoji;
  double x, y;
  final double tx;
  final double size;
  double opacity;
  final double duration;
  double elapsed;
  final String zone;

  _Particle(
      {required this.emoji,
      required this.x,
      required this.y,
      required this.tx,
      required this.size,
      required this.duration,
      required this.zone})
      : opacity = 0.0,
        elapsed = 0.0;
}

// ============================================================
//  ENTRY POINT — launch from your match/chat screen
// ============================================================
class EmojiCharadesGameScreen extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback? onChatUnlocked;
  final String? sessionId;

  /// When true, skip the intro animation and start at the category picker.
  final bool skipIntro;

  final bool chatAlreadyUnlocked;

  const EmojiCharadesGameScreen({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    this.onChatUnlocked,
    this.sessionId,
    this.skipIntro = false,
    this.chatAlreadyUnlocked = false,
  });

  @override
  State<EmojiCharadesGameScreen> createState() => _State();
}

class _State extends State<EmojiCharadesGameScreen>
    with TickerProviderStateMixin {
  final _db = Supabase.instance.client;
  final _rng = Random();

  // ── Phase ─────────────────────────────────────────────────
  _Phase _phase = _Phase.intro;

  // True while _loadMyRecord() is restoring state on re-entry (skipIntro=true).
  // Hides the UI so the category picker doesn't flash before the real phase loads.
  bool _checking = false;

  // ── My picks ──────────────────────────────────────────────
  int _catIdx = 0;
  int _phraseIdx = 0;
  String _myEmojis = '';
   String _myPhrase = ''; 
  final _emojiCtrl = TextEditingController();
  final _emojiFocus = FocusNode();

  // ── Partner Supabase record ───────────────────────────────
  Map<String, dynamic>? _partnerRow;

  // ── Solve state ───────────────────────────────────────────
  final _ansCtrl = TextEditingController();
  String _ansInput = '';
  bool _ansCorrect = false;
  bool _ansWrong = false;
  bool _skipped = false;
  bool _iSolved = false;
  int _timerVal = 15;
  bool _timerDone = false;
  Timer? _timer;
  Timer? _hintTimer;
  Timer? _completionPoller;
  bool _completionSent = false;

  // ── Confetti ──────────────────────────────────────────────
  late ConfettiController _confetti;

  // ── Intro animation ───────────────────────────────────────
  int _introSet = 0;
  int _lastExit = -1;
  List<String> _introEmojis = List.from(kIntroSets[0]);
  bool _introExiting = false;
  bool _introEntering = false;
  Timer? _introTimer;

  late AnimationController _floatL, _floatM, _floatR;
  late Animation<double> _floatLAnim, _floatMAnim, _floatRAnim;

  late AnimationController _exitCtrl, _enterCtrl;
  late Animation<double> _exitOpacity, _enterScale, _enterOpacity;

  // Particles
  final List<_Particle> _particles = [];
  late AnimationController _particleTick;
  Timer? _particleScheduler;

  // ── Supabase realtime ─────────────────────────────────────
  RealtimeChannel? _channel;

  // ── Category page controller ──────────────────────────────
  final _pageCtrl = PageController(viewportFraction: 0.85);

  // ── Tutorial ──────────────────────────────────────────────
  bool _showTut = false;

  // ── Getters ───────────────────────────────────────────────
  EcCategory get _cat => kEcCategories[_catIdx];
  String _singular(String label) {
    const map = {
      'Movies': 'Movie',
      'Activities': 'Activity',
      'Songs': 'Song',
      'Personalities': 'Personality',
    };
    return map[label] ?? label;
  }
  List<String> get _phrases => kEcPhrases[_cat.key]!;
  String get _phrase => _phrases[_phraseIdx];
  String get _partnerEmojis => _partnerRow?['emojis'] as String? ?? '';
  String get _partnerPhrase => _partnerRow?['phrase'] as String? ?? '';
  String get _partnerCatKey =>
      _partnerRow?['category_key'] as String? ?? 'movies';
  bool get _partnerSubmitted => _partnerRow?['submitted'] == true;
  bool get _partnerSolved => _partnerRow?['solved'] == true;
  bool get _partnerSkipped => _partnerRow?['skipped'] == true;
  bool get _partnerFinished => _partnerSolved || _partnerSkipped;

  EcCategory get _partnerCat =>
      kEcCategories.firstWhere((c) => c.key == _partnerCatKey,
          orElse: () => kEcCategories[0]);

  _Outcome get _outcome {
    if (_iSolved && _partnerSolved) return _Outcome.bothSolved;
    if (_iSolved && _partnerSkipped) return _Outcome.iSolvedTheySkipped;
    if (_skipped && _partnerSolved) return _Outcome.iSkippedTheySolved;
    return _Outcome.bothSkipped;
  }

  // Avatars
   String _myAvatarUrl = '';
   String _partnerAvatarUrl = '';
  // ============================================================
  //  INIT & DISPOSE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _fetchAvatars();
    _confetti = ConfettiController(duration: const Duration(seconds: 1));

    _floatL = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _floatM = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _floatR = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _floatLAnim = Tween<double>(begin: 0, end: -14)
        .animate(CurvedAnimation(parent: _floatL, curve: Curves.easeInOut));
    _floatMAnim = Tween<double>(begin: 0, end: -16)
        .animate(CurvedAnimation(parent: _floatM, curve: Curves.easeInOut));
    _floatRAnim = Tween<double>(begin: 0, end: -8)
        .animate(CurvedAnimation(parent: _floatR, curve: Curves.easeInOut));

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _exitOpacity = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut));

    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _enterScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.18), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.06), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.02), weight: 17),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 18),
    ]).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterOpacity = Tween<double>(begin: 1, end: 1).animate(_enterCtrl);

    _particleTick =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..repeat();
    _particleTick.addListener(_tickParticles);

    if (widget.skipIntro) {
      _phase = _Phase.category;
      _checking = true; // hide UI until _loadMyRecord restores the real phase
    } else {
      _startIntro();
    }
    _subscribeRealtime();
    _loadMyRecord();
  }
  
  Future<void> _fetchAvatars() async {
    try {
      final rows = await _db
          .from('profiles')
          .select('id, photos')
          .inFilter('id', [widget.currentUserId, widget.partnerUserId]);
      for (final row in (rows as List)) {
        final id = row['id'] as String;
        final photos = row['photos'];
        final url = (photos is List && photos.isNotEmpty)
            ? photos[0] as String
            : '';
        if (!mounted) return;
        if (id == widget.currentUserId) setState(() => _myAvatarUrl = url);
        if (id == widget.partnerUserId) setState(() => _partnerAvatarUrl = url);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    _completionPoller?.cancel();
    _introTimer?.cancel();
    _particleScheduler?.cancel();
    _floatL.dispose();
    _floatM.dispose();
    _floatR.dispose();
    _exitCtrl.dispose();
    _enterCtrl.dispose();
    _particleTick.removeListener(_tickParticles);
    _particleTick.dispose();
    _confetti.dispose();
    _emojiCtrl.dispose();
    _emojiFocus.dispose();
    _ansCtrl.dispose();
    _pageCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ============================================================
  //  INTRO ANIMATION
  // ============================================================
  void _startIntro() {
    _introTimer?.cancel();
    _introTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (_phase == _Phase.intro) _rotateIntroEmojis();
    });
    _spawnParticle();
    _scheduleNextParticle();
  }

  Future<void> _rotateIntroEmojis() async {
    if (_introExiting || _introEntering) return;

    final exits = [0, 1, 2, 3].where((i) => i != _lastExit).toList()..shuffle();
    _lastExit = exits.first;

    setState(() => _introExiting = true);
    await _exitCtrl.forward(from: 0);
    _exitCtrl.reset();

    setState(() {
      _introExiting = false;
      _introEntering = true;
      _introSet = (_introSet + 1) % kIntroSets.length;
      _introEmojis = List.from(kIntroSets[_introSet]);
    });

    await _enterCtrl.forward(from: 0);
    _enterCtrl.reset();
    setState(() => _introEntering = false);
  }

  // ── Particles ────────────────────────────────────────────
  void _tickParticles() {
    if (_phase != _Phase.intro) return;
    setState(() {
      const dt = 0.016;
      _particles.removeWhere((p) {
        p.elapsed += dt;
        final progress = (p.elapsed / p.duration).clamp(0.0, 1.0);
        p.y -= dt * 0.12;
        p.x += p.tx * dt * 0.015;
        if (progress < 0.10) {
          p.opacity = (progress / 0.10).clamp(0, 1);
        } else if (progress > 0.70)
          p.opacity = (1 - (progress - 0.70) / 0.30).clamp(0, 1);
        else
          p.opacity = 1.0;
        return progress >= 1.0;
      });
    });
  }

  void _spawnParticle() {
    final zones = [
      'left',
      'left',
      'right',
      'right',
      'centre',
      'centre',
      'centre'
    ];
    final zone = zones[_rng.nextInt(zones.length)];
    double x;
    double tx;

    if (zone == 'left') {
      x = 0.02 + _rng.nextDouble() * 0.18;
      tx = 0.04 + _rng.nextDouble() * 0.10;
    } else if (zone == 'right') {
      x = 0.80 + _rng.nextDouble() * 0.18;
      tx = -(0.04 + _rng.nextDouble() * 0.10);
    } else {
      x = 0.30 + _rng.nextDouble() * 0.40;
      tx = (_rng.nextDouble() - 0.5) * 0.08;
    }

    _particles.add(_Particle(
      emoji: kParticlePool[_rng.nextInt(kParticlePool.length)],
      x: x,
      y: 0.80 + (_rng.nextDouble() - 0.5) * 0.10,
      tx: tx,
      size: 22 + _rng.nextDouble() * 12,
      duration: 4.0 + _rng.nextDouble() * 2.0,
      zone: zone,
    ));
  }

  void _scheduleNextParticle() {
    if (_phase != _Phase.intro) return;
    final ms = 400 + _rng.nextInt(400);
    _particleScheduler = Timer(Duration(milliseconds: ms), () {
      if (_phase == _Phase.intro && mounted) {
        _spawnParticle();
        _scheduleNextParticle();
      }
    });
  }

  // ============================================================
  //  SUPABASE
  // ============================================================
  Future<void> _loadMyRecord() async {
    var q = _db
        .from('emoji_charades_games')
        .select()
        .eq('match_id', widget.matchId)
        .eq('user_id', widget.currentUserId);
    if (widget.sessionId != null) q = q.eq('session_id', widget.sessionId!);
    final res = await q.maybeSingle();
    if (res != null && mounted) {
      final emojis     = (res['emojis'] as String?) ?? '';
      final submitted  = res['submitted'] == true;
      final solved     = res['solved'] == true;
      final skipped    = res['skipped'] == true;

      setState(() {
        _myEmojis = emojis;
        _myPhrase = (res['phrase'] as String?) ?? '';
        if (submitted) {
          if (solved)   _iSolved = true;
          if (skipped)  _skipped = true;
        }
      });

      // When rejoining (skipIntro=true), restore the phase from DB state so
      // the user lands where they left off instead of the category picker.
     
if (widget.skipIntro && _phase != _Phase.done) {
        // Check if session is already completed — jump straight to done screen
        if (widget.sessionId != null) {
          final sessionRow = await _db
              .from('game_sessions')
              .select('status')
              .eq('id', widget.sessionId!)
              .maybeSingle();
          if (sessionRow?['status'] == 'completed') {
            _goTo(_Phase.done);
            if (_outcome == _Outcome.bothSolved || _outcome == _Outcome.iSolvedTheySkipped) {
              _confetti.play();
            }
            if (mounted) setState(() => _checking = false);
            return;
          }
        }
        if (submitted) {
          if (solved || skipped) {
            // Finished solving — waiting for partner to finish.
            _goTo(_Phase.waitSolve);
          } else {
            // Submitted my charade but haven't solved partner's yet.
            // Land on waiting screen; "Solve Puzzle" button activates
            // automatically once _partnerSubmitted is set by realtime.
            _goTo(_Phase.waiting);
          }
        } else if (emojis.isNotEmpty) {
          // Was creating the charade but hadn't submitted yet.
          _goTo(_Phase.create);
        } else {
          // emojis empty + not submitted → user hasn't really started.
          // Show intro so they see the game instructions first.
          _goTo(_Phase.intro);
        }
      }
      _checkCompletionOnLoad();
      // Phase restored — reveal the UI now.
      if (_checking) setState(() => _checking = false);
    } else if (mounted && _checking) {
      // No DB record — user hasn't started the game at all.
      // If we got here via skipIntro (sender tapping their own card),
      // show the intro so they get the full experience before picking a category.
      setState(() {
        _checking = false;
        if (widget.skipIntro) {
          _phase = _Phase.intro;
        }
      });
      if (widget.skipIntro) _startIntro();
    }
  }

  // Detect re-entry into an already-finished game (e.g. after app restart or
  // _resumePendingChallengePoller navigating to a stuck-active session).
  // Called after each initial record fetch — safe to call multiple times.
  void _checkCompletionOnLoad() {
    final myDone = _iSolved || _skipped;
    if (!myDone || !_partnerFinished || _phase == _Phase.done) return;
    _goTo(_Phase.done);
   if (_outcome == _Outcome.bothSolved || _outcome == _Outcome.iSolvedTheySkipped) _confetti.play();
    _sendCompletion();
  }

  void _subscribeRealtime() {
    _channel = _db
        .channel('ec:${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'emoji_charades_games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row['user_id'] != widget.partnerUserId) {
              return;
            }
            // Ignore events from a different session (same match, old game)
            final rowSession = row['session_id'] as String?;
            if (widget.sessionId != null &&
                rowSession != null &&
                rowSession != widget.sessionId) {
              return;
            }
            setState(() => _partnerRow = row);
            _onPartnerUpdate();
          },
        )
        .subscribe();

    var pq = _db
        .from('emoji_charades_games')
        .select()
        .eq('match_id', widget.matchId)
        .eq('user_id', widget.partnerUserId);
    if (widget.sessionId != null) pq = pq.eq('session_id', widget.sessionId!);
    pq.maybeSingle().then((row) {
      if (row != null && mounted) {
        setState(() => _partnerRow = row);
        _checkCompletionOnLoad();
      }
    });
  }

  /// Record EC score to the shared game_scores table.
  ///
  /// Scoring rules (matching WS for consistency):
  ///   • Win  (I solved, they skipped)   → complete_game_session already inserted
  ///                                        a score row server-side — do nothing here.
  ///   • Loss (I skipped, they solved)   → same; complete_game_session handled it.
  ///   • Both solved                     → award each player +1 (complete_game_session
  ///                                        skips the insert for draws/null winner).
  ///   • Both skipped                    → no points for anyone.
  ///
  /// We must NOT call recordWinner for wins/losses — complete_game_session
  /// (SECURITY DEFINER) already inserts a game_scores row, so a client-side
  /// call here would double-count every win.

 Future<void> _sendCompletion() async {
    debugPrint('[EmojiCharades] sendCompletion called, sessionId=${widget.sessionId}, sent=$_completionSent');
    if (_completionSent || widget.sessionId == null) return;
    _completionSent = true;
    final String? winnerId = switch (_outcome) {
      _Outcome.iSolvedTheySkipped => widget.currentUserId,
      _Outcome.iSkippedTheySolved => widget.partnerUserId,
      _ => null,
    };
    final String resultLabel = switch (_outcome) {
      _Outcome.bothSolved         => 'both_solved',
      _Outcome.bothSkipped        => 'both_skipped',
      _Outcome.iSolvedTheySkipped => 'completed',
      _Outcome.iSkippedTheySolved => 'completed',
    };
    try {
      await _db.rpc('complete_game_session', params: {
        'p_session_id': widget.sessionId,
        'p_winner_id': winnerId,
        'p_result_label': resultLabel,
      });
      debugPrint('[EmojiCharades] complete_game_session done');
    } catch (e) {
      debugPrint('[EmojiCharades] complete_game_session error: $e');
    }
  }

  void _onPartnerUpdate() {
    debugPrint('[PARTNER-UPDATE] phase=$_phase partnerFinished=$_partnerFinished partnerSolved=$_partnerSolved partnerSkipped=$_partnerSkipped');
    if (_phase == _Phase.waiting && _partnerSubmitted) {
      setState(() {});
    }
    if (_phase == _Phase.waitSolve && _partnerFinished) {
      debugPrint('[PARTNER-UPDATE] going to done');
      _goTo(_Phase.done);
      if (_outcome == _Outcome.bothSolved || _outcome == _Outcome.iSolvedTheySkipped) _confetti.play();
      _sendCompletion();
    }
  }

  Future<void> _upsertMyRecord(Map<String, dynamic> data) async {
    await _db.from('emoji_charades_games').upsert({
      'match_id': widget.matchId,
      'user_id': widget.currentUserId,
      if (widget.sessionId != null) 'session_id': widget.sessionId,
      ...data,
    }, onConflict: 'match_id,user_id');
  }

  // ============================================================
  //  NAVIGATION
  // ============================================================
  void _goTo(_Phase p) {
    _timer?.cancel();
    _introTimer?.cancel();
    _particleScheduler?.cancel();
    _completionPoller?.cancel();
    setState(() => _phase = p);
    if (p == _Phase.intro) _startIntro();
    if (p == _Phase.solve) _startSolveTimer();
    if (p == _Phase.waitSolve) _startCompletionPoller();
  }

  void _startCompletionPoller() {
    _completionPoller = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _completionSent) {
        _completionPoller?.cancel();
        return;
      }
      var pq = _db
          .from('emoji_charades_games')
          .select()
          .eq('match_id', widget.matchId)
          .eq('user_id', widget.partnerUserId);
      if (widget.sessionId != null) {
        pq = pq.eq('session_id', widget.sessionId!);
      }
      final row = await pq.maybeSingle();
      if (row == null || !mounted || _completionSent) return;
      setState(() => _partnerRow = row);
      if (_partnerFinished) {
        _completionPoller?.cancel();
        _onPartnerUpdate();
      }
    });
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    // Still loading DB state on re-entry — show blank background to prevent
    // the category picker from flashing before the real phase is restored.
    if (_checking) {
      return const Scaffold(backgroundColor: _kBgMid, body: SizedBox.expand());
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
  gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            stops: [0.0, 0.18, 0.38, 0.60, 0.82, 1.0],
            colors: [
              Color.fromARGB(255, 110, 29, 131),
              Color(0xFF2E0858),
              Color(0xFF180430),
              Color(0xFF0F0B1E),
              Color(0xFF0D0B14),
              Color(0xFF0C0B11),
            ],
          ),
        ),
          child: Stack(children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.12, 0.22, 0.30],
                  colors: [
                    Color(0xCC0C0A12),
                    Color(0x550C0A12),
                    Color(0x110C0A12),
                    Color(0x000C0A12),
                  ],
                ),
              ),
            ),
            // SafeArea(top: false) pads only the bottom so phase content
            // (buttons, "Start Chatting", etc.) clears the system nav bar
            // on Samsung devices.  The top SafeArea is handled per-phase
            // inside _topBar()'s own SafeArea(bottom: false).
            SafeArea(top: false, child: _buildPhase()),
            if (_showTut && _phase == _Phase.intro) _buildTutorial(),
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
            child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 60,
                  gravity: 0.3,
                  maxBlastForce: 20,
                  minBlastForce: 10,
                  emissionFrequency: 0.01,
                colors: const [
                      Colors.white,
                      Color(0xFFAB5CF5),
                      Color(0xFF7C3AED),
                      Color(0xFF4C1D95),
                      Color(0xFFDDD6FE),
                      Color(0xFF6930C3),
                    ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro();
      case _Phase.category:
        return _buildCategory();
      case _Phase.phrase:
        return _buildPhrase();
      case _Phase.create:
        return _buildCreate();
      case _Phase.waiting:
        return _buildWaiting();
      case _Phase.solve:
        return _buildSolve();
      case _Phase.waitSolve:
        return _buildWaitSolve();
      case _Phase.done:
        return _buildDone();
    }
  }

  // ============================================================
  //  SHARED WIDGETS
  // ============================================================
  Widget _topBar({VoidCallback? onBack}) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Icon(Icons.chevron_left_rounded,
                color: onBack != null
                    ? const Color(0xFFC4B8E8)
                    : Colors.transparent,
                size: 28),
          ),
          Expanded(
              child: Center(
            child: Text('EMOJI CHARADES',
                style: _f(13,
                    fw: FontWeight.w600, c: const Color(0xFF7B6AAA), ls: 1.0)),
          )),
          const SizedBox(width: 28),
        ]),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
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
                ? const LinearGradient(
                    colors: [Color(0xFF2A1E48), Color(0xFF362856)])
                : const LinearGradient(colors: [
                    _kPurpleD,
                    _kPurple,
                    _kPurpleL,
                    Color(0xFF7C3AED)
                  ]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
              child: Text(label,
                  style: _f(18,
                      fw: FontWeight.w600,
                      c: onTap == null ? const Color(0xFF6B5A90) : _kText))),
        ),
      ),
    );
  }

  Widget _ghostBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0x66AB5CF5), width: 1.5),
        ),
        child: Text(label,
            style: _f(16, fw: FontWeight.w500, c: const Color(0xFFC4A8FF))),
      ),
    );
  }

  Widget _pulseDots() {
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            3, (i) => _PulseDot(delay: Duration(milliseconds: i * 280))));
  }

  // ============================================================
  //  SCREEN: INTRO
  // ============================================================
  Widget _buildIntro() {
  final size = MediaQuery.of(context).size;
  return Stack(children: [
    ...(_particles.map((p) => Positioned(
          left: p.x * size.width - p.size / 2,
          top: p.y * size.height,
          child: Opacity(
              opacity: p.opacity.clamp(0, 1),
              child: Text(p.emoji, style: TextStyle(fontSize: p.size))),
        ))),
    Column(children: [
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFFC4B8E8), size: 28),
            ),
          ),
        ),
      ),
      const SizedBox(height: 28),
      Text('EMOJI', style: _f(56, fw: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('CHARADES', style: _f(56, fw: FontWeight.w700, c: _kAmber)),
      const SizedBox(height: 6),
      Expanded(
          child: Center(
              child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _introEmojiSlot(0, _floatLAnim, rotDeg: -4),
          _introEmojiSlot(1, _floatMAnim, scl: 1.1),
          _introEmojiSlot(2, _floatRAnim, rotDeg: 6),
        ],
      ))),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 50),
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() => _showTut = true),
            child: Text('View tutorial',
                style: _f(18, fw: FontWeight.w500, c: const Color(0xFFC8AAFF))
                    .copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFC8AAFF))),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _primaryBtn('Play now', () => _goTo(_Phase.category)),
          ),
        ]),
      ),
    ]),
  ]);
}

  Widget _introEmojiSlot(int idx, Animation<double> floatAnim,
      {double rotDeg = 0, double scl = 1.0}) {
    return AnimatedBuilder(
      animation: floatAnim,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, floatAnim.value),
          child: Transform.rotate(
            angle: rotDeg * pi / 180,
            child: _introEntering
                ? AnimatedBuilder(
                    animation: _enterCtrl,
                    builder: (_, __) => Transform.scale(
                        scale: _enterScale.value,
                        child: Text(_introEmojis[idx],
                            style: TextStyle(fontSize: idx == 1 ? 58 : 50))))
                : _introExiting
                    ? AnimatedBuilder(
                        animation: _exitCtrl,
                        builder: (_, __) => Opacity(
                            opacity: _exitOpacity.value,
                            child: Text(_introEmojis[idx],
                                style:
                                    TextStyle(fontSize: idx == 1 ? 58 : 50))))
                    : Text(_introEmojis[idx],
                        style: TextStyle(fontSize: idx == 1 ? 58 : 50)),
          ),
        );
      },
    );
  }

  // ============================================================
  //  SCREEN: TUTORIAL OVERLAY
  // ============================================================
  Widget _buildTutorial() {
    return GestureDetector(
      onTap: () => setState(() => _showTut = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A0F3A), Color(0xFF0F0920)]),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: _kBorder),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: const Color(0x66AB5CF5),
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 18),
                                      Center(
                    child: Text('HOW TO PLAY',
                        style: _f(13, fw: FontWeight.w700, c: _kPurple, ls: 2.0)),
                  ),
                    const SizedBox(height: 18),
                    _tutStep('1', 'Pick a category and a random phrase',
                        const Color(0xFF00E5FF)),
                    const SizedBox(height: 18),
                    _tutStep('2', 'Turn it into emojis and send your puzzle',
                        _kPink),
                    const SizedBox(height: 18),
                    _tutStep(
                        '3', 'Type your guess, you have 15 seconds!', _kGreen),
                    const SizedBox(height: 24),
                    _primaryBtn(
                        'GOT IT', () => setState(() => _showTut = false)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tutStep(String num, String text, Color c) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 2),
                  boxShadow: [
                    BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 10)
                  ]),
              child: Center(
                  child: Text(num, style: _f(16, fw: FontWeight.w700, c: c)))),
          const SizedBox(width: 14),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(text,
                      style: _f(16,
                          fw: FontWeight.w500,
                          c: const Color(0xFFE2D5FF),
                          lh: 1.4)))),
        ],
      );

  // ============================================================
  //  SCREEN: CATEGORY
  // ============================================================
  Widget _buildCategory() {
    return Column(children: [
      _topBar(onBack: () => _goTo(_Phase.intro)),
      const SizedBox(height: 24),
      Text('CHOOSE A',
          style:
              _f(18, fw: FontWeight.w600, c: const Color(0xFFC084FC), ls: 2.5)),
      const SizedBox(height: 6),
      _GlowText(text: 'Category', style: _f(50, fw: FontWeight.w700)),
      const SizedBox(height: 12),
      Text('Swipe to explore',
          style: _f(16, fw: FontWeight.w500, c: const Color(0xFFC084FC))),
     const SizedBox(height: 24),
    
      const SizedBox(height: 60),
      SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _catIdx = i),
            itemCount: kEcCategories.length,
            itemBuilder: (_, i) {
              final cat = kEcCategories[i];
              final active = i == _catIdx;
              return AnimatedScale(
                scale: active ? 1.0 : 0.86,
                duration: const Duration(milliseconds: 250),
                child: AnimatedOpacity(
                  opacity: active ? 1.0 : 0.55,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: active
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [cat.bg, cat.dark],
                            )
                          : null,
                      color: active ? null : const Color(0xFF0F0D1E),
                      border: Border.all(
                        color:
                            active ? cat.neon : Colors.white.withValues(alpha: 0.06),
                        width: 2,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: cat.neon.withValues(alpha: 0.35),
                                  blurRadius: 32)
                            ]
                          : [],
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 68)),
                          const SizedBox(height: 18),
                          Text(cat.label,
                              style: _f(28,
                                  fw: FontWeight.w700,
                                  c: active
                                      ? cat.neon
                                      : cat.neon.withValues(alpha: 0.2))),
                        ]),
                  ),
                ),
              );
            },
          )),
      const SizedBox(height: 14),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              kEcCategories.length,
              (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _catIdx ? 20 : 6,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _catIdx
                          ? kEcCategories[i].neon
                          : const Color(0xFF2B2945),
                    ),
                  ))),
      const Spacer(),
      Padding(
      padding: const EdgeInsets.fromLTRB(34, 12, 34, 40),
      child: _primaryBtn('Select ${_cat.label}', () {
        setState(() => _phraseIdx = _rng.nextInt(_phrases.length));
        _goTo(_Phase.phrase);
      }),
    ),
        ]);
      }
  // ============================================================
  //  SCREEN: PHRASE
  // ============================================================
  Widget _buildPhrase() {
    return Column(children: [
      _topBar(onBack: () => _goTo(_Phase.category)),
      const SizedBox(height: 32),
      _FloatingText(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_cat.icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Text(_cat.label, style: _f(26, fw: FontWeight.w600, c: _cat.neon)),
        ]),
      ),
      Expanded(
          child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _FloatingText(
            child: Text(_phrase,
                textAlign: TextAlign.center,
                style: _f(42, fw: FontWeight.w700)),
          ),
        ),
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
        child: Column(children: [
          _primaryBtn('Use this phrase', () => _goTo(_Phase.create)),
          const SizedBox(height: 14),
          _ghostBtn('Try another', () {
            setState(() => _phraseIdx = (_phraseIdx + 1) % _phrases.length);
          }),
          const SizedBox(height: 14),
          _ghostBtn('Change category', () => _goTo(_Phase.category)),
        ]),
      ),
    ]);
  }

  // ============================================================
  //  SCREEN: CREATE EMOJI
  // ============================================================
 Widget _buildCreate() {
  final hasEmojis = _myEmojis.trim().isNotEmpty;
  return Column(children: [
    _topBar(onBack: () => _goTo(_Phase.phrase)),
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(children: [
        Text(_phrase,
            textAlign: TextAlign.center,
            style: _f(40, fw: FontWeight.w700)),
        const SizedBox(height: 10),
        Text('Turn it into emojis 👇', style: _f(17, c: _kSub)),
      ]),
    ),
    Expanded(
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(_emojiFocus),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.86,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _kCard,
              border: Border.all(
                  color: hasEmojis
                      ? _kPurple.withValues(alpha: 0.8)
                      : _kPurple.withValues(alpha: 0.35),
                  width: 2),
              boxShadow: hasEmojis
                  ? [BoxShadow(
                      color: _kPurple.withValues(alpha: 0.28), blurRadius: 24)]
                  : [],
            ),
            child: Stack(alignment: Alignment.center, children: [
              if (!hasEmojis)
                Text('Tap to open emoji keyboard',
                    style: _f(15, c: const Color(0xFF4E3D72))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _emojiCtrl,
                  focusNode: _emojiFocus,
                  onChanged: (v) => setState(() => _myEmojis = v),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 36, letterSpacing: 4),
                  maxLines: 2,
                  inputFormatters: [_EmojiOnlyFormatter()],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 40),
                    isCollapsed: true,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 48),
      child: _primaryBtn('Send Puzzle', hasEmojis ? _sendPuzzle : null),
    ),
  ]);
}

  Future<void> _sendPuzzle() async {
    FocusScope.of(context).unfocus(); // dismiss keyboard before transitioning
    await _upsertMyRecord({
      'category_key': _cat.key,
      'phrase': _phrase,
      'emojis': _myEmojis,
      'submitted': true,
      'solved': false,   // reset stale flags from any previous session on this match
      'skipped': false,
    });
    _goTo(_Phase.waiting);
  }

  // ============================================================
  //  SCREEN: WAITING
  // ============================================================
  Widget _buildWaiting() {
    final ps = _partnerSubmitted;
    final theirInit = widget.partnerName.isNotEmpty
        ? widget.partnerName[0].toUpperCase()
        : '?';

    return Column(children: [
      _topBar(onBack: () => Navigator.of(context).pop()),
      const SizedBox(height: 20),
      const _PulsingRings(child: Text('⏳', style: TextStyle(fontSize: 32))),
      const SizedBox(height: 20),
      Text('Puzzle Sent', style: _f(34, fw: FontWeight.w700)),
      const SizedBox(height: 10),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: _f(16, c: _kSub, lh: 1.6),
                children: ps
                    ? [
                        TextSpan(
                            text: widget.partnerName,
                            style: _f(16,
                                fw: FontWeight.w600,
                                c: const Color(0xFFC4A8FF))),
                        const TextSpan(text: ' already sent their puzzle!')
                      ]
                    : [
                        const TextSpan(text: 'Waiting for '),
                        TextSpan(
                            text: widget.partnerName,
                            style: _f(16,
                                fw: FontWeight.w600,
                                c: const Color(0xFFC4A8FF))),
                        const TextSpan(text: ' to create their puzzle...')
                      ],
              ))),
      const SizedBox(height: 50),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(children: [
            Text('YOUR PUZZLE',
                style: _f(13,
                    fw: FontWeight.w600, c: const Color(0xFF6B5A90), ls: 1.0)),
            const SizedBox(height: 16),
            _card(
                child: Column(children: [
              Text(_myEmojis,
                  style: const TextStyle(fontSize: 64, letterSpacing: 4),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  ps
                      ? '${widget.partnerName} is solving this...'
                      : "${widget.partnerName} hasn't seen this yet",
                  style: _f(14, c: const Color(0xFF6B5A90))),
            ])),
          ])),
      const SizedBox(height: 50),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusAvatar('Y', true, true),
            const SizedBox(width: 12),
            Container(
                width: 90,
                height: 2,
                margin: const EdgeInsets.only(top: 30),
                color: _kPurple.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            _statusAvatar(theirInit, ps, false),
          ]),
      if (ps) ...[
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🔔', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text("${widget.partnerName}'s puzzle is ready!",
              style: _f(15, fw: FontWeight.w500, c: const Color.fromARGB(255, 251, 251, 251))),
        ]),
        const SizedBox(height: 14),
          Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: _primaryBtn(
            "Solve ${widget.partnerName}'s Puzzle", () => _goTo(_Phase.solve)),
        ),
      ],
      const Spacer(),
    ]);
  }

  Widget _statusAvatar(String init, bool done, bool isMe) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF6930C3), Color(0xFF8B5CF6)])
                    : null,
                color: isMe ? null : _kCard,
                border: Border.all(
                    color: done ? const Color.fromARGB(255, 192, 83, 239) : _kPurple.withValues(alpha: 0.3),
                    width: 3),
                boxShadow: done
                    ? [
                        BoxShadow(
                            color: const Color.fromARGB(255, 177, 51, 232).withValues(alpha: 0.5), blurRadius: 16)
                      ]
                    : [],
              ),
              child: Center(
                  child: Text(init, style: _f(26, fw: FontWeight.w700)))),
          const SizedBox(height: 8),
          done ? Text('✓', style: _f(18, c: _kGreen)) : _pulseDots(),
          const SizedBox(height: 6),
          Text(isMe ? 'You' : widget.partnerName, style: _f(15, c: _kSub)),
        ],
      );

  Widget _slimBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_kPurpleD, _kPurple, _kPurpleL, Color(0xFF7C3AED)]),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: _kPurpleD.withValues(alpha: 0.4), blurRadius: 12)
            ],
          ),
          child: Center(child: Text(label, style: _f(13, fw: FontWeight.w500))),
        ),
      );

  // ============================================================
  //  SCREEN: SOLVE
  // ============================================================
  Widget _buildSolve() {
    final hint = _buildHintText(_partnerPhrase);
    final showTimer = !_skipped && !_ansCorrect && !_timerDone;

    return Column(children: [
      _topBar(), // no back arrow on the solve screen

      // ── Category + sub-label ─────────────────────────────────
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      
        Text(_partnerCat.label,
            style: _f(30, fw: FontWeight.w600, c: _partnerCat.neon)),
            
      ]),
      const SizedBox(height: 14),
      RichText(
          text: TextSpan(
        style: _f(16, c: _kSub),
        children: [
          const TextSpan(text: 'Guess '),
          TextSpan(
              text: "${widget.partnerName}'s",
              style: _f(16, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
          const TextSpan(text: ' phrase'),
        ],
      )),

         // ── Timer ─────────────────────────────────────────────────
      if (showTimer) ...[
        const SizedBox(height: 20),
       Text(
        'Skip After $_timerVal seconds',
        style: _f(16, c: _timerVal <= 5
            ? const Color(0xFFFF6B6B)
            : const Color.fromARGB(255, 184, 160, 192)),
      ),
      ],

      // ── Emoji display ─────────────────────────────────────────
      const SizedBox(height: 110),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_partnerEmojis.isEmpty ? '🤔' : _partnerEmojis,
              style: const TextStyle(fontSize: 76, letterSpacing: 6)),
        ),
      ),

      const SizedBox(height: 36),

      // ── Scrollable: answer area + skip + submit ───────────────
      // Replaces the old Spacer/Spacer layout which collapsed when
      // the keyboard opened, cramping the Skip and Submit buttons.
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(children: [

            // ── Answer area ─────────────────────────────────────
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ShakeWidget(
                  shake: _ansWrong,
                  child: TextField(
                  controller: _ansCtrl,
                  onChanged: (v) => setState(() {
                    _ansInput = v;
                    if (_ansWrong) _ansWrong = false;
                  }),
                  onSubmitted: (_) => _submitAnswer(),
                  textAlign: TextAlign.center,
                  style: _f(19,
                      fw: FontWeight.w500,
                      c: _ansWrong ? const Color.fromARGB(255, 112, 13, 13) : _kText),
                  decoration: InputDecoration(
                    hintText: 'What ${_singular(_partnerCat.label)} is this? Type your guess...',
                    hintStyle: _f(15, c: const Color(0xFF4E3D72)),
                    filled: true,
                    fillColor: _kCard,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: _ansWrong
                                ? const Color(0xFFFF6B6B)
                                : _kPurple.withValues(alpha: 0.35),
                            width: 2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _kPurple, width: 2)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: _ansWrong
                                ? const Color(0xFFFF6B6B)
                                : _kPurple.withValues(alpha: 0.35),
                            width: 2))),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_ansWrong)
                RichText(
                    text: TextSpan(
                  style: _f(14, c: _kRed),
                  children: [
                    const TextSpan(text: 'Hint: '),
                    TextSpan(
                        text: hint,
                        style: _f(14, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
                  ],
                ))
              else
                Text('Press Enter or tap Submit',
                    style: _f(15, c: const Color(0xFF4E3D72))),

            // ── Skip button ─────────────────────────────────────
            if (_timerDone && !_ansCorrect && !_skipped) ...[
              const SizedBox(height: 16),
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _skipAnswer,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: const BorderSide(
                        color: Color(0xFFFF6B6B), width: 1.5),
                  ),
                  child: Text('Skip',
                      style: _f(18, fw: FontWeight.w600,
                          c: const Color(0xFFFF9999))),
                ),
              ),
            ),
            ],

            const SizedBox(height: 200),

            // ── Submit / Continue button ─────────────────────────
                    Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
         child: _primaryBtn('Submit Answer', _submitAnswer),
          ),
          ]),
        ),
      ),
    ]);
  }

  void _startSolveTimer() {
    _timer?.cancel();
    _timerVal = 15;
    _timerDone = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timerVal--;
        if (_timerVal <= 0) {
          _timerVal = 0;
          _timerDone = true;
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _submitAnswer() async {
    final correct =
        _ansInput.trim().toLowerCase() == _partnerPhrase.trim().toLowerCase();
if (correct) {
  _timer?.cancel();
  setState(() {
    _ansCorrect = true;
    _iSolved = true;
  });
 await _upsertMyRecord({'solved': true});
await Future.delayed(const Duration(milliseconds: 300));
await _afterSolve();
} else {
      setState(() => _ansWrong = true);
      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _ansWrong = false);
      });
    }
  }

  Future<void> _skipAnswer() async {
  _timer?.cancel();
  setState(() => _skipped = true);
  await _upsertMyRecord({'skipped': true});
await Future.delayed(const Duration(milliseconds: 300));
await _afterSolve();
}
  Future<void> _afterSolve() async {
    await _upsertMyRecord({
      if (_iSolved) 'solved': true,
      if (_skipped) 'skipped': true,
    });
    debugPrint('[AFTERSOLVE] _partnerFinished=$_partnerFinished _partnerRow=$_partnerRow');
    if (_partnerFinished) {
      _goTo(_Phase.done);
      if (_outcome == _Outcome.bothSolved) _confetti.play();
      _sendCompletion();
    } else {
      _goTo(_Phase.waitSolve);
    }
  }

  String _buildHintText(String phrase) => phrase.split(' ').map((w) {
        if (w.length <= 1) return w;
        return '${w[0]}${'_' * (w.length - 2)}${w[w.length - 1]}';
      }).join(' ');

  // ============================================================
  //  SCREEN: WAIT SOLVE
  // ============================================================
Widget _buildWaitSolve() {
  final theirInit = widget.partnerName[0].toUpperCase();

  return Column(children: [
    _topBar(onBack: () => Navigator.of(context).pop()),
    const SizedBox(height: 32),
    const _PulsingRings(child: Text('🎯', style: TextStyle(fontSize: 22))),
    const SizedBox(height: 16),
    Text(_skipped ? 'Round done!' : 'You got it!',
        style: _f(26, fw: FontWeight.w700, c: _skipped ? _kText : _kGreen)),
    const SizedBox(height: 8),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: _f(13, c: _kSub, lh: 1.5),
          children: _partnerFinished
              ? [
                  TextSpan(text: widget.partnerName,
                      style: _f(13, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
                  const TextSpan(text: ' is done too — loading results...')
                ]
              : [
                  const TextSpan(text: 'Waiting for '),
                  TextSpan(text: widget.partnerName,
                      style: _f(13, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
                  const TextSpan(text: ' to finish...')
                ],
        ),
      ),
    ),
    const SizedBox(height: 70),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YOU SENT PARTNER
            Expanded(
              child: Column(children: [
                Text('You sent ${widget.partnerName}',
                    textAlign: TextAlign.center,
                    style: _f(16, fw: FontWeight.w700,
                        c: const Color(0xFFAB5CF5), ls: 0)),
                const SizedBox(height: 12),
                Text(_phrase,
                    textAlign: TextAlign.center,
                    style: _f(20, fw: FontWeight.w700)),
                if (_myEmojis.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_myEmojis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, letterSpacing: 2)),
                ],
                const SizedBox(height: 8),
                Text(_partnerFinished ? '✅ Done' : '⏳ Still playing...',
                    style: _f(14, fw: FontWeight.w600,
                        c: _partnerFinished ? _kGreen : _kSub)),
              ]),
            ),
            // Divider
            Container(
                width: 1,
                color: _kPurple.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(horizontal: 8)),
                
            // PARTNER SENT YOU
            Expanded(
              child: Column(children: [
                Text('${widget.partnerName} sent you',
                    textAlign: TextAlign.center,
                    style: _f(16, fw: FontWeight.w700,
                        c: const Color(0xFFAB5CF5), ls: 0)),
                const SizedBox(height: 12),
                Text(_skipped ? '???' : _partnerPhrase,
                textAlign: TextAlign.center,
                style: _f(18, fw: FontWeight.w700)),
                if (_partnerEmojis.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_partnerEmojis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, letterSpacing: 2)),
                ],
                const SizedBox(height: 8),
                Text(_skipped ? '⏭ Skipped' : '✅ Guessed',
                    style: _f(14, fw: FontWeight.w600,
                        c: _skipped ? _kRed : _kGreen)),
              ]),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 100),
    Padding(
  padding: const EdgeInsets.symmetric(horizontal:70),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _statusAvatar('Y', true, true),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 31, left: 8, right: 8),
          child: _DottedLine(color: _kPurple.withValues(alpha: 0.5)),
        ),
      ),
      _statusAvatar(theirInit, false, false),
    ],
  ),
),
    const Spacer(),
  ]);
}
  // ============================================================
  //  SCREEN: DONE (4 outcomes)
  // ============================================================
 
Widget _buildDone() {
  final String title, subtitle;
  final bool showCrownMe, showCrownThem;
  final int starCount;

  switch (_outcome) {
    case _Outcome.bothSolved:
      title      = 'You Both Nailed It!';
      subtitle   = '';
      showCrownMe  = true;
      showCrownThem = true;
      starCount  = 3;
    case _Outcome.iSolvedTheySkipped:
      title      = 'You got it!';
      subtitle   = '${widget.partnerName} skipped this round.';
      showCrownMe  = true;
      showCrownThem = false;
      starCount  = 1;
    case _Outcome.iSkippedTheySolved:
      title      = '${widget.partnerName} got it!';
      subtitle   = 'You skipped this round.';
      showCrownMe  = false;
      showCrownThem = true;
      starCount  = 0;
    case _Outcome.bothSkipped:
      title      = 'You both skipped!';
      subtitle   = 'Maybe next time!';
      showCrownMe  = false;
      showCrownThem = false;
      starCount  = 0;
  }

  return Column(children: [
    _topBar(),
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(children: [

          const SizedBox(height: 16),

          // ── Floating animated title ───────────────────────────
          _FloatingText(
            child: ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: (showCrownMe || showCrownThem)
                    ? [const Color(0xFFFFD700), const Color(0xFFFFF0A0), const Color(0xFFFFD700)]
                    : [const Color(0xFFC084FC), Colors.white, const Color(0xFFC084FC)],
              ).createShader(b),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _f(34, fw: FontWeight.w800),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: _f(16, c: const Color.fromARGB(255, 219, 217, 224)),
          ),

          const SizedBox(height: 60),

          // ── Avatars centered with crowns ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarWithCrown(
                url: _myAvatarUrl,
                label: 'You',
                showCrown: showCrownMe,
                skipped: _skipped,
                glowColor: const Color(0xFFAB5CF5),
              ),
              const SizedBox(width: 32),
              _buildAvatarWithCrown(
                url: _partnerAvatarUrl,
                label: widget.partnerName,
                showCrown: showCrownThem,
                skipped: _partnerSkipped,
                glowColor: const Color(0xFF00E5FF),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── VS phrase cards ───────────────────────────────────
          _buildVsCards(),

          const SizedBox(height: 120),

          // ── CTA Button ────────────────────────────────────────
          Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: _primaryBtn(
            widget.chatAlreadyUnlocked
                ? 'Continue Chatting'
                : 'Start Chatting',
            () async {
              debugPrint('[EC-BTN] tapped. sessionId=${widget.sessionId}, completionSent=$_completionSent, iSolved=$_iSolved, skipped=$_skipped, outcome=$_outcome');
              await _sendCompletion();
              debugPrint('[EC-BTN] sendCompletion finished');
              widget.onChatUnlocked?.call();
            },
          ),
         ),
         const SizedBox(height: 14),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 30),
  child: _ghostBtn('Play Again', () {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameHubScreen(
          matchId: widget.matchId,
          currentUserId: widget.currentUserId,
          partnerUserId: widget.partnerUserId,
          partnerName: widget.partnerName,
          chatAlreadyUnlocked: widget.chatAlreadyUnlocked,
          onChatUnlocked: widget.onChatUnlocked ?? () {},
        ),
      ),
    );
  }),
),
        ]),
      ),
    ),
  ]);
}

Widget _buildAvatarWithCrown({
  required String url,
  required String label,
  required bool showCrown,
  required bool skipped,
  required Color glowColor,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Crown above avatar
          if (showCrown)
            const Positioned(
              top: -22,
              child: Text('👑', style: TextStyle(fontSize: 28)),
            ),
          // Glow ring
          // Glow ring + avatar centered together
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!skipped)
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                      border: Border.all(
                        color: glowColor.withValues(alpha: 0.9),
                        width: 2.5,
                      ),
                    ),
                  ),
                ClipOval(
                  child: Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFF2A1A4E),
                    child: url.isNotEmpty
                        ? Image.network(url, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarInitial(label))
                        : _avatarInitial(label),
                  ),
                ),
                if (skipped)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: skipped ? Colors.white38 : Colors.white,
        ),
      ),
    ],
  );
}

Widget _avatarInitial(String name) => Center(
  child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 28,
    ),
  ),
);

Widget _buildVsCards() {
// Left card = (You) — what PARTNER sent you + did YOU solve it?
final myStatus         = _skipped ? '(SKIPPED)' : '✓ SOLVED';
final myStatusColor    = _skipped ? _kRed : _kGreen;

// Right card = (Partner) — what YOU sent them + did THEY solve it?
final theirStatus      = _partnerSkipped ? '(SKIPPED)' : '✓ SOLVED';
final theirStatusColor = _partnerSkipped ? _kRed : _kGreen;
  return SizedBox(
    height: 200,
    child: Stack(
      children: [
        // ── Left card (You) ─────────────────────────────────────
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          right: MediaQuery.of(context).size.width * 0.5 - 18,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D0F60), Color(0xFF1A0838)],
              ),
              border: Border.all(
                color: const Color(0xFFAB5CF5).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB5CF5).withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
  _partnerEmojis.isNotEmpty ? _partnerEmojis : '❓',
                  style: const TextStyle(fontSize: 32, letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                  _partnerPhrase,
                  textAlign: TextAlign.center,
                    style: _f(13, fw: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  myStatus,
                  style: _f(10, fw: FontWeight.w700, c: myStatusColor, ls: 0.5),
                ),
              ],
            ),
          ),
        ),

        // ── Right card (Partner) ────────────────────────────────
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          left: MediaQuery.of(context).size.width * 0.5 - 18,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0F2060), Color(0xFF081838)],
              ),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                _myEmojis.isNotEmpty ? _myEmojis : '❓',
                  style: const TextStyle(fontSize: 32, letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _myPhrase.isNotEmpty ? _myPhrase : _phrase,
                    textAlign: TextAlign.center,
                    style: _f(13, fw: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  theirStatus,
                  style: _f(10, fw: FontWeight.w700, c: theirStatusColor, ls: 0.5),
                ),
              ],
            ),
          ),
        ),

        // ── VS divider in the middle ────────────────────────────
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 2,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFFAB5CF5).withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A0838),
                  border: Border.all(
                    color: const Color(0xFFAB5CF5).withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB5CF5).withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'VS',
                    style: _f(11, fw: FontWeight.w800, c: const Color(0xFFAB5CF5)),
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFAB5CF5).withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _revealCard(String label, String phrase, String emojis, Color lc) =>
      _card(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: _f(10, fw: FontWeight.w600, c: lc, ls: 0.8)),
          const SizedBox(height: 4),
          Text(phrase,
              textAlign: TextAlign.center, style: _f(16, fw: FontWeight.w600)),
          if (emojis.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(emojis,
                style: const TextStyle(fontSize: 18, letterSpacing: 2)),
          ],
        ],
      ));
    }

  // ============================================================
  //  SHARED: Card
  // ============================================================
  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder.withValues(alpha: 0.7), width: 1.5),
        ),
        child: child,
      );

// Starrow 
class _StarRow extends StatefulWidget {
  final int count;
  const _StarRow({required this.count});
  @override
  State<_StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<_StarRow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = widget.count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(stars, (i) {
        final delay = i * 0.25;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = Curves.elasticOut.transform(
              ((_ctrl.value - delay) / (1 - delay)).clamp(0.0, 1.0),
            );
            return Transform.scale(
              scale: t,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: stars == 1 ? 0 : 4),
                child: Text(
                  '⭐',
                  style: TextStyle(
                    fontSize: i == 1 ? 42 : 32,
                    shadows: const [
                      Shadow(color: Color(0xFFFFD700), blurRadius: 16)
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}


class _AvatarRow extends StatelessWidget {
  final String myAvatarUrl;
  final String partnerAvatarUrl;
  final String partnerName;
  final bool myGlowing;
  final bool theirGlowing;
  final bool showCrown;
  final bool mySkipped;
  final bool theirSkipped;

  const _AvatarRow({
    required this.myAvatarUrl,
    required this.partnerAvatarUrl,
    required this.partnerName,
    required this.myGlowing,
    required this.theirGlowing,
    required this.showCrown,
    required this.mySkipped,
    required this.theirSkipped,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        if (showCrown)
          const Positioned(
            top: -18,
            child: Text('👑', style: TextStyle(fontSize: 36)),
          ),
        Padding(
          padding: EdgeInsets.only(top: showCrown ? 18 : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatar(
                url: myAvatarUrl,
                label: 'You',
                glowing: myGlowing,
                skipped: mySkipped,
                glowColor: const Color(0xFFAB5CF5),
              ),
              const SizedBox(width: 24),
              _buildAvatar(
                url: partnerAvatarUrl,
                label: partnerName,
                glowing: theirGlowing,
                skipped: theirSkipped,
                glowColor: const Color(0xFF00E5FF),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({
    required String url,
    required String label,
    required bool glowing,
    required bool skipped,
    required Color glowColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (glowing)
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.55),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.8),
                    width: 2.5,
                  ),
                ),
              ),
            ClipOval(
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFF2A1A4E),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initial(label),
                      )
                    : _initial(label),
              ),
            ),
            if (skipped)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: const Center(
                  child: Text('❌', style: TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: skipped
                ? Colors.white38
                : glowing
                    ? Colors.white
                    : Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _initial(String name) => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
        ),
      );
}
  
// ============================================================
//  HELPER WIDGETS
// ============================================================
class _DottedLine extends StatelessWidget {
  const _DottedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          const dot = 3.0;
          const gap = 6.0;
          final count = (c.maxWidth / (dot + gap)).floor().clamp(1, 200);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          );
        },
      );
}
class _PulseDot extends StatefulWidget {
  final Duration delay;
  const _PulseDot({required this.delay});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFAB5CF5).withValues(alpha: 0.2 + 0.8 * _c.value),
          ),
        ),
      );
}

class _FloatingText extends StatefulWidget {
  final Widget child;
  const _FloatingText({required this.child});
  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _y;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _y = Tween<double>(begin: 0, end: -10)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _y,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, _y.value), child: child),
        child: widget.child,
      );
}

class _PulsingRings extends StatefulWidget {
  final Widget child;
  const _PulsingRings({required this.child});
  @override
  State<_PulsingRings> createState() => _PulsingRingsState();
}

class _PulsingRingsState extends State<_PulsingRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(alignment: Alignment.center, children: [
        ...List.generate(
            3,
            (i) => AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final progress = ((_c.value + i * 0.33) % 1.0);
                    return Opacity(
                      opacity: (1 - progress).clamp(0.0, 0.8),
                      child: Container(
                        width: 84 * (0.5 + progress * 0.95),
                        height: 84 * (0.5 + progress * 0.95),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFAB5CF5).withValues(alpha: 0.6),
                                width: 2)),
                      ),
                    );
                  },
                )),
        Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A1560), Color(0xFF1A0D3E)]),
              border: Border.all(color: const Color(0xFFAB5CF5), width: 2),
            ),
            child: Center(child: widget.child)),
      ]),
    );
  }
}

class _TimerCircle extends StatelessWidget {
  final int value;
  final bool urgent;
  const _TimerCircle({required this.value, required this.urgent});
  @override
  Widget build(BuildContext context) {
    final c = urgent ? const Color(0xFFFF6B6B) : const Color(0xFFAB5CF5);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.6), width: 2),
        boxShadow: urgent
            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 12)]
            : [],
      ),
      child: Center(
          child: Text('$value',
              style: GoogleFonts.fredoka(
                  fontSize: 14, fontWeight: FontWeight.w600, color: c))),
    );
  }
}

class _GlowText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _GlowText({required this.text, required this.style});
  @override
  State<_GlowText> createState() => _GlowTextState();
}

class _GlowTextState extends State<_GlowText>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _g;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _g = Tween<double>(begin: 4, end: 18)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _g,
        builder: (_, __) => Text(widget.text,
            style: widget.style.copyWith(shadows: [
              Shadow(blurRadius: _g.value, color: Colors.white.withValues(alpha: 0.6))
            ])),
      );
}

class _BounceIn extends StatefulWidget {
  final Widget child;
  const _BounceIn({required this.child});
  @override
  State<_BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<_BounceIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _s = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _s,
        builder: (_, child) => Transform.scale(scale: _s.value, child: child),
        child: widget.child,
      );
}

class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  const _ShakeWidget({required this.child, required this.shake});
  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _x;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _x = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 25),
    ]).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ShakeWidget old) {
    super.didUpdateWidget(old);
    if (widget.shake && !old.shake) _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _x,
        builder: (_, child) =>
            Transform.translate(offset: Offset(_x.value, 0), child: child),
        child: widget.child,
      );
}

/// Strips any non-emoji characters from text input so the create-emoji field
/// only accepts emojis.  Covers:
///   • Main emoji block (U+1F000–U+1FFFF) — emoticons, symbols, pictographs …
///   • Misc symbols & dingbats (U+2300–U+27BF) — ☀️ ⭐ ⏰ ✂️ …
///   • Geometric shapes / misc arrows (U+25A0–U+2BFF)
///   • Regional indicator pairs (U+1F1E0–U+1F1FF) — country flags
///   • Zero-width joiner U+200D — compound emoji like 👨‍👩‍👧
///   • Variation selector-16 U+FE0F — emoji presentation selector
///   • Combining enclosing keycap U+20E3 — 1️⃣ 2️⃣ …
class _EmojiOnlyFormatter extends TextInputFormatter {
  static final _nonEmoji = RegExp(
    r'[^\u{1F000}-\u{1FFFF}'  // Main emoji block
    r'\u{2300}-\u{27BF}'      // Misc technical + symbols + dingbats
    r'\u{25A0}-\u{2BFF}'      // Geometric shapes / misc arrows
    r'\u{1F1E0}-\u{1F1FF}'   // Regional indicator symbols (flags)
    r'\u{200D}'               // ZWJ
    r'\u{FE0F}'               // Variation selector-16
    r'\u{20E3}'               // Combining enclosing keycap
    r']',
    unicode: true,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(_nonEmoji, '');
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

class _SlimOutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SlimOutlineBtn(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.5), width: 1.5),
          ),
          child: Text(label,
              style: GoogleFonts.fredoka(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFF9999))),
        ),
      );
}
