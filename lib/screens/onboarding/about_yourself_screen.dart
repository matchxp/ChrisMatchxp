import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'interests_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_progress_dots.dart';
import 'looking_for_screen.dart';

class AboutYourselfScreen extends StatefulWidget {
  const AboutYourselfScreen({Key? key}) : super(key: key);

  @override
  State<AboutYourselfScreen> createState() => _AboutYourselfScreenState();
}

class _AboutYourselfScreenState extends State<AboutYourselfScreen> {
  String? _drinkingHabit;
  String? _smokingHabit;
  String? _workoutHabit;
  final TextEditingController _petsController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  @override
  void initState() {
    super.initState();
    _drinkingHabit = _onboardingData.drinkingHabit;
    _smokingHabit = _onboardingData.smokingHabit;
    _workoutHabit = _onboardingData.workoutHabit;
    // Load existing pets as text
    if (_onboardingData.pets.isNotEmpty) {
      _petsController.text = _onboardingData.pets.join(', ');
    }
  }

  @override
  void dispose() {
    _petsController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_drinkingHabit == null &&
        _smokingHabit == null &&
        _workoutHabit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer at least one question to continue'),
          backgroundColor: Color.fromARGB(236, 187, 86, 214),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      _onboardingData.drinkingHabit = _drinkingHabit;
      _onboardingData.smokingHabit = _smokingHabit;
      _onboardingData.workoutHabit = _workoutHabit;
      // Convert text answer to list
      final petsText = _petsController.text.trim();
      _onboardingData.pets = petsText.isNotEmpty ? [petsText] : [];

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveLifestyle(
          userId: userId,
          drinkingHabit: _drinkingHabit,
          smokingHabit: _smokingHabit,
          workoutHabit: _workoutHabit,
          pets: _onboardingData.pets,
        );
        if (!result['success']) throw Exception(result['error']);
      }

      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LookingForScreen()));
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
          child: Column(
            children: [
              // ── Back + dots ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    Expanded(
                      child: OnboardingProgressDots(currentStep: 5),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Scrollable content ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title

                      SizedBox(
                        width: double.infinity,
                        child: Text('About Yourself',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            )),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Do their habits match yours? You go first.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.80),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Drinking ──────────────────────────────────
                      _sectionLabel('How often do you drink?'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          'Never',
                          'On special Occasionally',
                          'Socially on weekends',
                          'Most Nights',
                        ]
                            .map((v) => _buildChip(v, _drinkingHabit,
                                (val) => setState(() => _drinkingHabit = val)))
                            .toList(),
                      ),

                      const SizedBox(height: 32),

                      // ── Smoking — "Smoker when drinking" removed ──
                      _sectionLabel('How often do you smoke?'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          'Non-smoker',
                          'Social smoker',
                          'Trying to quit',
                          'Smoker',
                        ]
                            .map((v) => _buildChip(v, _smokingHabit,
                                (val) => setState(() => _smokingHabit = val)))
                            .toList(),
                      ),

                      const SizedBox(height: 32),

                      // ── Workout ───────────────────────────────────
                      _sectionLabel('Do you workout?'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          'Everyday',
                          'Often',
                          'Sometimes',
                          'No, not really',
                          'No, but I plan to start',
                        ]
                            .map((v) => _buildChip(v, _workoutHabit,
                                (val) => setState(() => _workoutHabit = val)))
                            .toList(),
                      ),

                      const SizedBox(height: 32),

                      // ── Pets — text answer box ────────────────────
                      _sectionLabel('Do you have any pets?'),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                              color: _purple.withOpacity(0.42), width: 1.0),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 16),
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Icon(Icons.pets_rounded,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 18),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _petsController,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400),
                                cursorColor: _purple,
                                decoration: InputDecoration(
                                  hintText:
                                      'e.g. I have a golden retriever and a cat...',
                                  hintStyle: GoogleFonts.outfit(
                                      color: Colors.white.withOpacity(0.36),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w300),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Continue button ───────────────────────────
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
            ],
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

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.outfit(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600));

  Widget _buildChip(
      String label, String? currentValue, Function(String) onSelect) {
    final isSelected = currentValue == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? _purple.withOpacity(0.18) : Colors.transparent,
          border: Border.all(
            color: isSelected ? _purple : _purple.withOpacity(0.42),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.95),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
    );
  }
}
