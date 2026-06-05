import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connect_with_screen.dart';

class LookingForScreen extends StatefulWidget {
  const LookingForScreen({Key? key}) : super(key: key);

  @override
  State<LookingForScreen> createState() => _LookingForScreenState();
}

class _LookingForScreenState extends State<LookingForScreen> {
  // ── Changed to list for multi-select ──
  final List<String> _selected = [];
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  static const _options = [
    'Make New Friends',
    'Something Casual',
    'Long Term Relationship',
    'Not Sure Yet',
  ];

  @override
  void initState() {
    super.initState();
    // Load existing selection
    if (_onboardingData.lookingFor != null) {
      _selected.add(_onboardingData.lookingFor!);
    }
  }

  void _toggleOption(String option) {
    if (_selected.contains(option)) {
      setState(() => _selected.remove(option));
    } else if (_selected.length < 2) {
      setState(() => _selected.add(option));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'You can only pick 2',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2A1060),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selected.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      _onboardingData.lookingFor = _selected.join(', ');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'looking_for': _selected}).eq('id', userId);
      }
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ConnectWithScreen()));
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
                // ── Back + dots ───────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    const Expanded(
                      child: OnboardingProgressDots(currentStep: 6),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────
                Text(
                  'What are you\nlooking for?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select up to 2',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),

                const Spacer(),

                // ── Options — multi-select ────────────────────────
                ..._options.map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildOption(option),
                    )),

                const Spacer(),

                // ── Continue button ───────────────────────────────
                GestureDetector(
                  onTap: (_selected.isNotEmpty && !_isSaving)
                      ? _saveAndContinue
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: (_selected.isNotEmpty && !_isSaving)
                          ? const LinearGradient(colors: [_purple, _purple2])
                          : null,
                      color: (_selected.isEmpty || _isSaving)
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
                          : Text('Continue',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
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
                    ? _purple.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }

  // ── Option pill — multi-select with checkbox ──────────────────────────────
  Widget _buildOption(String option) {
    final isSelected = _selected.contains(option);
    return GestureDetector(
      onTap: () => _toggleOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: isSelected
              ? _purple.withValues(alpha: 0.15)
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
              option,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _purple : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _purple : Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
