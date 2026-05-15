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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import 'emoji_charades_data.dart';
import '../word_search/word_search_service.dart';

// ── Palette ──────────────────────────────────────────────────
const _kBg     = Color(0xFF07060F);
const _kBgMid  = Color(0xFF120D2E);
const _kPurple = Color(0xFF8B5CF6);
const _kPurpleD= Color(0xFF6930C3);
const _kPurpleL= Color(0xFFA78BFA);
const _kAmber  = Color(0xFFFFB800);
const _kCyan   = Color(0xFF00E5FF);
const _kGreen  = Color(0xFF39FF14);
const _kPink   = Color(0xFFFF2D78);
const _kText   = Color(0xFFFFFFFF);
const _kSub    = Color(0xFF8B7AB8);
const _kCard   = Color(0xFF14093A);
const _kBorder = Color(0xFF2E1F5E);
const _kRed    = Color(0xFFFF9999);

// ── Text style shorthand ─────────────────────────────────────
TextStyle _f(double sz, {FontWeight fw = FontWeight.w400, Color c = _kText,
    double ls = 0, double lh = 1.0}) =>
  GoogleFonts.fredoka(fontSize: sz, fontWeight: fw, color: c,
      letterSpacing: ls, height: lh);

// ── Game phase ───────────────────────────────────────────────
enum _Phase { intro, category, phrase, create, waiting, solve, waitSolve, done }

// ── Final screen outcome ─────────────────────────────────────
enum _Outcome { bothSolved, iSolvedTheySkipped, iSkippedTheySolved, bothSkipped }

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

  _Particle({required this.emoji, required this.x, required this.y,
    required this.tx, required this.size, required this.duration,
    required this.zone})
    : opacity = 0.0, elapsed = 0.0;
}

// ============================================================
//  ENTRY POINT — launch from your match/chat screen
// ============================================================
class EmojiCharadesGameScreen extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final String partnerUserId;
  final String partnerName;
  final VoidCallback onChatUnlocked;

  /// When true, skip the intro animation and start at the category picker.
  final bool skipIntro;

  const EmojiCharadesGameScreen({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.partnerUserId,
    required this.partnerName,
    required this.onChatUnlocked,
    this.skipIntro = false,
  });

  @override
  State<EmojiCharadesGameScreen> createState() => _State();
}

class _State extends State<EmojiCharadesGameScreen> with TickerProviderStateMixin {

  final _db = Supabase.instance.client;
  final _rng = Random();

  // ── Phase ─────────────────────────────────────────────────
  _Phase _phase = _Phase.intro;

  // ── My picks ──────────────────────────────────────────────
  int _catIdx   = 0;
  int _phraseIdx= 0;
  String _myEmojis = '';
  final _emojiCtrl = TextEditingController();
  final _emojiFocus = FocusNode();

  // ── Partner Supabase record ───────────────────────────────
  Map<String, dynamic>? _partnerRow;

  // ── Solve state ───────────────────────────────────────────
  final _ansCtrl = TextEditingController();
  String _ansInput  = '';
  bool _ansCorrect  = false;
  bool _ansWrong    = false;
  bool _skipped     = false;
  bool _iSolved     = false;
  int  _timerVal    = 15;
  bool _timerDone   = false;
  Timer? _timer;
  Timer? _hintTimer;

  // ── Confetti ──────────────────────────────────────────────
  late ConfettiController _confetti;

  // ── Intro animation ───────────────────────────────────────
  int _introSet  = 0;
  int _lastExit  = -1;
  List<String> _introEmojis = List.from(kIntroSets[0]);
  bool _introExiting = false;
  bool _introEntering= false;
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
  List<String> get _phrases => kEcPhrases[_cat.key]!;
  String get _phrase => _phrases[_phraseIdx];
  String get _partnerEmojis => _partnerRow?['emojis'] as String? ?? '';
  String get _partnerPhrase => _partnerRow?['phrase'] as String? ?? '';
  String get _partnerCatKey => _partnerRow?['category_key'] as String? ?? 'movies';
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

  // ============================================================
  //  INIT & DISPOSE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 5));

