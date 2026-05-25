import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../models/onboarding_data.dart';
import 'add_photos_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ValuesScreen extends StatefulWidget {
  const ValuesScreen({Key? key}) : super(key: key);

  @override
  State<ValuesScreen> createState() => _ValuesScreenState();
}

class _ValuesScreenState extends State<ValuesScreen> {
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  // ── Zodiac — single select, calendar order ────────────────────────────────
  String? _selectedZodiac;

  final List<Map<String, dynamic>> _zodiacs = [
    {'icon': Icons.local_fire_department_rounded, 'label': 'Aries'},
    {'icon': Icons.landscape_rounded, 'label': 'Taurus'},
    {'icon': Icons.people_rounded, 'label': 'Gemini'},
    {'icon': Icons.water_rounded, 'label': 'Cancer'},
    {'icon': Icons.wb_sunny_rounded, 'label': 'Leo'},
    {'icon': Icons.spa_rounded, 'label': 'Virgo'},
    {'icon': Icons.balance_rounded, 'label': 'Libra'},
    {'icon': Icons.bolt_rounded, 'label': 'Scorpio'},
    {'icon': Icons.arrow_upward_rounded, 'label': 'Sagittarius'},
    {'icon': Icons.terrain_rounded, 'label': 'Capricorn'},
    {'icon': Icons.water_drop_rounded, 'label': 'Aquarius'},
    {'icon': Icons.set_meal_rounded, 'label': 'Pisces'},
  ];

  // ── Religion — multi select ───────────────────────────────────────────────
  final List<String> _selectedReligions = [];

  final List<Map<String, dynamic>> _religions = [
    {'icon': Icons.church_rounded, 'label': 'Catholic'},
    {'icon': Icons.church_rounded, 'label': 'Christian'},
    {'icon': Icons.mosque_rounded, 'label': 'Muslim'},
    {'icon': Icons.temple_buddhist_rounded, 'label': 'Buddhist'},
    {'icon': Icons.temple_hindu_rounded, 'label': 'Hindu'},
    {'icon': Icons.synagogue_rounded, 'label': 'Jewish'},
    {'icon': Icons.self_improvement_rounded, 'label': 'Jain'},
    {'icon': Icons.account_balance_rounded, 'label': 'Mormon'},
    {'icon': Icons.science_rounded, 'label': 'Atheist'},
    {'icon': Icons.help_outline_rounded, 'label': 'Agnostic'},
  ];

  Future<void> _saveAndContinue() async {
    if (_selectedZodiac == null && _selectedReligions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one option or tap Skip'),
          backgroundColor: Color.fromARGB(236, 187, 86, 214),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').update({
          if (_selectedZodiac != null) 'zodiac': _selectedZodiac,
          if (_selectedReligions.isNotEmpty) 'religion': _selectedReligions,
        }).eq('id', userId);
      }
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPhotosScreen()));
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

  void _skip() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const AddPhotosScreen()));

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
                    Expanded(
                      child: OnboardingProgressDots(currentStep: 9),
                    ),
                    GestureDetector(
                      onTap: _skip,
                      child: Text('Skip',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.90),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ),
              ),

              // ── Title ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('A little more\nabout you',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      'Help us understand you a little better,\ntotally optional',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.80),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Scrollable sections ───────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Zodiac section ────────────────────────
                      _sectionLabel('Zodiac', Icons.auto_awesome_rounded),
                      const SizedBox(height: 14),
                      _buildTwoColGrid(_zodiacs, isZodiac: true),

                      const SizedBox(height: 32),

                      // ── Religion section ──────────────────────
                      _sectionLabel(
                          'Religion', Icons.volunteer_activism_rounded),
                      const SizedBox(height: 14),
                      _buildTwoColGrid(_religions, isZodiac: false),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Continue button ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveAndContinue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _isSaving
                          ? null
                          : const LinearGradient(colors: [_purple, _purple2]),
                      color: _isSaving ? Colors.white.withOpacity(0.08) : null,
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

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _purple, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }

  // ── 2-column pill grid ────────────────────────────────────────────────────
  Widget _buildTwoColGrid(List<Map<String, dynamic>> items,
      {required bool isZodiac}) {
    return Column(
      children: List.generate(
        (items.length / 2).ceil(),
        (rowIndex) {
          final left = rowIndex * 2;
          final right = left + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _buildPill(items[left], isZodiac: isZodiac)),
                const SizedBox(width: 10),
                right < items.length
                    ? Expanded(
                        child: _buildPill(items[right], isZodiac: isZodiac))
                    : const Expanded(child: SizedBox()),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Single pill ───────────────────────────────────────────────────────────
  Widget _buildPill(Map<String, dynamic> item, {required bool isZodiac}) {
    final label = item['label'] as String;
    final icon = item['icon'] as IconData;

    final isSelected = isZodiac
        ? _selectedZodiac == label
        : _selectedReligions.contains(label);

    return GestureDetector(
      onTap: () => setState(() {
        if (isZodiac) {
          _selectedZodiac = isSelected ? null : label;
        } else {
          isSelected
              ? _selectedReligions.remove(label)
              : _selectedReligions.add(label);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _purple.withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? _purple : _purple.withOpacity(0.42),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.55),
                size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.95),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ),
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
                    ? _purple.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
          ),
        );
      }),
    );
  }
}
