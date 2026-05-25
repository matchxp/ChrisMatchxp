import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import 'onboarding/profile_details_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// SplashScreen
//
// Timeline:
//   0.30–1.10s  MATCH + XP snap in (easeOutBack)
//   1.10–2.10s  Hold together (1 second)
//   2.10–2.35s  MATCH fades out — XP stays put, no flash
//   2.35–3.00s  XP slides to screen centre (easeInOut)
//   3.00–4.00s  XP hold centred
//   4.00–4.70s  Fade to dark → navigate
// ═══════════════════════════════════════════════════════════════════

const String _matchSvg = '''
<svg viewBox="0 0 133 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M0 0.660437H10.3689L14.9919 33.7484H15.124L19.7471 0.660437H30.116V46.8911H23.2474V11.8879H23.1153L17.8318 46.8911H11.7558L6.4723 11.8879H6.34021V46.8911H0V0.660437Z" fill="white"/>
  <path d="M41.8114 0.660437H51.652L59.181 46.8911H51.9161L50.5952 37.711V37.8431H42.3398L41.0189 46.8911H34.2824L41.8114 0.660437ZM49.7367 31.569L46.5005 8.71779H46.3684L43.1983 31.569H49.7367Z" fill="white"/>
  <path d="M66.0144 7.26482H58.4194V0.660437H80.8743V7.26482H73.2792V46.8911H66.0144V7.26482Z" fill="white"/>
  <path d="M95.0309 47.5516C91.5526 47.5516 88.8888 46.5609 87.0396 44.5796C85.2344 42.5983 84.3318 39.8024 84.3318 36.192V11.3595C84.3318 7.74914 85.2344 4.95329 87.0396 2.97197C88.8888 0.990658 91.5526 0 95.0309 0C98.5092 0 101.151 0.990658 102.956 2.97197C104.805 4.95329 105.73 7.74914 105.73 11.3595V16.2468H98.8614V10.8972C98.8614 8.03533 97.6506 6.60438 95.229 6.60438C92.8074 6.60438 91.5966 8.03533 91.5966 10.8972V36.7204C91.5966 39.5382 92.8074 40.9472 95.229 40.9472C97.6506 40.9472 98.8614 39.5382 98.8614 36.7204V29.6537H105.73V36.192C105.73 39.8024 104.805 42.5983 102.956 44.5796C101.151 46.5609 98.5092 47.5516 95.0309 47.5516Z" fill="white"/>
  <path d="M110.737 0.660437H118.002V19.4829H125.795V0.660437H133.06V46.8911H125.795V26.0873H118.002V46.8911H110.737V0.660437Z" fill="white"/>
</svg>
''';

const String _xpSvg = '''
<svg viewBox="143.56 0 47.44 47.44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M149.761 0C146.336 0 143.56 2.77642 143.56 6.2013V41.2386C143.56 44.6635 146.336 47.4399 149.761 47.4399H184.799C188.224 47.4399 191 44.6635 191 41.2386V6.2013C191 2.77642 188.224 0 184.799 0H149.761ZM150.036 8.06172L155.574 23.5136L149.761 39.6883H154.522L158.275 28.6642H158.366L162.028 39.6883H167.338L161.525 23.5136L167.063 8.06172H162.303L158.824 18.2726H158.733L155.346 8.06172H150.036ZM177.602 8.06172H170.187V39.6883H175.222V26.8118H177.602C180.104 26.8118 181.981 26.1491 183.232 24.8238C184.483 23.4985 185.109 21.5557 185.109 18.9955V15.878C185.109 13.3178 184.483 11.375 183.232 10.0497C181.981 8.72437 180.104 8.06172 177.602 8.06172ZM179.433 21.616C179.036 22.0678 178.426 22.2937 177.602 22.2937H175.222V12.5798H177.602C178.426 12.5798 179.036 12.8057 179.433 13.2575C179.86 13.7093 180.074 14.4774 180.074 15.5617V19.3118C180.074 20.3961 179.86 21.1642 179.433 21.616Z" fill="#9A45DD"/>
</svg>
''';

// ── Sizes ──────────────────────────────────────────────────────────
const double _matchW = 117.0;
const double _matchH = 43.5;
const double _xpSize = 45.0;

// ── Centre-based offsets ───────────────────────────────────────────
// combined = 117 + 10 (gap) + 45 = 172
// _matchLogoTx  = -(172/2 − 117/2) = −27.5
// _xpLogoOffset = +(172/2 − 45/2)  = +63.5
const double _matchLogoTx = -27.5;
const double _matchOffTx = -280.0;
const double _xpLogoOffset = 63.5;
const double _xpOffScreen = 280.0;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Widget? _destination;
  bool _animDone = false;
  bool _navigated = false;

  // ── Timeline (seconds) ────────────────────────────────────────────
  static const double _entS = 0.30; // entrance start
  static const double _entE = 1.10; // entrance end
