import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/matchxp_background.dart';

// ── Theme constants ───────────────────────────────────────────────────────────
const kBgColor      = Color(0xFF0D0618);
const kSurfaceColor = Color(0xFF1E1035);
const kAccentColor  = Color(0xFF7C3AED);
const kBorderColor  = Color(0x407C3AED);   // rgba(124,58,237,0.25)
const kTextPrimary  = Colors.white;
const kTextMuted    = Color(0x8DFFFFFF);   // rgba(255,255,255,0.55)
const kDividerColor = Color(0x337C3AED);   // rgba(124,58,237,0.2)

// ── Interest icon map ─────────────────────────────────────────────────────────
const Map<String, IconData> _kInterestIcons = {
  'Photography' : Icons.camera_alt_rounded,
  'Coffee'      : Icons.coffee_rounded,
  'Travelling'  : Icons.flight_rounded,
  'Music'       : Icons.music_note_rounded,
  'Cooking'     : Icons.restaurant_rounded,
  'Movies'      : Icons.movie_rounded,
  'Yoga'        : Icons.self_improvement_rounded,
  'Shopping'    : Icons.shopping_bag_rounded,
  'Fitness'     : Icons.fitness_center_rounded,
  'Hiking'      : Icons.hiking_rounded,
  'Video Games' : Icons.videogame_asset_rounded,
  'Dancing'     : Icons.nightlife_rounded,
  'Wine'        : Icons.wine_bar_rounded,
  'Baking'      : Icons.cake_rounded,
  'Gardening'   : Icons.yard_rounded,
  'Swimming'    : Icons.pool_rounded,
  'Crafts'      : Icons.palette_rounded,
  'Sports'      : Icons.sports_rounded,
  'Camping'     : Icons.outdoor_grill_rounded,
  'Foodie'      : Icons.fastfood_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────

class FullProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback? onLike;
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;
  /// When true: hides superlike, flag, swipe; shows preview banner; ✕ replaces ←.
  final bool isPreview;

  const FullProfileScreen({
    super.key,
    required this.profile,
    this.onLike,
    this.onPass,
    this.onSuperLike,
    this.isPreview = false,
  });

  @override
  State<FullProfileScreen> createState() => _FullProfileScreenState();
}

