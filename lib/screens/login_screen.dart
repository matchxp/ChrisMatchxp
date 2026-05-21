import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_login_button.dart';
import 'onboarding/profile_details_screen.dart';
import 'main_navigation.dart';

// ─────────────────────────────────────────
// SHARED BACKGROUND — use on every screen
// ─────────────────────────────────────────
class MatchXPBackground extends StatelessWidget {
  final Widget child;
  const MatchXPBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      // Layer 1 — base ash-black fills entire screen
      color: const Color(0xFF0C0B11),
      child: Stack(
        children: [
          // Layer 2 — purple radial from top-right, large spread
          Positioned.fill(
            child: CustomPaint(
              painter: _PurpleGradientPainter(),
            ),
          ),
          // Layer 3 — left ash-black fade (25% width)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.10, 0.18, 0.25],
                  colors: [
                    Color(0xB80C0A12),
                    Color(0x660C0A12),
                    Color(0x1A0C0A12),
                    Color(0x000C0A12),
                  ],
                ),
              ),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }
}

// Custom painter for the radial ellipse gradient (matches CSS ellipse 400% 140%)
class _PurpleGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Anchor at top-right corner
    final center = Offset(size.width, 0);
    final radiusX = size.width * 4.0; // 400% wide
    final radiusY = size.height * 1.4; // 140% tall

    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color.fromARGB(172, 95, 38, 128), // rgba(72,38,128,0.68) → 0xAD
          Color(0x7A1E1E60), // 0.48
          Color(0x4D221642), // 0.30
          Color(0x1F140F28), // 0.12
          Color(0x080A0716), // 0.03
          Color(0x00000000),
        ],
        stops: const [0.0, 0.18, 0.36, 0.56, 0.78, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radiusX / radiusY, 1.0); // squash horizontally to make ellipse
    canvas.drawCircle(Offset.zero, radiusY, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Auth
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  final String _selectedCountryCode = '+61';
  bool _isLoading = false;

  // Slides
  int _currentSlide = 0;
  late Timer _slideTimer;
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

  // ── FLOATING ANIMATION ──
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth sine-wave float: 7px up and down over 3.8 seconds
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0.0, end: 7.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Auto-advance slides every 6 seconds
    _slideTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _currentSlide = (_currentSlide + 1) % 3);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _floatController.dispose();
    _slideTimer.cancel();
    super.dispose();
  }

  // ── UNCHANGED: Skip to home (test) ──
  void _goToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

  // ── UNCHANGED: Send OTP ──
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
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => VerifyScreen(phoneNumber: phone)),
      );
    } else {
      _showMessage('Failed to send OTP. Please try again.');
    }
  }

  // ── UNCHANGED: Google sign-in ──
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const MainNavigation()));
      } else {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ProfileDetailsScreen()));
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UNCHANGED: Snack bar ──
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFF6C3FE8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MatchXPBackground(
        child: SafeArea(
          child: SizedBox(
            height: screenHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── TOP SECTION: Logo + Tagline + Slides ──
                  Column(
                    children: [
                      const SizedBox(height: 20),

                      // MATCHXP logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('MATCH',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              )),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF6C3FE8),
                                Color(0xFF9D50BB)
                              ],
                            ).createShader(bounds),
                            child: Text('XP',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                )),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── FLOATING: Tagline + Slides ──
                      AnimatedBuilder(
                        animation: _floatAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, -_floatAnimation.value),
                          child: child,
                        ),
                        child: Column(
                          children: [
                            // Tagline
                            Text(
                              'Match · Game · Set',
                              style: GoogleFonts.outfit(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Feature slides with horizontal swipe
                            SizedBox(
                              height: 68,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 550),
                                transitionBuilder: (child, animation) {
                                  final inSlide = Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  ));
                                  final outSlide = Tween<Offset>(
                                    begin: const Offset(-1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  ));
                                  return SlideTransition(
                                    position: animation.status ==
                                            AnimationStatus.reverse
                                        ? outSlide
                                        : inSlide,
                                    child: FadeTransition(
                                        opacity: animation, child: child),
                                  );
                                },
                                child: Column(
                                  key: ValueKey<int>(_currentSlide),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _slides[_currentSlide]['title']!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _slides[_currentSlide]['desc']!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white.withOpacity(0.50),
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── BOTTOM SECTION: Login ──
                  Column(
                    children: [
                      // Login heading
                      Text('Login',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 5),
                      Text(
                        'Please enter your valid phone number.\nWe will send you a 6-digit code to verify',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.50),
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Phone input
                      PhoneInputField(
                        controller: _phoneController,
                        countryCode: _selectedCountryCode,
                      ),

                      const SizedBox(height: 10),

                      // Continue with Phone
                      _buildOutlineButton(
                        onTap: _isLoading ? null : _sendOTP,
                        icon: const Icon(Icons.phone,
                            color: Colors.white70, size: 20),
                        label:
                            _isLoading ? 'Sending...' : 'Continue with Phone',
                      ),

                      const SizedBox(height: 10),

                      // OR divider
                      Row(children: [
                        const Expanded(
                            child:
                                Divider(color: Colors.white24, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withOpacity(0.68),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              )),
                        ),
                        const Expanded(
                            child:
                                Divider(color: Colors.white24, thickness: 1)),
                      ]),

                      const SizedBox(height: 10),

                      // Continue with Google
                      _isLoading
                          ? const CircularProgressIndicator(
                              color: Color(0xFF6C3FE8))
                          : _buildGoogleButton(),

                      const SizedBox(height: 14),

                      // Trouble signing in
                      Text('Trouble signing in?',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.44),
                          )),

                      const SizedBox(height: 8),

                      // Legal text
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: Colors.white.withOpacity(0.52),
                            height: 1.6,
                          ),
                          children: const [
                            TextSpan(
                                text:
                                    "By tapping 'Continue' you agree to our "),
                            TextSpan(
                                text: 'Terms',
                                style: TextStyle(
                                    color: Colors.white70,
                                    decoration: TextDecoration.underline)),
                            TextSpan(
                                text:
                                    '. Learn how we process your data in our '),
                            TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                    color: Colors.white70,
                                    decoration: TextDecoration.underline)),
                            TextSpan(text: ' and '),
                            TextSpan(
                                text: 'Cookies Policy',
                                style: TextStyle(
                                    color: Colors.white70,
                                    decoration: TextDecoration.underline)),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton(
      {required VoidCallback? onTap,
      required Widget icon,
      required String label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF6C3FE8).withOpacity(0.42)),
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withOpacity(0.06),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ]),
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
          border: Border.all(color: const Color(0xFF6C3FE8).withOpacity(0.42)),
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withOpacity(0.06),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// VERIFY SCREEN — logic unchanged, style updated
// ─────────────────────────────────────────
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
    for (var c in _otpControllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const MainNavigation()));
      } else {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ProfileDetailsScreen()));
      }
    } else {
      _showMessage('Invalid OTP. Please try again.');
      for (var c in _otpControllers) c.clear();
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
          content: Text(message), backgroundColor: const Color(0xFF6C3FE8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MatchXPBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                    color: Colors.white.withOpacity(0.65),
                    height: 1.5),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 50,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _focusNodes[index].hasFocus
                            ? const Color(0xFF6C3FE8)
                            : Colors.white24,
                        width: _focusNodes[index].hasFocus ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.04),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.zero),
                      onChanged: (value) {
                        if (value.length == 1 && index < 5)
                          _focusNodes[index + 1].requestFocus();
                        if (value.isEmpty && index > 0)
                          _focusNodes[index - 1].requestFocus();
                        if (index == 5 && value.length == 1) _verifyOTP();
                        setState(() {});
                      },
                    ),
                  );
                }),
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
                      Color(0xFF9D50BB)
                    ]),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF6C3FE8).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Text(_isLoading ? 'Verifying...' : 'Submit',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLoading ? null : _resendOTP,
                child: Text('Resend OTP',
                    style: GoogleFonts.outfit(
                      color:
                          _isLoading ? Colors.white54 : const Color(0xFF6C3FE8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PHONE INPUT FIELD — pill shape, purple border
// ─────────────────────────────────────────
class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final String countryCode;
  const PhoneInputField(
      {Key? key, required this.controller, required this.countryCode})
      : super(key: key);

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
              : const Color(0xFF6C3FE8).withOpacity(0.42),
          width: _isFocused ? 2.0 : 1.5,
        ),
        borderRadius: BorderRadius.circular(50),
        color: Colors.white.withOpacity(0.05),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                    color: const Color(0xFF6C3FE8).withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4))
              ]
            : [],
      ),
      child: Row(children: [
        // Flag + country code — forced single line
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
        // Vertical divider
        Container(
            width: 1,
            height: 24,
            color: _isFocused
                ? const Color(0xFF6C3FE8).withOpacity(0.6)
                : Colors.white24),
        // Text input
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)
            ],
            onTap: () => setState(() => _isFocused = true),
            onTapOutside: (_) => setState(() => _isFocused = false),
            onEditingComplete: () => setState(() => _isFocused = false),
            decoration: InputDecoration(
              hintText: 'Enter phone number',
              hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.36),
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
