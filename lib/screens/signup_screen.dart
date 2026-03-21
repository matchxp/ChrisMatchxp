import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_login_button.dart';
import 'onboarding/profile_details_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final String _selectedCountryCode = '+61';
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('\n🚀 ========== SIGNING UP USER ==========');
      print('📧 Email: ${_emailController.text.trim()}');
      
      // Sign up with Supabase
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'phone': '$_selectedCountryCode${_phoneController.text.trim()}',
        },
      );

      print('✅ Signup successful!');
      print('👤 User ID: ${response.user?.id}');
      print('📧 User Email: ${response.user?.email}');
      print('=====================================\n');

      if (response.user != null) {
        // Check if email confirmation is required
        if (response.session == null) {
          // Email confirmation required
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please check your email to confirm your account'),
                backgroundColor: Color(0xFF6C3FE8),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          // User is logged in, proceed to onboarding
          // ✅ THIS ALREADY NAVIGATES TO ONBOARDING - PERFECT!
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully! 🎉'),
                backgroundColor: Color(0xFF6C3FE8),
              ),
            );

            // Navigate to profile details (first onboarding screen)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileDetailsScreen(),
              ),
            );
          }
        }
      }
    } on AuthException catch (e) {
      print('❌ Auth error: ${e.message}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                const SizedBox(height: 40),
                // Title
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                // Phone Input Field
                PhoneInputFieldSignup(
                  controller: _phoneController,
                  countryCode: _selectedCountryCode,
                ),
                const SizedBox(height: 20),
                // Full Name Field
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Full Name',
                ),
                const SizedBox(height: 20),
                // Email Field
                CustomTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                // Password Field
                CustomTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                // Terms Checkbox
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreedToTerms = value ?? false;
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(color: Colors.white24),
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF6C3FE8);
                          }
                          return Colors.transparent;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'I agree to the ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const Text(
                      'Terms of Service',
                      style: TextStyle(
                        color: Color(0xFF6C3FE8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Continue Button
                CustomButton(
                  text: _isLoading ? 'Creating Account...' : 'Continue',
                  onPressed: (_agreedToTerms && !_isLoading) ? _handleSignUp : null,
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
                // Social Login Text
                const Text(
                  'Login using',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Social Login Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SocialLoginButton(
                      icon: Icons.facebook,
                      color: const Color(0xFF1877F2),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 20),
                    SocialLoginButton(
                      icon: Icons.g_mobiledata,
                      color: const Color(0xFFDB4437),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Color(0xFF6C3FE8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Phone Input Field Widget for Signup
class PhoneInputFieldSignup extends StatefulWidget {
  final TextEditingController controller;
  final String countryCode;

  const PhoneInputFieldSignup({
    Key? key,
    required this.controller,
    required this.countryCode,
  }) : super(key: key);

  @override
  State<PhoneInputFieldSignup> createState() => _PhoneInputFieldSignupState();
}

class _PhoneInputFieldSignupState extends State<PhoneInputFieldSignup> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isFocused ? const Color(0xFF6C3FE8) : Colors.white24,
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
          // Country Code Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Image.network(
                  'https://flagcdn.com/w40/au.png',
                  width: 24,
                  height: 16,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.flag, size: 20, color: Colors.white);
                  },
                ),
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
          // Phone Number Input
          Expanded(
            child: TextField(
              controller: widget.controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
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
                hintText: '0452312775',
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