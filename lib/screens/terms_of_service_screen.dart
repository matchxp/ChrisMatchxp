import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/matchxp_background.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  static const _bg     = Color(0xFF0C0B11);
  static const _purple = Color(0xFF6C3FE8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: MatchXPBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _lastUpdated('April 9, 2026'),
                    const SizedBox(height: 20),
                    _section('1. Acceptance of Terms',
                        'By downloading, installing, or using the MatchXP application, you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the app. We may update these Terms at any time and will notify you of material changes.'),
                    _section('2. Eligibility',
                        'You must be at least 18 years old to use MatchXP. By using the app, you confirm that you are 18 or older and have the legal capacity to enter into a binding agreement. Accounts found to belong to minors will be immediately terminated.'),
                    _section('3. Your Account',
                        'You are responsible for maintaining the confidentiality of your account credentials. You agree to provide accurate and complete information when creating your profile. You must not create a fake profile, impersonate another person, or misrepresent your identity or affiliation.'),
                    _section('4. Acceptable Use',
                        'You agree not to:\n\n• Harass, abuse, or harm other users.\n• Post content that is illegal, offensive, or violates the rights of others.\n• Use the app for commercial solicitation or spam.\n• Attempt to hack, reverse-engineer, or disrupt the service.\n• Share another user\'s personal information without their consent.\n• Use bots, scrapers, or automated tools to access the app.'),
                    _section('5. Content & Intellectual Property',
                        'You retain ownership of content you post (photos, messages, etc.), but grant MatchXP a non-exclusive, royalty-free, worldwide licence to use, display, and distribute your content solely to operate the service. MatchXP\'s brand, logo, and software are our exclusive intellectual property and may not be used without written permission.'),
                    _section('6. Matches & Communications',
                        'MatchXP facilitates connections between users but does not guarantee matches, compatibility, or the accuracy of user-provided information. We are not responsible for the conduct of users on or off the platform. Please exercise caution when meeting someone in person.'),
                    _section('7. Premium Features (XP+)',
                        'Some features require a paid subscription ("XP+"). Subscriptions automatically renew unless cancelled at least 24 hours before the renewal date. Purchases are non-refundable except where required by law. Pricing may change with reasonable notice.'),
                    _section('8. Termination',
                        'We may suspend or terminate your account at any time for violations of these Terms, illegal activity, or behaviour that harms other users or the integrity of the platform. You may delete your account at any time through the app settings.'),
                    _section('9. Disclaimer of Warranties',
                        'MatchXP is provided "as is" without warranties of any kind, express or implied. We do not warrant that the service will be uninterrupted, error-free, or free of harmful components. Use of the app is at your own risk.'),
                    _section('10. Limitation of Liability',
                        'To the maximum extent permitted by law, MatchXP shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the app, including but not limited to loss of data, loss of profits, or personal injury.'),
                    _section('11. Governing Law',
                        'These Terms are governed by the laws of the jurisdiction in which MatchXP operates, without regard to conflict of law principles. Any disputes shall be resolved through binding arbitration or in the courts of that jurisdiction.'),
                    _section('12. Contact',
                        'For questions about these Terms, contact us at:\n\nlegal@matchxp.app'),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text('Terms of Service', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _lastUpdated(String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(50),
      border: Border.all(color: _purple.withOpacity(0.42)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 14),
      const SizedBox(width: 8),
      Text('Last updated: $date',
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
    ]),
  );

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.outfit(color: _purple, fontSize: 14,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(body, style: GoogleFonts.outfit(
            color: Colors.white70, fontSize: 13, height: 1.6)),
      ]),
    ),
  );
}
