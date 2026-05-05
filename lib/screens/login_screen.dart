import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_login_button.dart';
import 'onboarding/profile_details_screen.dart';
import 'main_navigation.dart'; // ← ADD THIS IMPORT

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  final String _selectedCountryCode = '+61';
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ✅ TEST FUNCTION - Skip to home page
  void _goToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavigation(),
      ),
    );
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyScreen(phoneNumber: phone),
        ),
      );
    } else {
      _showMessage('Failed to send OTP. Please try again.');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final success = await _authService.signInWithGoogle();

      if (!success) {
        setState(() => _isLoading = false);
        _showMessage('Google sign-in failed. Please try again.');
        return;
      }

      // Check if the user has already completed onboarding
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

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (profileDone) {
        // Already done onboarding → go straight to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } else {
        // First time → go through onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileDetailsScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6C3FE8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0C1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0C1E), Color(0xFF07070F)],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ✅ BIG TEST BUTTON - SKIP TO HOME PAGE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      
                      const SizedBox(height: 16),
                      const SizedBox(height: 8),
                      
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _goToHomePage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF6B00),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'GO TO HOME PAGE NOW',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                const Divider(color: Colors.white24, thickness: 1),
                const SizedBox(height: 20),
                
                // Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MATCH',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C3FE8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter your valid phone number.\nWe will send you a 4-digit code to verify',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                // Phone Input
                PhoneInputField(
                  controller: _phoneController,
                  countryCode: _selectedCountryCode,
                ),
                const SizedBox(height: 32),
                // Submit Button
                CustomButton(
                  text: _isLoading ? 'Sending...' : 'Submit',
                  onPressed: _isLoading ? () {} : _sendOTP,
                ),
                const SizedBox(height: 32),
                // OR Divider
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Continue with',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Google Sign-In Button
                _isLoading
                    ? const CircularProgressIndicator(
                        color: Color(0xFF6C3FE8),
                      )
                    : _buildGoogleSignInButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return InkWell(
      onTap: _signInWithGoogle,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.g_mobiledata,
                  color: Colors.white,
                  size: 24,
                );
              },
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// VERIFY SCREEN WITH EDITABLE OTP INPUT
// ========================================
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
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
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
      // Check if user already completed onboarding
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              profileDone ? const MainNavigation() : const ProfileDetailsScreen(),
        ),
      );
    } else {
      _showMessage('Invalid OTP. Please try again.');
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    
    final success = await _authService.sendOTP(widget.phoneNumber);
    
    setState(() => _isLoading = false);
    
    if (success) {
      _showMessage('OTP sent successfully');
    } else {
      _showMessage('Failed to resend OTP');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6C3FE8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0C1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0C1E), Color(0xFF07070F)],
          ),
        ),
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              const Text(
                'Verify',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please enter the 6-digit code\nsent to ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(179, 255, 255, 255),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),
              // OTP Input Boxes
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
                    ),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
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
                  );
                }),
              ),
              const SizedBox(height: 40),
              // Submit Button
              CustomButton(
                text: _isLoading ? 'Verifying...' : 'Submit',
                onPressed: _isLoading ? () {} : _verifyOTP,
              ),
              const SizedBox(height: 24),
              // Resend OTP
              GestureDetector(
                onTap: _isLoading ? null : _resendOTP,
                child: Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: _isLoading 
                        ? const Color.fromARGB(255, 255, 255, 255) 
                        : const Color(0xFF6C3FE8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ========================================
// PHONE INPUT FIELD
// ========================================
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
          color: _isFocused ? const Color(0xFF6C3FE8) : const Color(0xFF6C3FE8),
          width: _isFocused ? 2.0 : 1.5,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF6C3FE8).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.flag, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.countryCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: _isFocused ? const Color(0xFF6C3FE8) : Colors.white24,
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onTap: () {
                setState(() => _isFocused = true);
              },
              onTapOutside: (_) {
                setState(() => _isFocused = false);
              },
              onEditingComplete: () {
                setState(() => _isFocused = false);
              },
              decoration: const InputDecoration(
                hintText: '0450372221',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}