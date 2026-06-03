import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'birthday_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({Key? key}) : super(key: key);

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String? _selectedGender;
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  @override
  void initState() {
    super.initState();
    if (_onboardingData.gender != null) {
      _selectedGender = _onboardingData.gender;
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedGender == null) return;
    setState(() => _isSaving = true);
    try {
      _onboardingData.gender = _selectedGender;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveGender(
          userId: userId,
          gender: _selectedGender!,
        );
        if (!result['success']) throw Exception(result['error']);
      }
      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BirthdayScreen()));
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
      body: MatchXPBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Back + dots on same row ───────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    const Expanded(
                      child: OnboardingProgressDots(currentStep: 2),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────
                Text(
                  'Tell us who you are',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Select your gender',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.50),
                  ),
                ),

                const Spacer(),

                // ── Gender options ────────────────────────────────
                _buildGenderOption('Man', 'Man'),
                const SizedBox(height: 14),
                _buildGenderOption('Woman', 'Woman'),
                const SizedBox(height: 14),
                _buildGenderOption('Non-binary', 'Non-Binary'),
                const Spacer(),

                // ── Continue button ───────────────────────────────
                GestureDetector(
                  onTap: (_selectedGender != null && !_isSaving)
                      ? _saveAndContinue
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: (_selectedGender != null && !_isSaving)
                          ? const LinearGradient(colors: [_purple, _purple2])
                          : null,
                      color: (_selectedGender == null || _isSaving)
                          ? Colors.white.withValues(alpha: 0.08)
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
    );
  }

  // ── Step indicator ──────────────────────────────────────────────────────
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
                    ? _purple.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }

  // ── Gender pill option ──────────────────────────────────────────────────
  Widget _buildGenderOption(String label, String value) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: isSelected
              ? _purple.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? _purple : _purple.withValues(alpha: 0.42),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration:
                    const BoxDecoration(color: _purple, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 13),
              ),
          ],
        ),
      ),
    );
  }
}