static const double _mOutS = 2.10; // MATCH fade start
  static const double _mOutE = 2.35; // MATCH fade end
  static const double _xpSlS =
      2.35; // XP slide start (immediately after MATCH gone)
  static const double _xpSlE = 3.00; // XP slide end
  static const double _endS = 4.00; // fade-to-dark start
  static const double _endE = 4.70; // fade-to-dark end
  static const double _total = 5.00;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).round()),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _animDone = true;
        _tryNavigate();
      }
    });
    _resolveDestination();
    Timer(const Duration(seconds: 7), () {
      _destination ??= const LoginScreen();
      _animDone = true;
      _tryNavigate();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolveDestination() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _destination = const LoginScreen();
      _tryNavigate();
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('profile_completed')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final done = profile?['profile_completed'] == true;
      _destination =
          done ? const MainNavigation() : const ProfileDetailsScreen();
    } catch (_) {
      _destination = const LoginScreen();
    }
    _tryNavigate();
  }

  void _tryNavigate() {
    if (!_animDone || _destination == null) return;
    _navigate(_destination!);
  }

  void _navigate(Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    });
  }

  // ── Easings ──────────────────────────────────────────────────────
  static double _easeOut(double t) => 1 - pow(1 - t, 3).toDouble();

  static double _easeInOut(double t) =>
      t < 0.5 ? 4 * t * t * t : (1 - pow(-2 * t + 2, 3) / 2).toDouble();

  static double _easeOutBack(double t) {
    const c = 2.2;
    return 1 + c * pow(t - 1, 3) + c * pow(t - 1, 2);
  }

  static double _p(double t, double s, double e) =>
      ((t - s) / (e - s)).clamp(0.0, 1.0);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B11),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value * _total;

          // ── MATCH ─────────────────────────────────────────────────
          // Phase 1: snap in from left
          // Phase 2: fade out smoothly — XP stays put the whole time
          // Phase 3: gone
          double matchOpacity = 0.0;
          double matchTx = _matchOffTx;

          if (t >= _entS && t < _mOutS) {
            // Entrance + hold
            final ep = _easeOutBack(_p(t, _entS, _entE));
            matchOpacity = _easeOut(_p(t, _entS, _entS + 0.35));
            matchTx = _lerp(_matchOffTx, _matchLogoTx, ep);
          } else if (t >= _mOutS && t < _mOutE) {
            // Fade out — position stays locked at logo position
            final mp = _easeInOut(_p(t, _mOutS, _mOutE));
            matchOpacity = 1.0 - mp;
            matchTx = _matchLogoTx;
          }
          // t >= _mOutE: matchOpacity stays 0, matchTx irrelevant

          // ── XP ────────────────────────────────────────────────────
          // Phase 1: snap in from right alongside MATCH
          // Phase 2: hold at logo position while MATCH fades (NO gap = no flash)
          // Phase 3: slide smoothly to screen centre
          // Phase 4: hold centred until fade-out
          double xpOpacity = 0.0;
          double xpOffset = _xpOffScreen;

          if (t >= _entS && t < _mOutS) {
            // Entrance + hold at logo position
            final ep = _easeOutBack(_p(t, _entS, _entE));
            xpOpacity = _easeOut(_p(t, _entS, _entS + 0.35));
            xpOffset = _lerp(_xpOffScreen, _xpLogoOffset, ep);
          } else if (t >= _mOutS && t < _xpSlS) {
            // ── KEY FIX: XP stays fully visible while MATCH fades ──
            // No opacity reset, no position jump → zero flash
            xpOpacity = 1.0;
            xpOffset = _xpLogoOffset;
          } else if (t >= _xpSlS && t < _endS) {
            // Slide to centre then hold
            final xp = _easeInOut(_p(t, _xpSlS, _xpSlE));
            xpOpacity = 1.0;
            xpOffset = _lerp(_xpLogoOffset, 0.0, xp);
          }
          // t >= _endS: xpOpacity stays 0 (fade-to-dark covers it)

          // ── Fade to dark ──────────────────────────────────────────
          double endOpacity = 0.0;
          if (t >= _endS) {
            endOpacity = _easeInOut(_p(t, _endS, _endE));
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Background: purple top-right → ash-black bottom-left
              Container(
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
              ),

              // Left-side ash darkening
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

              // MATCH
              if (matchOpacity > 0)
                Center(
                  child: Transform.translate(
                    offset: Offset(matchTx, 0),
                    child: Opacity(
                      opacity: matchOpacity.clamp(0.0, 1.0),
                      child: SvgPicture.string(
                        _matchSvg,
                        width: _matchW,
                        height: _matchH,
                      ),
                    ),
                  ),
                ),

              // XP
              if (xpOpacity > 0)
                Center(
                  child: Transform.translate(
                    offset: Offset(xpOffset, 0),
                    child: Opacity(
                      opacity: xpOpacity.clamp(0.0, 1.0),
                      child: SvgPicture.string(
                        _xpSvg,
                        width: _xpSize,
                        height: _xpSize,
                      ),
                    ),
                  ),
                ),

              // Fade to dark
              if (endOpacity > 0)
                Opacity(
                  opacity: endOpacity.clamp(0.0, 1.0),
                  child: Container(color: const Color(0xFF0C0B11)),
                ),
            ],
          );
        },
      ),
    );
  }
}
