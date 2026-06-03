import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'values_screen.dart';
import 'add_photos_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({Key? key}) : super(key: key);

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final List<String> _selectedInterests = [];
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  final List<Map<String, dynamic>> _interests = [
    {'icon': Icons.camera_alt_rounded, 'label': 'Photography'},
    {'icon': Icons.restaurant_rounded, 'label': 'Cooking'},
    {'icon': Icons.nightlife_rounded, 'label': 'Dancing'},
    {'icon': Icons.videogame_asset_rounded, 'label': 'Video Games'},
    {'icon': Icons.music_note_rounded, 'label': 'Music'},
    {'icon': Icons.coffee_rounded, 'label': 'Coffee'},
    {'icon': Icons.wine_bar_rounded, 'label': 'Wine'},
    {'icon': Icons.cake_rounded, 'label': 'Baking'},
    {'icon': Icons.yard_rounded, 'label': 'Gardening'},
    {'icon': Icons.flight_rounded, 'label': 'Travelling'},
    {'icon': Icons.shopping_bag_rounded, 'label': 'Shopping'},
    {'icon': Icons.pool_rounded, 'label': 'Swimming'},
    {'icon': Icons.palette_rounded, 'label': 'Crafts'},
    {'icon': Icons.sports_rounded, 'label': 'Sports'},
    {'icon': Icons.fitness_center_rounded, 'label': 'Fitness'},
    {'icon': Icons.self_improvement_rounded, 'label': 'Yoga'},
    {'icon': Icons.fastfood_rounded, 'label': 'Foodie'},
    {'icon': Icons.outdoor_grill_rounded, 'label': 'Camping'},
    {'icon': Icons.hiking_rounded, 'label': 'Hiking'},
    {'icon': Icons.movie_rounded, 'label': 'Movies'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedInterests.addAll(_onboardingData.interests);
  }

  Future<void> _saveAndContinue() async {
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 interest or tap Skip'),
          backgroundColor: Color.fromARGB(236, 187, 86, 214),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      _onboardingData.interests = _selectedInterests;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveInterests(
          userId: userId,
          interests: _selectedInterests,
        );
        if (!result['success']) throw Exception(result['error']);
      }
      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ValuesScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: const Color.fromARGB(236, 187, 86, 214)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _skip() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ValuesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B11),
      body: MatchXPBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Back + dots + skip ────────────────────────────
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
                    const Expanded(
                      child: OnboardingProgressDots(currentStep: 8),
                    ),
                    GestureDetector(
                      onTap: _skip,
                      child: Text('Skip',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ),
              ),

              // ── Title — centred ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Likes and Interests',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 6),
                    Text('Share your likes and passion to connect quicker',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.80),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 52),

              // ── 2 pills per row ───────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: List.generate(
                      (_interests.length / 2).ceil(),
                      (rowIndex) {
                        final left = rowIndex * 2;
                        final right = left + 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(child: _buildPill(_interests[left])),
                              const SizedBox(width: 10),
                              right < _interests.length
                                  ? Expanded(
                                      child: _buildPill(_interests[right]))
                                  : const Expanded(child: SizedBox()),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Continue button ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveAndContinue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _isSaving
                          ? null
                          : const LinearGradient(colors: [_purple, _purple2]),
                      color: _isSaving ? Colors.white.withValues(alpha: 0.08) : null,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Single pill ───────────────────────────────────────────────────────────
  Widget _buildPill(Map<String, dynamic> interest) {
    final label = interest['label'] as String;
    final icon = interest['icon'] as IconData;
    final isSelected = _selectedInterests.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        isSelected
            ? _selectedInterests.remove(label)
            : _selectedInterests.add(label);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _purple.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? _purple : _purple.withValues(alpha: 0.42),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color:
                    isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.outfit(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.95),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                )),
          ],
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
}
