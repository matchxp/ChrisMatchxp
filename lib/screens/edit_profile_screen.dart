import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/matchxp_background.dart';

// ── Photo item ────────────────────────────────────────────────────────────────
class _PhotoItem {
  final String? url;
  final File? file;
  _PhotoItem.network(this.url) : file = null;
  _PhotoItem.local(this.file) : url = null;
  bool get isLocal => file != null;
}

// ── Nominatim result ──────────────────────────────────────────────────────────
class _LocationResult {
  final String display;
  final double? lat, lon;
  const _LocationResult({required this.display, this.lat, this.lon});
}

// ── Interest option metadata (icon + label) ───────────────────────────────────
class _InterestMeta {
  final String label;
  final IconData icon;
  const _InterestMeta(this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({Key? key, required this.profile}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _picker = ImagePicker();
  bool _isSaving = false;

  // ── Colour tokens — match preferences screen exactly ──────────────────────
  static const _bg      = Color(0xFF0C0B11);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);
  static const _green   = Color(0xFF4CAF50);

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _locationCtrl;
  final FocusNode _locationFocus = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  String? _gender;
  DateTime? _birthday;
  int _heightCm = 170;
  String? _drinkingHabit;
  String? _smokingHabit;
  String? _workoutHabit;
  List<String> _selectedInterests = [];
  List<String> _lookingFor        = [];
  List<String> _connectWith       = [];
  String? _zodiac;
  List<String> _selectedReligions  = [];
  List<_PhotoItem> _photos         = [];

  // ── Location autocomplete ─────────────────────────────────────────────────
  List<_LocationResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _suppressSearch = false;
  Timer? _debounce;

  // ── Static option lists ───────────────────────────────────────────────────
  static const _genderOptions      = ['Man', 'Woman', 'Non-Binary'];
  static const _drinkingOptions    = ['Never', 'On special Occasionally', 'Socially on weekends', 'Most Nights'];
  static const _smokingOptions     = ['Non-smoker', 'Social smoker', 'Trying to quit', 'Smoker'];
  static const _workoutOptions     = ['Everyday', 'Often', 'Sometimes', 'No, not really', 'No, but I plan to start'];
  static const _lookingForOptions  = ['Make New Friends', 'Something Casual', 'Long Term Relationship', 'Not Sure Yet'];
  static const _connectWithOptions = ['Men', 'Women', 'Everyone'];
  static const _zodiacOptions = [
    'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
  ];
  static const _religionOptions = [
    'Catholic', 'Christian', 'Muslim', 'Buddhist', 'Hindu',
    'Jewish', 'Jain', 'Mormon', 'Atheist', 'Agnostic',
  ];

  static const _interestsMeta = [
    _InterestMeta('Photography',  Icons.camera_alt_rounded),
    _InterestMeta('Cooking',      Icons.restaurant_rounded),
    _InterestMeta('Dancing',      Icons.nightlife_rounded),
    _InterestMeta('Video Games',  Icons.videogame_asset_rounded),
    _InterestMeta('Music',        Icons.music_note_rounded),
    _InterestMeta('Coffee',       Icons.coffee_rounded),
    _InterestMeta('Wine',         Icons.wine_bar_rounded),
    _InterestMeta('Baking',       Icons.cake_rounded),
    _InterestMeta('Gardening',    Icons.yard_rounded),
    _InterestMeta('Travelling',   Icons.flight_rounded),
    _InterestMeta('Shopping',     Icons.shopping_bag_rounded),
    _InterestMeta('Swimming',     Icons.pool_rounded),
    _InterestMeta('Crafts',       Icons.palette_rounded),
    _InterestMeta('Sports',       Icons.sports_rounded),
    _InterestMeta('Fitness',      Icons.fitness_center_rounded),
    _InterestMeta('Yoga',         Icons.self_improvement_rounded),
    _InterestMeta('Foodie',       Icons.fastfood_rounded),
    _InterestMeta('Camping',      Icons.outdoor_grill_rounded),
    _InterestMeta('Hiking',       Icons.hiking_rounded),
    _InterestMeta('Movies',       Icons.movie_rounded),
  ];

  // ── Init / Dispose ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstNameCtrl = TextEditingController(text: p['first_name'] as String? ?? '');
    _lastNameCtrl  = TextEditingController(text: p['last_name']  as String? ?? '');
    _bioCtrl       = TextEditingController(text: p['bio']        as String? ?? '');
    _locationCtrl  = TextEditingController(text: p['location']   as String? ?? '');

    _gender        = p['gender']         as String?;
    _drinkingHabit = p['drinking_habit'] as String?;
    _smokingHabit  = p['smoking_habit']  as String?;
    _workoutHabit  = p['workout_habit']  as String?;
    _heightCm      = (p['height_cm'] as num?)?.toInt() ?? 170;

    final rawBday = p['birthday'] as String?;
    if (rawBday != null) _birthday = DateTime.tryParse(rawBday);

    final interests = p['interests'];
    if (interests is List) _selectedInterests = List<String>.from(interests);

    final lf = p['looking_for'];
    if (lf is List)                    _lookingFor = List<String>.from(lf);
    else if (lf is String && lf.isNotEmpty) _lookingFor = [lf];

    final cw = p['connect_with'];
    if (cw is List)                    _connectWith = List<String>.from(cw);
    else if (cw is String && cw.isNotEmpty) _connectWith = [cw];

    _zodiac = p['zodiac'] as String?;
    final rel = p['religion'];
    if (rel is List) _selectedReligions = List<String>.from(rel);

    // Photos
    final rawUrls = <String>[];
    final photos = p['photos'];
    if (photos is List && photos.isNotEmpty) {
      rawUrls.addAll(photos.whereType<String>().where((u) => u.isNotEmpty));
    }
    if (rawUrls.isEmpty) {
      final url = p['profile_image_url'] as String?;
      if (url != null && url.isNotEmpty) rawUrls.add(url);
    }
    _photos = rawUrls.map((u) => _PhotoItem.network(u)).toList();
    if (rawUrls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveSignedUrls(rawUrls));
    }