    _floatL = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _floatM = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _floatR = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _floatLAnim = Tween<double>(begin: 0, end: -14).animate(CurvedAnimation(parent: _floatL, curve: Curves.easeInOut));
    _floatMAnim = Tween<double>(begin: 0, end: -16).animate(CurvedAnimation(parent: _floatM, curve: Curves.easeInOut));
    _floatRAnim = Tween<double>(begin: 0, end:  -8).animate(CurvedAnimation(parent: _floatR, curve: Curves.easeInOut));

    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut));

    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _enterScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.18), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.06), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.02), weight: 17),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0),  weight: 18),
    ]).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterOpacity = Tween<double>(begin: 1, end: 1).animate(_enterCtrl);

    _particleTick = AnimationController(vsync: this,
      duration: const Duration(seconds: 60))..repeat();
    _particleTick.addListener(_tickParticles);

    if (widget.skipIntro) {
      _phase = _Phase.category;
    } else {
      _startIntro();
    }
    _subscribeRealtime();
    _loadMyRecord();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    _introTimer?.cancel();
    _particleScheduler?.cancel();
    _floatL.dispose(); _floatM.dispose(); _floatR.dispose();
    _exitCtrl.dispose(); _enterCtrl.dispose();
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

    final exits = [0,1,2,3].where((i) => i != _lastExit).toList()..shuffle();
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
        if (progress < 0.10)      p.opacity = (progress / 0.10).clamp(0,1);
        else if (progress > 0.70) p.opacity = (1 - (progress - 0.70) / 0.30).clamp(0,1);
        else                      p.opacity = 1.0;
        return progress >= 1.0;
      });
    });
  }

  void _spawnParticle() {
    final zones = ['left','left','right','right','centre','centre','centre'];
    final zone  = zones[_rng.nextInt(zones.length)];
    double x;
    double tx;

    if (zone == 'left') {
      x  = 0.02 + _rng.nextDouble() * 0.18;
      tx = 0.04 + _rng.nextDouble() * 0.10;
    } else if (zone == 'right') {
      x  = 0.80 + _rng.nextDouble() * 0.18;
      tx = -(0.04 + _rng.nextDouble() * 0.10);
    } else {
      x  = 0.30 + _rng.nextDouble() * 0.40;
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
    final res = await _db
      .from('emoji_charades_games')
      .select()
      .eq('match_id', widget.matchId)
      .eq('user_id', widget.currentUserId)
      .maybeSingle();
    if (res != null && mounted) {
      setState(() {
        _myEmojis = res['emojis'] ?? '';
        if (res['submitted'] == true) {
          if (res['solved'] == true) _iSolved = true;
          if (res['skipped'] == true) _skipped = true;
        }
      });
    }
  }

  void _subscribeRealtime() {
    _channel = _db.channel('ec:${widget.matchId}')
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
          if (row['user_id'] == widget.partnerUserId) {
            setState(() => _partnerRow = row);
            _onPartnerUpdate();
          }
        },
      ).subscribe();

    _db.from('emoji_charades_games')
      .select()
      .eq('match_id', widget.matchId)
      .eq('user_id', widget.partnerUserId)
      .maybeSingle()
      .then((row) {
        if (row != null && mounted) {
          setState(() => _partnerRow = row);
        }
      });
  }

  /// Record EC win/loss to the shared game_scores table.
  /// Called by whoever finishes second (the one who triggers onChatUnlocked).
  void _recordEcScore() {
    switch (_outcome) {
      case _Outcome.iSolvedTheySkipped:
        WordSearchService().recordWinner(
          matchId:  widget.matchId,
          winnerId: widget.currentUserId,
          loserId:  widget.partnerUserId,
        );
        break;
      case _Outcome.iSkippedTheySolved:
        WordSearchService().recordWinner(
          matchId:  widget.matchId,
          winnerId: widget.partnerUserId,
          loserId:  widget.currentUserId,
        );
        break;
      case _Outcome.bothSolved:
      case _Outcome.bothSkipped:
        // Draw — no score recorded.
        break;
    }
  }

  void _onPartnerUpdate() {
    if (_phase == _Phase.waiting && _partnerSubmitted) {
      setState(() {});
    }
    if (_phase == _Phase.waitSolve && _partnerFinished) {
      _goTo(_Phase.done);
      if (_outcome == _Outcome.bothSolved) _confetti.play();
      _recordEcScore();
      widget.onChatUnlocked();
    }
  }

  Future<void> _upsertMyRecord(Map<String, dynamic> data) async {
    await _db.from('emoji_charades_games').upsert({
      'match_id': widget.matchId,
      'user_id' : widget.currentUserId,
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
    setState(() => _phase = p);
    if (p == _Phase.intro) _startIntro();
    if (p == _Phase.solve) _startSolveTimer();
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.4), // 50% x, 30% y
              radius: 1.1,
              colors: [Color(0xFF3D1172), Color(0xFF0A0818)],
              stops: [0.0, 0.65],
            ),
          ),
          child: Stack(children: [
          _buildPhase(),
          if (_showTut) _buildTutorial(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [_kPurple, _kPurpleL, _kAmber, _kGreen, _kCyan, _kPink, Colors.white],
            ),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:     return _buildIntro();
      case _Phase.category:  return _buildCategory();
      case _Phase.phrase:    return _buildPhrase();
      case _Phase.create:    return _buildCreate();
      case _Phase.waiting:   return _buildWaiting();
      case _Phase.solve:     return _buildSolve();
      case _Phase.waitSolve: return _buildWaitSolve();
      case _Phase.done:      return _buildDone();
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
              color: onBack != null ? const Color(0xFFC4B8E8) : Colors.transparent,
              size: 28),
          ),
          Expanded(child: Center(
            child: Text('EMOJI CHARADES',
              style: _f(13, fw: FontWeight.w600, c: const Color(0xFF7B6AAA), ls: 1.0)),
          )),
          const SizedBox(width: 28),
        ]),
      ),
    );
  }

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
            style: _f(18, fw: FontWeight.w600,
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

  Widget _pulseDots() {
    return Row(mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) =>
        _PulseDot(delay: Duration(milliseconds: i * 280))));
  }

  // ============================================================
  //  SCREEN: INTRO
  // ============================================================
  Widget _buildIntro() {
    final size = MediaQuery.of(context).size;
    return Stack(children: [
      ...(_particles.map((p) => Positioned(
        left:  p.x * size.width - p.size / 2,
        top:   p.y * size.height,
        child: Opacity(opacity: p.opacity.clamp(0,1),
          child: Text(p.emoji, style: TextStyle(fontSize: p.size))),
      ))),

      Column(children: [
        // Back button — pops EmojiCharadesGameScreen and returns to GameHub.
        // Other phases already have _topBar() with internal navigation that
        // chains back here, so this single addition closes the escape route.
        _topBar(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 24),

        Text('EMOJI', style: _f(62, fw: FontWeight.w700)),
        Text('CHARADES', style: _f(62, fw: FontWeight.w700, c: _kAmber)),
        const SizedBox(height: 4),

        Expanded(child: Center(child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _introEmojiSlot(0, _floatLAnim, rotDeg: -4),
            _introEmojiSlot(1, _floatMAnim, scl: 1.1),
            _introEmojiSlot(2, _floatRAnim, rotDeg: 6),
          ],
        ))),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
          child: Column(children: [
            GestureDetector(
              onTap: () => setState(() => _showTut = true),
              child: Text('View tutorial',
                style: _f(15, fw: FontWeight.w500, c: const Color(0xFFC8AAFF))
                  .copyWith(decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFC8AAFF))),
            ),
            const SizedBox(height: 16),
            _primaryBtn('Play now', () => _goTo(_Phase.category)),
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
              ? AnimatedBuilder(animation: _enterCtrl, builder: (_, __) =>
                  Transform.scale(scale: _enterScale.value,
                    child: Text(_introEmojis[idx],
                      style: TextStyle(fontSize: idx == 1 ? 58 : 50))))
              : _introExiting
              ? AnimatedBuilder(animation: _exitCtrl, builder: (_, __) =>
                  Opacity(opacity: _exitOpacity.value,
                    child: Text(_introEmojis[idx],
                      style: TextStyle(fontSize: idx == 1 ? 58 : 50))))
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
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0F3A), Color(0xFF0F0920)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: _kBorder),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0x66AB5CF5),
                    borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                Text('HOW TO PLAY', style: _f(13, fw: FontWeight.w700,
                  c: _kPurple, ls: 2.0)),
                const SizedBox(height: 18),
                _tutStep('1', 'Pick a category and a random phrase',
                  const Color(0xFF00E5FF)),
                const SizedBox(height: 18),
                _tutStep('2', 'Turn it into emojis and send your puzzle',
                  _kPink),
                const SizedBox(height: 18),
                _tutStep('3', 'Type your guess, you have 15 seconds!',
                  _kGreen),
                const SizedBox(height: 24),
                _primaryBtn('GOT IT', () => setState(() => _showTut = false)),
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
      Container(width: 34, height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: c, width: 2),
          boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 10)]),
        child: Center(child: Text(num, style: _f(16, fw: FontWeight.w700, c: c)))),
      const SizedBox(width: 14),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: _f(16, fw: FontWeight.w500,
          c: const Color(0xFFE2D5FF), lh: 1.4)))),
    ],
  );

  // ============================================================
  //  SCREEN: CATEGORY
  // ============================================================
  Widget _buildCategory() {
    return Column(children: [
      _topBar(onBack: () => _goTo(_Phase.intro)),

      const SizedBox(height: 24),
      Text('CHOOSE A', style: _f(16, fw: FontWeight.w600,
        c: const Color(0xFFC084FC), ls: 2.5)),
      const SizedBox(height: 6),
      _GlowText(text: 'Category', style: _f(58, fw: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Swipe to explore', style: _f(16, fw: FontWeight.w500,
        c: const Color(0xFFC084FC))),

      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2FBE), Color(0xFFAB5CF5)])),
            child: Center(child: Text(widget.partnerName[0].toUpperCase(),
              style: _f(16, fw: FontWeight.w700)))),
          const SizedBox(width: 12),
          Expanded(child: Text('${widget.partnerName} is also picking...',
            style: _f(15, fw: FontWeight.w500, c: const Color(0xFFC4B8E8)))),
          _pulseDots(),
        ]),
      ),

      const SizedBox(height: 24),
      SizedBox(height: 260, child: PageView.builder(
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
                  gradient: active ? LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [cat.bg, cat.dark],
                  ) : null,
                  color: active ? null : const Color(0xFF0F0D1E),
                  border: Border.all(
                    color: active ? cat.neon : Colors.white.withOpacity(0.06),
                    width: 2,
                  ),
                  boxShadow: active ? [BoxShadow(
                    color: cat.neon.withOpacity(0.35), blurRadius: 32)] : [],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 68)),
                  const SizedBox(height: 18),
                  Text(cat.label, style: _f(28, fw: FontWeight.w700,
                    c: active ? cat.neon : cat.neon.withOpacity(0.2))),
                ]),
              ),
            ),
          );
        },
      )),

      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(kEcCategories.length, (i) =>
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: i == _catIdx ? 20 : 6, height: 5, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i == _catIdx
                ? kEcCategories[i].neon
                : const Color(0xFF2B2945),
            ),
          ))),

      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
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
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_cat.icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 10),
        Text(_cat.label, style: _f(26, fw: FontWeight.w600, c: _cat.neon)),
      ]),

      Expanded(child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _FloatingText(
            child: Text(_phrase, textAlign: TextAlign.center,
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
            setState(() =>
              _phraseIdx = (_phraseIdx + 1) % _phrases.length);
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

      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                Text(_phrase, textAlign: TextAlign.center,
                  style: _f(40, fw: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('Turn it into emojis 👇',
                  style: _f(17, c: _kSub)),
              ]),
            ),

            const SizedBox(height: 32),

            // Emoji input box
            GestureDetector(
              onTap: () => FocusScope.of(context).requestFocus(_emojiFocus),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.86,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: _kCard,
                  border: Border.all(
                    color: hasEmojis
                      ? _kPurple.withOpacity(0.8)
                      : _kPurple.withOpacity(0.35),
                    width: 2),
                  boxShadow: hasEmojis ? [BoxShadow(
                    color: _kPurple.withOpacity(0.28), blurRadius: 24)] : [],
                ),
                child: Stack(alignment: Alignment.center, children: [
                  if (!hasEmojis)
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('😊', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 10),
                      Text('Tap to open emoji keyboard',
                        textAlign: TextAlign.center,
                        style: _f(15, c: const Color(0xFF4E3D72))),
                      const SizedBox(height: 48),
                    ]),
                  TextField(
                    controller: _emojiCtrl,
                    focusNode: _emojiFocus,
                    onChanged: (v) => setState(() => _myEmojis = v),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 42, letterSpacing: 4),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '',
                    ),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _primaryBtn('Send Puzzle',
                hasEmojis ? _sendPuzzle : null),
            ),

            const SizedBox(height: 16),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _sendPuzzle() async {
    FocusScope.of(context).unfocus(); // dismiss keyboard before transitioning
    await _upsertMyRecord({
      'category_key': _cat.key,
      'phrase'      : _phrase,
      'emojis'      : _myEmojis,
      'submitted'   : true,
    });
    _goTo(_partnerSubmitted ? _Phase.solve : _Phase.waiting);
  }

  // ============================================================
  //  SCREEN: WAITING
  // ============================================================
  Widget _buildWaiting() {
    final ps = _partnerSubmitted;
    final theirInit = widget.partnerName.isNotEmpty
      ? widget.partnerName[0].toUpperCase() : '?';

    return Column(children: [
      _topBar(onBack: () => Navigator.of(context).pop()),
      const SizedBox(height: 36),

      _PulsingRings(child: const Text('⏳', style: TextStyle(fontSize: 32))),
      const SizedBox(height: 20),

      Text('Puzzle Sent!', style: _f(34, fw: FontWeight.w700)),
      const SizedBox(height: 10),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
        child: RichText(textAlign: TextAlign.center, text: TextSpan(
          style: _f(16, c: _kSub, lh: 1.6),
          children: ps
            ? [TextSpan(text: widget.partnerName,
                style: _f(16, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
               const TextSpan(text: ' already sent their puzzle!')]
            : [const TextSpan(text: 'Waiting for '),
               TextSpan(text: widget.partnerName,
                style: _f(16, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
               const TextSpan(text: ' to create their puzzle...')],
        ))),

      const SizedBox(height: 28),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(children: [
          Text('YOUR PUZZLE', style: _f(13, fw: FontWeight.w600,
            c: const Color(0xFF6B5A90), ls: 1.0)),
          const SizedBox(height: 12),
          _card(child: Column(children: [
            Text(_myEmojis, style: const TextStyle(fontSize: 36,
              letterSpacing: 4), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(ps ? '${widget.partnerName} is solving this...'
                    : "${widget.partnerName} hasn't seen this yet",
              style: _f(14, c: const Color(0xFF6B5A90))),
          ])),
        ])),

      const SizedBox(height: 28),

      Row(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusAvatar('Y', true, true),
          const SizedBox(width: 12),
          Container(width: 40, height: 2, margin: const EdgeInsets.only(top: 30),
            color: _kPurple.withOpacity(0.4)),
          const SizedBox(width: 12),
          _statusAvatar(theirInit, ps, false),
        ]),

      if (ps) ...[
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🔔', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text("${widget.partnerName}'s puzzle is ready!",
            style: _f(15, fw: FontWeight.w500, c: _kAmber)),
        ]),
        const SizedBox(height: 14),
        _slimBtn("Solve ${widget.partnerName}'s Puzzle",
          () => _goTo(_Phase.solve)),
      ],

      const Spacer(),
    ]);
  }

  Widget _statusAvatar(String init, bool done, bool isMe) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: isMe ? const LinearGradient(
            colors: [Color(0xFF6930C3), Color(0xFF8B5CF6)]) : null,
          color: isMe ? null : _kCard,
          border: Border.all(
            color: done ? _kGreen : _kPurple.withOpacity(0.3), width: 3),
          boxShadow: done ? [BoxShadow(
            color: _kGreen.withOpacity(0.5), blurRadius: 16)] : [],
        ),
        child: Center(child: Text(init, style: _f(26, fw: FontWeight.w700)))),
      const SizedBox(height: 8),
      done
        ? Text('✓', style: _f(18, c: _kGreen))
        : _pulseDots(),
      const SizedBox(height: 6),
      Text(isMe ? 'You' : widget.partnerName, style: _f(15, c: _kSub)),
    ],
  );

  Widget _slimBtn(String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPurpleD, _kPurple, _kPurpleL, Color(0xFF7C3AED)]),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(
            color: _kPurpleD.withOpacity(0.4), blurRadius: 12)],
        ),
        child: Center(child: Text(label,
          style: _f(13, fw: FontWeight.w500))),
      ),
    );

  // ============================================================
  //  SCREEN: SOLVE
  // ============================================================
  Widget _buildSolve() {
    final hint = _buildHintText(_partnerPhrase);
    final showTimer = !_skipped && !_ansCorrect && !_timerDone;

    return Column(children: [
      _topBar(onBack: () => _goTo(_Phase.waiting)),

      // ── Category + sub-label ─────────────────────────────────
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_partnerCat.icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Text(_partnerCat.label, style: _f(20, fw: FontWeight.w600,
          c: _partnerCat.neon)),
      ]),
      const SizedBox(height: 8),
      RichText(text: TextSpan(
        style: _f(16, c: _kSub),
        children: [
          const TextSpan(text: 'Guess '),
          TextSpan(text: "${widget.partnerName}'s",
            style: _f(16, fw: FontWeight.w600, c: const Color(0xFFC4A8FF))),
          const TextSpan(text: ' phrase'),
        ],
      )),

      // ── Emoji display ─────────────────────────────────────────
      const SizedBox(height: 40),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_partnerEmojis.isEmpty ? '🤔' : _partnerEmojis,
            style: const TextStyle(fontSize: 76, letterSpacing: 6)),
        ),
      ),

      // ── Timer ─────────────────────────────────────────────────
      if (showTimer) ...[
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _TimerCircle(value: _timerVal, urgent: _timerVal <= 5),
          const SizedBox(width: 6),
          Text('seconds', style: _f(14, c: const Color(0xFF4E3D72))),
        ]),
      ] else
        const SizedBox(height: 14),

      const Spacer(),

      // ── Answer area ───────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(children: [
          if (_skipped) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder.withOpacity(0.7), width: 1.5),
              ),
              child: Column(children: [
                Text('The answer was', style: _f(14, fw: FontWeight.w600,
                  c: _kRed, ls: 0.8)),
                const SizedBox(height: 12),
                Text(_partnerPhrase, style: _f(28, fw: FontWeight.w700),
                  textAlign: TextAlign.center),
              ]),
            ),
            const SizedBox(height: 10),
            Text('Better luck next time!', style: _f(15, c: _kSub)),
          ] else if (_ansCorrect) ...[
            TextField(
              controller: _ansCtrl,
              readOnly: true,
              textAlign: TextAlign.center,
              style: _f(19, fw: FontWeight.w500, c: _kGreen),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kGreen.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _kGreen, width: 2)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _kGreen, width: 2)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _kGreen, width: 2)),
              ),
            ),
            const SizedBox(height: 10),
            Text('✅ You got it!', style: _f(16, c: _kGreen)),
          ] else ...[
            _ShakeWidget(
              shake: _ansWrong,
              child: TextField(
                controller: _ansCtrl,
                onChanged: (v) => setState(() {
                  _ansInput = v;
                  if (_ansWrong) _ansWrong = false;
                }),
                onSubmitted: (_) => _submitAnswer(),
                textAlign: TextAlign.center,
                style: _f(19, fw: FontWeight.w500,
                  c: _ansWrong ? const Color(0xFFFF6B6B) : _kText),
                decoration: InputDecoration(
                  hintText: 'Type your guess...',
                  hintStyle: _f(19, c: const Color(0xFF4E3D72)),
                  filled: true,
                  fillColor: _kCard,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _ansWrong
                        ? const Color(0xFFFF6B6B)
                        : _kPurple.withOpacity(0.35), width: 2)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kPurple, width: 2)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _ansWrong
                        ? const Color(0xFFFF6B6B)
                        : _kPurple.withOpacity(0.35), width: 2)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_ansWrong)
              RichText(text: TextSpan(
                style: _f(14, c: _kRed),
                children: [
                  const TextSpan(text: 'Hint: '),
                  TextSpan(text: hint,
                    style: _f(14, fw: FontWeight.w600,
                      c: const Color(0xFFC4A8FF))),
                ],
              ))
            else
              Text('Press Enter or tap Submit',
                style: _f(15, c: const Color(0xFF4E3D72))),
          ],
        ]),
      ),

      if (_timerDone && !_ansCorrect && !_skipped) ...[
        const SizedBox(height: 16),
        _SlimOutlineBtn('Skip', () => _skipAnswer()),
      ],

      const Spacer(),

      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        child: _ansCorrect || _skipped
          ? _primaryBtn('Continue', _afterSolve)
          : _primaryBtn('Submit Answer', _submitAnswer),
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

  void _submitAnswer() {
    final correct = _ansInput.trim().toLowerCase() ==
      _partnerPhrase.trim().toLowerCase();
    if (correct) {
      _timer?.cancel();
      setState(() { _ansCorrect = true; _iSolved = true; });
      _upsertMyRecord({'solved': true});
    } else {
      setState(() => _ansWrong = true);
      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _ansWrong = false);
      });
    }
  }

  void _skipAnswer() {
    _timer?.cancel();
    setState(() => _skipped = true);
    _upsertMyRecord({'skipped': true});
  }

  Future<void> _afterSolve() async {
    await _upsertMyRecord({
      if (_iSolved) 'solved': true,
      if (_skipped) 'skipped': true,
    });
    if (_partnerFinished) {
      _goTo(_Phase.done);
      if (_outcome == _Outcome.bothSolved) _confetti.play();
      _recordEcScore();
      widget.onChatUnlocked();
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
      _topBar(onBack: () => _goTo(_Phase.solve)),
      const SizedBox(height: 22),

      _PulsingRings(child: const Text('🎯', style: TextStyle(fontSize: 22))),
      const SizedBox(height: 10),

      Text(_skipped ? 'Round done!' : 'You got it!',
        style: _f(22, fw: FontWeight.w700,
          c: _skipped ? _kText : _kGreen)),
      const SizedBox(height: 5),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
        child: RichText(textAlign: TextAlign.center, text: TextSpan(
          style: _f(13, c: _kSub, lh: 1.5),
          children: _partnerFinished
            ? [TextSpan(text: widget.partnerName,
                style: _f(13, fw: FontWeight.w600,
                  c: const Color(0xFFC4A8FF))),
               const TextSpan(text: ' is done too — loading results...')]
            : [const TextSpan(text: 'Waiting for '),
               TextSpan(text: widget.partnerName,
                style: _f(13, fw: FontWeight.w600,
                  c: const Color(0xFFC4A8FF))),
               const TextSpan(text: ' to finish...')],
        ))),

      const SizedBox(height: 14),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(children: [
          _phraseRevealCard('YOUR PHRASE', _phrase, _myEmojis,
            const Color(0xFFAB5CF5)),
          const SizedBox(height: 9),
          _phraseRevealCard(
            "${widget.partnerName}'s PHRASE ${_skipped ? '(skipped)' : '(you guessed ✓)'}",
            _partnerPhrase, _partnerEmojis,
            _skipped ? _kRed : const Color(0xFF00E5FF)),
        ])),

      const SizedBox(height: 14),

      Row(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusAvatar('Y', true, true),
          const SizedBox(width: 8),
          Container(width: 26, height: 1.5, margin: const EdgeInsets.only(top: 16),
            color: _kPurple.withOpacity(0.4)),
          const SizedBox(width: 8),
          _statusAvatar(theirInit, false, false),
        ]),

      const Spacer(),
    ]);
  }

  Widget _phraseRevealCard(String label, String phrase, String emojis, Color labelColor) =>
    _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center,
          style: _f(10, fw: FontWeight.w600, c: labelColor, ls: 0.8)),
        const SizedBox(height: 4),
        Text(phrase, textAlign: TextAlign.center,
          style: _f(16, fw: FontWeight.w600)),
        if (emojis.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(emojis, style: const TextStyle(fontSize: 18, letterSpacing: 2)),
        ],
      ],
    ));

  // ============================================================
  //  SCREEN: DONE (4 outcomes)
  // ============================================================
  Widget _buildDone() {
    final String bigEmoji, title, subtitle;
    switch (_outcome) {
      case _Outcome.bothSolved:
        bigEmoji = '🎉'; title = 'Ice Broken!'; subtitle = 'You both nailed it!';
      case _Outcome.iSolvedTheySkipped:
        bigEmoji = '🎯'; title = 'You got it!';
        subtitle = 'But ${widget.partnerName} skipped this round.';
      case _Outcome.iSkippedTheySolved:
        bigEmoji = '😅'; title = '${widget.partnerName} got it!';
        subtitle = 'You skipped this round.';
      case _Outcome.bothSkipped:
        bigEmoji = '🤝'; title = 'You both skipped!'; subtitle = 'Maybe next time!';
    }

    final myLabelColor = _skipped ? _kRed : const Color(0xFFAB5CF5);
    final theirLabelColor = _partnerSkipped ? _kRed : const Color(0xFF00E5FF);
    final myStatus   = _skipped        ? '(skipped)' : '✓';
    final theirStatus= _partnerSkipped ? '(skipped)' : '✓';

    return Column(children: [
      _topBar(onBack: () => Navigator.of(context).pop()),

      Expanded(child: Column(children: [
        const SizedBox(height: 20),

        _BounceIn(child: Text(bigEmoji,
          style: const TextStyle(fontSize: 68))),
        const SizedBox(height: 8),

        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFC084FC), Colors.white, Color(0xFFC084FC)],
          ).createShader(b),
          child: Text(title, style: _f(36, fw: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center,
          style: _f(14, c: _kSub)),

        const SizedBox(height: 16),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(children: [
            _revealCard("Your phrase $myStatus", _phrase, _myEmojis, myLabelColor),
            const SizedBox(height: 9),
            _revealCard("${widget.partnerName}'s phrase $theirStatus",
              _partnerPhrase, _partnerEmojis, theirLabelColor),
          ])),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          child: Column(children: [
            _primaryBtn('Start Chatting', widget.onChatUnlocked),
            const SizedBox(height: 9),
            _ghostBtn('Play Again', _playAgain),
          ]),
        ),
      ])),
    ]);
  }

  Widget _revealCard(String label, String phrase, String emojis, Color lc) =>
    _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label.toUpperCase(), textAlign: TextAlign.center,
          style: _f(10, fw: FontWeight.w600, c: lc, ls: 0.8)),
        const SizedBox(height: 4),
        Text(phrase, textAlign: TextAlign.center,
          style: _f(16, fw: FontWeight.w600)),
        if (emojis.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(emojis, style: const TextStyle(fontSize: 18, letterSpacing: 2)),
        ],
      ],
    ));

  void _playAgain() {
    _timer?.cancel();
    _hintTimer?.cancel();
    setState(() {
      _phase = _Phase.intro;
      _catIdx = 0; _phraseIdx = 0;
      _myEmojis = ''; _emojiCtrl.clear();
      _ansInput = ''; _ansCtrl.clear();
      _ansCorrect = false; _ansWrong = false;
      _skipped = false; _iSolved = false;
      _timerVal = 15; _timerDone = false;
      _partnerRow = null;
    });
    _db.from('emoji_charades_games')
      .delete()
      .eq('match_id', widget.matchId)
      .eq('user_id', widget.currentUserId);
    _startIntro();
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
      border: Border.all(color: _kBorder.withOpacity(0.7), width: 1.5),
    ),
    child: child,
  );
}

