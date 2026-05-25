import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'about_yourself_screen.dart';
import 'onboarding_progress_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HeightScreen extends StatefulWidget {
  const HeightScreen({Key? key}) : super(key: key);

  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  double _heightCm = 170.0;
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  int get feet => (_heightCm / 30.48).floor();
  int get inches => (((_heightCm / 30.48) - feet) * 12).round();

  @override
  void initState() {
    super.initState();
    if (_onboardingData.heightCm != null) {
      _heightCm = _onboardingData.heightCm!.toDouble();
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    try {
      _onboardingData.heightCm = _heightCm.toInt();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveHeight(
          userId: userId,
          heightCm: _heightCm.toInt(),
        );
        if (!result['success']) throw Exception(result['error']);
      }
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AboutYourselfScreen()));
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
                      child: OnboardingProgressDots(currentStep: 4),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 40),

                // ── Title — UNCHANGED ─────────────────────────────
                Text(
                  "What's your\nHeight?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 60),

                // ── Height display — UNCHANGED ────────────────────
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$feet',
                            style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: _purple,
                                height: 1)),
                        const Padding(
                          padding:
                              EdgeInsets.only(bottom: 12, left: 4, right: 8),
                          child: Text('ft',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70)),
                        ),
                        Text('$inches',
                            style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: _purple,
                                height: 1)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, left: 4),
                          child: Text('in',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${_heightCm.toInt()} cm',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white54)),
                  ],
                ),

                const SizedBox(height: 80),

                // ── Ruler slider — UNCHANGED ──────────────────────
                SizedBox(
                  height: 120,
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 3,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _purple,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: _purple.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            setState(() {
                              final scrollOffset = notification.metrics.pixels;
                              _heightCm = 120.0 + (scrollOffset / 5);
                              _heightCm = _heightCm.clamp(120.0, 220.0);
                            });
                          }
                          return true;
                        },
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          controller: ScrollController(
                            initialScrollOffset: (_heightCm - 120.0) * 5,
                          ),
                          itemCount: 101,
                          itemBuilder: (context, index) {
                            final height = 120 + index;
                            final isSelected = height == _heightCm.toInt();
                            final isMajorMark = height % 10 == 0;
                            final isMinorMark = height % 5 == 0;
                            return Container(
                              width: 20,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 2,
                                    height: isMajorMark
                                        ? 60
                                        : isMinorMark
                                            ? 40
                                            : 25,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _purple
                                          : isMajorMark
                                              ? Colors.white
                                              : Colors.white38,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  if (isMajorMark)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('$height',
                                          style: TextStyle(
                                            color: isSelected
                                                ? _purple
                                                : Colors.white70,
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          )),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                const Center(
                  child: Text('Slide to adjust your height',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
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
}
