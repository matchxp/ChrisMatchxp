import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'full_profile_screen.dart';
import 'preferences_screen.dart';
import '../services/matching_service.dart';
import '../services/auth_service.dart';
import '../games/game_hub_screen.dart';
import '../widgets/matchxp_background.dart';
import 'main_navigation.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _swipeAnimationController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _nextCardScaleAnimation;
  late Animation<Offset> _snapBackAnimation;

  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;
  bool _showSuperLikeStamp = false;
  bool _isAnimating = false;
  int _currentProfileIndex = 0;

  // Real profiles loaded from Supabase
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Match popup — rendered via root Overlay so it layers above the nav bar
  OverlayEntry? _matchOverlayEntry;
  Map<String, dynamic>? _matchedCardProfile;
  String? _matchedMatchId;
  String? _matchedPartnerUserId;
  String? _myPhoto;
  late AnimationController _matchAnimController;

  final MatchingService _matchingService = MatchingService();

  @override
  void initState() {
    super.initState();

    _swipeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _matchAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resetAnimations();
    _loadProfiles();
    _loadMyPhoto();
  }

  Future<void> _loadMyPhoto() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ??
        AuthService().getCurrentUserId();
    if (currentUserId == null) return;
    final profile = await _matchingService.getProfileById(currentUserId);
    if (!mounted || profile == null) return;
    final images = _getAllImages(profile);
    setState(() => _myPhoto = images.isNotEmpty ? images.first : null);
  }

  void _resetAnimations() {
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_swipeAnimationController);

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(_swipeAnimationController);

    _nextCardScaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeOut,
    ));

    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_swipeAnimationController);
  }

  /// Fetch real profiles from Supabase via MatchingService.
  /// [resetMode] = true → refresh after seeing everyone; only excludes matched users.
  Future<void> _loadProfiles({bool resetMode = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final profiles = await _matchingService
          .getDiscoverProfiles(limit: 20, onlyExcludeMatched: resetMode)
          .timeout(const Duration(seconds: 15), onTimeout: () => []);
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _currentProfileIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load profiles: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Load more profiles when the stack is running low
  Future<void> _loadMoreIfNeeded() async {
    final remaining = _profiles.length - _currentProfileIndex;
    if (remaining <= 3 && !_isLoading) {
      final more = await _matchingService.getDiscoverProfiles(limit: 20);
      if (more.isNotEmpty && mounted) {
        setState(() {
          _profiles.addAll(more);
        });
      }
    }
  }

  @override
  void dispose() {
    _matchOverlayEntry?.remove();
    _matchOverlayEntry = null;
    _swipeAnimationController.dispose();
    _matchAnimController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() => _dragPosition += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;

    // Tap detection
    if (_dragPosition.dx.abs() < 10 && _dragPosition.dy.abs() < 10) {
      final currentProfile = _profiles[_currentProfileIndex];
      setState(() {
        _dragPosition = Offset.zero;
        _isDragging = false;
      });
      _openProfile(currentProfile);
      return;
    }

    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Upward swipe → super like
    if (_dragPosition.dy < -screenHeight * 0.18 &&
        _dragPosition.dx.abs() < screenWidth * 0.25) {
      _animateSuperLike();
      return;
    }

    // Horizontal swipe → like or pass
    if (_dragPosition.dx.abs() > screenWidth * 0.25) {
      final isLike = _dragPosition.dx > 0;
      _saveSwipeAction(isLike);
      _animateSwipe(isLike);
    } else {
      _animateSnapBack();
    }
  }

  /// Saves a like or pass to Supabase and triggers the match popup if matched.
  void _saveSwipeAction(bool isLike) {
    if (_profiles.isEmpty || _currentProfileIndex >= _profiles.length) return;
    final profile = _profiles[_currentProfileIndex];
    if (isLike) {
      _matchingService.likeProfile(profile['id'] as String).then((matchId) {
        if (matchId != null && mounted) {
          _triggerMatchPopup(
            _toCardProfile(profile),
            matchId: matchId,
            partnerUserId: profile['id'] as String,
          );
        }
      });
    } else {
      _matchingService.passProfile(profile['id'] as String);
    }
  }

  /// Shows the "It's a Match!" overlay.
  void _triggerMatchPopup(
    Map<String, dynamic> cardProfile, {
    required String matchId,
    required String partnerUserId,
  }) {
    // Remove any existing popup before inserting a new one so we don't leak
    // a stuck entry when two matches arrive before the first is dismissed.
    _matchOverlayEntry?.remove();
    _matchOverlayEntry = null;

    // Tell MainNavigation not to show a banner for this match — User B already
    // sees the full popup, so the poll banner would be redundant.
    MainNavigation.suppressBannerFor(matchId);

    setState(() {
      _matchedCardProfile = cardProfile;
      _matchedMatchId = matchId;
      _matchedPartnerUserId = partnerUserId;
    });
    _matchAnimController.forward(from: 0);
    HapticFeedback.heavyImpact();
    _matchOverlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(child: _buildMatchPopup()),
    );
    Navigator.of(context, rootNavigator: true)
        .overlay
        ?.insert(_matchOverlayEntry!);
  }

  void _closeMatchPopup() {
    _matchOverlayEntry?.remove();
    _matchOverlayEntry = null;
    setState(() {
      _matchedCardProfile = null;
      _matchedMatchId = null;
      _matchedPartnerUserId = null;
    });
    _matchAnimController.reverse();
  }

  void _animateSnapBack() async {
    _isAnimating = true;

    _snapBackAnimation = Tween<Offset>(
      begin: _dragPosition,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.elasticOut,
    ));

    setState(() => _isDragging = false);
    _swipeAnimation = _snapBackAnimation;

    await _swipeAnimationController.forward(from: 0);

    setState(() {
      _dragPosition = Offset.zero;
      _isAnimating = false;
    });
    _resetAnimations();
    _swipeAnimationController.reset();
  }

  void _animateSwipe(bool isLike) async {
    if (_isAnimating) return;
    _isAnimating = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final endX = isLike ? screenWidth * 1.5 : -screenWidth * 1.5;

    _swipeAnimation = Tween<Offset>(
      begin: _dragPosition,
      end: Offset(endX, _dragPosition.dy * 0.3),
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _getRotation(),
      end: isLike ? 0.3 : -0.3,
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeOut,
    ));

    setState(() => _isDragging = false);

    await _swipeAnimationController.forward(from: 0);

    _resetAnimations();
    _swipeAnimationController.reset();

    setState(() {
      _currentProfileIndex++;
      _dragPosition = Offset.zero;
      _isAnimating = false;
    });

    // Load more profiles when stack is running low
    _loadMoreIfNeeded();

    HapticFeedback.lightImpact();
  }

  double _getRotation() {
    const maxRotation = 0.08;
    final rotation =
        (_dragPosition.dx / MediaQuery.of(context).size.width) * maxRotation;
    return rotation.clamp(-maxRotation, maxRotation);
  }

  /// Save like to Supabase and trigger swipe animation
  void _handleLike() {
    if (_isDragging || _isAnimating || _profiles.isEmpty) return;
    _dragPosition = Offset(MediaQuery.of(context).size.width * 0.3, 0);
    _saveSwipeAction(true);
    _animateSwipe(true);
  }

  /// Save pass to Supabase and trigger swipe animation
  void _handlePass() {
    if (_isDragging || _isAnimating || _profiles.isEmpty) return;
    _dragPosition = Offset(-MediaQuery.of(context).size.width * 0.3, 0);
    _saveSwipeAction(false);
    _animateSwipe(false);
  }

  /// Star button — set up starting offset then delegate to shared animation.
  void _handleSuperLike() {
    if (_isDragging || _isAnimating || _profiles.isEmpty) return;
    HapticFeedback.mediumImpact();
    _dragPosition = Offset.zero; // button starts from rest
    _animateSuperLike();
  }

  /// Shared super-like animation — works for both gesture and button.
  Future<void> _animateSuperLike() async {
    if (_isAnimating) return;
    _isAnimating = true;

    final profile = _profiles[_currentProfileIndex];
    _matchingService.superLikeProfile(profile['id'] as String).then((matchId) {
      if (matchId != null && mounted) {
        _triggerMatchPopup(
          _toCardProfile(profile),
          matchId: matchId,
          partnerUserId: profile['id'] as String,
        );
      }
    });

    final screenHeight = MediaQuery.of(context).size.height;

    _swipeAnimation = Tween<Offset>(
      begin: _dragPosition, // continues from wherever the drag left off
      end: Offset(0, -screenHeight * 1.5),
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeOut,
    ));

    _rotationAnimation =
        Tween<double>(begin: 0, end: 0).animate(_swipeAnimationController);

    setState(() {
      _isDragging = false;
      _showSuperLikeStamp = true;
    });

    _swipeAnimationController.duration = const Duration(milliseconds: 1200);
    await _swipeAnimationController.forward(from: 0);
    _swipeAnimationController.duration = const Duration(milliseconds: 300);

    _resetAnimations();
    _swipeAnimationController.reset();

    setState(() {
      _currentProfileIndex++;
      _dragPosition = Offset.zero;
      _isAnimating = false;
      _showSuperLikeStamp = false;
    });

    _loadMoreIfNeeded();
    HapticFeedback.lightImpact();
  }

  void _openProfile(Map<String, dynamic> profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullProfileScreen(
          profile: _toCardProfile(profile),
          onLike: () {
            _matchingService.likeProfile(profile['id'] as String)
                .then((matchId) {
              if (matchId != null && mounted) {
                _triggerMatchPopup(
                  _toCardProfile(profile),
                  matchId: matchId,
                  partnerUserId: profile['id'] as String,
                );
              }
            });
            setState(() {
              _currentProfileIndex++;
              _dragPosition = Offset.zero;
            });
            _loadMoreIfNeeded();
          },
          onPass: () {
            _matchingService.passProfile(profile['id'] as String);
            setState(() {
              _currentProfileIndex++;
              _dragPosition = Offset.zero;
            });
            _loadMoreIfNeeded();
          },
          onSuperLike: () {
            _matchingService.superLikeProfile(profile['id'] as String)
                .then((matchId) {
              if (matchId != null && mounted) {
                _triggerMatchPopup(
                  _toCardProfile(profile),
                  matchId: matchId,
                  partnerUserId: profile['id'] as String,
                );
              }
            });
            setState(() {
              _currentProfileIndex++;
              _dragPosition = Offset.zero;
            });
            _loadMoreIfNeeded();
          },
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the primary display image URL for a profile.
  /// Converts any signed/expired Supabase URL to a stable public URL.
  String _toPublicUrl(String url) {
    final regex = RegExp(r'(https?://[^/]+/storage/v1/object/)(?:public|sign)/([^?]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      return '${match.group(1)}public/${match.group(2)}';
    }
    return url;
  }

  /// Falls back to profile_image_url if the photos array is empty.
  String _getFirstImage(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return _toPublicUrl(photos[0] as String);
    }
    final url = profile['profile_image_url'] as String?;
    return url != null ? _toPublicUrl(url) : '';
  }

  /// Returns all image URLs for a profile (used in full profile view).
  List<String> _getAllImages(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.whereType<String>().map(_toPublicUrl).toList();
    }
    final url = profile['profile_image_url'] as String?;
    return url != null ? [_toPublicUrl(url)] : [];
  }

  /// Returns interests as a List<String>, safely cast from the DB array.
  List<String> _getInterests(Map<String, dynamic> profile) {
    final interests = profile['interests'];
    if (interests is List) return interests.cast<String>();
    return [];
  }

  /// Converts a raw DB profile map into the shape the card/full-profile
  /// widget expects, so we only do this mapping in one place.
  Map<String, dynamic> _toCardProfile(Map<String, dynamic> profile) {
    // Format height_cm → "175 cm" string
    String heightStr = '';
    final hcm = profile['height_cm'];
    if (hcm != null) heightStr = '$hcm cm';

    // looking_for and connect_with may be stored as JSON arrays
    List<String> _castList(dynamic v) {
      if (v is List) return v.whereType<String>().toList();
      return [];
    }

    return {
      'id'              : profile['id'],
      'name'            : profile['first_name'] ?? 'Unknown',
      'age'             : profile['age'] ?? 0,
      'location'        : profile['location'] ?? '',
      'distance'        : profile['distance'] ?? '',
      'bio'             : profile['bio'] ?? '',
      'interests'       : _getInterests(profile),
      'images'          : _getAllImages(profile),
      // Extra fields for full profile view
      'gender'          : profile['gender'] ?? '',
      'height'          : heightStr,
      'zodiac'          : profile['zodiac'] ?? '',
      'religion'        : profile['religion'] ?? '',
      'drinking_habit'  : profile['drinking_habit'] ?? '',
      'smoking_habit'   : profile['smoking_habit'] ?? '',
      'workout_habit'   : profile['workout_habit'] ?? '',
      'pets'            : profile['pets'] ?? '',
      'looking_for'     : _castList(profile['looking_for']),
      'connect_with'    : _castList(profile['connect_with']),
      'photo_captions'  : _castList(profile['photo_captions']),
    };
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: MatchXPBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchPopup() {
    final profile = _matchedCardProfile!;
    final images = profile['images'] as List<String>? ?? [];
    final photo = images.isNotEmpty ? images[0] : '';
    final name = profile['name'] as String? ?? 'Match';

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _closeMatchPopup,
        child: MatchXPBackground(
          child: Align(
            alignment: const Alignment(0, 0.25),
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _matchAnimController,
                  curve: Curves.elasticOut,
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        const SizedBox(height: 10),
                        Text(
                          ' IT\'S A MATCH!',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 72,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle
                        Text(
                          'Play a game with $name to unlock your chat',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 95),
                        // Two cards — poker overlap, right card lifted
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.centerLeft,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 150),
                                child: Transform.translate(
                                  offset: const Offset(0, -24),
                                  child: Transform.rotate(
                                    angle: 0.18,
                                    child: _matchAvatar(
                                        photo, const Color(0xFF6C3FE8)),
                                  ),
                                ),
                              ),
                              Transform.rotate(
                                angle: -0.08,
                                child: _matchAvatar(
                                    _myPhoto, const Color(0xFF6C3FE8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 70),
                        // Buttons — same size pill style
                        GestureDetector(
                          onTap: () {
                            final matchId = _matchedMatchId;
                            final partnerUserId = _matchedPartnerUserId;
                            final partnerName =
                                _matchedCardProfile?['name'] as String? ??
                                    'Match';
                            final currentUserId =
                                Supabase.instance.client.auth.currentUser?.id ??
                                    '';
                            _closeMatchPopup();
                            if (matchId != null && partnerUserId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameHubScreen(
                                    matchId: matchId,
                                    currentUserId: currentUserId,
                                    partnerUserId: partnerUserId,
                                    partnerName: partnerName,
                                    onChatUnlocked: () {},
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C3FE8),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Text(
                              'PLAY GAME TO UNLOCK CHAT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _closeMatchPopup,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              'KEEP SWIPING',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.75),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ), // ScaleTransition
            ), // Transform.translate
          ), // Align
        ), // MatchXPBackground
      ), // GestureDetector
    ); // Material
  }

  Widget _matchAvatar(String? photo, Color borderColor) {
    return Container(
      width: 150,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: photo != null && photo.isNotEmpty
            ? Image.network(photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person,
                        size: 52, color: Colors.white54)))
            : Container(
                color: Colors.grey[800],
                child:
                    const Icon(Icons.person, size: 52, color: Colors.white54)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_hasError) return _buildErrorState();
    if (_profiles.isEmpty || _currentProfileIndex >= _profiles.length) {
      return _buildEmptyState();
    }
    return _buildCardStack();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF6C3FE8)),
          SizedBox(height: 16),
          Text(
            'Finding people near you...',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 60),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your connection and try again',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadProfiles,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text(
            "You've seen everyone!",
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new people',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _loadProfiles(resetMode: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).viewPadding.top + 12;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPad - 6, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 34, height: 34), // spacer for overlay logo
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreferencesScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF6C3FE8).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.tune, color: Color(0xFF6C3FE8), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    final profile = _profiles[_currentProfileIndex];
    final hasNext = _currentProfileIndex + 1 < _profiles.length;
    final nextProfile = hasNext ? _profiles[_currentProfileIndex + 1] : null;

    final dragProgress =
        (_dragPosition.dx.abs() / MediaQuery.of(context).size.width)
            .clamp(0.0, 1.0);

    return Stack(
      children: [
        // Back card
        if (nextProfile != null)
          AnimatedBuilder(
            animation: _swipeAnimationController,
            child: KeyedSubtree(
              key: ValueKey('back_${_currentProfileIndex + 1}'),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildProfileCard(nextProfile),
              ),
            ),
            builder: (context, child) {
              final scale = _isDragging
                  ? 0.92 + dragProgress * 0.08
                  : _nextCardScaleAnimation.value;
              final opacity = _isDragging
                  ? (0.5 + dragProgress * 0.5).clamp(0.5, 1.0)
                  : (0.5 + _swipeAnimationController.value * 0.5)
                      .clamp(0.5, 1.0);
              return Transform.scale(
                scale: scale,
                child: Opacity(opacity: opacity, child: child),
              );
            },
          ),

        // Front card
        AnimatedBuilder(
          animation: _swipeAnimationController,
          child: KeyedSubtree(
            key: ValueKey('front_$_currentProfileIndex'),
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildProfileCard(profile, showStar: true, showStamp: true),
              ),
            ),
          ),
          builder: (context, child) {
            final offset = _isDragging ? _dragPosition : _swipeAnimation.value;
            final rotation =
                _isDragging ? _getRotation() : _rotationAnimation.value;
            return Transform.translate(
              offset: offset,
              child: Transform.rotate(angle: rotation, child: child),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile, {bool showStar = false, bool showStamp = false}) {
    final imageUrl = _getFirstImage(profile);
    final name = profile['first_name'] ?? 'Unknown';
    final ageRaw = profile['age'];
    final age = ageRaw != null ? '$ageRaw' : '';
    final location = profile['location'] ?? '';
    final interests = _getInterests(profile);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Profile photo
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1A1A2E),
                                Color(0xFF16213E),
                                Color(0xFF0F3460)
                              ],
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF6C3FE8), strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),

              // Bottom gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // LIKE / NOPE stamp — only on the active front card
              if (showStamp && _isDragging && _dragPosition.dx.abs() > 20)
                Positioned(
                  top: 60,
                  left: _dragPosition.dx > 0 ? 40 : null,
                  right: _dragPosition.dx < 0 ? 40 : null,
                  child: Opacity(
                    opacity: (_dragPosition.dx.abs() / 80).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: _dragPosition.dx > 0 ? -0.3 : 0.3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _dragPosition.dx > 0
                                ? const Color(0xFF00D4AA)
                                : const Color(0xFFFF3B60),
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _dragPosition.dx > 0 ? 'LIKE' : 'NOPE',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _dragPosition.dx > 0
                                ? const Color(0xFF00D4AA)
                                : const Color(0xFFFF3B60),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // SUPER LIKE stamp — upward drag or button trigger, centered
              if (showStamp && ((_isDragging && _dragPosition.dy < -20 && _dragPosition.dx.abs() <= 20) || _showSuperLikeStamp))
                Positioned.fill(
                  child: Opacity(
                    opacity: _showSuperLikeStamp
                        ? 1.0
                        : (_dragPosition.dy.abs() / 80).clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF7C3AED),
                            width: 4,
                          ),
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
                  ),
                ),
              ),

              // Profile info
              Positioned(
                bottom: 20,
                left: 20,
                right: 88, // leave room for star button on the right
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            age != '' ? '$name, $age' : name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (age != '') ...[
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
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: interests
                            .take(3)
                            .map((interest) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C3FE8)
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    interest,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Star (super-like) button — bottom-right corner of card
              if (showStar)
                Positioned(
                  bottom: 20,
                  right: 20,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 100, color: Colors.white38),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.close_rounded,
            gradient: const LinearGradient(
                colors: [Color(0xFFFF3B60), Color(0xFFFF6B8A)]),
            size: 58,
            onTap: _handlePass,
          ),
          _buildActionButton(
            icon: Icons.star_rounded,
            gradient: const LinearGradient(
                colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
            size: 52,
            onTap: _handleSuperLike,
          ),
          _buildActionButton(
            icon: Icons.favorite_rounded,
            gradient: const LinearGradient(
                colors: [Color(0xFF00D4AA), Color(0xFF00E5BD)]),
            size: 66,
            onTap: _handleLike,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required LinearGradient gradient,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.48),
      ),
    );
  }
}