// ============================================================
//  HELPER WIDGETS
// ============================================================

class _PulseDot extends StatefulWidget {
  final Duration delay;
  const _PulseDot({required this.delay});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFAB5CF5).withOpacity(0.2 + 0.8 * _c.value),
      ),
    ),
  );
}

class _FloatingText extends StatefulWidget {
  final Widget child;
  const _FloatingText({required this.child});
  @override State<_FloatingText> createState() => _FloatingTextState();
}
class _FloatingTextState extends State<_FloatingText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _y;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _y = Tween<double>(begin: 0, end: -10)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _y,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, _y.value), child: child),
    child: widget.child,
  );
}

class _PulsingRings extends StatefulWidget {
  final Widget child;
  const _PulsingRings({required this.child});
  @override State<_PulsingRings> createState() => _PulsingRingsState();
}
class _PulsingRingsState extends State<_PulsingRings> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return SizedBox(width: 84, height: 84,
      child: Stack(alignment: Alignment.center, children: [
        ...List.generate(3, (i) => AnimatedBuilder(
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
                    color: const Color(0xFFAB5CF5).withOpacity(0.6), width: 2)),
              ),
            );
          },
        )),
        Container(width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
  @override Widget build(BuildContext context) {
    final c = urgent ? const Color(0xFFFF6B6B) : const Color(0xFFAB5CF5);
    return Container(width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.withOpacity(0.6), width: 2),
        boxShadow: urgent ? [BoxShadow(color: c.withOpacity(0.4),
          blurRadius: 12)] : [],
      ),
      child: Center(child: Text('$value',
        style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.w600,
          color: c))),
    );
  }
}

