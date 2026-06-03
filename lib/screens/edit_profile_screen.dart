import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// ── Option metadata ───────────────────────────────────────────────────────────
class _OptionMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _OptionMeta(this.label, this.icon, this.color);
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

  // ── Colours (match preferences screen exactly) ────────────────────────────
  static const _bg      = Color(0xFF0A0A0A);
  static const _card    = Color(0xFF1A1A1A);
  static const _card2   = Color(0xFF222222);
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
  List<_PhotoItem> _photos = [];

  // ── Location autocomplete ─────────────────────────────────────────────────
  List<_LocationResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _suppressSearch = false;
  Timer? _debounce;

  // ── Option metadata ───────────────────────────────────────────────────────
  static const _genderMeta = [
    _OptionMeta('Men',   Icons.male_rounded,   Color(0xFF6C3FE8)),
    _OptionMeta('Women', Icons.female_rounded, Color(0xFFFF6B8A)),
    _OptionMeta('Other', Icons.person_outline, Color(0xFFFF9800)),
  ];
  static const _drinkingMeta = [
    _OptionMeta('Never',                   Icons.no_drinks_outlined,     Color(0xFF00D4AA)),
    _OptionMeta('On special Occasionally', Icons.celebration_outlined,   Color(0xFF6C3FE8)),
    _OptionMeta('Socially on weekends',    Icons.local_bar_outlined,     Color(0xFFFF9800)),
    _OptionMeta('Most Nights',             Icons.sports_bar_outlined,    Color(0xFFFF6B8A)),
  ];
  static const _smokingMeta = [
    _OptionMeta('Non-smoker',            Icons.smoke_free_rounded,      Color(0xFF00D4AA)),
    _OptionMeta('Smoker when drinking',  Icons.local_bar_outlined,      Color(0xFFFF9800)),
    _OptionMeta('Social smoker',         Icons.people_outline_rounded,  Color(0xFF6C3FE8)),
    _OptionMeta('Trying to quit',        Icons.favorite_outline_rounded,Color(0xFFFF6B8A)),
    _OptionMeta('Smoker',                Icons.smoking_rooms_rounded,   Color(0xFF9E9E9E)),
  ];
  static const _workoutMeta = [
    _OptionMeta('Everyday',             Icons.fitness_center_rounded,  Color(0xFF6C3FE8)),
    _OptionMeta('Often',                Icons.directions_run_rounded,  Color(0xFF00D4AA)),
    _OptionMeta('Sometimes',            Icons.self_improvement_rounded,Color(0xFFFF9800)),
    _OptionMeta('No, not really',       Icons.weekend_outlined,        Color(0xFFFF6B8A)),
    _OptionMeta('No, but I plan to start', Icons.flag_outlined,        Color(0xFF9E9E9E)),
  ];
  static const _interestsMeta = [
    _OptionMeta('Photography',    Icons.camera_alt_rounded,       Color(0xFF6C3FE8)),
    _OptionMeta('Cooking',        Icons.restaurant_rounded,       Color(0xFFFF9800)),
    _OptionMeta('Video Games',    Icons.videogame_asset_rounded,  Color(0xFF00D4AA)),
    _OptionMeta('Music',          Icons.music_note_rounded,       Color(0xFFFF6B8A)),
    _OptionMeta('Travelling',     Icons.flight_rounded,           Color(0xFF6C3FE8)),
    _OptionMeta('Shopping',       Icons.shopping_bag_rounded,     Color(0xFFFF9800)),
    _OptionMeta('Art & Crafts',   Icons.palette_rounded,          Color(0xFF00D4AA)),
    _OptionMeta('Swimming',       Icons.pool_rounded,             Color(0xFF6C3FE8)),
    _OptionMeta('Drinking',       Icons.local_bar_rounded,        Color(0xFFFF6B8A)),
    _OptionMeta('Extreme Sports', Icons.sports_rounded,           Color(0xFFFF9800)),
    _OptionMeta('Fitness',        Icons.fitness_center_rounded,   Color(0xFF00D4AA)),
    _OptionMeta('Reading',        Icons.book_rounded,             Color(0xFF6C3FE8)),
    _OptionMeta('Movies',         Icons.movie_rounded,            Color(0xFFFF6B8A)),
    _OptionMeta('Hiking',         Icons.hiking_rounded,           Color(0xFF00D4AA)),
    _OptionMeta('Pets',           Icons.pets_rounded,             Color(0xFFFF9800)),
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

    final raw = p['birthday'] as String?;
    if (raw != null) _birthday = DateTime.tryParse(raw);

    final interests = p['interests'];
    if (interests is List) _selectedInterests = List<String>.from(interests);

    // Collect raw URLs — then resolve to signed URLs after first frame
    final rawUrls = <String>[];
    final photos = p['photos'];
    if (photos is List && photos.isNotEmpty) {
      rawUrls.addAll(photos.whereType<String>().where((u) => u.isNotEmpty));
    }
    if (rawUrls.isEmpty) {
      final url = p['profile_image_url'] as String?;
      if (url != null && url.isNotEmpty) rawUrls.add(url);
    }
    // Show placeholders immediately, then swap with signed URLs
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
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _bioCtrl.dispose(); _locationCtrl.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  // ── Resolve signed URLs for storage photos ───────────────────────────────
  /// Converts any Supabase storage public/private URL into a 1-hour signed URL
  /// so photos display correctly regardless of bucket visibility settings.
  Future<void> _resolveSignedUrls(List<String> rawUrls) async {
    final resolved = <_PhotoItem>[];
    final storage = Supabase.instance.client.storage;

    for (final url in rawUrls) {
      // Extract bucket + path from URL patterns:
      //   .../storage/v1/object/public/<bucket>/<path>
      //   .../storage/v1/object/sign/<bucket>/<path>
      final regex = RegExp(
          r'/storage/v1/object/(?:public|sign)/([^/?]+)/([^?]+)');
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
      // Fallback: use URL as-is
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
          photoUrls.add(Supabase.instance.client.storage.from('user-photos').getPublicUrl(fn));
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
        'first_name': firstName, 'last_name': _lastNameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(), 'location': _locationCtrl.text.trim(),
        'height_cm': _heightCm, 'drinking_habit': _drinkingHabit,
        'smoking_habit': _smokingHabit, 'workout_habit': _workoutHabit,
        'interests': _selectedInterests, 'photos': photoUrls,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (_gender != null) payload['gender'] = _gender;
      if (_birthday != null) payload['birthday'] = _birthday!.toIso8601String();
      if (age != null) payload['age'] = age;
      if (photoUrls.isNotEmpty) payload['profile_image_url'] = photoUrls.first;
      await Supabase.instance.client.from('profiles').update(payload).eq('id', uid);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile saved!'), backgroundColor: _purple,
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
    content: Text(msg), backgroundColor: Colors.redAccent,
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
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
                  _buildOptionGrid(_genderMeta, _gender, (v) => setState(() => _gender = v == _gender ? null : v)),
                  const SizedBox(height: 28),

                  _sectionLabel('Birthday'),
                  const SizedBox(height: 12),
                  _buildBirthdayCard(),
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
                  _buildOptionGrid(_drinkingMeta, _drinkingHabit, (v) => setState(() => _drinkingHabit = v == _drinkingHabit ? null : v)),
                  const SizedBox(height: 28),

                  _sectionLabel('How often do you smoke?'),
                  const SizedBox(height: 12),
                  _buildOptionGrid(_smokingMeta, _smokingHabit, (v) => setState(() => _smokingHabit = v == _smokingHabit ? null : v)),
                  const SizedBox(height: 28),

                  _sectionLabel('Do you workout?'),
                  const SizedBox(height: 12),
                  _buildOptionGrid(_workoutMeta, _workoutHabit, (v) => setState(() => _workoutHabit = v == _workoutHabit ? null : v)),
                  const SizedBox(height: 28),

                  _sectionLabel('Interests'),
                  const SizedBox(height: 12),
                  _buildInterestsGrid(),
                  const SizedBox(height: 32),

                  _saveButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        _isSaving
            ? const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: _purple, strokeWidth: 2.5)))
            : GestureDetector(
                onTap: _save,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_purple, _purple2]),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
      ],
    ),
  );

  // ── Page header ───────────────────────────────────────────────────────────
  Widget _buildPageHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Colors.white, Color(0xFFCBB4FF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ).createShader(b),
        child: const Text('Edit Profile',
            style: TextStyle(color: Colors.white, fontSize: 30,
                fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ),
      const SizedBox(height: 6),
      const Text('Update your info and photos',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
    ],
  );

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));

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
            itemBuilder: (_, i) => i == _photos.length ? _addPhotoTile() : _photoTile(i),
          ),
        ),
        const SizedBox(height: 8),
        const Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.white24, size: 13),
          SizedBox(width: 5),
          Text('First photo is your main profile photo · max 6',
              style: TextStyle(color: Colors.white24, fontSize: 11)),
        ]),
      ],
    );
  }

  Widget _photoTile(int index) {
    final item = _photos[index];
    final isMain = index == 0;
    return Stack(children: [
      Container(
        width: 105, height: 130,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _card,
          border: Border.all(color: isMain ? _purple : Colors.white.withValues(alpha: 0.07), width: isMain ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: item.isLocal
              ? Image.file(item.file!, fit: BoxFit.cover, width: 105, height: 130)
              : Image.network(item.url!, fit: BoxFit.cover, width: 105, height: 130,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: _purple.withValues(alpha: 0.6), strokeWidth: 2)));
                  },
                  errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white.withValues(alpha: 0.2), size: 28))),
        ),
      ),
      Positioned(top: 6, right: 16,
        child: GestureDetector(
          onTap: () => _removePhoto(index),
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 12),
          ),
        ),
      ),
      if (isMain) Positioned(bottom: 8, left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_purple, _purple2]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _addPhotoTile() => GestureDetector(
    onTap: _addPhoto,
    child: Container(
      width: 105, height: 130,
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.add_rounded, color: _purple.withValues(alpha: 0.9), size: 24),
        ),
        const SizedBox(height: 8),
        Text('Add photo', style: TextStyle(color: _purple.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  // ── Basic Info ────────────────────────────────────────────────────────────
  Widget _buildBasicInfo() {
    return Column(children: [
      Row(children: [
        Expanded(child: _inputCard('First name', _firstNameCtrl, Icons.person_outline, _purple)),
        const SizedBox(width: 10),
        Expanded(child: _inputCard('Last name', _lastNameCtrl, Icons.person_outline, _purple)),
      ]),
      const SizedBox(height: 10),
      _inputCard('Bio', _bioCtrl, Icons.edit_outlined, const Color(0xFF00D4AA),
          maxLines: 4, hint: 'Write something about yourself…'),
    ]);
  }

  Widget _inputCard(String label, TextEditingController ctrl, IconData icon, Color color,
      {int maxLines = 1, String? hint}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 12 : 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
              TextField(
                controller: ctrl, maxLines: maxLines,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                cursorColor: _purple,
                decoration: InputDecoration(
                  hintText: hint ?? label, isDense: true,
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Option grid (2-column, matches preferences "Here for" grid) ──────────
  Widget _buildOptionGrid(List<_OptionMeta> metas, String? selected, ValueChanged<String> onTap) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8,
      childAspectRatio: 3.2,
      children: metas.map((meta) {
        final isSelected = selected == meta.label;
        return GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onTap(meta.label); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: isSelected ? _purple.withValues(alpha: 0.13) : _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _purple.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.07),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: _purple.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                  color: isSelected ? _purple.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(meta.icon, color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55), size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(meta.label, maxLines: 2,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.75),
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.3)),
              ),
              if (isSelected)
                Container(width: 17, height: 17,
                  decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Birthday card ─────────────────────────────────────────────────────────
  Widget _buildBirthdayCard() => GestureDetector(
    onTap: _pickBirthday,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFFFF9800).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.cake_outlined, color: Color(0xFFFF9800), size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Date of birth', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(
            _birthday != null
                ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
                : 'Select birthday',
            style: TextStyle(
              color: _birthday != null ? Colors.white : Colors.white38,
              fontSize: _birthday != null ? 20 : 15,
              fontWeight: _birthday != null ? FontWeight.w800 : FontWeight.w400,
              letterSpacing: -0.3,
            ),
          ),
        ])),
        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white30, size: 22),
      ]),
    ),
  );

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 22),
      firstDate: DateTime(now.year - 80), lastDate: DateTime(now.year - 18),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: _purple, onPrimary: Colors.white,
              surface: Color(0xFF1E1A2E), onSurface: Colors.white), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1A1A1A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  // ── Height card ───────────────────────────────────────────────────────────
  Widget _buildHeightCard() {
    final ft = (_heightCm / 30.48).floor();
    final inch = ((_heightCm / 30.48 - ft) * 12).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.straighten_rounded, color: _purple, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Height', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text('$_heightCm cm  ($ft\'$inch")',
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ])),
        ]),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _purple, inactiveTrackColor: _purple.withValues(alpha: 0.15),
            thumbColor: _purple, overlayColor: _purple.withValues(alpha: 0.15), trackHeight: 4,
          ),
          child: Slider(value: _heightCm.toDouble(), min: 140, max: 220, divisions: 80,
              onChanged: (v) => setState(() => _heightCm = v.toInt())),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('140 cm', style: TextStyle(color: Colors.white24, fontSize: 11)),
            Text('220 cm', style: TextStyle(color: Colors.white24, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Widget _buildLocationField() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _locationFocus.hasFocus ? _purple.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
            width: _locationFocus.hasFocus ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_on_outlined, color: _green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _locationCtrl, focusNode: _locationFocus,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              cursorColor: _purple, onTap: () => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none, hintText: 'Search suburb or city…',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 15),
                isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_isSearchingLocation)
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _purple))
          else if (_locationCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () { _locationCtrl.clear(); setState(() => _locationSuggestions = []); },
              child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18),
            ),
        ]),
      ),
      if (_locationSuggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: _card2, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _purple.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: _locationSuggestions.asMap().entries.map((e) {
                final r = e.value;
                return GestureDetector(
                  onTap: () => _selectLocation(r),
                  behavior: HitTestBehavior.opaque,
                  child: Column(children: [
                    if (e.key > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(width: 30, height: 30,
                          decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.location_on_outlined, color: _green, size: 15),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(r.display,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
      if (_locationCtrl.text.isNotEmpty && _locationSuggestions.isEmpty && !_isSearchingLocation)
        const Padding(
          padding: EdgeInsets.only(top: 8, left: 4),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: Colors.white24, size: 13),
            SizedBox(width: 6),
            Text('Searching Australian locations only', style: TextStyle(color: Colors.white24, fontSize: 11)),
          ]),
        ),
    ]);
  }

  // ── Interests grid ────────────────────────────────────────────────────────
  Widget _buildInterestsGrid() {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8,
      childAspectRatio: 3.2,
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
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: isSelected ? _purple.withValues(alpha: 0.13) : _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _purple.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.07),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: _purple.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                  color: isSelected ? _purple.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(meta.icon, color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55), size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(meta.label, maxLines: 2,
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3))),
              if (isSelected)
                Container(width: 17, height: 17,
                  decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _saveButton() => GestureDetector(
    onTap: _isSaving ? null : _save,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: _isSaving ? null : const LinearGradient(colors: [_purple, _purple2]),
        color: _isSaving ? _card : null,
        borderRadius: BorderRadius.circular(30),
        boxShadow: _isSaving ? [] : [BoxShadow(color: _purple.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Center(
        child: _isSaving
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      ),
    ),
  );
}
