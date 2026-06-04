// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Result Screen
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/rps_models.dart';
import '../rps_theme.dart';
import '../widgets/rps_widgets.dart';
import '../../game_hub_screen.dart';

class RPSResultScreen extends StatefulWidget {
  const RPSResultScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.opponentId,
    required this.opponentName,
    required this.myMove,
    required this.opponentMove,
    required this.result,
    required this.onChatUnlocked,
    this.sessionId,
    this.popCount = 1,
    this.chatAlreadyUnlocked = false,
    required this.matchId,
    required this.partnerUserId,
    required this.partnerName,
  });

  final String currentUserId;
  final String currentUserName;
  final String opponentId;
  final String opponentName;
  final RPSMove myMove;
  final RPSMove opponentMove;
  final RPSResult result;
  final VoidCallback onChatUnlocked;
  final String? sessionId;
  final int popCount;
  final bool chatAlreadyUnlocked;
  final String matchId;
  final String partnerUserId;
  final String partnerName;

  @override
  State<RPSResultScreen> createState() => _RPSResultScreenState();
}

class _RPSResultScreenState extends State<RPSResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _titleCtrl;
  late final Animation<double> _titleFloat;
  late final AnimationController _movesCtrl;
  late final Animation<double> _movesFloat;
  late final ConfettiController _confetti;

  String _myPhotoUrl = '';
  String _opponentPhotoUrl = '';

  String _toPublicUrl(String url) {
    final regex = RegExp(r'(https?://[^/]+/storage/v1/object/)(?:public|sign)/([^?]+)');
    final match = regex.firstMatch(url);
    if (match != null) return '${match.group(1)}public/${match.group(2)}';
    return url;
  }

  Future<void> _fetchAvatars() async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, photos')
          .inFilter('id', [widget.currentUserId, widget.opponentId]);
      for (final row in (rows as List)) {
        final id = row['id'] as String;
        final photos = row['photos'];
        final url = (photos is List && photos.isNotEmpty)
            ? _toPublicUrl(photos[0] as String)
            : '';
        if (!mounted) return;
        if (id == widget.currentUserId) setState(() => _myPhotoUrl = url);
        if (id == widget.opponentId) setState(() => _opponentPhotoUrl = url);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchAvatars();

    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _titleFloat = Tween<double>(begin: 0, end: -10)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeInOut));

    _movesCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _movesFloat = Tween<double>(begin: 0, end: -10)
        .animate(CurvedAnimation(parent: _movesCtrl, curve: Curves.easeInOut));

    _confetti = ConfettiController(duration: const Duration(seconds: 1));
    if (widget.result == RPSResult.win) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _movesCtrl.dispose();
    _confetti.dispose();
    super.dispose();
  }

  RPSMove get myMove => widget.myMove;
  RPSMove get oppMove => widget.opponentMove;
  RPSResult get result => widget.result;

  bool get iWin => result == RPSResult.win;
  bool get isDraw => result == RPSResult.draw;
  bool get iLose => result == RPSResult.lose;

  String get outcomeText {
    if (iWin) return 'You Win';
    if (isDraw) return "It's a Draw";
    return 'You Lose';
  }

  String get subtitleText {
    if (iWin) return myMove.beatsLabel;
    if (isDraw) return 'Great minds think alike';
    return oppMove.beatsLabel;
  }

  void _startChat() {
    int pops = 0;
    Navigator.of(context).popUntil((_) => pops++ >= widget.popCount);
    widget.onChatUnlocked();
  }

  // ── EC-style primary button ───────────────────────────────
  Widget _primaryBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xFF6930C3),
              Color(0xFF8B5CF6),
              Color(0xFFA78BFA),
              Color(0xFF7C3AED),
            ]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ),
      ),
    );
  }

  // ── EC-style ghost button ─────────────────────────────────
  Widget _ghostBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0x66AB5CF5), width: 1.5),
        ),
        child: Text(label,
            style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC4A8FF))),
      ),
    );
  }

  // ── Avatar with crown ─────────────────────────────────────
  Widget _buildAvatar({
    required String photoUrl,
    required String label,
    required bool showCrown,
    required bool isWinner,
    required Color glowColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            if (showCrown)
              const Positioned(
                top: -40,
                child: Text('👑', style: TextStyle(fontSize: 40)),
              ),
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Border always shown — glowing for winner, dim for loser
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isWinner
                          ? [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ]
                          : null,
                      border: Border.all(
                        color: isWinner
                            ? glowColor.withValues(alpha: 0.9)
                            : glowColor.withValues(alpha: 0.3),
                        width: 2.5,
                      ),
                    ),
                  ),
                  // Avatar photo or initial
                  ClipOval(
                    child: Container(
                      width: 96,
                      height: 96,
                      color: const Color(0xFF2A1A4E),
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarInitial(label),
                            )
                          : _avatarInitial(label),
                    ),
                  ),
                  // Dim overlay for loser
                  if (!isWinner && !isDraw)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: (!isWinner && !isDraw) ? Colors.white38 : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _avatarInitial(String name) => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RPSBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti on win
              if (iWin)
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confetti,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 60,
                   colors: const [
                      Colors.white,
                      Color(0xFFAB5CF5),
                      Color(0xFF7C3AED),
                      Color(0xFF4C1D95),
                      Color(0xFFDDD6FE),
                      Color(0xFF6930C3),
                    ],
                    child: const SizedBox.shrink(),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
                child: Column(
                  children: [
                    RPSNavBar(onBack: () => Navigator.pop(context)),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 45),

                            // ── Floating gradient title ───────────
                            AnimatedBuilder(
                              animation: _titleFloat,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _titleFloat.value),
                                child: child,
                              ),
                              child: ShaderMask(
                                shaderCallback: (b) => LinearGradient(
                                  colors: iWin
                                      ? [
                                          const Color(0xFFFFD700),
                                          const Color(0xFFFFF0A0),
                                          const Color(0xFFFFD700),
                                        ]
                                      : [
                                          const Color(0xFFC084FC),
                                          Colors.white,
                                          const Color(0xFFC084FC),
                                        ],
                                ).createShader(b),
                                child: Text(
                                  outcomeText,
                                  textAlign: TextAlign.center,
                                  style: RPSTheme.font(40,
                                      fw: FontWeight.w800),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Subtitle ──────────────────────────
                            AnimatedBuilder(
                              animation: _titleFloat,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _titleFloat.value),
                                child: child,
                              ),
                              child: Text(
                                subtitleText,
                                textAlign: TextAlign.center,
                                style: RPSTheme.font(15,
                                    fw: FontWeight.w700,
                                    color: const Color(0xFFDBD9E0)),
                              ),
                            ),

                            const SizedBox(height: 70),

                            // ── Avatars with crowns ───────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAvatar(
                                  photoUrl: _myPhotoUrl,
                                  label: 'You',
                                  showCrown: iWin || isDraw,
                                  isWinner: iWin || isDraw,
                                  glowColor: const Color(0xFFAB5CF5),
                                ),
                                const SizedBox(width: 110),
                                _buildAvatar(
                                  photoUrl: _opponentPhotoUrl,
                                  label: widget.opponentName,
                                  showCrown: iLose || isDraw,
                                  isWinner: iLose || isDraw,
                                  glowColor: const Color(0xFF00E5FF),
                                ),
                              ],
                            ),

                            const SizedBox(height: 45),

                            // ── Move emojis with VS in middle ─────
                              AnimatedBuilder(
                              animation: _movesFloat,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _movesFloat.value),
                                child: child,
                              ),
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    Text(myMove.emoji,
                                        style: const TextStyle(fontSize: 65)),
                                    const SizedBox(height: 10),
                                    Text(
                                      myMove.labelUpper,
                                      style: RPSTheme.font(13,
                                          fw: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: iWin || isDraw
                                              ? const Color.fromARGB(255, 255, 255, 255)
                                              : RPSTheme.muted),
                                      
                                    ),
                                  ],
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 60),
                                  child: Text(
                                    'VS',
                                    style: RPSTheme.font(18,
                                        fw: FontWeight.w700,
                                        color: RPSTheme.muted),
                                  ),
                                ),

                                Column(
                                  children: [
                                    Text(oppMove.emoji,
                                        style: const TextStyle(fontSize: 65)),
                                    const SizedBox(height: 6),
                                    Text(
                                      oppMove.labelUpper,
                                      style: RPSTheme.font(13,
                                          fw: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: iLose || isDraw
                                              ? const Color.fromARGB(255, 255, 255, 255)
                                              : const Color.fromARGB(255, 253, 253, 253)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ), // AnimatedBuilder closes here

                            const SizedBox(height: 100),

                            // ── Buttons ───────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40),
                              child: _primaryBtn(
                                widget.chatAlreadyUnlocked
                                    ? 'Continue Chatting'
                                    : 'Start Chatting',
                                _startChat,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40),
                              child: _ghostBtn('Play Again', () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => GameHubScreen(
                                      matchId: widget.matchId,
                                      currentUserId: widget.currentUserId,
                                      partnerUserId: widget.partnerUserId,
                                      partnerName: widget.partnerName,
                                      chatAlreadyUnlocked: widget.chatAlreadyUnlocked,
                                      onChatUnlocked: widget.onChatUnlocked,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}