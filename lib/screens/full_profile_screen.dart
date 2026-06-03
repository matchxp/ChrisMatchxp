import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

const Map<String, String> _kLookingForEmojis = {
  'Long Term Relationship' : '💛',
  'Make New Friends'       : '👋',
  'Something Casual'       : '🌊',
  'Not Sure Yet'           : '🤷',
};

// ─────────────────────────────────────────────────────────────────────────────

class FullProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback? onLike;
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;

  const FullProfileScreen({
    super.key,
    required this.profile,
    this.onLike,
    this.onPass,
    this.onSuperLike,
  });

  @override
  State<FullProfileScreen> createState() => _FullProfileScreenState();
}

class _FullProfileScreenState extends State<FullProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Photo pager ───────────────────────────────────────────────────────────────
  final PageController _pageCtrl = PageController();
  int _photoIdx = 0;

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
  String get _religion         => _s('religion');
  String get _drink            => _s('drinking_habit');
  String get _smoke            => _s('smoking_habit');
  String get _workout          => _s('workout_habit');
  String get _pets             => _s('pets');
  List<String> get _interests     => _l('interests');
  List<String> get _lookingFor   => _l('looking_for');
  List<String> get _photoCaptions => _l('photo_captions');

  @override
  void dispose() {
    _pageCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  // ── Swipe gesture handlers ────────────────────────────────────────────────────

  void _onHorizDragStart(DragStartDetails _) {
    if (_isAnimating) return;
    setState(() => _isDragging = true);
  }

  void _onHorizDragUpdate(DragUpdateDetails d) {
    if (_isAnimating) return;
    setState(() => _dragPosition += Offset(d.delta.dx, 0));
  }

  void _onHorizDragEnd(DragEndDetails _) {
    if (_isAnimating) return;
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
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
          child: Stack(
            children: [
              _buildScrollContent(context),
              // LIKE / NOPE stamp
              if (_isDragging && _dragPosition.dx.abs() > 20)
                _buildSwipeStamp(),
              // SUPER LIKE stamp
              if (_showSuperLikeStamp) _buildSuperLikeStamp(),
              _buildStickyFooter(),
            ],
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

  // ── Scrollable content ────────────────────────────────────────────────────────

  Widget _buildScrollContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context),
        SliverToBoxAdapter(child: _buildMainContent(context)),
      ],
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    final imgs = _images;
    final nameDisplay = _name.isNotEmpty ? "$_name's Profile" : 'Profile';

    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      backgroundColor: const Color(0xD90D0618),
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 60,
      leadingWidth: 64,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: _navIconBtn(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      title: Text(
        nameDisplay,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        _navIconBtn(Icons.flag_outlined),
        const SizedBox(width: 10),
        _navIconBtn(Icons.more_vert),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // ── Hero photo / placeholder ────────────────────────────────────
            imgs.isNotEmpty
                ? PageView.builder(
                    controller: _pageCtrl,
                    itemCount: imgs.length,
                    onPageChanged: (i) => setState(() => _photoIdx = i),
                    itemBuilder: (_, i) => Image.network(
                      imgs[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _heroPHolderGradient(),
                    ),
                  )
                : _heroPHolderGradient(),

            // ── Photo dot indicators — bottom of hero ──────────────────────
            if (imgs.length > 1)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(imgs.length, (i) {
                    final active = _photoIdx == i;
                    return Row(
                      children: [
                        Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xE6FFFFFF)
                                : const Color(0x40FFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        if (i < imgs.length - 1)
                          const SizedBox(width: 5),
                      ],
                    );
                  }),
                ),
              ),


            // ── Photo caption overlay ───────────────────────────────────────
            Builder(builder: (_) {
              final captions = _photoCaptions;
              final caption  = _photoIdx < captions.length
                  ? captions[_photoIdx]
                  : '';
              if (caption.isEmpty) return const SizedBox.shrink();
              return Positioned(
                bottom: imgs.length > 1 ? 104 : 88,
                left: 16,
                right: 16,
                child: Text(
                  caption,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── Bottom fade ─────────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 180,
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
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + location ───────────────────────────────────────────────
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _name.isNotEmpty && _age > 0
                    ? '$_name, $_age'
                    : 'Profile',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4AA).withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: kAccentColor, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _buildLocationStr(),
                  style: GoogleFonts.outfit(
                      color: kTextMuted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Quick info chips ──────────────────────────────────────────────
          _buildQuickChips(),

          // ── About Me ──────────────────────────────────────────────────────
          if (_bio.isNotEmpty) ...[
            const _Divider(),
            const _SectionLabel('ABOUT ME'),
            const SizedBox(height: 8),
            Text(
              _bio,
              style: GoogleFonts.outfit(
                color: const Color(0xE0FFFFFF),
                fontSize: 15,
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kSurfaceColor,
                    border: Border.all(color: kBorderColor),
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color: kAccentColor,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],

          // ── Photos ────────────────────────────────────────────────────────
          if (_images.length > 1) ...[
            const _Divider(),
            const _SectionLabel('PHOTOS'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  _images[1],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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
            if (_photoCaptions.length > 1 && _photoCaptions[1].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Text(
                  _photoCaptions[1],
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                ),
              ),
          ],

          // ── Lifestyle ─────────────────────────────────────────────────────
          if (_drink.isNotEmpty || _smoke.isNotEmpty ||
              _workout.isNotEmpty || _pets.isNotEmpty) ...[
            const _Divider(),
            const _SectionLabel('LIFESTYLE'),
            const SizedBox(height: 10),
            _buildLifestylePills(),
          ],

          // ── Values ────────────────────────────────────────────────────────
          if (_zodiac.isNotEmpty || _religion.isNotEmpty) ...[
            const _Divider(),
            const _SectionLabel('VALUES'),
            const SizedBox(height: 10),
            _buildValuesPills(),
          ],

          // ── Looking For ───────────────────────────────────────────────────
          if (_lookingFor.isNotEmpty) ...[
            const _Divider(),
            const _SectionLabel('LOOKING FOR'),
            const SizedBox(height: 10),
            _buildLookingFor(),
          ],

          // ── Interests ─────────────────────────────────────────────────────
          if (_interests.isNotEmpty) ...[
            const _Divider(),
            const _SectionLabel('INTERESTS'),
            const SizedBox(height: 10),
            _buildInterests(),
          ],
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

  // ── Values pills ──────────────────────────────────────────────────────────────

  Widget _buildValuesPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_zodiac.isNotEmpty)
          _ValuePill(emoji: '♍', label: 'Zodiac', value: _zodiac),
        if (_religion.isNotEmpty)
          _ValuePill(emoji: '🙏', label: 'Religion', value: _religion),
      ],
    );
  }

  // ── Looking For ───────────────────────────────────────────────────────────────

  Widget _buildLookingFor() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _lookingFor
          .map((l) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kBorderColor),
                ),
                child: Text(
                  '${_kLookingForEmojis[l] ?? '💫'} $l',
                  style: GoogleFonts.outfit(
                    color: const Color(0xD9FFFFFF),
                    fontSize: 13,
                  ),
                ),
              ))
          .toList(),
    );
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
          color: kTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );
}

// ── _Divider ──────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 16),
        color: kDividerColor,
      );
}

// ── _InfoChip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kAccentColor, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: const Color(0xCCFFFFFF),
                fontSize: 12,
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
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccentColor.withOpacity(0.18),
              ),
              child: Icon(icon, color: kAccentColor, size: 14),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: const Color(0x66FFFFFF),
                    fontSize: 10,
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
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: const Color(0x66FFFFFF),
                    fontSize: 10,
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kAccentColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? Colors.white
                  : const Color(0xA6FFFFFF),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected
                    ? Colors.white
                    : const Color(0xA6FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
