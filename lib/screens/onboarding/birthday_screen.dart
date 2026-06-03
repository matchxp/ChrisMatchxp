import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'height_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({Key? key}) : super(key: key);

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  // ── Picker data ──────────────────────────────────────────────────────────
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late final List<int> _days;
  late final List<int> _years;

  // Selected indices
  int _monthIdx = 0;
  int _dayIdx = 0;
  int _yearIdx = 0;

  // Controllers
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _yearCtrl;

  static const double _itemH = 52.0;
  static const double _pickerH = 260.0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final maxYear = now.year - 18;
    _days = List.generate(31, (i) => i + 1);
    _years = List.generate(maxYear - 1923, (i) => maxYear - i); // newest first

    // Default: today - 18 years
    final def = DateTime(maxYear, now.month, now.day);
    _monthIdx = def.month - 1;
    _dayIdx = def.day - 1;
    _yearIdx = 0; // maxYear is index 0

    // Load saved birthday if any
    if (_onboardingData.birthday != null) {
      final b = _onboardingData.birthday!;
      _monthIdx = b.month - 1;
      _dayIdx = b.day - 1;
      _yearIdx = _years.indexOf(b.year).clamp(0, _years.length - 1);
    }

    _monthCtrl = FixedExtentScrollController(initialItem: _monthIdx);
    _dayCtrl = FixedExtentScrollController(initialItem: _dayIdx);
    _yearCtrl = FixedExtentScrollController(initialItem: _yearIdx);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  DateTime get _selectedDate => DateTime(
        _years[_yearIdx],
        _monthIdx + 1,
        _days[_dayIdx].clamp(1, _daysInMonth(_monthIdx + 1, _years[_yearIdx])),
      );

  int _daysInMonth(int month, int year) => DateTime(year, month + 1, 0).day;

  Future<void> _saveAndContinue() async {
    final birthday = _selectedDate;
    final now = DateTime.now();
    var age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be at least 18 years old'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      _onboardingData.birthday = birthday;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveBirthday(
            userId: userId, birthday: birthday);
        if (!result['success']) throw Exception(result['error']);
      }
      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const HeightScreen()));
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
                      child: OnboardingProgressDots(currentStep: 3),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 36),

                // ── Title ─────────────────────────────────────────
                Text(
                  'When is your\nbirthday?',
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
                  'Your age will be shown on your profile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.50),
                  ),
                ),

                const Spacer(),

                // ── Drum-roll pickers ─────────────────────────────
                SizedBox(
                  height: _pickerH,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Selection highlight bar
                      Positioned(
                        child: Container(
                          height: _itemH,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _purple.withValues(alpha: 0.55), width: 1.5),
                          ),
                        ),
                      ),

                      // Three columns
                      Row(
                        children: [
                          // Month
                          Expanded(
                            flex: 3,
                            child: _buildPicker(
                              controller: _monthCtrl,
                              itemCount: _months.length,
                              labelBuilder: (i) => _months[i],
                              onChanged: (i) => setState(() => _monthIdx = i),
                            ),
                          ),
                          // Day
                          Expanded(
                            flex: 2,
                            child: _buildPicker(
                              controller: _dayCtrl,
                              itemCount: _days.length,
                              labelBuilder: (i) =>
                                  _days[i].toString().padLeft(2, '0'),
                              onChanged: (i) => setState(() => _dayIdx = i),
                            ),
                          ),
                          // Year
                          Expanded(
                            flex: 3,
                            child: _buildPicker(
                              controller: _yearCtrl,
                              itemCount: _years.length,
                              labelBuilder: (i) => _years[i].toString(),
                              onChanged: (i) => setState(() => _yearIdx = i),
                            ),
                          ),
                        ],
                      ),

                      // Top fade
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _pickerH * 0.35,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF0C0B11).withValues(alpha: 0.0),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom fade
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: _pickerH * 0.35,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  const Color(0xFF0C0B11).withValues(alpha: 0.0),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Continue button ───────────────────────────────
                GestureDetector(
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

  // ── Single drum-roll picker column ───────────────────────────────────────
  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _itemH,
      perspective: 0.004,
      diameterRatio: 1.8,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final isSelected =
              controller.hasClients && controller.selectedItem == index;
          return Center(
            child: Text(
              labelBuilder(index),
              style: GoogleFonts.outfit(
                fontSize: isSelected ? 20 : 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color:
                    isSelected ? Colors.white : Colors.white.withValues(alpha: 0.35),
              ),
            ),
          );
        },
      ),
    );
  }
}
