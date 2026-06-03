import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/matchxp_background.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  // ── Colour tokens ──────────────────────────────────────────────────────────
  static const _bg      = Color(0xFF0A0A0A);
  static const _card    = Color(0xFF1A1A1A);
  static const _card2   = Color(0xFF222222);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  // ── State ──────────────────────────────────────────────────────────────────
  String _hereTo     = 'Make New Friends';
  String _wantToMeet = 'Woman';
  double _ageMin     = 20;
  double _ageMax     = 35;
  String _language   = 'English';
  final _locationCtrl  = TextEditingController();
  final _locationFocus = FocusNode();
  double _distance     = 10;
  List<String> _lookingFor  = [];
  List<String> _connectWith = [];

  // ── Location autocomplete ──────────────────────────────────────────────────
  List<_LocationResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _suppressSearch = false; // prevents re-search on programmatic text set
  Timer? _debounce;

  // ── Options ────────────────────────────────────────────────────────────────
  static const _hereToOptions = [
    _Option('Make New Friends',         Icons.people_outline_rounded),
    _Option('Something Casual',         Icons.wb_sunny_outlined),
    _Option('A Long-Term Relationship', Icons.favorite_outline_rounded),
    _Option('Not Sure Yet',             Icons.help_outline_rounded),
  ];
  static const _meetOptions = [
    _Option('Woman',    Icons.female_rounded),
    _Option('Man',      Icons.male_rounded),
    _Option('Non-binary', Icons.people_alt_outlined),
  ];
  static const _langOptions = [
    _Option('English',    Icons.language_rounded),
    _Option('Spanish',    Icons.language_rounded),
    _Option('French',     Icons.language_rounded),
    _Option('German',     Icons.language_rounded),
    _Option('Arabic',     Icons.language_rounded),
    _Option('Mandarin',   Icons.language_rounded),
    _Option('Hindi',      Icons.language_rounded),
    _Option('Portuguese', Icons.language_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _locationCtrl.addListener(_onLocationChanged);
    // Delay hiding suggestions so a tap on a result registers first
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
    _locationCtrl.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  // ── Nominatim location search ──────────────────────────────────────────────

  void _onLocationChanged() {
    if (_suppressSearch) return; // skip when we set text programmatically
    final q = _locationCtrl.text.trim();
    if (q.length < 3) {
      setState(() => _locationSuggestions = []);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchAU(q));
  }

  Future<void> _searchAU(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingLocation = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&countrycodes=au'
        '&format=json'
        '&limit=6'
        '&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'MatchXP/1.0 (matchxp.app)',
        'Accept-Language': 'en',
      });
      if (!mounted) return;
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _locationSuggestions = data.map((item) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            // Build a short human-friendly label
            final suburb = addr['suburb'] ?? addr['town'] ?? addr['village'] ?? '';
            final city   = addr['city'] ?? addr['county'] ?? '';
            final state  = addr['state'] ?? '';
            final parts  = [suburb, city, state]
                .where((s) => (s as String).isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
            final short = parts.take(3).join(', ');
            return _LocationResult(
              display: short.isNotEmpty ? short : (item['display_name'] as String),
              full: item['display_name'] as String,
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
    _locationCtrl.selection =
        TextSelection.collapsed(offset: r.display.length);
    _suppressSearch = false;
    setState(() => _locationSuggestions = []);
    _locationFocus.unfocus();
  }

  // ── Data loading / saving ──────────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final p = await _supabase
          .from('profiles')
          .select('here_to, want_to_meet, pref_age_range, '
              'pref_language, location, max_distance_km, '
              'looking_for, connect_with')
          .eq('id', uid)
          .maybeSingle();
      if (p == null || !mounted) return;
      setState(() {
        _hereTo     = _safe(p['here_to'],       _hereToOptions, 'Make New Friends');
        _wantToMeet = _safe(p['want_to_meet'],  _meetOptions,   'Woman');
        _language   = _safe(p['pref_language'], _langOptions,   'English');
        final raw = p['pref_age_range'] as String? ?? '20 - 35';
        final parts = raw.split(' - ');
        _ageMin = double.tryParse(parts.first.trim()) ?? 20;
        _ageMax = double.tryParse(parts.last.trim())  ?? 35;
        _locationCtrl.text = (p['location'] as String?) ?? '';
        _distance   = (p['max_distance_km'] as num?)?.toDouble() ?? 10;
        final lf = p['looking_for'];
        if (lf is List) _lookingFor = List<String>.from(lf);
        else if (lf is String && lf.isNotEmpty) _lookingFor = [lf];
        final cw = p['connect_with'];
        if (cw is List) _connectWith = List<String>.from(cw);
        else if (cw is String && cw.isNotEmpty) _connectWith = [cw];
      });
    } catch (_) {}
  }

  String _safe(dynamic raw, List<_Option> opts, String fallback) {
    final s = raw as String?;
    return (s != null && opts.any((o) => o.label == s)) ? s : fallback;
  }

  Future<void> _applyFilters() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.from('profiles').update({
        'here_to':         _hereTo,
        'want_to_meet':    _wantToMeet,
        'pref_age_range':  '${_ageMin.round()} - ${_ageMax.round()}',
        'pref_language':   _language,
        'location':        _locationCtrl.text.trim(),
        'max_distance_km': _distance.round(),
        'looking_for':     _lookingFor,
        'connect_with':    _connectWith,
        'updated_at':      DateTime.now().toIso8601String(),
      }).eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Preferences saved!'),
          backgroundColor: _purple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: const Color(0xFFFF3B60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetDefaults() {
    HapticFeedback.mediumImpact();
    _debounce?.cancel();
    _suppressSearch = true;
    _locationCtrl.clear();
    _suppressSearch = false;
    setState(() {
      _hereTo      = 'Make New Friends';
      _wantToMeet  = 'Woman';
      _ageMin      = 20;
      _ageMax      = 35;
      _language    = 'English';
      _locationSuggestions = [];
      _distance    = 10;
      _lookingFor  = [];
      _connectWith = [];
    });
  }

  void _showPicker({
    required String title,
    required List<_Option> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        title: title,
        options: options,
        selected: selected,
        onSelect: (val) {
          HapticFeedback.selectionClick();
          onSelect(val);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B11),
      body: MatchXPBackground(
        child: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),

                  _sectionLabel('What are you here for?'),
                  const SizedBox(height: 12),
                  _buildHereToGrid(),
                  const SizedBox(height: 24),

                  _sectionLabel('Want to meet'),
                  const SizedBox(height: 12),
                  _buildMeetPills(),
                  const SizedBox(height: 24),

                  _sectionLabel('Preferred age range'),
                  const SizedBox(height: 12),
                  _buildAgeRangeCard(),
                  const SizedBox(height: 24),

                  _sectionLabel('Language'),
                  const SizedBox(height: 12),
                  _buildLanguageTrigger(),
                  const SizedBox(height: 24),

                  _sectionLabel('Location'),
                  const SizedBox(height: 12),
                  _buildLocationCard(),
                  const SizedBox(height: 24),

                  _sectionLabel('Max distance'),
                  const SizedBox(height: 12),
                  _buildDistanceCard(),
                  const SizedBox(height: 32),

                  _applyButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _resetDefaults,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.withOpacity(0.42)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded,
                    color: Colors.white38, size: 14),
                SizedBox(width: 5),
                Text('Reset',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        'Your Preferences',
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
        'Fine-tune who and what you see',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: Colors.white.withOpacity(0.50),
        ),
      ),
    ],
  );

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700));

  // ── Here to (2×2 grid) ─────────────────────────────────────────────────────

  Widget _buildHereToGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _hereToOptions.map((opt) {
        final selected = _hereTo == opt.label;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _hereTo = opt.label);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: selected
                  ? _purple.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: selected ? _purple : _purple.withOpacity(0.42),
                width: selected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: _purple, shape: BoxShape.circle),
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

  // ── Want to Meet (3 pill cards) ────────────────────────────────────────────

  Widget _buildMeetPills() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _meetOptions.map((opt) {
        final selected = _wantToMeet == opt.label;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _wantToMeet = opt.label);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: selected
                  ? _purple.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: selected ? _purple : _purple.withOpacity(0.42),
                width: selected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: _purple, shape: BoxShape.circle),
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

  // ── Age range ──────────────────────────────────────────────────────────────

  Widget _buildAgeRangeCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_ageMin.round()} – ${_ageMax.round()}',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purple2]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_ageMin.round()} – ${_ageMax.round()}',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _purple,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: _purple.withOpacity(0.15),
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            trackHeight: 3,
            valueIndicatorColor: _purple,
            valueIndicatorTextStyle:
                GoogleFonts.outfit(color: Colors.white, fontSize: 12),
          ),
          child: RangeSlider(
            values: RangeValues(_ageMin, _ageMax),
            min: 18,
            max: 80,
            divisions: 62,
            labels: RangeLabels('${_ageMin.round()}', '${_ageMax.round()}'),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() {
                _ageMin = v.start;
                _ageMax = v.end;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('18', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11)),
              Text('80', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Language pill trigger + wrap bottom sheet ──────────────────────────────

  Widget _buildLanguageTrigger() {
    return GestureDetector(
      onTap: _showLanguagePicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: _purple.withOpacity(0.42), width: 1.0),
        ),
        child: Row(
          children: [
            Text('Preferred Language',
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
            const Spacer(),
            Text(_language,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_purple, _purple2],
                ).createShader(b),
                child: Text('Preferred Language',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _langOptions.map((opt) {
                  final selected = _language == opt.label;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _language = opt.label);
                      setSheet(() {});
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: selected
                            ? _purple.withOpacity(0.12)
                            : Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: selected ? _purple : _purple.withOpacity(0.42),
                          width: selected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(opt.label,
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                  color: _purple, shape: BoxShape.circle),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Generic picker row (unused for language now) ───────────────────────────

  Widget _buildPickerRow({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _purple.withOpacity(0.42)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _purple, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white30, size: 22),
            ],
          ),
        ),
      );

  // ── Location card with Nominatim autocomplete ──────────────────────────────

  Widget _buildLocationCard() {
    return Column(
      children: [
        // Input field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: _locationFocus.hasFocus ? _purple : _purple.withOpacity(0.42),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_outlined,
                    color: Color(0xFF4CAF50), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _locationCtrl,
                  focusNode: _locationFocus,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  cursorColor: _purple,
                  onTap: () => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search suburb or city…',
                    hintStyle:
                        TextStyle(color: Colors.white30, fontSize: 15),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_isSearchingLocation)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _purple),
                )
              else if (_locationCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _locationCtrl.clear();
                    setState(() => _locationSuggestions = []);
                  },
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white30, size: 18),
                ),
            ],
          ),
        ),

        // Suggestions dropdown
        if (_locationSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _purple.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: _locationSuggestions
                    .asMap()
                    .entries
                    .map((entry) {
                  final idx = entry.key;
                  final r   = entry.value;
                  return GestureDetector(
                    onTap: () => _selectLocation(r),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        if (idx > 0)
                          Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white
                                  .withValues(alpha: 0.05)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFF4CAF50),
                                    size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(r.display,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Australian only hint
        if (_locationCtrl.text.isNotEmpty &&
            _locationSuggestions.isEmpty &&
            !_isSearchingLocation)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white24, size: 13),
                SizedBox(width: 6),
                Text('Searching Australian locations only',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }

  // ── Distance card ──────────────────────────────────────────────────────────

  Widget _buildDistanceCard() {
    final km = _distance.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                km >= 160 ? 'Anywhere in Australia' : '$km km away',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purple2]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                km >= 160 ? '∞' : '$km km',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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
            value: _distance,
            min: 1,
            max: 160,
            divisions: 32,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _distance = v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('1 km', style: TextStyle(color: Colors.white24, fontSize: 11)),
              Text('Anywhere', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Apply button ───────────────────────────────────────────────────────────

  Widget _applyButton() => GestureDetector(
    onTap: _isSaving
        ? null
        : () {
            HapticFeedback.mediumImpact();
            _applyFilters();
          },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        gradient: _isSaving
            ? LinearGradient(colors: [
                _purple.withValues(alpha: 0.5),
                _purple2.withValues(alpha: 0.5)
              ])
            : const LinearGradient(colors: [_purple, _purple2]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: _purple.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: _isSaving
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          : Text('Save Preferences',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
    ),
  );
}

// ── Data models ────────────────────────────────────────────────────────────────

class _Option {
  final String   label;
  final IconData icon;
  const _Option(this.label, this.icon);
}

class _LocationResult {
  final String  display;
  final String  full;
  final double? lat;
  final double? lon;
  const _LocationResult({
    required this.display,
    required this.full,
    this.lat,
    this.lon,
  });
}

// ── Bottom sheet picker ────────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final String             title;
  final List<_Option>      options;
  final String             selected;
  final ValueChanged<String> onSelect;

  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);
  static const _sheet   = Color(0xFF161616);

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [_purple, _purple2],
                  ).createShader(b),
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final isSelected = opt.label == selected;
            return GestureDetector(
              onTap: () => onSelect(opt.label),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _purple.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? _purple.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.07),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _purple.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(opt.icon,
                          color: isSelected
                              ? _purple
                              : Colors.white38,
                          size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(opt.label,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    ),
                    if (isSelected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_purple, _purple2]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
