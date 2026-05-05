import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'preferences_screen.dart';
import 'edit_profile_screen.dart';
import 'onboarding/profile_details_screen.dart';
import 'onboarding/gender_screen.dart';
import 'onboarding/birthday_screen.dart';
import 'onboarding/height_screen.dart';
import 'onboarding/location_screen.dart';
import 'onboarding/about_yourself_screen.dart';
import 'onboarding/interests_screen.dart';
import 'onboarding/add_photos_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  // ── App colour tokens (same as the rest of the app) ──────────────────────
  static const _bg       = Color(0xFF000000);
  static const _card     = Color(0xFF16121F);
  static const _purple   = Color(0xFF6C3FE8);
  static const _purple2  = Color(0xFF9D50BB);
  static const _pink     = Color(0xFFFF6B8A);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) { setState(() => _isLoading = false); return; }
    final profile = await _profileService.getUserProfile(userId);
    if (mounted) setState(() { _profile = profile; _isLoading = false; });
  }

  double _calcCompletion(Map<String, dynamic> p) {
    int done = 0;
    if ((p['first_name'] as String?)?.isNotEmpty == true) done++;
    if ((p['gender']     as String?)?.isNotEmpty == true) done++;
    if (p['birthday']   != null) done++;
    if (p['height_cm']  != null) done++;
    if ((p['location']  as String?)?.isNotEmpty == true) done++;
    if (p['drinking_habit'] != null || p['smoking_habit'] != null ||
        p['workout_habit']  != null) done++;
    final i = p['interests']; if (i is List && i.isNotEmpty) done++;
    final ph = p['photos'];   if (ph is List && ph.length >= 2) done++;
    return done / 8;
  }

  String _displayName(Map<String, dynamic> p) {
    final n = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : 'Your Name';
  }

  String _photoUrl(Map<String, dynamic> p) {
    final ph = p['photos'];
    if (ph is List && ph.isNotEmpty) return ph[0] as String;
    return (p['profile_image_url'] as String?) ?? '';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: _purple,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildAvatarSection()),
                  SliverToBoxAdapter(child: _buildActionButtons()),
                  SliverToBoxAdapter(child: _buildCompletionSection()),
                  SliverToBoxAdapter(child: _buildFeatureCards()),
                  SliverToBoxAdapter(child: _buildXPPlusSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: const [
              Text('MATCH',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1.5)),
              Text('XP',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: _purple, letterSpacing: 1.5)),
            ]),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withOpacity(0.3)),
                ),
                child: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar + name ─────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final p = _profile;
    final photoUrl   = p != null ? _photoUrl(p) : '';
    final name       = p != null ? _displayName(p) : 'Your Name';
    final age        = p?['age'];
    final location   = (p?['location'] as String?) ?? '';
    final completion = p != null ? _calcCompletion(p) : 0.0;
    final percent    = (completion * 100).round();
    final xp         = (p?['xp'] as num?)?.toInt() ?? 1000;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Avatar ring + badge
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Gradient ring
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
                      ? Image.network(photoUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder())
                      : _avatarPlaceholder(),
                ),
              ),
              // Completion pill
              Positioned(
                bottom: -13,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_purple, _purple2]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _bg, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: _purple.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 1),
                    ],
                  ),
                  child: Text('$percent%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Name + age
          Text(
            age != null ? '$name, $age' : name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800),
          ),

          // Location
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on,
                    color: Colors.white54, size: 14),
                const SizedBox(width: 3),
                Text(location,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ],
            ),
          ],

          // XP badge
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎮', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text('$xp XP',
                    style: const TextStyle(
                        color: _purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
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
          Expanded(child: _pillButton(
            label: 'Edit Profile',
            onTap: () async {
              if (_profile == null) return;
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditProfileScreen(profile: _profile!),
                ),
              );
              if (updated == true) _loadProfile();
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: _pillButton(
            label: 'Preferences',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const PreferencesScreen()));
            },
          )),
        ],
      ),
    );
  }

  Widget _pillButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Profile completion ────────────────────────────────────────────────────

  // Returns a list of incomplete steps: each entry has label, icon, color, and
  // a builder that pushes the correct screen.
  List<_CompletionStep> _missingSteps(Map<String, dynamic> p) {
    final steps = <_CompletionStep>[];

    if ((p['first_name'] as String?)?.isEmpty != false)
      steps.add(_CompletionStep(
        label: 'Add your name',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF6C3FE8),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileDetailsScreen())),
      ));

    if ((p['gender'] as String?)?.isEmpty != false)
      steps.add(_CompletionStep(
        label: 'Select your gender',
        icon: Icons.wc_rounded,
        color: const Color(0xFFFF6B8A),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GenderScreen())),
      ));

    if (p['birthday'] == null)
      steps.add(_CompletionStep(
        label: 'Add your birthday',
        icon: Icons.cake_outlined,
        color: const Color(0xFFFF9800),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BirthdayScreen())),
      ));

    if (p['height_cm'] == null)
      steps.add(_CompletionStep(
        label: 'Add your height',
        icon: Icons.straighten_rounded,
        color: const Color(0xFF00BCD4),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HeightScreen())),
      ));

    if ((p['location'] as String?)?.isEmpty != false)
      steps.add(_CompletionStep(
        label: 'Set your location',
        icon: Icons.location_on_outlined,
        color: const Color(0xFF4CAF50),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LocationScreen())),
      ));

    if (p['drinking_habit'] == null &&
        p['smoking_habit'] == null &&
        p['workout_habit'] == null)
      steps.add(_CompletionStep(
        label: 'Share your lifestyle',
        icon: Icons.self_improvement_rounded,
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AboutYourselfScreen())),
      ));

    final interests = p['interests'];
    if (interests is! List || (interests).isEmpty)
      steps.add(_CompletionStep(
        label: 'Pick your interests',
        icon: Icons.favorite_border_rounded,
        color: const Color(0xFFE91E63),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InterestsScreen())),
      ));

    final photos = p['photos'];
    if (photos is! List || (photos as List).length < 2)
      steps.add(_CompletionStep(
        label: 'Add more photos',
        icon: Icons.add_photo_alternate_outlined,
        color: const Color(0xFF00D4AA),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPhotosScreen())),
      ));

    return steps;
  }

  Widget _buildCompletionSection() {
    final p = _profile;
    if (p == null) return const SizedBox.shrink();

    final completion = _calcCompletion(p);
    final percent    = (completion * 100).round();
    final missing    = _missingSteps(p);

    // Hide section once profile is fully complete
    if (missing.isEmpty) return const SizedBox.shrink();

    const total = 8;
    final done  = total - missing.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _purple.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.12),
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
              // ── Header row ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete your profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$done of $total steps done',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Percentage badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_purple, _purple2]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Progress bar ────────────────────────────────────────────
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

              // ── Incomplete steps ────────────────────────────────────────
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
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: step.color.withOpacity(0.25), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: step.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(step.icon,
                              color: step.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
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
            iconBg: Colors.white.withOpacity(0.12),
            title: 'Boost',
            subtitle: 'Get seen by 4x more people',
            onTap: () => _snack('Boost coming soon!'),
          ),
          const SizedBox(height: 12),
          _featureCard(
            icon: Icons.auto_awesome_rounded,
            iconBg: Colors.white.withOpacity(0.12),
            title: 'XP',
            subtitle: '2x as likely to lead to a date',
            onTap: () => _snack('XP feature coming soon!'),
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
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _purple.withOpacity(0.9),
              _purple2.withOpacity(0.85),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _purple.withOpacity(0.25),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.5), size: 22),
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
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          // Gradient border via a stack trick
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
                color: _purple.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                _purple.withOpacity(0.08),
                _purple2.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _purple.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    // Crown badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('PREMIUM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Title + subtitle ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFCBB4FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(b),
                      child: const Text('XP+',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 4),
                    const Text('Unlock unlimited likes & premium features',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Feature list ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _xpFeatureRow(Icons.bolt_rounded,
                        const Color(0xFF6C3FE8), 'Unlimited likes'),
                    const SizedBox(height: 10),
                    _xpFeatureRow(Icons.visibility_outlined,
                        const Color(0xFF00D4AA), 'See who liked you'),
                    const SizedBox(height: 10),
                    _xpFeatureRow(Icons.replay_rounded,
                        const Color(0xFFFF6B8A), 'Unlimited rewinds'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Upgrade button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _snack('XP+ upgrade coming soon!');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_purple, _purple2],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: _purple.withOpacity(0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Upgrade to XP+',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                      ],
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

  Widget _xpFeatureRow(IconData icon, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Icon(Icons.check_circle_rounded, color: color, size: 18),
      ],
    );
  }

  // ignore: unused_element
  Widget _xpIconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
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
