import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'full_profile_screen.dart';
import 'preferences_screen.dart';
import '../services/matching_service.dart';
import '../games/game_hub_screen.dart';

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
  bool _isAnimating = false;
  int _currentProfileIndex = 0;

  // Real profiles loaded from Supabase
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Match popup
  bool _showMatchPopup = false;
  Map<String, dynamic>? _matchedCardProfile;
  String? _matchedMatchId;
  String? _matchedPartnerUserId;
  late AnimationController _matchAnimController;

  RealtimeChannel? _matchNotifChannel;

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
    _subscribeToMatchNotifications();
  }

  void _subscribeToMatchNotifications() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    _matchNotifChannel = _matchingService.subscribeToMatchNotifications(
      currentUserId,
      (matchId, partnerId) async {
        final profile = await _matchingService.getProfileById(partnerId);
        if (!mounted || profile == null) return;
        _triggerMatchPopup(profile, matchId: matchId, partnerUserId: partnerId);
      },
    );
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
    if (_matchNotifChannel != null) {
      Supabase.instance.client.removeChannel(_matchNotifChannel!);
    }
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

    final screenWidth = MediaQuery.of(context).size.width;
    if (_dragPosition.dx.abs() > screenWidth * 0.25) {
      final isLike = _dragPosition.dx > 0;
      _saveSwipeAction(isLike); // ← save to Supabase just like the buttons do
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
    setState(() {
      _matchedCardProfile = cardProfile;
      _matchedMatchId = matchId;
      _matchedPartnerUserId = partnerUserId;
      _showMatchPopup = true;
    });
    _matchAnimController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _closeMatchPopup() {
    setState(() {
      _showMatchPopup = false;
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
    final rotation = (_dragPosition.dx / MediaQuery.of(context).size.width) * maxRotation;
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

  /// Save super like to Supabase and animate card upward
  void _handleSuperLike() async {
    if (_isDragging || _isAnimating || _profiles.isEmpty) return;
    _isAnimating = true;
    HapticFeedback.mediumImpact();

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
      begin: Offset.zero,
      end: Offset(0, -screenHeight * 1.5),
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(begin: 0, end: 0)
        .animate(_swipeAnimationController);

    setState(() => _isDragging = false);

    await _swipeAnimationController.forward(from: 0);

    _resetAnimations();
    _swipeAnimationController.reset();

    setState(() {
      _currentProfileIndex++;
      _dragPosition = Offset.zero;
      _isAnimating = false;
    });

    _loadMoreIfNeeded();
    debugPrint('⭐ Super Liked!');
  }

  void _openProfile(Map<String, dynamic> profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullProfileScreen(profile: _toCardProfile(profile)),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the primary display image URL for a profile.
  /// Falls back to profile_image_url if the photos array is empty.
  String _getFirstImage(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos[0] as String;
    }
    return (profile['profile_image_url'] as String?) ?? '';
  }

  /// Returns all image URLs for a profile (used in full profile view).
  List<String> _getAllImages(Map<String, dynamic> profile) {
    final photos = profile['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.cast<String>();
    }
    final url = profile['profile_image_url'] as String?;
    return url != null ? [url] : [];
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
    return {
      'id': profile['id'],
      'name': profile['first_name'] ?? 'Unknown',
      'age': profile['age'] ?? 0,
      'location': profile['location'] ?? '',
      'distance': profile['distance'] ?? '',
      'bio': profile['bio'] ?? '',
      'interests': _getInterests(profile),
      'images': _getAllImages(profile),
    };
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
                if (!_isLoading && !_hasError && _profiles.isNotEmpty && _currentProfileIndex < _profiles.length)
                  _buildActionButtons(),
                const SizedBox(height: 4),
              ],
            ),
          ),
          if (_showMatchPopup && _matchedCardProfile != null)
            _buildMatchPopup(),
        ],
      ),
    );
  }

  Widget _buildMatchPopup() {
    final profile = _matchedCardProfile!;
    final images = profile['images'] as List<String>? ?? [];
    final photo = images.isNotEmpty ? images[0] : '';
    final name = profile['name'] as String? ?? 'Match';

    return GestureDetector(
      onTap: _closeMatchPopup,
      child: Container(
        color: Colors.black.withOpacity(0.92),
        child: Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _matchAnimController,
              curve: Curves.elasticOut,
            ),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF6C3FE8).withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C3FE8).withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB), Color(0xFFFF6B8A)],
                      ).createShader(bounds),
                      child: const Text(
                        "IT'S A MATCH!",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You and $name liked each other!',
                      style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _matchAvatar(null, const Color(0xFF6C3FE8)),
                            const SizedBox(width: 40),
                            _matchAvatar(photo, const Color(0xFFFF6B8A)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C3FE8), Color(0xFFFF6B8A)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C3FE8).withOpacity(0.6),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Primary: Play Game
                          GestureDetector(
                            onTap: () {
                              final matchId       = _matchedMatchId;
                              final partnerUserId = _matchedPartnerUserId;
                              final partnerName   = _matchedCardProfile?['name'] as String? ?? 'Match';
                              final currentUserId =
                                  Supabase.instance.client.auth.currentUser?.id ?? '';
                              _closeMatchPopup();
                              if (matchId != null && partnerUserId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GameHubScreen(
                                      matchId:        matchId,
                                      currentUserId:  currentUserId,
                                      partnerUserId:  partnerUserId,
                                      partnerName:    partnerName,
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
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)],
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Text(
                                'PLAY GAME TO UNLOCK CHAT',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Play a mini icebreaker game to unlock chat — it\'s interactive & fun!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Secondary: Keep Swiping
                          TextButton(
                            onPressed: _closeMatchPopup,
                            child: Text(
                              'Keep Swiping',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchAvatar(String? photo, Color borderColor) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(color: borderColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: photo != null && photo.isNotEmpty
            ? Image.network(photo, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person, size: 50, color: Colors.white54)))
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person, size: 50, color: Colors.white54)),
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
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
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
          const Text('🎉', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            "You've seen everyone!",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('MATCH',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1.5)),
              const Text('XP',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: Color(0xFF6C3FE8), letterSpacing: 1.5)),
            ],
          ),
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
                border: Border.all(color: const Color(0xFF6C3FE8).withOpacity(0.3)),
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
        (_dragPosition.dx.abs() / MediaQuery.of(context).size.width).clamp(0.0, 1.0);

    return Stack(
      children: [
        // Back card
        if (nextProfile != null)
          AnimatedBuilder(
            animation: _swipeAnimationController,
            child: KeyedSubtree(
              key: ValueKey('back_${_currentProfileIndex + 1}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildProfileCard(nextProfile),
              ),
            ),
            builder: (context, child) {
              final scale = _isDragging
                  ? 0.92 + dragProgress * 0.08
                  : _nextCardScaleAnimation.value;
              final opacity = _isDragging
                  ? (0.5 + dragProgress * 0.5).clamp(0.5, 1.0)
                  : (0.5 + _swipeAnimationController.value * 0.5).clamp(0.5, 1.0);
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildProfileCard(profile),
              ),
            ),
          ),
          builder: (context, child) {
            final offset = _isDragging ? _dragPosition : _swipeAnimation.value;
            final rotation = _isDragging ? _getRotation() : _rotationAnimation.value;
            return Transform.translate(
              offset: offset,
              child: Transform.rotate(angle: rotation, child: child),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final imageUrl = _getFirstImage(profile);
    final name = profile['first_name'] ?? 'Unknown';
    final age = profile['age'] ?? '';
    final location = profile['location'] ?? '';
    final interests = _getInterests(profile);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
                              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
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
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // LIKE / NOPE stamp
              if (_isDragging && _dragPosition.dx.abs() > 20)
                Positioned(
                  top: 60,
                  left: _dragPosition.dx > 0 ? 40 : null,
                  right: _dragPosition.dx < 0 ? 40 : null,
                  child: Opacity(
                    opacity: (_dragPosition.dx.abs() / 80).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: _dragPosition.dx > 0 ? -0.3 : 0.3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

              // Profile info
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            age != '' ? '$name, $age' : name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
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
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 14),
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
                        children: interests.take(3).map((interest) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C3FE8).withOpacity(0.7),
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
                        )).toList(),
                      ),
                    ],
                  ],
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
            gradient: const LinearGradient(colors: [Color(0xFFFF3B60), Color(0xFFFF6B8A)]),
            size: 58,
            onTap: _handlePass,
          ),
          _buildActionButton(
            icon: Icons.star_rounded,
            gradient: const LinearGradient(colors: [Color(0xFF6C3FE8), Color(0xFF9D50BB)]),
            size: 52,
            onTap: _handleSuperLike,
          ),
          _buildActionButton(
            icon: Icons.favorite_rounded,
            gradient: const LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF00E5BD)]),
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
              color: gradient.colors.first.withOpacity(0.4),
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
