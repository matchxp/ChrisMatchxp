import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'word_search_data.dart';

// ═══════════════════════════════════════════════════════════════
// COLOURS — exact match to HTML demo
// ═══════════════════════════════════════════════════════════════

const _bg         = Color(0xFF050310);
const _bgGrad1    = Color(0xFF2A1560);
const _bgGrad2    = Color(0xFF120D2E);
const _bgGrad3    = Color(0xFF07060F);
const _purple     = Color(0xFFAB5CF5);
const _purpleDark = Color(0xFF6930C3);
const _purpleMid  = Color(0xFF8B5CF6);
const _textMain   = Color(0xFFE2D5FF);
const _textMuted  = Color(0xFF6B5A90);
const _textDim    = Color(0xFF4A3870);
const _cardBg     = Color(0xFF140E30);
const _cardBg2    = Color(0xFF0A061C);
const _green      = Color(0xFF39FF14);
const _amber      = Color(0xFFFFB800);
const _red        = Color(0xFFFF6B6B);
const _redSoft    = Color(0xFFFF9999);

// ═══════════════════════════════════════════════════════════════
// TEXT STYLE HELPERS
// ═══════════════════════════════════════════════════════════════

TextStyle _fredoka(double size, FontWeight weight, Color color,
    {double letterSpacing = 0, List<Shadow>? shadows}) {
  return GoogleFonts.fredoka(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    shadows: shadows,
  );
}

// ═══════════════════════════════════════════════════════════════
// CONFETTI PARTICLE
// ═══════════════════════════════════════════════════════════════

class _Particle {
  double x, y, vx, vy, w, h, rot, rv, opacity;
  Color color;
  _Particle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.w, required this.h, required this.rot, required this.rv,
    required this.color, this.opacity = 1.0,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN WIDGET
// ═══════════════════════════════════════════════════════════════

class WordSearchGameScreen extends StatefulWidget {
  /// Display name of the matched partner (e.g. "Jenny")
  final String partnerName;

  /// Called with event data for Supabase integration:
  ///   event = 'puzzleSubmitted' → {word, grid, wc, catIdx}
  ///   event = 'wordSolved'
  ///   event = 'wordSkipped'
  ///   event = 'chatPressed'
  final void Function(Map<String, dynamic> event)? onGameEvent;

  /// When true, skip the welcome screen and start at the category picker.
  final bool skipWelcome;

  final bool chatAlreadyUnlocked;

  const WordSearchGameScreen({
    super.key,
    required this.partnerName,
    this.onGameEvent,
    this.skipWelcome = false,
    this.chatAlreadyUnlocked = false,
  });