class _FullProfileScreenState extends State<FullProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Hero photo index + PageController ────────────────────────────────────────
  int _photoIdx = 0;
  late final PageController _photoPageCtrl = PageController();

  // ── Hero photo area tracking (for gesture routing) ───────────────────────────
  final _heroKey             = GlobalKey();
  bool   _dragStartedInPhoto = false;
  double _photoDragDx        = 0.0;

  // ── Swipe state (mirrors home screen) ────────────────────────────────────────
  late final AnimationController _swipeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late Animation<Offset> _swipeAnim =
      AlwaysStoppedAnimation(Offset.zero);
  late Animation<double> _rotAnim =
      AlwaysStoppedAnimation(0.0);

  Offset _dragPosition        = Offset.zero;
  bool   _isDragging          = false;
  bool   _isAnimating         = false;
  bool   _showSuperLikeStamp  = false;

  // ── Safe accessors ────────────────────────────────────────────────────────────
  String _s(String key) {
    final v = widget.profile[key];
    return v is String ? v : '';
  }

  List<String> _l(String key) {
    final v = widget.profile[key];
    return v is List ? v.whereType<String>().toList() : [];
  }

  List<String> get _images     => _l('images');
  String get _name             => _s('name');
  int    get _age              => (widget.profile['age'] as num?)?.toInt() ?? 0;
  String get _location         => _s('location');
  String get _distance         => _s('distance');
  String get _bio              => _s('bio');
  String get _gender           => _s('gender');
  String get _height           => _s('height');
  String get _zodiac           => _s('zodiac');
  String get _drink            => _s('drinking_habit');
  String get _smoke            => _s('smoking_habit');
  String get _workout          => _s('workout_habit');
  String get _pets             => _s('pets');
  List<String> get _interests     => _l('interests');
  List<String> get _lookingFor   => _l('looking_for');
  List<String> get _photoCaptions   => _l('photo_captions');
  String get _featuredPhoto         => _s('featured_photo');
  String get _featuredCaption       => _s('featured_caption');

  @override
  void dispose() {
    _photoPageCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  // ── Hero photo bottom edge (global Y) ────────────────────────────────────────

  double? _heroPhotoBottom() {
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset(0, box.size.height)).dy;
  }

  // ── Photo navigation helper ───────────────────────────────────────────────────

  void _navigatePhoto(double dx) {
    final imgs = _images;
    if (imgs.length <= 1) return;
    final newIdx = (dx < 0 ? _photoIdx + 1 : _photoIdx - 1)
        .clamp(0, imgs.length - 1);
    if (newIdx == _photoIdx) return;
    setState(() => _photoIdx = newIdx);
    _photoPageCtrl.animateToPage(
      newIdx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  // Completes or snaps back a live photo drag based on how far the user dragged.
  void _completePhotoDrag() {
    if (!_photoPageCtrl.hasClients) {
      _photoDragDx = 0;
      _dragStartedInPhoto = false;
      return;
    }
    final imgs = _images;
    final page = _photoPageCtrl.page ?? _photoIdx.toDouble();
    int targetIdx;
    if (page > _photoIdx + 0.3) {
      targetIdx = (_photoIdx + 1).clamp(0, imgs.length - 1);
    } else if (page < _photoIdx - 0.3) {
      targetIdx = (_photoIdx - 1).clamp(0, imgs.length - 1);
    } else {
      targetIdx = _photoIdx;
    }
    setState(() => _photoIdx = targetIdx);
    _photoPageCtrl.animateToPage(
      targetIdx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _photoDragDx = 0;
    _dragStartedInPhoto = false;
  }

  // ── Swipe gesture handlers ────────────────────────────────────────────────────

  void _onHorizDragStart(DragStartDetails d) {
    if (_isAnimating) return;
    // Route to photo navigation if drag starts within the hero photo area.
    final photoBottom = _heroPhotoBottom();
    _dragStartedInPhoto =
        photoBottom != null && d.globalPosition.dy < photoBottom;
    _photoDragDx = 0.0;
    if (!_dragStartedInPhoto) {
      setState(() => _isDragging = true);
    }
  }

  void _onHorizDragUpdate(DragUpdateDetails d) {
    if (_isAnimating) return;
    if (_dragStartedInPhoto) {
      _photoDragDx += d.delta.dx;
      // Follow the finger in real time — swipe left increases page position.
      if (_photoPageCtrl.hasClients) {
        final sw = MediaQuery.of(context).size.width;
        final newPos = (_photoPageCtrl.position.pixels - d.delta.dx)
            .clamp(0.0, (_images.length - 1) * sw);
        _photoPageCtrl.jumpTo(newPos);
      }
      return;
    }
    setState(() => _dragPosition += Offset(d.delta.dx, 0));
  }

  void _onHorizDragEnd(DragEndDetails _) {
    if (_isAnimating) return;
    if (_dragStartedInPhoto) {
      _completePhotoDrag();
      return;
    }
    // Original card-swipe logic.
    final sw = MediaQuery.of(context).size.width;
    if (_dragPosition.dx.abs() > sw * 0.25) {
      final isLike = _dragPosition.dx > 0;
      if (isLike) {
        widget.onLike?.call();
      } else {
        widget.onPass?.call();
      }
      _animateSwipe(isLike);
    } else {
      _animateSnapBack();
    }
  }

  double _getRotation() {
    const max = 0.08;
    final sw = MediaQuery.of(context).size.width;
    return (_dragPosition.dx / sw * max).clamp(-max, max);
  }

  // ── Animations ────────────────────────────────────────────────────────────────

  Future<void> _animateSnapBack() async {
    _isAnimating = true;
    _swipeAnim = Tween<Offset>(begin: _dragPosition, end: Offset.zero)
        .animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.elasticOut));
    _rotAnim = Tween<double>(begin: _getRotation(), end: 0.0)
        .animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.elasticOut));
    setState(() => _isDragging = false);
    await _swipeCtrl.forward(from: 0);
    setState(() {
      _dragPosition = Offset.zero;
      _isAnimating  = false;
    });
    _swipeCtrl.reset();
  }

  Future<void> _animateSwipe(bool isLike) async {
    if (_isAnimating) return;
    _isAnimating = true;
    final sw  = MediaQuery.of(context).size.width;
    final endX = isLike ? sw * 1.6 : -sw * 1.6;
    _swipeAnim = Tween<Offset>(
      begin: _dragPosition,
      end: Offset(endX, _dragPosition.dy * 0.3),
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    _rotAnim = Tween<double>(
      begin: _getRotation(),
      end: isLike ? 0.3 : -0.3,
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    setState(() => _isDragging = false);
    await _swipeCtrl.forward(from: 0);
    _swipeCtrl.reset();
    HapticFeedback.lightImpact();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _animateSuperLike() async {
    if (_isAnimating) return;
    _isAnimating = true;
    final sh = MediaQuery.of(context).size.height;
    _swipeAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(0, -sh * 1.5),
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    _rotAnim = AlwaysStoppedAnimation(0.0);
    setState(() {
      _isDragging         = false;
      _showSuperLikeStamp = true;
    });
    _swipeCtrl.duration = const Duration(milliseconds: 750);
    _swipeCtrl.forward(from: 0);
    // Pop once the card is ~65% off screen — badge visible, transition feels smooth
    await Future.delayed(const Duration(milliseconds: 420));
    if (mounted) Navigator.pop(context);
  }

  // ── Button actions ────────────────────────────────────────────────────────────

  void _handlePass() {
    if (_isAnimating) return;
    HapticFeedback.lightImpact();
    _dragPosition = Offset(-MediaQuery.of(context).size.width * 0.3, 0);
    widget.onPass?.call();
    _animateSwipe(false);
  }

  void _handleLike() {
    if (_isAnimating) return;
    HapticFeedback.mediumImpact();
    _dragPosition = Offset(MediaQuery.of(context).size.width * 0.3, 0);
    widget.onLike?.call();
    _animateSwipe(true);
  }

  void _handleSuperLike() {
    if (_isAnimating) return;
    HapticFeedback.mediumImpact();
    widget.onSuperLike?.call();
    _animateSuperLike();
  }

  // ── Flag sheet ────────────────────────────────────────────────────────────────

  void _showFlagSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final displayName = _name.isNotEmpty ? _name : 'this user';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF130D1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _flagOption(
              emoji: '🚫',
              label: 'Block $displayName',
              sublabel: 'They won\'t appear in your deck again',
              color: const Color(0xFFFF3B60),
              onTap: () { Navigator.pop(context); _blockUser(); },
            ),
            const SizedBox(height: 10),
            _flagOption(
              emoji: '🚩',
              label: 'Report $displayName',
              sublabel: 'Let us know what\'s wrong',
              color: const Color(0xFFFF9500),
              onTap: () { Navigator.pop(context); _showReportSheet(); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _flagOption({
    required String emoji,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(
                    color: color, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sublabel, style: GoogleFonts.outfit(
                    color: Colors.white38, fontSize: 12)),
              ],
            )),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 20),
          ]),
        ),
      );

  // ── Block ─────────────────────────────────────────────────────────────────────

  Future<void> _blockUser() async {
    HapticFeedback.mediumImpact();
    final currentId   = Supabase.instance.client.auth.currentUser?.id;
    final blockedId   = widget.profile['id'] as String?;
    final displayName = _name.isNotEmpty ? _name : 'User';

    // Persist block in the background — don't await so dismissal is instant
    if (currentId != null && blockedId != null) {
      Supabase.instance.client.from('blocks').upsert({
        'blocker_id': currentId,
        'blocked_id': blockedId,
        'created_at': DateTime.now().toIso8601String(),
      }).catchError((_) {});
    }

    if (!mounted) return;

    // Show snack on the previous screen after pop
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$displayName has been blocked.',
          style: GoogleFonts.outfit()),
      backgroundColor: const Color(0xFF1A1228),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    // Trigger pass callback so deck removes the card, then animate away
    widget.onPass?.call();
    _animateSwipe(false);
  }

  // ── Report ────────────────────────────────────────────────────────────────────

  void _showReportSheet() {
    final displayName = _name.isNotEmpty ? _name : 'this user';
    String? _selectedReason;

    const reasons = [
      'Inappropriate photos',
      'Fake profile',
      'Harassment or abuse',
      'Spam or scam',
      'Underage user',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C0B11),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text('Report $displayName',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('What\'s going on?',
                  style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.50),
                      fontSize: 14,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 24),
              // Reason pills — wrap layout like onboarding
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: reasons.map((reason) {
                  final selected = _selectedReason == reason;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setSheet(() => _selectedReason = reason);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccentColor.withOpacity(0.12)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: selected
                              ? kAccentColor
                              : kAccentColor.withOpacity(0.42),
                          width: selected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(reason,
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(
                                  color: kAccentColor,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              // Submit button — purple gradient pill
              GestureDetector(
                onTap: _selectedReason == null
                    ? null
                    : () { Navigator.pop(ctx); _submitReport(_selectedReason!); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: _selectedReason != null
                        ? const LinearGradient(
                            colors: [kAccentColor, Color(0xFF9D50BB)])
                        : null,
                    color: _selectedReason == null
                        ? Colors.white.withOpacity(0.08)
                        : null,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: _selectedReason != null
                        ? [BoxShadow(
                            color: kAccentColor.withOpacity(0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6))]
                        : [],
                  ),
                  child: Text('Submit Report',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: _selectedReason != null
                              ? Colors.white
                              : Colors.white30,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    HapticFeedback.mediumImpact();
    final currentId   = Supabase.instance.client.auth.currentUser?.id;
    final reportedId  = widget.profile['id'] as String?;
    final displayName = _name.isNotEmpty ? _name : 'User';

    if (currentId != null && reportedId != null) {
      try {
        await Supabase.instance.client.from('reports').insert({
          'reporter_id': currentId,
          'reported_id': reportedId,
          'reason':      reason,
          'created_at':  DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Report submitted. Thanks for keeping MatchXP safe.',
            style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF1A1228),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final contentStack = Stack(
      children: [
        _buildScrollContent(context),
        // LIKE / NOPE stamp — hidden in preview
        if (!widget.isPreview && _isDragging && _dragPosition.dx.abs() > 20)
          _buildSwipeStamp(),
        // SUPER LIKE stamp — hidden in preview
        if (!widget.isPreview && _showSuperLikeStamp) _buildSuperLikeStamp(),
        // Superlike footer button — hidden in preview
        if (!widget.isPreview) _buildStickyFooter(),
        // Preview banner — shown only in preview
        if (widget.isPreview) _buildPreviewBanner(),
      ],
    );

    return Scaffold(
      backgroundColor: kBgColor,
      extendBodyBehindAppBar: true,
      body: MatchXPBackground(
        child: widget.isPreview
            // Preview: no swipe gestures
            ? contentStack
            : GestureDetector(
                onHorizontalDragStart: _onHorizDragStart,
                onHorizontalDragUpdate: _onHorizDragUpdate,
                onHorizontalDragEnd: _onHorizDragEnd,
                child: AnimatedBuilder(
                  animation: _swipeCtrl,
                  builder: (_, child) {
                    final offset = _isAnimating ? _swipeAnim.value : _dragPosition;
                    final angle  = _isAnimating ? _rotAnim.value  : _getRotation();
                    return Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle: angle,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    );
                  },
                  child: contentStack,
                ),
              ),
      ),
    );
  }

  // ── Swipe stamp overlay ───────────────────────────────────────────────────────

  Widget _buildSuperLikeStamp() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF7C3AED), width: 4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'SUPER LIKE',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7C3AED),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeStamp() {
    final isLike = _dragPosition.dx > 0;
    final color  = isLike ? const Color(0xFF00D4AA) : const Color(0xFFFF3B60);
    final label  = isLike ? 'LIKE' : 'NOPE';
    final sw     = MediaQuery.of(context).size.width;
    final opacity = (_dragPosition.dx.abs() / 80).clamp(0.0, 1.0);

    return Positioned(
      top: 120,
      left:  isLike ? 40 : null,
      right: isLike ? null : 40,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: isLike ? -0.3 : 0.3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Scrollable content — photo extends full-bleed, buttons float over it ─────

  Widget _buildScrollContent(BuildContext context) {
    return Stack(
      children: [
        // Scroll content: hero photo + main sections — no SliverAppBar
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroPhoto()),
            SliverToBoxAdapter(child: _buildMainContent(context)),
          ],
        ),

        // Floating buttons overlay — transparent background, photo shows through
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: _navIconBtn(
                    widget.isPreview
                        ? Icons.close_rounded
                        : Icons.arrow_back_ios_new_rounded,
                  ),
                ),
                const Spacer(),
                // Flag hidden in preview — can't report yourself
                if (!widget.isPreview)
                  GestureDetector(
                    onTap: () => _showFlagSheet(context),
                    child: _navIconBtn(Icons.flag_outlined),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero photo — natural aspect ratio, tap left/right to advance ─────────────

  Widget _buildHeroPhoto() {
    final imgs     = _images;
    final captions = _photoCaptions;

    if (imgs.isEmpty) {
      return Container(
        key: _heroKey,
        width: double.infinity,
        height: 480,
        child: _heroPHolderGradient(),
      );
    }

    final url     = imgs[_photoIdx];
    final caption = _photoIdx < captions.length ? captions[_photoIdx] : '';

    return Container(
      key: _heroKey,
      color: kBgColor, // prevents any white bleed between photo and content below
      child: GestureDetector(
      onTapUp: (details) {
        if (imgs.length <= 1) return;
        final goNext = details.localPosition.dx > MediaQuery.of(context).size.width / 2;
        _navigatePhoto(goNext ? -1 : 1);
      },
      // Preview mode: no outer card-swipe detector, so handle drag directly.
      onHorizontalDragUpdate: widget.isPreview
          ? (details) {
              _photoDragDx += details.delta.dx;
              if (_photoPageCtrl.hasClients) {
                final sw = MediaQuery.of(context).size.width;
                final newPos = (_photoPageCtrl.position.pixels - details.delta.dx)
                    .clamp(0.0, (_images.length - 1) * sw);
                _photoPageCtrl.jumpTo(newPos);
              }
            }
          : null,
      onHorizontalDragEnd: widget.isPreview
          ? (_) => _completePhotoDrag()
          : null,
      child: Stack(
        children: [
          // PageView tracks the finger in real time via PageController.jumpTo.
          // NeverScrollableScrollPhysics disables its own gesture handling so
          // our gesture routing stays in control.
          SizedBox(
            width: double.infinity,
            height: 480,
            child: PageView.builder(
              controller: _photoPageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: imgs.length,
              onPageChanged: (idx) => setState(() => _photoIdx = idx),
              itemBuilder: (_, i) => Image.network(
                imgs[i],
                width: double.infinity,
                height: 480,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _heroPHolderGradient(),
              ),
            ),
          ),

          // Dot indicators
          if (imgs.length > 1)
            Positioned(
              bottom: 80, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(imgs.length, (i) {
                  final active = _photoIdx == i;
                  return Row(children: [
                    Container(
                      width: 28, height: 3,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xE6FFFFFF)
                            : const Color(0x40FFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (i < imgs.length - 1) const SizedBox(width: 5),
                  ]);
                }),
              ),
            ),

          // Caption overlay
          if (caption.isNotEmpty)
            Positioned(
              bottom: imgs.length > 1 ? 100 : 84,
              left: 16, right: 16,
              child: Text(
                caption,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),

          // Bottom fade into content
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kBgColor, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    ),    // GestureDetector
    );    // Container(_heroKey)
  }

  Widget _heroPHolderGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF251248), Color(0xFF0D0618)],
          ),
        ),
      );

  Widget _navIconBtn(IconData icon) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x990D0618),
          border: Border.all(color: kAccentColor.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      );

  // ── Main content ──────────────────────────────────────────────────────────────

  Widget _buildMainContent(BuildContext context) {
    final imgs     = _images;
    final captions = _photoCaptions;
    final c        = <Widget>[];

    // Helper — builds a full-width photo card for a given index.
    Widget photoCard(int i) {
      final caption = i < captions.length ? captions[i] : '';
      return _interleavePhoto(imgs[i], caption);
    }

    // ── 2. Bio — name, age, online dot, location, chips ──────────────────────
    c.add(const SizedBox(height: 8));
    c.add(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _name.isNotEmpty && _age > 0 ? '$_name, $_age' : 'Profile',
          style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 38, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF00D4AA),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFF00D4AA).withOpacity(0.6),
                  blurRadius: 8, spreadRadius: 1),
            ],
          ),
        ),
      ],
    ));
    c.add(const SizedBox(height: 6));
    c.add(Row(children: [
      const Icon(Icons.location_on, color: kAccentColor, size: 14),
      const SizedBox(width: 5),
      Expanded(child: Text(_buildLocationStr(),
          style: GoogleFonts.outfit(color: kTextMuted, fontSize: 13))),
    ]));
    c.add(const SizedBox(height: 14));
    c.add(_buildQuickChips());

    if (_bio.isNotEmpty) {
      c.addAll([
        const _Divider(),
        const _SectionLabel('ABOUT ME'),
        const SizedBox(height: 8),
        Text(_bio, style: GoogleFonts.outfit(
            color: const Color(0xE0FFFFFF), fontSize: 15,
            fontWeight: FontWeight.w300, height: 1.6)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: kSurfaceColor, border: Border.all(color: kBorderColor)),
              child: const Icon(Icons.favorite_border, color: kAccentColor, size: 14),
            ),
          ),
        ),
      ]);
    }

    // ── 3. Lifestyle ─────────────────────────────────────────────────────────
    if (_drink.isNotEmpty || _smoke.isNotEmpty ||
        _workout.isNotEmpty || _pets.isNotEmpty) {
      c.addAll([
        const _Divider(),
        const _SectionLabel('LIFESTYLE'),
        const SizedBox(height: 10),
        _buildLifestylePills(),
      ]);
    }

    // ── 4. Photos 2 + 3 (indices 1 and 2) ────────────────────────────────────
    if (imgs.length > 1) c.add(photoCard(1));
    if (imgs.length > 2) c.add(photoCard(2));

    // ── 5. Interests ─────────────────────────────────────────────────────────
    if (_interests.isNotEmpty) {
      c.addAll([
        const _Divider(),
        const _SectionLabel('INTERESTS'),
        const SizedBox(height: 10),
        _buildInterests(),
      ]);
    }

    // ── 6. Remaining photos (4th onwards, indices 3+) ─────────────────────────
    for (int i = 3; i < imgs.length; i++) {
      c.add(photoCard(i));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: c),
    );
  }

  // ── Interleaved photo card ─────────────────────────────────────────────────────

  Widget _interleavePhoto(String url, String caption) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            // No height constraint — image renders at its natural aspect ratio
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, __, ___) => AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF251248), Color(0xFF0D0618)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 2),
              child: Text(
                caption,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w300,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Quick info chips ──────────────────────────────────────────────────────────

  Widget _buildQuickChips() {
    final chips = <Widget>[
      if (_height.isNotEmpty)
        _InfoChip(icon: Icons.straighten_rounded, label: _height),
      if (_gender.isNotEmpty)
        _InfoChip(icon: Icons.wc_rounded, label: _gender),
      if (_zodiac.isNotEmpty)
        _InfoChip(icon: Icons.auto_awesome_rounded, label: _zodiac),
      if (_lookingFor.isNotEmpty)
        _InfoChip(
            icon: Icons.favorite_border_rounded,
            label: _lookingFor.first),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 7, runSpacing: 7, children: chips);
  }

  // ── Lifestyle pills ───────────────────────────────────────────────────────────

  Widget _buildLifestylePills() {
    final pills = <Widget>[
      if (_drink.isNotEmpty)
        _LifestylePill(
            icon: Icons.wine_bar_rounded,
            label: 'Drinks',
            value: _drink),
      if (_smoke.isNotEmpty)
        _LifestylePill(
            icon: Icons.smoking_rooms_rounded,
            label: 'Smoking',
            value: _smoke),
      if (_workout.isNotEmpty)
        _LifestylePill(
            icon: Icons.fitness_center_rounded,
            label: 'Works out',
            value: _workout),
      if (_pets.isNotEmpty)
        _LifestylePill(
            icon: Icons.pets_rounded,
            label: 'Pets',
            value: _pets),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: pills);
  }

  // ── Interests ─────────────────────────────────────────────────────────────────

  Widget _buildInterests() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _interests.map((interest) {
        final icon = _kInterestIcons[interest] ?? Icons.star_rounded;
        return _InterestTag(
          label: interest,
          icon: icon,
          selected: true, // all user interests are "selected"
        );
      }).toList(),
    );
  }

  // ── Location string ───────────────────────────────────────────────────────────

  String _buildLocationStr() {
    if (_location.isEmpty) return '';
    if (_distance.isNotEmpty) return '$_location · $_distance';
    return _location;
  }

  // ── Preview banner ────────────────────────────────────────────────────────────

  Widget _buildPreviewBanner() {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // Sit below the ✕ nav row (~34px button + 4px top padding + 8px gap)
          padding: const EdgeInsets.only(top: 50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_outlined,
                    color: Colors.white60, size: 13),
                const SizedBox(width: 6),
                Text(
                  'This is how others see you',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sticky footer ─────────────────────────────────────────────────────────────

  Widget _buildStickyFooter() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _handleSuperLike,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3FE8).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFF6C3FE8),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═════════════════════════════════════════════════════════════════════════════

// ── _SectionLabel ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
}

// ── _Divider ──────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 20),
        color: Colors.white.withOpacity(0.08),
      );
}

// ── _InfoChip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: kAccentColor.withOpacity(0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kAccentColor, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}

// ── _LifestylePill ────────────────────────────────────────────────────────────

class _LifestylePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LifestylePill(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: kAccentColor.withOpacity(0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kAccentColor, size: 15),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── _ValuePill ────────────────────────────────────────────────────────────────

class _ValuePill extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _ValuePill(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: kAccentColor.withOpacity(0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── _InterestTag ──────────────────────────────────────────────────────────────

class _InterestTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  const _InterestTag(
      {required this.label, required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: kAccentColor.withOpacity(0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ── _ActionButton ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kSurfaceColor,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      );
}
