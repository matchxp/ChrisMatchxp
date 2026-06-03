import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/matchxp_background.dart';

class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({Key? key}) : super(key: key);
  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  static const _bg      = Color(0xFF0C0B11);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  final _searchController = TextEditingController();
  String _query = '';
  int? _expandedIndex;

  final List<_FaqItem> _faqs = const [
    _FaqItem(question: 'How does matching work?',
        answer: 'MatchXP shows you profiles based on your preferences (age range, distance, gender). Swipe right to like someone or left to pass. When both of you swipe right, it\'s a match and you can start chatting!',
        category: 'Matching'),
    _FaqItem(question: 'Why am I not getting matches?',
        answer: 'A few things to try:\n\n• Make sure your profile is fully complete — profiles with more photos and detailed bios get significantly more matches.\n• Check your discovery preferences — your distance or age range might be too narrow.\n• Add more photos (at least 3 is recommended).\n• Try Boost to get seen by more people temporarily.',
        category: 'Matching'),
    _FaqItem(question: 'How do I edit my profile?',
        answer: 'Go to your Profile tab and tap "Edit Profile". From there you can update your photos, bio, interests, height, and lifestyle details. Remember to save your changes when done.',
        category: 'Profile'),
    _FaqItem(question: 'Can I undo a swipe?',
        answer: 'Free users get a limited number of rewinds per day. XP+ subscribers get unlimited rewinds. Tap the yellow rewind button on the home screen to undo your last swipe.',
        category: 'Matching'),
    _FaqItem(question: 'How do I report or block someone?',
        answer: 'Open their profile and tap the three-dot menu (⋮) in the top right corner. Select "Report" or "Block". Blocked users can no longer see your profile or contact you. Reports are reviewed by our safety team within 24 hours.',
        category: 'Safety'),
    _FaqItem(question: 'Is my location shared with other users?',
        answer: 'Other users only see your approximate distance (e.g., "2 km away"), never your exact location. You can disable location access entirely in your device settings, though distance-based matching will not work.',
        category: 'Privacy'),
    _FaqItem(question: 'How do I delete my account?',
        answer: 'Go to Settings → Account Settings → Delete Account. This will permanently delete your profile, matches, and messages. This action cannot be undone. Your data will be fully removed within 30 days.',
        category: 'Account'),
    _FaqItem(question: 'What is XP+ and how do I subscribe?',
        answer: 'XP+ is our premium plan that includes unlimited likes, unlimited rewinds, the ability to see who liked you, and more. Tap "Upgrade to XP+" on your Profile tab to view pricing and subscribe.',
        category: 'Billing'),
    _FaqItem(question: 'How do I cancel my XP+ subscription?',
        answer: 'Subscriptions are managed through the App Store (iOS) or Google Play (Android). Go to your device\'s subscription settings to cancel. Cancellation takes effect at the end of your current billing period.',
        category: 'Billing'),
    _FaqItem(question: 'I found a bug — how do I report it?',
        answer: 'We\'re sorry about that! Please email us at support@matchxp.app with a description of the issue, your device model, and OS version. Screenshots are always helpful. We aim to respond within 2 business days.',
        category: 'Technical'),
  ];

  List<_FaqItem> get _filtered {
    if (_query.isEmpty) return _faqs;
    final q = _query.toLowerCase();
    return _faqs.where((f) =>
        f.question.toLowerCase().contains(q) ||
        f.answer.toLowerCase().contains(q) ||
        f.category.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _contactSupport() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Opening email to support@matchxp.app', style: GoogleFonts.outfit()),
      backgroundColor: _purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      body: MatchXPBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: _purple.withOpacity(0.42)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                        cursorColor: _purple,
                        onChanged: (v) => setState(() { _query = v; _expandedIndex = null; }),
                        decoration: InputDecoration(
                          hintText: 'Search help articles…',
                          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                          border: InputBorder.none, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () { _searchController.clear(); setState(() => _query = ''); },
                        child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                      ),
                  ]),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    if (filtered.isEmpty)
                      _emptyState()
                    else ...[
                      Text('${filtered.length} ${filtered.length == 1 ? 'result' : 'results'}',
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 10),
                      ...filtered.asMap().entries.map((e) => _faqTile(e.value, e.key)),
                    ],
                    const SizedBox(height: 28),
                    _contactCard(),
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

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text('Help Centre', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _faqTile(_FaqItem item, int index) {
    final isOpen = _expandedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expandedIndex = isOpen ? null : index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isOpen ? _purple.withOpacity(0.08) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOpen ? _purple : _purple.withOpacity(0.42),
              width: isOpen ? 1.5 : 1.0,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: _purple.withOpacity(0.4)),
                  ),
                  child: Text(item.category,
                      style: GoogleFonts.outfit(color: _purple, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.question,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w600, height: 1.3)),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isOpen ? 0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white38, size: 20),
                ),
              ]),
            ),
            if (isOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(item.answer,
                    style: GoogleFonts.outfit(color: Colors.white60,
                        fontSize: 13, height: 1.6)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      const Icon(Icons.search_off_rounded, color: Colors.white24, size: 48),
      const SizedBox(height: 12),
      Text('No results for "$_query"',
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text('Try a different keyword or contact support below.',
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12)),
    ]),
  );

  Widget _contactCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _purple.withOpacity(0.42)),
    ),
    child: Column(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: _purple.withOpacity(0.4)),
        ),
        child: const Icon(Icons.support_agent_rounded, color: _purple, size: 28),
      ),
      const SizedBox(height: 12),
      Text('Still need help?', style: GoogleFonts.outfit(color: Colors.white,
          fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Our support team usually responds\nwithin 2 business days.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, height: 1.4)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _contactSupport,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_purple, _purple2]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.email_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Contact Support', style: GoogleFonts.outfit(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );
}

class _FaqItem {
  final String question;
  final String answer;
  final String category;
  const _FaqItem({required this.question, required this.answer, required this.category});
}
