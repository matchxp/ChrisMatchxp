import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_login_button.dart';
import 'onboarding/profile_details_screen.dart';
import 'main_navigation.dart';

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

// ═══════════════════════════════════════════════════════
// SHARED BACKGROUND WIDGET
// ═══════════════════════════════════════════════════════
class MatchXPBackground extends StatelessWidget {
  final Widget child;
  const MatchXPBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
        child,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  final String _selectedCountryCode = '+61';
  bool _isLoading = false;

  int _currentSlide = 0;
  late Timer _slideTimer;
  late final PageController _pageController;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Avoid Awkward Matches',
      'desc': 'Kickstart connections with fun games.'
    },
    {
      'title': 'Discover Real Matches',
      'desc': 'Go beyond profiles; find shared interests.'
    },
    {
      'title': 'Build Lasting Bonds',
      'desc': 'Games pave the way for deeper connections.'
    },
  ];

  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
    _slideTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      _currentSlide = (_currentSlide + 1) % _slides.length;
      _pageController.animateToPage(
        _currentSlide,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _floatController.dispose();
    _pageController.dispose();
    _slideTimer.cancel();
    super.dispose();
  }

  void _goToHomePage() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainNavigation()));
  }

  Future<void> _sendOTP() async {
    final phone = _selectedCountryCode + _phoneController.text.trim();
    if (_phoneController.text.isEmpty) {
      _showMessage('Please enter phone number');
      return;
    }
    setState(() => _isLoading = true);
    final success = await _authService.sendOTP(phone);
    setState(() => _isLoading = false);
    if (success) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => VerifyScreen(phoneNumber: phone)));
    } else {
      _showMessage('Failed to send OTP. Please try again.');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final success = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (!success) {
        _showMessage('Google sign-in cancelled.');
        return;
      }
      final userId = Supabase.instance.client.auth.currentUser?.id;
      bool profileDone = false;
      if (userId != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('profile_completed')
              .eq('id', userId)
              .maybeSingle();
          profileDone = profile?['profile_completed'] == true;
        } catch (_) {}
      }
      if (!mounted) return;
      if (profileDone) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainNavigation()));
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()));
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFF6C3FE8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B11),
      resizeToAvoidBottomInset: true,
      body: MatchXPBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  // minHeight = actual available body height (already shrunk by keyboard)
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── MATCHXP LOGO ──────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SvgPicture.string(_matchSvg,
                                  width: 70, height: 26),
                              const SizedBox(width: 5),
                              SvgPicture.string(_xpSvg, width: 26, height: 26),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── TAGLINE ────────────────────────────────
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              final dy =
                                  sin(_floatController.value * 2 * pi) * 7.0;
                              return Transform.translate(
                                offset: Offset(0, dy),
                                child: child,
                              );
                            },
                            child: Text(
                              'Match · Game · Set',
                              style: GoogleFonts.outfit(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0,
                              ),
                            ),
                          ),

                          // ── SLIDES — Expanded works inside IntrinsicHeight ──
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                height: 90,
                                child: PageView.builder(
                                  controller: _pageController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _slides.length,
                                  itemBuilder: (context, index) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _slides[index]['title']!,
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _slides[index]['desc']!,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w300,
                                            color:
                                                Colors.white.withValues(alpha: 0.50),
                                            height: 1.55,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // ── LOGIN SECTION ──────────────────────────
                          Text('Login',
                              style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(height: 5),
                          Text(
                            'Please enter your valid phone number.\nWe will send you a 6-digit code to verify',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withValues(alpha: 0.50),
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 16),

                          PhoneInputField(
                            controller: _phoneController,
                            countryCode: _selectedCountryCode,
                          ),

                          const SizedBox(height: 10),

                          _buildPillButton(
                            onTap: _isLoading ? null : _sendOTP,
                            icon: const Icon(Icons.phone,
                                color: Colors.white70, size: 20),
                            label: _isLoading
                                ? 'Sending...'
                                : 'Continue with Phone',
                          ),

                          const SizedBox(height: 10),

                          Row(children: [
                            Expanded(
                              child: Divider(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  thickness: 1),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  )),
                            ),
                            Expanded(
                              child: Divider(
                                  color: Colors.white.withValues(alpha: 0.13),
                                  thickness: 1),
                            ),
                          ]),

                          const SizedBox(height: 10),

                          _isLoading
                              ? const SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF6C3FE8),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _buildGoogleButton(),

                          const SizedBox(height: 14),

                          Text('Trouble signing in?',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.44))),

                          const SizedBox(height: 8),

                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.52),
                                height: 1.6,
                              ),
                              children: const [
                                TextSpan(
                                    text:
                                        "By tapping 'Continue' you agree to our "),
                                TextSpan(
                                    text: 'Terms',
                                    style: TextStyle(
                                        color: Color(0xC2FFFFFF),
                                        decoration: TextDecoration.underline)),
                                TextSpan(
                                    text:
                                        '. Learn how we process your data in our '),
                                TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                        color: Color(0xC2FFFFFF),
                                        decoration: TextDecoration.underline)),
                                TextSpan(text: ' and '),
                                TextSpan(
                                    text: 'Cookies Policy',
                                    style: TextStyle(
                                        color: Color(0xC2FFFFFF),
                                        decoration: TextDecoration.underline)),
                                TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required VoidCallback? onTap,
    required Widget icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.42), width: 1),
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _signInWithGoogle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.42), width: 1),
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              width: 20,
              height: 20,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.g_mobiledata, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Continue with Google',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// VERIFY SCREEN
