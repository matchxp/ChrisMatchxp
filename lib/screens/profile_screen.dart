import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/profile_service.dart';
import '../widgets/matchxp_background.dart';
import 'login_screen.dart' hide MatchXPBackground;
import 'settings_screen.dart';
import 'preferences_screen.dart';
import 'edit_profile_screen.dart';
import 'onboarding/profile_details_screen.dart';
import 'onboarding/gender_screen.dart';
import 'onboarding/birthday_screen.dart' show BirthdayScreen;
import 'onboarding/height_screen.dart';
import 'onboarding/location_screen.dart';
import 'onboarding/about_yourself_screen.dart';
import 'onboarding/interests_screen.dart' hide BirthdayScreen;
import 'onboarding/add_photos_screen.dart';
import 'preview_profile_screen.dart';
import 'premium_state.dart';

const String _matchSvg = '''
<svg viewBox="0 0 133 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M0 0.660437H10.3689L14.9919 33.7484H15.124L19.7471 0.660437H30.116V46.8911H23.2474V11.8879H23.1153L17.8318 46.8911H11.7558L6.4723 11.8879H6.34021V46.8911H0V0.660437Z" fill="white"/>
  <path d="M41.8114 0.660437H51.652L59.181 46.8911H51.9161L50.5952 37.711V37.8431H42.3398L41.0189 46.8911H34.2824L41.8114 0.660437ZM49.7367 31.569L46.5005 8.71779H46.3684L43.1983 31.569H49.7367Z" fill="white"/>
  <path d="M66.0144 7.26482H58.4194V0.660437H80.8743V7.26482H73.2792V46.8911H66.0144V7.26482Z" fill="white"/>
  <path d="M95.0309 47.5516C91.5526 47.5516 88.8888 46.5609 87.0396 44.5796C85.2344 42.5983 84.3318 39.8024 84.3318 36.192V11.3595C84.3318 7.74914 85.2344 4.95329 87.0396 2.97197C88.8888 0.990658 91.5526 0 95.0309 0C98.5092 0 101.151 0.990658 102.956 2.97197C104.805 4.95329 105.73 7.74914 105.73 11.3595V16.2468H98.8614V10.8972C98.8614 8.03533 97.6506 6.60438 95.229 6.60438C92.8074 6.60438 91.5966 8.03533 91.5966 10.8972V36.7204C91.5966 39.5382 92.8074 40.9472 95.229 40.9472C97.6506 40.9472 98.8614 39.5382 98.8614 36.7204V29.6537H105.73V36.192C105.73 39.8024 104.805 42.5983 102.956 44.5796C101.151 46.5609 98.5092 47.5516 95.0309 47.5516Z" fill="white"/>
  <path d="M110.737 0.660437H118.002V19.4829H125.795V0.660437H133.06V46.8911H125.795V26.0873H118.002V46.8911H110.737V0.660437Z" fill="white"/>
</svg>
''';

