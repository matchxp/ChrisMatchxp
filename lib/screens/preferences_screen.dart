import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String _hereTo      = 'Make New Friends';
  String _wantToMeet  = 'Woman';
  String _ageRange    = '20 - 35';
  String _language    = 'English';
  final _locationCtrl  = TextEditingController();
  final _locationFocus = FocusNode();
  double _distance     = 10;

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
    _Option('Everyone', Icons.people_alt_outlined),
  ];
  static const _ageOptions = [
    _Option('18 - 24', Icons.cake_outlined),
    _Option('20 - 35', Icons.cake_outlined),
    _Option('25 - 35', Icons.cake_outlined),
    _Option('30 - 40', Icons.cake_outlined),
    _Option('35 - 50', Icons.cake_outlined),
    _Option('40+',     Icons.cake_outlined),
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
              'pref_language, location, max_distance_km')
          .eq('id', uid)
          .maybeSingle();
      if (p == null || !mounted) return;
      setState(() {
        _hereTo     = _safe(p['here_to'],        _hereToOptions, 'Make New Friends');
        _wantToMeet = _safe(p['want_to_meet'],   _meetOptions,   'Woman');
        _ageRange   = _safe(p['pref_age_range'], _ageOptions,    '20 - 35');
        _language   = _safe(p['pref_language'],  _langOptions,   'English');
        _locationCtrl.text = (p['location'] as String?) ?? '';
        _distance   = (p['max_distance_km'] as num?)?.toDouble() ?? 10;
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
        'pref_age_range':  _ageRange,
        'pref_language':   _language,
        'location':        _locationCtrl.text.trim(),
        'max_distance_km': _distance.round(),
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
      _hereTo              = 'Make New Friends';
      _wantToMeet          = 'Woman';
      _ageRange            = '20 - 35';
      _language            = 'English';
      _locationSuggestions = [];
      _distance            = 10;
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
      backgroundColor: _bg,
      body: SafeArea(
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
                    _buildPickerRow(
                      icon: Icons.language_rounded,
                      value: _language,
                      onTap: () => _showPicker(
                        title: 'Preferred Language(s)',
                        options: _langOptions,
                        selected: _language,
                        onSelect: (v) => setState(() => _language = v),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sectionLabel('Location & distance'),
                    const SizedBox(height: 12),
                  _buildLocationCard(),
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
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
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
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Colors.white, Color(0xFFCBB4FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(b),
            child: const Text('Preferences',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.withOpacity(0.3)),
            ),
            child: const Text('Discovery',
                style: TextStyle(
                    color: _purple,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Fine-tune who and what you see on MatchXP',
        style:
            TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
      ),
    ],
  );

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700));

  // ── Here to (2×2 grid) ─────────────────────────────────────────────────────

  static const _hereToMeta = [
    _HereToMeta('Make New Friends',         Icons.people_outline_rounded,   Color(0xFF6C3FE8)),
    _HereToMeta('Something Casual',         Icons.wb_sunny_outlined,        Color(0xFFFF9800)),
    _HereToMeta('A Long-Term Relationship', Icons.favorite_outline_rounded, Color(0xFFFF6B8A)),
    _HereToMeta('Not Sure Yet',             Icons.help_outline_rounded,     Color(0xFF00D4AA)),
  ];

  Widget _buildHereToGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: _hereToMeta.map((meta) {
        final selected = _hereTo == meta.label;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _hereTo = meta.label);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: selected
                  ? meta.color.withOpacity(0.13)
                  : _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? meta.color.withOpacity(0.65)
                    : Colors.white.withOpacity(0.07),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: meta.color.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: meta.color.withOpacity(selected ? 0.22 : 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(meta.icon,
                      color: selected ? meta.color : Colors.white30,
                      size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    meta.label,
                    maxLines: 2,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: 11.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.3),
                  ),
                ),
                if (selected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                        color: meta.color, shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 11),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Want to Meet (3 pill cards) ────────────────────────────────────────────

  static const _meetMeta = [
    _MeetMeta('Woman',    Icons.female_rounded,      Color(0xFFFF6B8A)),
    _MeetMeta('Man',      Icons.male_rounded,        Color(0xFF6C3FE8)),
    _MeetMeta('Everyone', Icons.people_alt_outlined, Color(0xFF00D4AA)),
  ];

  Widget _buildMeetPills() {
    return Row(
      children: List.generate(_meetMeta.length, (i) {
        final meta     = _meetMeta[i];
        final selected = _wantToMeet == meta.label;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < _meetMeta.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _wantToMeet = meta.label);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? meta.color.withOpacity(0.13)
                      : _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? meta.color.withOpacity(0.6)
                        : Colors.white.withOpacity(0.07),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(meta.icon,
                        color: selected ? meta.color : Colors.white24,
                        size: 24),
                    const SizedBox(height: 7),
                    Text(meta.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Age range ──────────────────────────────────────────────────────────────

  Widget _buildAgeRangeCard() {
    return GestureDetector(
      onTap: () => _showPicker(
        title: 'Preferred Age Range',
        options: _ageOptions,
        selected: _ageRange,
        onSelect: (v) => setState(() => _ageRange = v),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _purple.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.cake_outlined,
                  color: _purple, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Age range',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(_ageRange,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white30, size: 22),
          ],
        ),
      ),
    );
  }

  // ── Language picker ────────────────────────────────────────────────────────

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
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.12),
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
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _locationFocus.hasFocus
                  ? _purple.withOpacity(0.5)
                  : Colors.white.withOpacity(0.07),
              width: _locationFocus.hasFocus ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
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
              color: _card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _purple.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
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
                                  .withOpacity(0.05)),
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
                                      .withOpacity(0.1),
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
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: const [
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.radar_rounded,
                    color: _purple, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max distance',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      km >= 160 ? 'Anywhere in Australia' : '$km km away',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_purple, _purple2]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  km >= 160 ? '∞' : '$km km',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _purple,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: _purple.withOpacity(0.15),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 20),
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
                Text('1 km',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 11)),
                Text('Anywhere',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
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
                _purple.withOpacity(0.5),
                _purple2.withOpacity(0.5)
              ])
            : const LinearGradient(colors: [_purple, _purple2]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: _purple.withOpacity(0.4),
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
          : const Text('Save Preferences',
              textAlign: TextAlign.center,
              style: TextStyle(
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

class _HereToMeta {
  final String   label;
  final IconData icon;
  final Color    color;
  const _HereToMeta(this.label, this.icon, this.color);
}

class _MeetMeta {
  final String   label;
  final IconData icon;
  final Color    color;
  const _MeetMeta(this.label, this.icon, this.color);
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
                      ? _purple.withOpacity(0.15)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? _purple.withOpacity(0.6)
                        : Colors.white.withOpacity(0.07),
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
                            ? _purple.withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
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