// ═══════════════════════════════════════════════════════
class VerifyScreen extends StatefulWidget {
  final String phoneNumber;
  const VerifyScreen({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otp.length < 6) {
      _showMessage('Please enter complete OTP');
      return;
    }
    setState(() => _isLoading = true);
    final success = await _authService.verifyOTP(widget.phoneNumber, _otp);
    setState(() => _isLoading = false);

    if (success) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      bool profileDone = false;
      if (userId != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('profile_completed')
              .eq('id', userId)
              .maybeSingle();
          profileDone = profile?['profile_completed'] == true;
        } catch (_) {}
      }
      if (!mounted) return;
      if (profileDone) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainNavigation()));
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()));
      }
    } else {
      _showMessage('Invalid OTP. Please try again.');
      for (var c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    final success = await _authService.sendOTP(widget.phoneNumber);
    setState(() => _isLoading = false);
    _showMessage(success ? 'OTP sent successfully' : 'Failed to resend OTP');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color.fromARGB(236, 187, 86, 214),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B11),
      resizeToAvoidBottomInset: true,
      body: MatchXPBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    Text('Verify',
                        style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(
                      'Please enter the 6-digit code\nsent to ${widget.phoneNumber}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          6,
                          (index) => Container(
                                width: 50,
                                height: 60,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _focusNodes[index].hasFocus
                                        ? const Color(0xFF6C3FE8)
                                        : Colors.white24,
                                    width:
                                        _focusNodes[index].hasFocus ? 2.0 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withValues(alpha: 0.04),
                                ),
                                child: TextField(
                                  controller: _otpControllers[index],
                                  focusNode: _focusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero),
                                  onChanged: (value) {
                                    if (value.length == 1 && index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    }
                                    if (value.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                    if (index == 5 && value.length == 1) {
                                      _verifyOTP();
                                    }
                                    setState(() {});
                                  },
                                ),
                              )),
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _isLoading ? null : _verifyOTP,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFF7C3AED),
                            Color(0xFF6C3FE8),
                            Color(0xFF9D50BB),
                          ]),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C3FE8).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Text(
                          _isLoading ? 'Verifying...' : 'Submit',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _isLoading ? null : _resendOTP,
                      child: Text('Resend OTP',
                          style: GoogleFonts.outfit(
                            color: _isLoading
                                ? Colors.white54
                                : const Color(0xFF6C3FE8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                    const Spacer(flex: 2),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PHONE INPUT FIELD
// ═══════════════════════════════════════════════════════
class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final String countryCode;
  const PhoneInputField({
    Key? key,
    required this.controller,
    required this.countryCode,
  }) : super(key: key);

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isFocused
              ? const Color(0xFF6C3FE8)
              : const Color(0xFF6C3FE8).withValues(alpha: 0.42),
          width: _isFocused ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(50),
        color: Colors.white.withValues(alpha: 0.05),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🇦🇺', style: TextStyle(fontSize: 17)),
            const SizedBox(width: 5),
            Text(widget.countryCode,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white54, size: 18),
          ]),
        ),
        Container(
          width: 1,
          height: 24,
          color: _isFocused
              ? const Color(0xFF6C3FE8).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.14),
        ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onTap: () => setState(() => _isFocused = true),
            onTapOutside: (_) => setState(() => _isFocused = false),
            onEditingComplete: () => setState(() => _isFocused = false),
            decoration: InputDecoration(
              hintText: 'Enter phone number',
              hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.36),
                  fontSize: 14,
                  fontWeight: FontWeight.w300),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ]),
    );
  }
}