const String _xpSvg = '''
<svg viewBox="143.56 0 47.44 47.44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M149.761 0C146.336 0 143.56 2.77642 143.56 6.2013V41.2386C143.56 44.6635 146.336 47.4399 149.761 47.4399H184.799C188.224 47.4399 191 44.6635 191 41.2386V6.2013C191 2.77642 188.224 0 184.799 0H149.761ZM150.036 8.06172L155.574 23.5136L149.761 39.6883H154.522L158.275 28.6642H158.366L162.028 39.6883H167.338L161.525 23.5136L167.063 8.06172H162.303L158.824 18.2726H158.733L155.346 8.06172H150.036ZM177.602 8.06172H170.187V39.6883H175.222V26.8118H177.602C180.104 26.8118 181.981 26.1491 183.232 24.8238C184.483 23.4985 185.109 21.5557 185.109 18.9955V15.878C185.109 13.3178 184.483 11.375 183.232 10.0497C181.981 8.72437 180.104 8.06172 177.602 8.06172ZM179.433 21.616C179.036 22.0678 178.426 22.2937 177.602 22.2937H175.222V12.5798H177.602C178.426 12.5798 179.036 12.8057 179.433 13.2575C179.86 13.7093 180.074 14.4774 180.074 15.5617V19.3118C180.074 20.3961 179.86 21.1642 179.433 21.616Z" fill="#9A45DD"/>
</svg>
''';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _showUpgradeModal = false;

  void _openUpgradeModal() {
    setState(() => _showUpgradeModal = true);
    premiumUpgradeVisible.value = true;
  }

  void _closeUpgradeModal() {
    setState(() => _showUpgradeModal = false);
    premiumUpgradeVisible.value = false;
  }

  // ── App colour tokens ─────────────────────────────────────────────────────
  static const _bg = Color(0xFF0C0B11);
  static const _card = Color(0xFF16121F);
  static const _purple = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);
  static const _pink = Color(0xFFFF6B8A);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final profile = await _profileService.getUserProfile(userId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  double _calcCompletion(Map<String, dynamic> p) {
    int done = 0;
    if ((p['first_name'] as String?)?.trim().isNotEmpty == true) done++;
    if ((p['gender'] as String?)?.trim().isNotEmpty == true) done++;
    if (p['birthday'] != null) done++;
    if (p['height_cm'] != null) done++;
    if ((p['location'] as String?)?.isNotEmpty == true) done++;
    if (p['drinking_habit'] != null ||
        p['smoking_habit'] != null ||
        p['workout_habit'] != null) {
      done++;
    }
    final i = p['interests'];
    if (i is List && i.isNotEmpty) done++;
    final ph = p['photos'];
    if (ph is List && ph.length >= 2) done++;
    return done / 8;
  }

  String _displayName(Map<String, dynamic> p) {
    final n = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : 'Your Name';
  }

  String _toPublicUrl(String url) {
    final regex = RegExp(r'(https?://[^/]+/storage/v1/object/)(?:public|sign)/([^?]+)');
    final match = regex.firstMatch(url);
    if (match != null) return '${match.group(1)}public/${match.group(2)}';
    return url;
  }

  String _photoUrl(Map<String, dynamic> p) {
    final ph = p['photos'];
    if (ph is List && ph.isNotEmpty) return _toPublicUrl(ph[0] as String);
    final url = (p['profile_image_url'] as String?) ?? '';
    return url.isNotEmpty ? _toPublicUrl(url) : '';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: MatchXPBackground(
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Fixed header — never scrolls ─────────────────────────────
                  _buildHeader(),
                  // ── Scrollable content ───────────────────────────────────────
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _purple))
                        : RefreshIndicator(
                            onRefresh: _loadProfile,
                            color: _purple,
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverToBoxAdapter(child: _buildAvatarSection()),
                                SliverToBoxAdapter(child: _buildActionButtons()),
                                SliverToBoxAdapter(
                                    child: _buildCompletionSection()),
                                SliverToBoxAdapter(child: _buildFeatureCards()),
                                SliverToBoxAdapter(child: _buildXPPlusSection()),
                                const SliverToBoxAdapter(
                                    child: SizedBox(height: 40)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              if (_showUpgradeModal) _buildUpgradeModal(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).viewPadding.top + 12;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPad - 6, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 34, height: 34), // spacer for overlay logo
          Row(
            children: [
              // ── Preview Profile eye button ──────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PreviewProfileScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.visibility_outlined,
                      color: Color(0xFF6C3FE8), size: 18),
                ),
              ),
              const SizedBox(width: 10),
              // ── Settings button ─────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.settings_outlined,
                      color: Color(0xFF6C3FE8), size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSpacer() {
    final topPad = MediaQuery.of(context).viewPadding.top + 12;
    // Same height as _buildHeader() so content starts in the right place
    return SizedBox(height: (topPad - 6) + 34 + 16);
  }

  // ── Avatar + name ─────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final p = _profile;
    final photoUrl = p != null ? _photoUrl(p) : '';
    final name = p != null ? _displayName(p) : 'Your Name';
    final age = p?['age'];
    final location = (p?['location'] as String?) ?? '';
    final completion = p != null ? _calcCompletion(p) : 0.0;
    final percent = (completion * 100).round();
    final xp = (p?['xp'] as num?)?.toInt() ?? 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Avatar ring + badge
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 124,
                height: 124,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_purple, _pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? Image.network(photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder())
                      : _avatarPlaceholder(),
                ),
              ),
              Positioned(
                bottom: -13,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_purple, _purple2]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _bg, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: _purple.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1),
                    ],
                  ),
                  child: Text(
                    '$percent%',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Name + age
          Text(
            age != null ? '$name, $age' : name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),

          // Location
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.white54, size: 14),
                const SizedBox(width: 3),
                Text(
                  location,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          // XP badge
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: const Color(0xFF1E1A2E),
        child: const Center(
            child: Icon(Icons.person, size: 60, color: Colors.white38)),
      );

  // ── Edit Profile + Preferences ────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
              child: _pillButton(
            label: 'Edit Profile',
            onTap: () async {
              if (_profile == null) return;
              await _loadProfile();
              if (!mounted || _profile == null) return;
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: _profile!),
                ),
              );
              if (updated == true) _loadProfile();
            },
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _pillButton(
            label: 'Preferences',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PreferencesScreen()));
            },
          )),
        ],
      ),
    );
  }

  Widget _pillButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Profile completion ────────────────────────────────────────────────────

  List<_CompletionStep> _missingSteps(Map<String, dynamic> p) {
    final steps = <_CompletionStep>[];

    if ((p['first_name'] as String?)?.trim().isEmpty != false) {
      steps.add(_CompletionStep(
        label: 'Add your name',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF6C3FE8),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileDetailsScreen())),
      ));
    }

    if ((p['gender'] as String?)?.trim().isEmpty != false) {
      steps.add(_CompletionStep(
        label: 'Select your gender',
        icon: Icons.wc_rounded,
        color: const Color(0xFFFF6B8A),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const GenderScreen())),
      ));
    }

    if (p['birthday'] == null) {
      steps.add(_CompletionStep(
        label: 'Add your birthday',
        icon: Icons.cake_outlined,
        color: const Color(0xFFFF9800),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BirthdayScreen())),
      ));
    }

    if (p['height_cm'] == null) {
      steps.add(_CompletionStep(
        label: 'Add your height',
        icon: Icons.straighten_rounded,
        color: const Color(0xFF00BCD4),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const HeightScreen())),
      ));
    }

    if ((p['location'] as String?)?.isEmpty != false) {
      steps.add(_CompletionStep(
        label: 'Set your location',
        icon: Icons.location_on_outlined,
        color: const Color(0xFF4CAF50),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LocationScreen())),
      ));
    }

    if (p['drinking_habit'] == null &&
        p['smoking_habit'] == null &&
        p['workout_habit'] == null) {
      steps.add(_CompletionStep(
        label: 'Share your lifestyle',
        icon: Icons.self_improvement_rounded,
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AboutYourselfScreen())),
      ));
    }

    final interests = p['interests'];
    if (interests is! List || (interests).isEmpty) {
      steps.add(_CompletionStep(
        label: 'Pick your interests',
        icon: Icons.favorite_border_rounded,
        color: const Color(0xFFE91E63),
        onTap: () async {
          if (_profile == null) return;
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile!)),
          );
          if (updated == true) _loadProfile();
        },
      ));
    }

    final photos = p['photos'];
    if (photos is! List || (photos).length < 2) {
      steps.add(_CompletionStep(
        label: 'Add more photos',
        icon: Icons.add_photo_alternate_outlined,
        color: const Color(0xFF00D4AA),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPhotosScreen())),
      ));
    }

    return steps;
  }

  Widget _buildCompletionSection() {
    final p = _profile;
    if (p == null) return const SizedBox.shrink();

    final completion = _calcCompletion(p);
    final percent = (completion * 100).round();
    final missing = _missingSteps(p);

    if (missing.isEmpty) return const SizedBox.shrink();

    const total = 8;
    final done = total - missing.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: _purple.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete your profile',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$done of $total steps done',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [_purple, _purple2]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percent%',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_purple),
                ),
              ),
              const SizedBox(height: 16),
              ...missing.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        step.onTap();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: step.color.withValues(alpha: 0.25),
                              width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: step.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:
                                  Icon(step.icon, color: step.color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step.label,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white30, size: 20),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Boost + XP cards ──────────────────────────────────────────────────────

  Widget _buildFeatureCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        children: [
          _featureCard(
            icon: Icons.bolt_rounded,
            iconBg: Colors.white.withValues(alpha: 0.12),
            title: 'Boost',
            subtitle: 'Get seen by 4x more people',
            onTap: _openUpgradeModal,
          ),
          const SizedBox(height: 12),
          _featureCard(
            icon: Icons.auto_awesome_rounded,
            iconBg: Colors.white.withValues(alpha: 0.12),
            title: 'XP',
            subtitle: '2x as likely to lead to a date',
            onTap: _openUpgradeModal,
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _purple.withValues(alpha: 0.9),
              _purple2.withValues(alpha: 0.85),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: _purple.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.5), size: 22),
          ],
        ),
      ),
    );
  }

  // ── XP+ section ───────────────────────────────────────────────────────────

  Widget _buildXPPlusSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _purple.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PREMIUM badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'PREMIUM',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // XP+ heading
            Text(
              'XP+',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),

            // Subtitle
            Text(
              'Unlock unlimited likes & premium features',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),

            // Feature rows
            _xpFeatureRow(Icons.bolt_rounded, 'Unlimited likes'),
            const SizedBox(height: 8),
            _xpFeatureRow(Icons.visibility_outlined, 'See who liked you'),
            const SizedBox(height: 8),
            _xpFeatureRow(Icons.replay_rounded, 'Unlimited rewinds'),
            const SizedBox(height: 14),

            // Upgrade button — styled as a selected preference pill
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _openUpgradeModal();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: _purple, width: 2.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Upgrade to XP+',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: _purple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xpFeatureRow(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: _purple,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 11),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _xpIconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ── Premium upgrade modal (same as Likes screen) ─────────────────────────

  Widget _buildUpgradeModal() {
    return GestureDetector(
      onTap: _closeUpgradeModal,
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent dismissal when tapping modal
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0A2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close button
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: _closeUpgradeModal,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Premium icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C3FE8).withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 60),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                        ).createShader(bounds),
                        child: Text(
                          'Upgrade to Premium',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unlock all features and find your perfect match faster!',
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Features
                      _buildUpgradeFeature(Icons.visibility, 'See who likes you'),
                      _buildUpgradeFeature(Icons.favorite, 'Unlimited likes'),
                      _buildUpgradeFeature(Icons.star, '5 Super Likes per day'),
                      _buildUpgradeFeature(Icons.location_on, 'Change your location'),
                      _buildUpgradeFeature(Icons.undo, 'Rewind unlimited'),
                      _buildUpgradeFeature(Icons.verified_user, 'Priority support'),
                      const SizedBox(height: 24),

                      // Pricing
                      _buildUpgradePricingOption(
                        title: '6 Months', price: '\$59.99',
                        perMonth: '\$10/month', badge: 'SAVE 50%', isPopular: true,
                      ),
                      const SizedBox(height: 12),
                      _buildUpgradePricingOption(
                        title: '12 Months', price: '\$89.99',
                        perMonth: '\$7.50/month', badge: 'BEST VALUE', isPopular: false,
                      ),
                      const SizedBox(height: 12),
                      _buildUpgradePricingOption(
                        title: '1 Month', price: '\$19.99',
                        perMonth: '', badge: '', isPopular: false,
                      ),
                      const SizedBox(height: 24),

                      // Continue button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment integration coming soon!',
                                  style: GoogleFonts.outfit()),
                              backgroundColor: const Color(0xFF6C3FE8),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                            ),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Center(
                            child: Text(
                              'Continue',
                              style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cancel anytime. Terms apply.',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePricingOption({
    required String title,
    required String price,
    required String perMonth,
    required String badge,
    required bool isPopular,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular
              ? const Color(0xFF6C3FE8)
              : Colors.white.withValues(alpha: 0.1),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (badge.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (perMonth.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    perMonth,
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          Text(
            price,
            style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ── Data class for completion steps ──────────────────────────────────────────

class _CompletionStep {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompletionStep({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