    _locationCtrl.addListener(_onLocationChanged);
    _locationFocus.addListener(() {
      if (!_locationFocus.hasFocus && mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _locationSuggestions = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationCtrl.removeListener(_onLocationChanged);
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  // ── Signed URL resolution ─────────────────────────────────────────────────
  Future<void> _resolveSignedUrls(List<String> rawUrls) async {
    final resolved = <_PhotoItem>[];
    final storage = Supabase.instance.client.storage;
    for (final url in rawUrls) {
      final regex = RegExp(r'/storage/v1/object/(?:public|sign)/([^/?]+)/([^?]+)');
      final match = regex.firstMatch(url);
      if (match != null) {
        final bucket = match.group(1)!;
        final path   = Uri.decodeComponent(match.group(2)!);
        try {
          final signed = await storage.from(bucket).createSignedUrl(path, 3600);
          resolved.add(_PhotoItem.network(signed));
          continue;
        } catch (_) {}
      }
      resolved.add(_PhotoItem.network(url));
    }
    if (mounted) setState(() => _photos = resolved);
  }

  // ── Nominatim ─────────────────────────────────────────────────────────────
  void _onLocationChanged() {
    if (_suppressSearch) return;
    final q = _locationCtrl.text.trim();
    if (q.length < 3) { setState(() => _locationSuggestions = []); return; }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchAU(q));
  }

  Future<void> _searchAU(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingLocation = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&countrycodes=au&format=json&limit=6&addressdetails=1',
      );
      final res = await http.get(uri,
          headers: {'User-Agent': 'MatchXP/1.0', 'Accept-Language': 'en'});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _locationSuggestions = data.map((item) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final parts = [
              addr['suburb'] ?? addr['town'] ?? addr['village'] ?? '',
              addr['city'] ?? addr['county'] ?? '',
              addr['state'] ?? '',
            ].where((s) => (s as String).isNotEmpty).cast<String>().toSet().toList();
            final short = parts.take(3).join(', ');
            return _LocationResult(
              display: short.isNotEmpty ? short : (item['display_name'] as String),
              lat: double.tryParse(item['lat'] as String? ?? ''),
              lon: double.tryParse(item['lon'] as String? ?? ''),
            );
          }).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationSuggestions = []);
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _selectLocation(_LocationResult r) {
    HapticFeedback.selectionClick();
    _debounce?.cancel();
    _suppressSearch = true;
    _locationCtrl.text = r.display;
    _locationCtrl.selection = TextSelection.collapsed(offset: r.display.length);
    _suppressSearch = false;
    setState(() => _locationSuggestions = []);
    _locationFocus.unfocus();
  }