class _GlowText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _GlowText({required this.text, required this.style});
  @override State<_GlowText> createState() => _GlowTextState();
}
class _GlowTextState extends State<_GlowText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _g;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _g = Tween<double>(begin: 4, end: 18).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _g,
    builder: (_, __) => Text(widget.text,
      style: widget.style.copyWith(
        shadows: [Shadow(blurRadius: _g.value,
          color: Colors.white.withOpacity(0.6))])),
  );
}

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
    _c = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1200))..forward();
    _s = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _s, builder: (_, child) =>
      Transform.scale(scale: _s.value, child: child),
    child: widget.child,
  );
}

class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  const _ShakeWidget({required this.child, required this.shake});
  @override State<_ShakeWidget> createState() => _ShakeWidgetState();
}
class _ShakeWidgetState extends State<_ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _x;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 500));
    _x = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0),  weight: 25),
    ]).animate(_c);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override void didUpdateWidget(_ShakeWidget old) {
    super.didUpdateWidget(old);
    if (widget.shake && !old.shake) _c.forward(from: 0);
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _x, builder: (_, child) =>
      Transform.translate(offset: Offset(_x.value, 0), child: child),
    child: widget.child,
  );
}

class _SlimOutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SlimOutlineBtn(this.label, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.5), width: 1.5),
      ),
      child: Center(child: Text(label,
        style: GoogleFonts.fredoka(fontSize: 13, fontWeight: FontWeight.w500,
          color: const Color(0xFFFF9999)))),
    ),
  );
}
