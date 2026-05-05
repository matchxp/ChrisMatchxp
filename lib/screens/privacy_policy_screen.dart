import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  static const _bg     = Color(0xFF0A0A0A);
  static const _card   = Color(0xFF1A1A1A);
  static const _purple = Color(0xFF6C3FE8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                children: [
                  _lastUpdated('April 9, 2026'),
                  const SizedBox(height: 20),
                  _section(
                    'Introduction',
                    'Welcome to MatchXP ("we", "our", "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, and share information about you when you use our mobile application.',
                  ),
                  _section(
                    'Information We Collect',
                    'We collect information you provide directly to us, including:\n\n• Account information such as your name, email address, date of birth, and password.\n• Profile information such as photos, gender, height, location, interests, and lifestyle habits.\n• Communications you send through the app, including messages to other users.\n• Device information including IP address, device type, operating system, and unique identifiers.',
                  ),
                  _section(
                    'How We Use Your Information',
                    'We use the information we collect to:\n\n• Provide, maintain, and improve the MatchXP service.\n• Match you with compatible users based on your preferences and profile.\n• Send you notifications about matches, messages, and app updates.\n• Personalise your experience and show you relevant content.\n• Detect and prevent fraudulent or illegal activity.\n• Comply with legal obligations.',
                  ),
                  _section(
                    'Sharing Your Information',
                    'We do not sell your personal data. We may share your information with:\n\n• Other users as part of the matching and messaging features (profile information you have made visible).\n• Service providers who assist us in operating the app (e.g. cloud hosting, analytics).\n• Law enforcement or regulatory authorities when required by law.\n• Acquirers in the event of a merger, acquisition, or sale of assets.',
                  ),
                  _section(
                    'Your Photos & Media',
                    'Photos you upload are stored securely on our servers. Your primary profile photo is visible to other users. You can delete your photos at any time from your profile settings. Deleted photos are permanently removed from our servers within 30 days.',
                  ),
                  _section(
                    'Location Data',
                    'We collect your approximate location to enable distance-based matching. Precise GPS coordinates are never shared with other users. You can disable location access at any time in your device settings, though some features may not function correctly.',
                  ),
                  _section(
                    'Data Retention',
                    'We retain your personal data for as long as your account is active or as needed to provide services. You can request deletion of your account and associated data at any time through the app settings. We will process deletion requests within 30 days.',
                  ),
                  _section(
                    'Security',
                    'We implement industry-standard security measures including encryption in transit (TLS) and at rest, access controls, and regular security reviews. However, no method of transmission over the internet is 100% secure.',
                  ),
                  _section(
                    'Children\'s Privacy',
                    'MatchXP is not intended for users under the age of 18. We do not knowingly collect personal information from minors. If we become aware that a user is under 18, we will terminate their account and delete their data.',
                  ),
                  _section(
                    'Changes to This Policy',
                    'We may update this Privacy Policy from time to time. We will notify you of significant changes via the app or by email. Your continued use of MatchXP after the changes take effect constitutes your acceptance of the updated policy.',
                  ),
                  _section(
                    'Contact Us',
                    'If you have questions about this Privacy Policy or your personal data, please contact us at:\n\nprivacy@matchxp.app',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text('Privacy Policy',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _lastUpdated(String date) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_today_outlined,
            color: Colors.white38, size: 14),
        const SizedBox(width: 8),
        Text('Last updated: $date',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    ),
  );

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _purple,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const SizedBox(height: 10),
          Text(body,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.6)),
        ],
      ),
    ),
  );
}