  @override
  State<WordSearchGameScreen> createState() => WordSearchGameScreenState();
}

class WordSearchGameScreenState extends State<WordSearchGameScreen>
    with TickerProviderStateMixin {

  // ── Game states ────────────────────────────────────────────
  WSState _me      = WSState.fresh(); // current user
  WSState _partner = WSState.fresh(); // partner (populated via Supabase)

  // ── Word input ─────────────────────────────────────────────
  final _wordCtrl = TextEditingController();
  final _wordFocus = FocusNode();

  // ── Animation controllers ──────────────────────────────────
  late AnimationController _floatCtrl;   // gentle float 0↔-19px
  late AnimationController _shimCtrl;    // shimmer sweep
  late AnimationController _p1, _p2, _p3; // pulse rings (staggered)
  late AnimationController _shakeCtrl;   // grid shake on wrong answer
  late AnimationController _bounceCtrl;  // done-screen emoji bounce-in

  late Animation<double> _floatAnim;
  late Animation<double> _shimAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _bounceAnim;
  late Animation<double> _p1Anim, _p2Anim, _p3Anim;

  // ── Skip timer ─────────────────────────────────────────────
  Timer? _skipTimer;
  bool _showSkip = false;

  // ── Confetti ───────────────────────────────────────────────
  List<_Particle> _particles = [];
  Ticker? _confettiTicker;

  // ── Carousel ───────────────────────────────────────────────
  double _carouselTargetOffset = 0;

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.skipWelcome) {
      _me = _me.copyWith(step: WSStep.category);
    }
  }

  void _initAnimations() {
    // Float: 2s, repeats reverse
    _floatCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Shimmer: 3s, repeats
    _shimCtrl = AnimationController(duration: const Duration(seconds: 3), vsync: this)
      ..repeat();
    _shimAnim = _shimCtrl.drive(Tween(begin: -1.0, end: 2.0));

    // Pulse rings: 2s each, staggered starts
    _p1 = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
    _p2 = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _p3 = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    Future.delayed(const Duration(milliseconds: 650), () { if (mounted) _p2.repeat(); });
    Future.delayed(const Duration(milliseconds: 1300), () { if (mounted) _p3.repeat(); });

    _p1Anim = CurvedAnimation(parent: _p1, curve: Curves.easeOut);
    _p2Anim = CurvedAnimation(parent: _p2, curve: Curves.easeOut);
    _p3Anim = CurvedAnimation(parent: _p3, curve: Curves.easeOut);

    // Shake: 400ms, plays once
    _shakeCtrl = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    // Bounce-in for done emoji
    _bounceCtrl = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _bounceAnim = CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _floatCtrl.dispose(); _shimCtrl.dispose();
    _p1.dispose(); _p2.dispose(); _p3.dispose();
    _shakeCtrl.dispose(); _bounceCtrl.dispose();
    _skipTimer?.cancel();
    _confettiTicker?.dispose();
    _wordCtrl.dispose(); _wordFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // PUBLIC API — call these from Supabase realtime listeners
  // ═══════════════════════════════════════════════════════════

  /// Restores the game to [step] when rejoining a session already in progress.
  /// Pass [myWord] and [myCatIdx] so the wait/waitPartner/done screens can
  /// display the player's own submitted word correctly.
  /// Call this AFTER setPartnerData so the solve screen has the grid ready.
  void resumeFrom(WSStep step, {String myWord = '', int myCatIdx = 0}) {
    final submitted = step == WSStep.wait ||
        step == WSStep.solve ||
        step == WSStep.waitPartner ||
        step == WSStep.done;
    setState(() {
      var s = _me.copyWith(step: step, submitted: submitted);
      if (myWord.isNotEmpty) {
        s = s.copyWith(word: myWord, catIdx: myCatIdx);
      }
      _me = s;
    });
  }

  void setPartnerData(List<List<String>> grid, String word, int catIdx) {
    setState(() {
      _partner = _partner.copyWith(grid: grid, word: word, catIdx: catIdx, submitted: true);
    });
  }

  void setPartnerSolved() {
    setState(() {
      _partner = _partner.copyWith(solved: true);
      if (_me.step == WSStep.waitPartner) _me = _me.copyWith(step: WSStep.done);
    });
    if (_me.step == WSStep.done) _startDone();
  }

  void setPartnerSkipped() {
    setState(() {
      _partner = _partner.copyWith(skipped: true);
      if (_me.step == WSStep.waitPartner) _me = _me.copyWith(step: WSStep.done);
    });
    if (_me.step == WSStep.done) _startDone();
  }

  // ═══════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════

  static const _backs = {
    WSStep.category:  WSStep.welcome,
    WSStep.enterWord: WSStep.category,
    WSStep.preview:   WSStep.enterWord,
  };

  void _goBack() {
    final back = _backs[_me.step];
    if (back != null) {
      setState(() => _me = _me.copyWith(step: back));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _go(WSStep step) => setState(() => _me = _me.copyWith(step: step));

  bool get _showBack => _backs.containsKey(_me.step) ||
      _me.step == WSStep.wait ||
      _me.step == WSStep.waitPartner;
  bool get _showTitle => _me.step != WSStep.welcome;

  // ═══════════════════════════════════════════════════════════
  // GAME LOGIC
  // ═══════════════════════════════════════════════════════════

  void _submitPuzzle() {
    setState(() => _me = _me.copyWith(submitted: true, step: WSStep.wait));
    widget.onGameEvent?.call({
      'event': 'puzzleSubmitted',
      'word': _me.word,
      'grid': _me.grid,
      'wc': _me.wc,
      'catIdx': _me.catIdx,
    });
  }

  void _tapCell(int r, int c) {
    if (_me.solved) return;
    final tw = _partner.word;
    final taps = List<List<int>>.from(_me.tapCells);

    final tIdx = taps.indexWhere((d) => d[0] == r && d[1] == c);
    if (tIdx >= 0) {
      setState(() => _me = _me.copyWith(tapCells: taps.sublist(0, tIdx)));
      return;
    }
    if (taps.isEmpty) {
      setState(() => _me = _me.copyWith(tapCells: [...taps, [r, c]]));
      return;
    }
    final last = taps.last;
    if (!WordSearchData.isAdjacent(last, [r, c])) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    taps.add([r, c]);
    if (taps.length == tw.length) {
      final sel = taps.map((t) => _partner.grid![t[0]][t[1]]).join();
      if (sel == tw.toUpperCase()) {
        setState(() => _me = _me.copyWith(tapCells: taps, solved: true));
        return;
      } else {
        setState(() => _me = _me.copyWith(tapCells: taps));
        _shakeCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 430), () {
          if (mounted) setState(() => _me = _me.copyWith(tapCells: []));
        });
        return;
      }
    }
    setState(() => _me = _me.copyWith(tapCells: taps));
  }

  void _resetBoard() => setState(() => _me = _me.copyWith(tapCells: []));

  void _doSolvedContinue() {
    widget.onGameEvent?.call({'event': 'wordSolved'});
    _goToWaitPartner();
  }

  void _doSkip() {
    _skipTimer?.cancel();
    widget.onGameEvent?.call({'event': 'wordSkipped'});
    setState(() => _me = _me.copyWith(skipped: true));
    _goToWaitPartner();
  }

  // Always shows the waitPartner screen first so the player sees confirmation.
  // If the partner is already done, auto-advances to done after a brief pause.
  void _goToWaitPartner() {
    setState(() => _me = _me.copyWith(step: WSStep.waitPartner));
    if (_partner.solved || _partner.skipped) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _me.step == WSStep.waitPartner) {
          setState(() => _me = _me.copyWith(step: WSStep.done));
          _startDone();
        }
      });
    }
  }

  void _startSkipTimer() {
    _skipTimer?.cancel();
    _showSkip = false;
    _skipTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_me.solved && !_me.skipped) setState(() => _showSkip = true);
    });
  }

  void _startDone() {
    _bounceCtrl.forward(from: 0);
    _startConfetti();
  }

  void _startConfetti() {
    final rng = Random();
    final colors = [_purple, _green, _amber, const Color(0xFF00E5FF),
        const Color(0xFFFF2D78), const Color(0xFFa78bfa)];
    _particles = List.generate(80, (_) => _Particle(
      x: rng.nextDouble() * 400,
      y: -18 - rng.nextDouble() * 110,
      vx: (rng.nextDouble() - 0.5) * 4,
      vy: 1.5 + rng.nextDouble() * 3.5,
      w: 3 + rng.nextDouble() * 8,
      h: 2 + rng.nextDouble() * 4,
      rot: rng.nextDouble() * 2 * pi,
      rv: (rng.nextDouble() - 0.5) * 0.15,
      color: colors[rng.nextInt(colors.length)],
    ));
    int frame = 0;
    _confettiTicker?.dispose();
    _confettiTicker = createTicker((_) {
      if (!mounted) return;
      setState(() {
        bool alive = false;
        for (final p in _particles) {
          p.x += p.vx; p.y += p.vy;
          p.rot += p.rv; p.vy += 0.07;
          if (frame > 90) p.opacity = (p.opacity - 0.016).clamp(0, 1);
          if (p.y < 900 && p.opacity > 0) alive = true;
        }
        if (!alive) _confettiTicker?.stop();
      });
      frame++;
    })..start();
  }

  // ═══════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _floatWrap(Widget child, {double amplitude = 19}) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value * -amplitude),
        child: child,
      ),
    );
  }

  /// Primary purple gradient button
  Widget _primaryBtn(String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: disabled
              ? const LinearGradient(colors: [Color(0xFF2A1E48), Color(0xFF362856)])
              : const LinearGradient(colors: [_purpleDark, _purpleMid, Color(0xFFa78bfa), Color(0xFF7C3AED)]),
          boxShadow: disabled ? null : [
            BoxShadow(color: _purpleDark.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 6)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(label, style: _fredoka(17, FontWeight.w600, disabled ? _textMuted : Colors.white)),
      ),
    );
  }

  /// Outline ghost button
  Widget _outlineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _purple.withOpacity(0.4), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: _fredoka(15, FontWeight.w500, const Color(0xFFC4A8FF))),
      ),
    );
  }

  /// Card with shimmer
  Widget _shimmerCard(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _purple.withOpacity(0.18), width: 1.5),
        ),
        child: Stack(children: [
          Padding(padding: const EdgeInsets.all(14), child: child),
          AnimatedBuilder(
            animation: _shimAnim,
            builder: (_, __) => Positioned(
              left: _shimAnim.value * MediaQuery.of(context).size.width,
              top: 0, bottom: 0,
              width: MediaQuery.of(context).size.width * 0.4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    _purple.withOpacity(0.05),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// 3 pulsing dots
  Widget _pulseDots() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _pDot(0), const SizedBox(width: 3), _pDot(280), const SizedBox(width: 3), _pDot(560),
    ]);
  }

  Widget _pDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: 0.2 + 0.8 * sin(v * pi),
        child: Transform.scale(scale: 0.7 + 0.5 * sin(v * pi),
          child: Container(width: 5, height: 5,
            decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle)),
        ),
      ),
    );
  }

  /// Pulsing rings for wait screen
  Widget _pulseRings() {
    return SizedBox(width: 96, height: 96,
      child: Stack(alignment: Alignment.center, children: [
        _ring(_p1Anim), _ring(_p2Anim), _ring(_p3Anim),
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2A1560), Color(0xFF1A0D3E)],
            ),
            border: Border.all(color: _purple.withOpacity(0.6), width: 2),
          ),
          child: Center(child: _floatWrap(
            const Text('🔍', style: TextStyle(fontSize: 26)), amplitude: 4)),
        ),
      ]),
    );
  }

  Widget _ring(Animation<double> anim) {
    return AnimatedBuilder(animation: anim, builder: (_, __) => Transform.scale(
      scale: 0.85 + anim.value * 0.65, // 0.85 → 1.5
      child: Opacity(
        opacity: (0.8 - anim.value * 0.8).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _purple.withOpacity(0.5), width: 2),
          ),
        ),
      ),
    ));
  }

  /// Interactive 4×4 grid
  Widget _buildGrid() {
    final solver   = _me;
    final setter   = _partner;
    final grid     = setter.grid!;
    final wcCoords = setter.wc;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0), child: child),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return Container(
            width: size,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg2.withOpacity(0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: solver.solved ? _green : _purple.withOpacity(0.18), width: 2),
              boxShadow: solver.solved
                  ? [BoxShadow(color: _green.withOpacity(0.25), blurRadius: 28)]
                  : [const BoxShadow(color: Colors.black54, blurRadius: 20)],
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: 16,
              itemBuilder: (_, idx) {
                final r = idx ~/ 4, c = idx % 4;
                final letter = grid[r][c];
                final taps = solver.tapCells;
                final tIdx = taps.indexWhere((d) => d[0] == r && d[1] == c);
                final isTapped = tIdx >= 0;
                final isFound  = solver.solved && wcCoords.any((wc) => wc[0] == r && wc[1] == c);
                final last     = taps.isNotEmpty ? taps.last : null;
                final isNext   = !solver.solved && last != null &&
                    WordSearchData.isAdjacent(last, [r, c]) && !isTapped;

                Color bg = _cardBg.withOpacity(0.85);
                Color border = _purple.withOpacity(0.14);
                Color col = _textMuted;
                List<BoxShadow> sh = [];

                if (isTapped || isFound) {
                  bg = _green.withOpacity(0.18);
                  border = _green;
                  col = _green;
                  sh = [BoxShadow(color: _green.withOpacity(0.4), blurRadius: 12)];
                } else if (isNext) {
                  border = _purple.withOpacity(0.6);
                  col = const Color(0xFFC4A8FF);
                }

                return GestureDetector(
                  onTap: () => _tapCell(r, c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 2),
                      boxShadow: sh,
                    ),
                    alignment: Alignment.center,
                    child: Text(letter, style: _fredoka(28, FontWeight.w700, col)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Blank tiles row beneath grid
  Widget _buildBlanks(String word, Color accent) {
    final taps = _me.tapCells;
    final grid = _partner.grid!;
    const innerW = 320.0, gap = 5.0;
    final blankW = min(44.0, (innerW - (word.length - 1) * gap) / word.length);
    final fSz = blankW > 34 ? 22.0 : blankW > 24 ? 18.0 : 14.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(word.length, (i) {
        final tapped = i < taps.length ? taps[i] : null;
        final letter = tapped != null ? grid[tapped[0]][tapped[1]] : '';
        return Container(
          width: blankW,
          margin: i < word.length - 1 ? const EdgeInsets.only(right: gap) : EdgeInsets.zero,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: letter.isNotEmpty ? accent : _purple.withOpacity(0.3), width: 2.5)),
          ),
          alignment: Alignment.center,
          child: Text(letter, style: _fredoka(fSz, FontWeight.w700, accent)),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SCREEN BUILDERS
  // ═══════════════════════════════════════════════════════════

  // ── 1. WELCOME ─────────────────────────────────────────────
  Widget _buildWelcome() {
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(children: [
          Text('WORD', style: _fredoka(58, FontWeight.w700, Colors.white, shadows: [
            const Shadow(color: Colors.white, blurRadius: 24),
            Shadow(color: const Color(0xFFDCBEFF).withOpacity(0.5), blurRadius: 48),
          ])),
          Text('SEARCH', style: _fredoka(58, FontWeight.w700, _amber, shadows: [
            BoxShadow(color: _amber.withOpacity(0.5), blurRadius: 24) as dynamic,
          ])),
          const SizedBox(height: 4),
          Expanded(child: Row(children: [
            Expanded(child: Center(child: _floatWrap(const Text('🐾', style: TextStyle(fontSize: 52)), amplitude: 15))),
            Expanded(child: Center(child: _floatWrap(const Text('🔍', style: TextStyle(fontSize: 60))))),
            Expanded(child: Center(child: _floatWrap(const Text('⭐', style: TextStyle(fontSize: 52)), amplitude: 13))),
          ])),
          GestureDetector(
            onTap: () => setState(() => _me = _me.copyWith(showTut: true)),
            child: Text('View tutorial',
                style: _fredoka(15, FontWeight.w500, const Color(0xFFC8AAFF))
                    .copyWith(decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFC8AAFF))),
          ),
          const SizedBox(height: 18),
          _primaryBtn('Play now', () => _go(WSStep.category)),
        ]),
      ),
      if (_me.showTut) _buildTutOverlay(),
    ]);
  }

  Widget _buildTutOverlay() {
    final steps = [
      ['#00E5FF', 'Choose a category and enter a word for your match to find'],
      ['#FF2D78', 'A grid is generated with your word hidden inside it'],
      ['#39FF14', "Both find each other's hidden word to unlock the chat"],
      ['#FFB800', "Stuck? Skip becomes available after 15 seconds. but you won't earn any points"],
    ];
    final colors = [const Color(0xFF00E5FF), const Color(0xFFFF2D78), _green, _amber];

    return GestureDetector(
      onTap: () => setState(() => _me = _me.copyWith(showTut: false)),
      child: Container(
        color: const Color(0xFF050312).withOpacity(0.65),
        child: BackdropFilter(
          filter: const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0F3A), Color(0xFF0F0920)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: _purple.withOpacity(0.3), width: 1.5),
              ),
              child: GestureDetector(
                onTap: () {},
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: _purple.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(alignment: Alignment.centerLeft,
                      child: Text('HOW TO PLAY', style: _fredoka(12, FontWeight.w700, _purple, letterSpacing: 2))),
                  ),
                  const SizedBox(height: 16),
                  ...steps.asMap().entries.map((e) {
                    final i = e.key;
                    final txt = e.value[1];
                    final c = colors[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c, width: 2),
                            boxShadow: [BoxShadow(color: c.withOpacity(0.27), blurRadius: 8)],
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: _fredoka(14, FontWeight.w700, c)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(txt, style: _fredoka(14, FontWeight.w500, _textMain)
                              .copyWith(height: 1.4)),
                        )),
                      ]),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
                    child: _primaryBtn('Got it', () => setState(() => _me = _me.copyWith(showTut: false))),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. CATEGORY ────────────────────────────────────────────
  Widget _buildCategory() {
    final cats = WordSearchData.categories;
    final cat  = cats[_me.catIdx];

    return Column(children: [
      const SizedBox(height: 22),
      Text('CHOOSE A CATEGORY',
          style: _fredoka(27, FontWeight.w700, Colors.white, shadows: [
            const Shadow(color: Colors.white, blurRadius: 24),
          ])),
      const SizedBox(height: 6),
      Text('Swipe to pick', style: _fredoka(14, FontWeight.w500, _textMuted)),
      const SizedBox(height: 50),

      // Carousel — fixed-height box so Column doesn't go unbounded
      LayoutBuilder(builder: (context, constraints) {
        final cw    = constraints.maxWidth;
        const cardW = 320.0;
        const cardH = 240.0;
        const gap   = 14.0;
        final offset = (cw - cardW) / 2 - _me.catIdx * (cardW + gap);
        return SizedBox(
          width: cw,
          height: cardH,
          child: ClipRect(
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final vel = d.primaryVelocity ?? 0;
                if (vel < -100 && _me.catIdx < 3) setState(() => _me = _me.copyWith(catIdx: _me.catIdx + 1));
                else if (vel > 100 && _me.catIdx > 0) setState(() => _me = _me.copyWith(catIdx: _me.catIdx - 1));
              },
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                maxHeight: cardH,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: offset),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  builder: (_, val, __) => Transform.translate(
                    offset: Offset(val, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: cats.asMap().entries.map((e) {
                        final i = e.key; final c = e.value;
                        final active = i == _me.catIdx;
                        return GestureDetector(
                          onTap: () => setState(() => _me = _me.copyWith(catIdx: i)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            width: cardW, height: cardH,
                            margin: EdgeInsets.only(right: i < 3 ? gap : 0),
                            transform: Matrix4.identity()..scale(active ? 1.0 : 0.80),
                            transformAlignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? c.bg : const Color(0xFF0F0D1E),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: active ? c.accent.withOpacity(0.45) : Colors.white.withOpacity(0.06),
                                width: 1.5,
                              ),
                              boxShadow: active
                                  ? [BoxShadow(color: c.accent.withOpacity(0.18), blurRadius: 40)]
                                  : [],
                            ),
                            child: Opacity(
                              opacity: active ? 1.0 : 0.4,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(c.emoji, style: const TextStyle(fontSize: 62)),
                                const SizedBox(height: 16),
                                Text(c.label, style: _fredoka(26, FontWeight.w700,
                                    active ? c.accent : _textDim,
                                    shadows: active ? [Shadow(color: c.accent.withOpacity(0.5), blurRadius: 16)] : [])),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),

      const SizedBox(height: 14),
      // Dot indicators
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: cats.asMap().entries.map((e) {
          final active = e.key == _me.catIdx;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 5, width: active ? 20 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: active ? cat.accent : const Color(0xFF2B2945),
              boxShadow: active ? [BoxShadow(color: cat.accent, blurRadius: 7)] : [],
            ),
          );
        }).toList(),
      ),

      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _primaryBtn('Choose ${cat.label}', () => _go(WSStep.enterWord)),
      ),
    ]);
  }

  // ── 3. ENTER WORD ──────────────────────────────────────────
  Widget _buildEnterWord() {
    final cat     = WordSearchData.categories[_me.catIdx];
    final valid   = WordSearchData.isValid(_me.word, cat.key);
    final invalid = _me.word.length >= 2 && !valid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_me.step == WSStep.enterWord) _wordFocus.requestFocus();
    });

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(cat.label, style: _fredoka(22, FontWeight.w600, cat.accent,
            shadows: [Shadow(color: cat.accent.withOpacity(0.4), blurRadius: 14)])),
        const SizedBox(height: 16),
        // Text input
        TextField(
          controller: _wordCtrl,
          focusNode: _wordFocus,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 12,
          style: _fredoka(22, FontWeight.w700, valid ? cat.accent : Colors.white,
              letterSpacing: 4),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'TYPE A WORD HERE',
            hintStyle: _fredoka(13, FontWeight.w500, _textDim),
            filled: true, fillColor: _cardBg.withOpacity(0.8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _purple.withOpacity(0.35), width: 2)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: invalid ? _red : valid ? cat.accent : _purple.withOpacity(0.35),
                    width: 2)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: invalid ? _red : valid ? cat.accent : _purple, width: 2)),
          ),
          onChanged: (v) {
            final cleaned = v.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
            if (cleaned != v) {
              _wordCtrl.value = TextEditingValue(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );
            }
            setState(() => _me = _me.copyWith(word: cleaned));
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 18,
          child: invalid
              ? Text('"${_me.word}" is not ${cat.errorLabel}',
                  style: _fredoka(13, FontWeight.w500, _redSoft))
              : null,
        ),
        const SizedBox(height: 8),
        _primaryBtn(valid ? 'Build puzzle' : 'Enter a word first', valid ? () {
          final result = WordSearchData.generateGrid(_me.word);
          setState(() => _me = _me.copyWith(grid: result.grid, wc: result.wc));
          _go(WSStep.preview);
        } : null),
      ]),
    );
  }

  // ── 4. PREVIEW ─────────────────────────────────────────────
  Widget _buildPreview() {
    final cat   = WordSearchData.categories[_me.catIdx];
    final grid  = _me.grid!;
    final wcSet = _me.wc.map((c) => '${c[0]},${c[1]}').toSet();

    return SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(children: [
        Text('Your puzzle is ready', style: _fredoka(16, FontWeight.w400, _textMuted)),
        const SizedBox(height: 8),
        Text(_me.word, style: _fredoka(30, FontWeight.w700, cat.accent, letterSpacing: 5,
            shadows: [Shadow(color: cat.accent.withOpacity(0.5), blurRadius: 18)])),
        const SizedBox(height: 20),
        // Preview grid — full width with generous padding
        LayoutBuilder(builder: (context, constraints) {
          final gridSize = constraints.maxWidth;
          return Container(
            width: gridSize, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg2.withOpacity(0.6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _purple.withOpacity(0.18), width: 1.5),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: 16,
              itemBuilder: (_, idx) {
                final r = idx ~/ 4, c = idx % 4;
                final isW = wcSet.contains('$r,$c');
                return Container(
                  decoration: BoxDecoration(
                    color: isW ? cat.bg : _cardBg.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isW ? cat.accent.withOpacity(0.5) : _purple.withOpacity(0.12), width: 2),
                    boxShadow: isW ? [BoxShadow(color: cat.accent.withOpacity(0.2), blurRadius: 10)] : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(grid[r][c],
                      style: _fredoka(26, FontWeight.w700, isW ? cat.accent : _textMuted)),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 16),
        Text('${widget.partnerName} will see this without highlights',
            style: _fredoka(13, FontWeight.w400, _textMuted)),
        const SizedBox(height: 16),
        _primaryBtn('Send to ${widget.partnerName}', _submitPuzzle),
        const SizedBox(height: 10),
        _outlineBtn('Change word', () => _go(WSStep.enterWord)),
      ]),
    ));
  }

  // ── 5. WAIT ────────────────────────────────────────────────
  Widget _buildWait() {
    final partnerReady = _partner.submitted;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pulseRings(),
        const SizedBox(height: 18),
        Text(
          partnerReady ? "${widget.partnerName}'s puzzle is ready!" : 'Waiting for ${widget.partnerName}',
          style: _fredoka(22, FontWeight.w600, Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          partnerReady ? 'Tap below when you\'re ready to solve' : 'They are setting up their puzzle',
          style: _fredoka(14, FontWeight.w400, _textMuted),
        ),
        const SizedBox(height: 18),
        _shimmerCard(Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR WORD', style: _fredoka(10, FontWeight.w700, _purple, letterSpacing: 1)),
              const SizedBox(height: 5),
              Text(_me.word, style: _fredoka(22, FontWeight.w700, Colors.white, letterSpacing: 2)),
            ]),
            Text('Sent ✓', style: _fredoka(13, FontWeight.w600, _amber)),
          ],
        )),
        if (partnerReady) ...[
          const SizedBox(height: 24),
          _primaryBtn(
            'Solve ${widget.partnerName}\'s Puzzle',
            () => setState(() => _me = _me.copyWith(step: WSStep.solve)),
          ),
        ],
      ]),
    );
  }

  // ── 6. SOLVE ───────────────────────────────────────────────
  Widget _buildSolve() {
    if (_partner.grid == null) return _buildWait();

    final cat   = WordSearchData.categories[_me.catIdx == _partner.catIdx ? _partner.catIdx : _partner.catIdx];
    final pCat  = WordSearchData.categories[_partner.catIdx.clamp(0, 3)];
    final solved = _me.solved;

    // Start skip timer once when entering solve
    if (!solved && !_me.skipped && _skipTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSkipTimer());
    }

    return SingleChildScrollView(child: Padding(
      padding: EdgeInsets.fromLTRB(16, solved ? 10 : 20, 16, 14),
      child: Column(children: [
        _floatWrap(Text(
          solved ? 'You solved it' : 'FIND ${pCat.findLabel}',
          style: _fredoka(26, FontWeight.w700,
              solved ? _green : pCat.accent, letterSpacing: 1,
              shadows: [Shadow(
                  color: solved ? _green.withOpacity(0.6) : pCat.accent.withOpacity(0.53),
                  blurRadius: 16)]),
        )),
        SizedBox(height: solved ? 24 : 28),
        _buildGrid(),
        SizedBox(height: solved ? 16 : 28),
        _buildBlanks(_partner.word, pCat.accent),
        if (solved) ...[
          const SizedBox(height: 32),
          _primaryBtn('Continue', _doSolvedContinue),
        ] else ...[
          if (_showSkip) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _doSkip,
              child: Container(
                width: double.infinity, height: 42,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _red.withOpacity(0.35), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text('Skip This Time', style: _fredoka(14, FontWeight.w600, _redSoft)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _resetBoard,
            child: Container(
              width: double.infinity, height: 46,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _purple.withOpacity(0.3), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text('Reset Board', style: _fredoka(14, FontWeight.w600, const Color(0xFFC4A8FF))),
            ),
          ),
          const SizedBox(height: 10),
          Text('Tap letters in order · each must be adjacent',
              style: _fredoka(12, FontWeight.w400, _textDim), textAlign: TextAlign.center),
        ],
      ]),
    ));
  }

  // ── 7. WAIT PARTNER ────────────────────────────────────────
  Widget _buildWaitPartner() {
    final cat     = WordSearchData.categories[_me.catIdx.clamp(0, 3)];
    final skipped = _me.skipped;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _floatWrap(Text(
          skipped ? 'You skipped' : 'You got it',
          style: _fredoka(34, FontWeight.w700, skipped ? _redSoft : Colors.white),
        )),
        const Spacer(),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0825),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cat.accent.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(color: cat.accent.withOpacity(0.08), blurRadius: 30),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('YOUR WORD', style: _fredoka(13, FontWeight.w700, cat.accent, letterSpacing: 2.5)),
              const SizedBox(height: 12),
              Text(_me.word, style: _fredoka(44, FontWeight.w700, Colors.white, letterSpacing: 5)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${widget.partnerName} is still searching for your word',
              style: _fredoka(14, FontWeight.w500, _textMuted)),
          const SizedBox(width: 6),
          _pulseDots(),
        ]),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🔒', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text('Chat unlocks when ${widget.partnerName} finds your word',
              style: _fredoka(13, FontWeight.w600, const Color(0xFFBB8DFF))),
          const SizedBox(width: 6),
          const Text('🔒', style: TextStyle(fontSize: 16)),
        ]),
        const Spacer(),
      ]),
    );
  }

  // ── 8. DONE ────────────────────────────────────────────────
  Widget _buildDone() {
    final myCat  = WordSearchData.categories[_me.catIdx.clamp(0, 3)];
    final pCat   = WordSearchData.categories[_partner.catIdx.clamp(0, 3)];
    final both   = _me.solved && _partner.solved;
    final fz     = WordSearchData.doneWordFontSize(_me.word, _partner.word);
    final lsp    = fz >= 22 ? 1.5 : 0.0;

    return Stack(children: [
      // Confetti
      if (_particles.isNotEmpty)
        Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(_particles))),

      SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(children: [
          // Bouncing emoji
          AnimatedBuilder(
            animation: _bounceAnim,
            builder: (_, __) => Transform.scale(
              scale: _bounceAnim.value,
              child: Text(both ? '🎉' : '🔓', style: const TextStyle(fontSize: 62)),
            ),
          ),
          const SizedBox(height: 12),
          // Gradient "Ice broken!" text
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFC084FC), Colors.white, Color(0xFFC084FC)],
            ).createShader(bounds),
            child: Text(both ? 'Ice broken!' : 'Game over',
                style: _fredoka(30, FontWeight.w700, Colors.white)),
          ),
          const SizedBox(height: 8),
          Text(both ? "You both found each other's hidden words" : "Here's how it went",
              style: _fredoka(13, FontWeight.w400, _textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          // Two-column word result
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: IntrinsicHeight(child: Row(children: [
              Expanded(child: Column(children: [
                Text('YOUR WORD', style: _fredoka(10, FontWeight.w700, myCat.accent, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Text(_me.word, style: _fredoka(fz, FontWeight.w700, Colors.white, letterSpacing: lsp),
                    maxLines: 1, overflow: TextOverflow.clip),
                const SizedBox(height: 6),
                Text(_me.skipped ? '⏭ You skipped' : '✅ Solved',
                    style: _fredoka(11, FontWeight.w600, _me.skipped ? _redSoft : _green)),
              ])),
              VerticalDivider(color: Colors.white.withOpacity(0.1), width: 16),
              Expanded(child: Column(children: [
                Text('${widget.partnerName.toUpperCase()}\'S WORD',
                    style: _fredoka(10, FontWeight.w700, pCat.accent, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Text(_partner.word, style: _fredoka(fz, FontWeight.w700, Colors.white, letterSpacing: lsp),
                    maxLines: 1, overflow: TextOverflow.clip),
                const SizedBox(height: 6),
                Text(_partner.skipped ? '⏭ ${widget.partnerName} skipped' : '✅ Solved',
                    style: _fredoka(11, FontWeight.w600, _partner.skipped ? _redSoft : _green)),
              ])),
            ])),
          ),
          const SizedBox(height: 12),
          Column(children: [
            const Text('🔓', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text('Chat unlocked', style: _fredoka(17, FontWeight.w700, _green)),
            const SizedBox(height: 3),
            Text(both ? 'Both words found' : 'Game complete',
                style: _fredoka(12, FontWeight.w400, _green.withOpacity(0.55))),
          ]),
          const SizedBox(height: 16),
          _primaryBtn(
              widget.chatAlreadyUnlocked ? 'Continue Chatting' : 'Start Chatting',
              () => widget.onGameEvent?.call({'event': 'chatPressed'})),
        ]),
      )),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.1),
              radius: 1.8,
              colors: [_bgGrad1, _bgGrad2, _bgGrad3],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: _showBack ? _goBack : null,
                    child: SizedBox(
                      width: 24,
                      child: _showBack
                          ? Text('‹', style: _fredoka(28, FontWeight.w300, const Color(0xFFC4B8E8)))
                          : null,
                    ),
                  ),
                  Expanded(
                    child: _showTitle
                        ? Text('WORD SEARCH',
                            style: _fredoka(13, FontWeight.w600, const Color(0xFF7B6AAA), letterSpacing: 1),
                            textAlign: TextAlign.center)
                        : const SizedBox(),
                  ),
                  const SizedBox(width: 24),
                ]),
              ),
              // Screen content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_me.step),
                    child: _buildCurrentScreen(),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_me.step) {
      case WSStep.welcome:     return _buildWelcome();
      case WSStep.category:    return _buildCategory();
      case WSStep.enterWord:   return _buildEnterWord();
      case WSStep.preview:     return _buildPreview();
      case WSStep.wait:        return _buildWait();
      case WSStep.solve:       return _buildSolve();
      case WSStep.waitPartner: return _buildWaitPartner();
      case WSStep.done:        return _buildDone();
    }
  }
}
