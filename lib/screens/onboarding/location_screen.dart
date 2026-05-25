import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/matchxp_background.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'about_yourself_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_progress_dots.dart';
import '../main_navigation.dart';
import 'add_photos_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentLocation = 'Richmond, Melbourne VIC';
  final ProfileService _profileService = ProfileService();
  final OnboardingData _onboardingData = OnboardingData();
  bool _isSaving = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  @override
  void initState() {
    super.initState();
    if (_onboardingData.location != null) {
      _currentLocation = _onboardingData.location!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    try {
      _onboardingData.location = _currentLocation;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await _profileService.saveLocation(
          userId: userId,
          location: _currentLocation,
          latitude: _onboardingData.latitude,
          longitude: _onboardingData.longitude,
        );
        if (!result['success']) throw Exception(result['error']);
        await Supabase.instance.client.from('profiles').update({
          'profile_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Complete! 🎉'),
            backgroundColor: _purple,
          ),
        );
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MainNavigation()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Color.fromARGB(236, 187, 86, 214)),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Back + dots ─────────────────────────
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new,
                                    color: Colors.white, size: 18),
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AddPhotosScreen()),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              Expanded(
                                child: OnboardingProgressDots(currentStep: 11),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Title ───────────────────────────────
                          Text(
                            'Where are you\nbased?',
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
                            'Help us find the best matches\naround you',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withOpacity(0.80),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 64),

                          // ── Current Location pill ────────────────
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Current Location',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.50),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                )),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                  color: _purple.withOpacity(0.42), width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    color: _purple, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_currentLocation,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      )),
                                ),
                                Icon(Icons.my_location_rounded,
                                    color: _purple, size: 18),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Search field ─────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                  color: _purple.withOpacity(0.42), width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded,
                                    color: Colors.white.withOpacity(0.40),
                                    size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: GoogleFonts.outfit(
                                        color: Colors.white, fontSize: 15),
                                    cursorColor: _purple,
                                    decoration: InputDecoration(
                                      hintText: 'Search your location',
                                      hintStyle: GoogleFonts.outfit(
                                        color: Colors.white.withOpacity(0.36),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w300,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ── Powered by Google ────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('powered by ',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 12,
                                  )),
                              Text('Google',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.70),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),

                          // ── Spacer pushes button to bottom ───────
                          const Spacer(),

                          // ── Continue button ──────────────────────
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
                                            color: Colors.white,
                                            strokeWidth: 2.5))
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
            },
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
                    ? _purple.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
          ),
        );
      }),
    );
  }
}
