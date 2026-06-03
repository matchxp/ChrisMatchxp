import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../widgets/matchxp_background.dart';

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

class MatchesScreenPremium extends StatefulWidget {
  const MatchesScreenPremium({Key? key}) : super(key: key);

  @override
  State<MatchesScreenPremium> createState() => _MatchesScreenPremiumState();
}

class _MatchesScreenPremiumState extends State<MatchesScreenPremium> {
  bool _showUpgradeModal = false;

  final List<Map<String, dynamic>> likesYou = [
    {
      'name': 'Emma',
      'age': 24,
      'image': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      'timeAgo': '2 hours ago',
    },
    {
      'name': 'Sasha',
      'age': 26,
      'image': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      'timeAgo': '5 hours ago',
    },
    {
      'name': 'Olivia',
      'age': 27,
      'image': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400',
      'timeAgo': '1 day ago',
    },
    {
      'name': 'Sophie',
      'age': 23,
      'image': 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400',
      'timeAgo': '1 day ago',
    },
    {
      'name': 'Isabella',
      'age': 27,
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      'timeAgo': '2 days ago',
    },
    {
      'name': 'Mia',
      'age': 24,
      'image': 'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400',
      'timeAgo': '3 days ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0C0B11),
      child: MatchXPBackground(
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header with top-left logo ──────────────────────────
                  Builder(builder: (context) {
                    final topPad = MediaQuery.of(context).viewPadding.top + 12;
                    return SizedBox(height: topPad + 22 + 16); // status bar + logo height + bottom pad
                  }),
                  // ── Scrollable content ─────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          // Premium Banner
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _showUpgradeModal = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C3FE8).withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unlock Premium',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'See all 6 likes and much more!',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // People counter
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${likesYou.length} people like you',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Blurred profiles grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: likesYou.length,
                            itemBuilder: (context, index) {
                              return _buildBlurredProfileCard(likesYou[index]);
                            },
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Upgrade Modal
              if (_showUpgradeModal)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showUpgradeModal = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {}, // Prevent dismissal when tapping modal
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
                                      onTap: () {
                                        setState(() {
                                          _showUpgradeModal = false;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Premium Icon
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
                                    child: const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 60,
                                    ),
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
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 32),

                                  // Features list
                                  _buildFeature(Icons.visibility, 'See who likes you'),
                                  _buildFeature(Icons.favorite, 'Unlimited likes'),
                                  _buildFeature(Icons.star, '5 Super Likes per day'),
                                  _buildFeature(Icons.location_on, 'Change your location'),
                                  _buildFeature(Icons.undo, 'Rewind unlimited'),
                                  _buildFeature(Icons.verified_user, 'Priority support'),
                                  const SizedBox(height: 24),

                                  // Pricing options
                                  _buildPricingOption(
                                    title: '6 Months',
                                    price: '\$59.99',
                                    perMonth: '\$10/month',
                                    badge: 'SAVE 50%',
                                    isPopular: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPricingOption(
                                    title: '12 Months',
                                    price: '\$89.99',
                                    perMonth: '\$7.50/month',
                                    badge: 'BEST VALUE',
                                    isPopular: false,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPricingOption(
                                    title: '1 Month',
                                    price: '\$19.99',
                                    perMonth: '',
                                    badge: '',
                                    isPopular: false,
                                  ),
                                  const SizedBox(height: 24),

                                  // Continue button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Payment integration coming soon!',
                                              style: GoogleFonts.outfit(),
                                            ),
                                            backgroundColor: const Color(0xFF6C3FE8),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            'CONTINUE',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Cancel anytime. Terms apply.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
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
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredProfileCard(Map<String, dynamic> profile) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _showUpgradeModal = true;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred image
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Image.network(
                  profile['image'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                        child: Icon(Icons.person, size: 60, color: Colors.white24),
                      ),
                    );
                  },
                ),
              ),

              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),

              // Lock icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              // Profile info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${profile['name']}, ${profile['age']}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile['timeAgo'],
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingOption({
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
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (badge.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
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
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            price,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