  // ── Photo helpers ─────────────────────────────────────────────────────────
  Future<void> _addPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photos.add(_PhotoItem.local(File(picked.path))));
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) { _snackErr('First name cannot be empty.'); return; }
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final List<String> photoUrls = [];
      for (final item in _photos) {
        if (item.isLocal) {
          final fn = 'photo_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('user-photos').upload(fn, item.file!);
          photoUrls.add(
              Supabase.instance.client.storage.from('user-photos').getPublicUrl(fn));
        } else {
          photoUrls.add(item.url!);
        }
      }
      int? age;
      if (_birthday != null) {
        final now = DateTime.now();
        age = now.year - _birthday!.year;
        if (now.month < _birthday!.month ||
            (now.month == _birthday!.month && now.day < _birthday!.day)) {
          age--;
        }
      }
      final payload = <String, dynamic>{
        'first_name':     firstName,
        'last_name':      _lastNameCtrl.text.trim(),
        'bio':            _bioCtrl.text.trim(),
        'location':       _locationCtrl.text.trim(),
        'height_cm':      _heightCm,
        'drinking_habit': _drinkingHabit,
        'smoking_habit':  _smokingHabit,
        'workout_habit':  _workoutHabit,
        'interests':      _selectedInterests,
        'looking_for':    _lookingFor,
        'connect_with':   _connectWith,
        'religion':       _selectedReligions,
        'photos':         photoUrls,
        'updated_at':     DateTime.now().toIso8601String(),
      };
      if (_gender != null)      payload['gender']            = _gender;
      if (_zodiac != null)      payload['zodiac']            = _zodiac;
      if (_birthday != null)    payload['birthday']           = _birthday!.toIso8601String();
      if (age != null)          payload['age']                = age;
      if (photoUrls.isNotEmpty) payload['profile_image_url']  = photoUrls.first;

      await Supabase.instance.client.from('profiles').update(payload).eq('id', uid);

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profile saved!', style: GoogleFonts.outfit()),
          backgroundColor: _purple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snackErr(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snackErr(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.outfit()),
    backgroundColor: Colors.redAccent,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: MatchXPBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    _buildPageHeader(),
                    const SizedBox(height: 28),

                    _sectionLabel('Photos'),
                    const SizedBox(height: 12),
                    _buildPhotos(),
                    const SizedBox(height: 28),

                    _sectionLabel('Basic Info'),
                    const SizedBox(height: 12),
                    _buildBasicInfo(),
                    const SizedBox(height: 28),

                    _sectionLabel('Gender'),
                    const SizedBox(height: 12),
                    _singleSelectPills(
                      _genderOptions, _gender,
                      (v) => setState(() => _gender = v == _gender ? null : v),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('Birthday'),
                    const SizedBox(height: 12),
                    _buildBirthdayPill(),
                    const SizedBox(height: 28),

                    _sectionLabel('Height'),
                    const SizedBox(height: 12),
                    _buildHeightCard(),
                    const SizedBox(height: 28),

                    _sectionLabel('Location'),
                    const SizedBox(height: 12),
                    _buildLocationField(),
                    const SizedBox(height: 28),

                    _sectionLabel('How often do you drink?'),
                    const SizedBox(height: 12),
                    _singleSelectPills(
                      _drinkingOptions, _drinkingHabit,
                      (v) => setState(() => _drinkingHabit = v == _drinkingHabit ? null : v),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('How often do you smoke?'),
                    const SizedBox(height: 12),
                    _singleSelectPills(
                      _smokingOptions, _smokingHabit,
                      (v) => setState(() => _smokingHabit = v == _smokingHabit ? null : v),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('Do you work out?'),
                    const SizedBox(height: 12),
                    _singleSelectPills(
                      _workoutOptions, _workoutHabit,
                      (v) => setState(() => _workoutHabit = v == _workoutHabit ? null : v),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('What are you looking for?'),
                    const SizedBox(height: 12),
                    _multiSelectPills(
                      _lookingForOptions, _lookingFor,
                      (v) => setState(() => _lookingFor.contains(v)
                          ? _lookingFor.remove(v)
                          : _lookingFor.add(v)),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('Want to meet'),
                    const SizedBox(height: 12),
                    _multiSelectPills(
                      _connectWithOptions, _connectWith,
                      (v) => setState(() => _connectWith.contains(v)
                          ? _connectWith.remove(v)
                          : _connectWith.add(v)),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('Interests'),
                    const SizedBox(height: 12),
                    _buildInterestsPills(),
                    const SizedBox(height: 28),

                    _sectionLabel('Zodiac sign'),
                    const SizedBox(height: 12),
                    _singleSelectPills(
                      _zodiacOptions, _zodiac,
                      (v) => setState(() => _zodiac = v == _zodiac ? null : v),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('Religion'),
                    const SizedBox(height: 12),
                    _multiSelectPills(
                      _religionOptions, _selectedReligions,
                      (v) => setState(() => _selectedReligions.contains(v)
                          ? _selectedReligions.remove(v)
                          : _selectedReligions.add(v)),
                    ),
                    const SizedBox(height: 36),

                    _saveButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar — matches Preferences exactly ────────────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: _purple, strokeWidth: 2.5),
            ),
          )
        else
          GestureDetector(
            onTap: _save,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purple2]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ── Page header — matches Preferences header style ────────────────────────
  Widget _buildPageHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        'Edit Profile',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Update your info and photos',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: Colors.white.withOpacity(0.50),
        ),
      ),
    ],
  );

  // ── Section label — identical to Preferences _sectionLabel ───────────────
  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.outfit(
      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
    ),
  );

  // ── Photos ────────────────────────────────────────────────────────────────
  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + (_photos.length < 6 ? 1 : 0),
            itemBuilder: (_, i) =>
                i == _photos.length ? _addPhotoTile() : _photoTile(i),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 13),
          const SizedBox(width: 5),
          Text(
            'First photo is your main profile photo · max 6',
            style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11),
          ),
        ]),
      ],
    );
  }

  Widget _photoTile(int index) {
    final item   = _photos[index];
    final isMain = index == 0;
    return Stack(children: [
      Container(
        width: 105, height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isMain ? _purple : _purple.withOpacity(0.42),
            width: isMain ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: item.isLocal
              ? Image.file(item.file!, fit: BoxFit.cover, width: 105, height: 130)
              : Image.network(
                  item.url!, fit: BoxFit.cover, width: 105, height: 130,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: _purple.withOpacity(0.6), strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.white.withOpacity(0.2), size: 28),
                  ),
                ),
        ),
      ),
      Positioned(
        top: 6, right: 16,
        child: GestureDetector(
          onTap: () => _removePhoto(index),
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7), shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 12),
          ),
        ),
      ),
      if (isMain)
        Positioned(
          bottom: 8, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, _purple2]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Main',
              style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _addPhotoTile() => GestureDetector(
    onTap: _addPhoto,
    child: Container(
      width: 105, height: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.add_rounded, color: _purple.withOpacity(0.9), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Add photo',
          style: GoogleFonts.outfit(
            color: _purple.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    ),
  );

  // ── Basic Info — pill-style inputs ────────────────────────────────────────
  Widget _buildBasicInfo() {
    return Column(children: [
      Row(children: [
        Expanded(child: _textPill('First name', _firstNameCtrl)),
        const SizedBox(width: 10),
        Expanded(child: _textPill('Last name', _lastNameCtrl)),
      ]),
      const SizedBox(height: 10),
      _textPill('Write something about yourself…', _bioCtrl, maxLines: 4),
    ]);
  }

  /// Single-line or multi-line pill/rounded input — matches Preferences style.
  Widget _textPill(
    String hint,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    final isMulti = maxLines > 1;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isMulti ? 14 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMulti ? 20 : 50),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.outfit(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400,
        ),
        cursorColor: _purple,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: isMulti ? 0 : 14),
        ),
      ),
    );
  }

  // ── Single-select pills — matches Preferences "Here to" / "Want to meet" ──
  Widget _singleSelectPills(
    List<String> options,
    String? selected,
    ValueChanged<String> onTap,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = selected == opt;
        return GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onTap(opt); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: isSelected
                  ? _purple.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isSelected ? _purple : _purple.withOpacity(0.42),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                      color: _purple, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Multi-select pills ────────────────────────────────────────────────────
  Widget _multiSelectPills(
    List<String> options,
    List<String> selected,
    Function(String) onToggle,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onToggle(opt); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: isSelected
                  ? _purple.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isSelected ? _purple : _purple.withOpacity(0.42),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                      color: _purple, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Interests — pills with icons ──────────────────────────────────────────
  Widget _buildInterestsPills() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _interestsMeta.map((meta) {
        final isSelected = _selectedInterests.contains(meta.label);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => isSelected
                ? _selectedInterests.remove(meta.label)
                : _selectedInterests.add(meta.label));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: isSelected
                  ? _purple.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isSelected ? _purple : _purple.withOpacity(0.42),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  meta.icon,
                  color: isSelected ? Colors.white : Colors.white54,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  meta.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                      color: _purple, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Birthday — pill trigger ────────────────────────────────────────────────
  Widget _buildBirthdayPill() => GestureDetector(
    onTap: _pickBirthday,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
      ),
      child: Row(children: [
        Text(
          _birthday != null
              ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
              : 'Select your birthday',
          style: GoogleFonts.outfit(
            color: _birthday != null ? Colors.white : Colors.white38,
            fontSize: 14,
            fontWeight: _birthday != null ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 18),
      ]),
    ),
  );

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 22),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _purple,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1A2E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A1A1A),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  // ── Height — slider matching Preferences style ────────────────────────────
  Widget _buildHeightCard() {
    final ft   = (_heightCm / 30.48).floor();
    final inch = ((_heightCm / 30.48 - ft) * 12).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              '$_heightCm cm  ($ft\'$inch")',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, _purple2]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_heightCm cm',
              style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _purple,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: _purple.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            trackHeight: 3,
          ),
          child: Slider(
            value: _heightCm.toDouble(),
            min: 140, max: 220, divisions: 80,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _heightCm = v.toInt());
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('140 cm', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11)),
              Text('220 cm', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Location — pill input + Nominatim autocomplete ────────────────────────
  Widget _buildLocationField() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: _locationFocus.hasFocus ? _purple : _purple.withOpacity(0.42),
            width: _locationFocus.hasFocus ? 2.0 : 1.0,
          ),
        ),
        child: Row(children: [
          const Icon(Icons.location_on_outlined, color: _green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _locationCtrl,
              focusNode: _locationFocus,
              style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400,
              ),
              cursorColor: _purple,
              onTap: () => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search suburb or city…',
                hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_isSearchingLocation)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
            )
          else if (_locationCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _locationCtrl.clear();
                setState(() => _locationSuggestions = []);
              },
              child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18),
            ),
        ]),
      ),

      if (_locationSuggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _purple.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: _locationSuggestions.asMap().entries.map((e) {
                final idx = e.key;
                final r   = e.value;
                return GestureDetector(
                  onTap: () => _selectLocation(r),
                  behavior: HitTestBehavior.opaque,
                  child: Column(children: [
                    if (idx > 0)
                      Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on_outlined,
                              color: _green, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(r.display,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),

      if (_locationCtrl.text.isNotEmpty &&
          _locationSuggestions.isEmpty &&
          !_isSearchingLocation)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 13),
            const SizedBox(width: 6),
            Text(
              'Searching Australian locations only',
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11),
            ),
          ]),
        ),
    ]);
  }

  // ── Save button — matches Preferences apply button exactly ────────────────
  Widget _saveButton() => GestureDetector(
    onTap: _isSaving ? null : _save,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        gradient: _isSaving
            ? LinearGradient(colors: [
                _purple.withOpacity(0.5),
                _purple2.withOpacity(0.5),
              ])
            : const LinearGradient(colors: [_purple, _purple2]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: _isSaving
            ? []
            : [
                BoxShadow(
                  color: _purple.withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: _isSaving
          ? const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          : Text(
              'Save Changes',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
    ),
  );
}
