import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../widgets/matchxp_background.dart';
import '../../../services/profile_service.dart';
import '../../../models/onboarding_data.dart';
import 'about_yourself_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_progress_dots.dart';
import '../main_navigation.dart';
import 'add_photos_screen.dart';

class _LocationResult {
  final String display;
  final double? lat;
  final double? lon;
  const _LocationResult({required this.display, this.lat, this.lon});
}

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

  // ── Location autocomplete ──────────────────────────────────
  List<_LocationResult> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  bool _suppressSearch = false;

  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  @override
  void initState() {
    super.initState();
    if (_onboardingData.location != null) {
      _currentLocation = _onboardingData.location!;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_suppressSearch) return;
    final q = _searchController.text.trim();
    if (q.length < 3) { setState(() => _suggestions = []); return; }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchLocation(q));
  }

  Future<void> _searchLocation(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&countrycodes=au&format=json&limit=6&addressdetails=1',
      );
      final res = await http.get(uri,
          headers: {'User-Agent': 'MatchXP/1.0', 'Accept-Language': 'en'});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _suggestions = data.map((item) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final parts = [
              addr['suburb'] ?? addr['town'] ?? addr['village'] ?? '',
              addr['city'] ?? addr['county'] ?? '',
              addr['state'] ?? '',
            ].where((s) => (s as String).isNotEmpty).cast<String>().toSet().toList();
            final short = parts.take(3).join(', ');
            return _LocationResult(
              display: short.isNotEmpty ? short : (item['display_name'] as String),
              lat: double.tryParse(item['lat'] as String? ?? ''),
              lon: double.tryParse(item['lon'] as String? ?? ''),
            );
          }).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectLocation(_LocationResult r) {
    _debounce?.cancel();
    _suppressSearch = true;
    _searchController.text = r.display;
    _suppressSearch = false;
    setState(() {
      _currentLocation = r.display;
      _suggestions = [];
      _onboardingData.latitude  = r.lat;
      _onboardingData.longitude = r.lon;
    });
    FocusScope.of(context).unfocus();
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
        final completionPayload = <String, dynamic>{
          'profile_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        };
        final bio = _onboardingData.bio;
        if (bio != null && bio.isNotEmpty) completionPayload['bio'] = bio;
        await Supabase.instance.client
            .from('profiles')
            .update(completionPayload)
            .eq('id', userId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile complete!'),
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
              backgroundColor: const Color.fromARGB(236, 187, 86, 214)),
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
                              const Expanded(
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
                              color: Colors.white.withValues(alpha: 0.80),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 64),

                          // ── Current Location pill ────────────────
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Current Location',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.50),
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
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                  color: _purple.withValues(alpha: 0.42), width: 1.0),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
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
                                const Icon(Icons.my_location_rounded,
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
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                  color: _purple.withValues(alpha: 0.42), width: 1.0),
                            ),
                            child: Row(
                              children: [
                                _isSearching
                                    ? SizedBox(
                                        width: 18, height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _purple.withValues(alpha: 0.7)))
                                    : Icon(Icons.search_rounded,
                                        color: Colors.white.withValues(alpha: 0.40),
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
                                        color: Colors.white.withValues(alpha: 0.36),
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

                          // ── Suggestions dropdown ──────────────────
                          if (_suggestions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _purple.withValues(alpha: 0.35), width: 1),
                              ),
                              child: Column(
                                children: _suggestions.asMap().entries.map((e) {
                                  final idx = e.key;
                                  final r   = e.value;
                                  return InkWell(
                                    onTap: () => _selectLocation(r),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: idx < _suggestions.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                    color: _purple.withValues(alpha: 0.15)))
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.location_on_outlined,
                                              color: _purple.withValues(alpha: 0.7),
                                              size: 16),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(r.display,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),

                          // ── Powered by OpenStreetMap ──────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('powered by ',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 12,
                                  )),
                              Text('OpenStreetMap',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.70),
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
                    ? _purple.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }
}
