import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../models/onboarding_data.dart';
import 'interests_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectWithScreen extends StatefulWidget {
  const ConnectWithScreen({Key? key}) : super(key: key);

  @override
  State<ConnectWithScreen> createState() => _ConnectWithScreenState();
}

class _ConnectWithScreenState extends State<ConnectWithScreen> {
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;
  bool _openToEveryone = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  static const _allOptions = ['Men', 'Women', 'Everyone'];
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    // Load existing selection if any
    if (_onboardingData.connectWith.isNotEmpty) {
      _selected.addAll(_onboardingData.connectWith);
      if (_selected.length == _allOptions.length) {
        _openToEveryone = true;
      }
    }
  }

  void _toggleOpenToEveryone(bool val) {
    setState(() {
      _openToEveryone = val;
      if (val) {
        _selected
          ..clear()
          ..addAll(_allOptions);
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleOption(String option) {
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
      _openToEveryone = _selected.length == _allOptions.length;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one option'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      _onboardingData.connectWith = List.from(_selected);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'connect_with': _selected}).eq('id', userId);
      }
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InterestsScreen()));
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
                    Expanded(
                      child: OnboardingProgressDots(currentStep: 7),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────
                Text(
                  'Who would you\nlike to connect with?',
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
                  'You can choose more than one answer\nand change it any time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.80),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 86),

                // ── Options ───────────────────────────────────────
                ..._allOptions.map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildOption(option),
                    )),

                const SizedBox(height: 8),

                // ── Hint text ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.visibility_outlined,
                        color: Colors.white.withOpacity(0.35), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You'll only be shown to people looking to connect with your gender.",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.80),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

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

  // ── Selectable option pill with checkbox ──────────────────────────────────
  Widget _buildOption(String option) {
    final isSelected = _selected.contains(option);
    return GestureDetector(
      onTap: () => _toggleOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: isSelected
              ? _purple.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? _purple : _purple.withOpacity(0.42),
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
                  color: isSelected ? _purple : Colors.white.withOpacity(0.35),
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
