import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../widgets/matchxp_background.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'gender_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  @override
  void initState() {
    super.initState();
    if (_onboardingData.firstName != null)
      _firstNameController.text = _onboardingData.firstName!;
    if (_onboardingData.lastName != null)
      _lastNameController.text = _onboardingData.lastName!;
    if (_onboardingData.profileImage != null)
      _profileImage = _onboardingData.profileImage;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _profileImage = File(image.path));
  }

  Future<void> _saveAndContinue() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Color.fromARGB(236, 187, 86, 214),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      _onboardingData.firstName = _firstNameController.text.trim();
      _onboardingData.lastName = _lastNameController.text.trim();
      _onboardingData.profileImage = _profileImage;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveProfileDetails(
          userId: userId,
          firstName: _onboardingData.firstName!,
          lastName: _onboardingData.lastName!,
          profileImage: _profileImage,
        );
        if (!result['success']) throw Exception(result['error']);
      }

      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const GenderScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Back button + dots on same row ──────────────
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 18),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                          ),
                          Expanded(
                            child: OnboardingProgressDots(currentStep: 1),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Title ──────────────────────────────────────
                      Text(
                        'Profile Details',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tell us a little about yourself',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),

                      const SizedBox(height: 64),

                      // ── Profile picture ────────────────────────────
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _profileImage != null
                                    ? null
                                    : LinearGradient(
                                        colors: [
                                          _purple.withOpacity(0.3),
                                          _purple2.withOpacity(0.15),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                border: Border.all(color: _purple, width: 2),
                                image: _profileImage != null
                                    ? DecorationImage(
                                        image: FileImage(_profileImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profileImage == null
                                  ? const Icon(Icons.person_rounded,
                                      size: 52, color: Color(0xFF9D70FF))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [_purple, _purple2]),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF0C0B11),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 68),

                      // ── First Name ─────────────────────────────────
                      _buildTextField(
                        controller: _firstNameController,
                        hintText: 'First Name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),

                      // ── Last Name ──────────────────────────────────
                      _buildTextField(
                        controller: _lastNameController,
                        hintText: 'Last Name',
                        icon: Icons.person_outline_rounded,
                      ),

                      const Spacer(),

                      const SizedBox(height: 32),

                      // ── Continue button ────────────────────────────
                      GestureDetector(
                        onTap: _isSaving ? null : _saveAndContinue,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: _isSaving
                                ? null
                                : const LinearGradient(
                                    colors: [_purple, _purple2]),
                            color: _isSaving
                                ? Colors.white.withOpacity(0.08)
                                : null,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Text(
                                    'Continue',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator({required int current, required int total}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isPast = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? _purple
                : isPast
                    ? _purple.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
          ),
        );
      }),
    );
  }

  // ── Plain input field ─────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: _purple.withOpacity(0.42),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
              cursorColor: _purple,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.36),
                    fontSize: 15,
                    fontWeight: FontWeight.w300),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
