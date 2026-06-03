import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'full_profile_screen.dart';

/// Shows the current user's own profile exactly as other users see it.
/// Reuses [FullProfileScreen] with [isPreview] = true so the superlike
/// button, flag icon, and swipe gestures are all hidden.
class PreviewProfileScreen extends StatefulWidget {
  const PreviewProfileScreen({super.key});

  @override
  State<PreviewProfileScreen> createState() => _PreviewProfileScreenState();
}

class _PreviewProfileScreenState extends State<PreviewProfileScreen> {
  static const _bg     = Color(0xFF0C0B11);
  static const _purple = Color(0xFF6C3FE8);

  bool _loading = true;
  Map<String, dynamic>? _mapped;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndMap();
  }

  // ── Fetch + map ─────────────────────────────────────────────────────────────

  Future<void> _loadAndMap() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() { _error = 'Not signed in.'; _loading = false; });
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data == null) {
        if (mounted) setState(() { _error = 'Profile not found.'; _loading = false; });
        return;
      }

      if (mounted) setState(() { _mapped = _mapProfile(data); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Safely reads a String field — returns '' if the value is not a String
  /// (guards against Supabase returning List or other types).
  String _str(Map<String, dynamic> p, String key) {
    final v = p[key];
    return v is String ? v : '';
  }

  /// Safely reads a List<String> field.
  List<String> _lst(Map<String, dynamic> p, String key) {
    final v = p[key];
    return v is List ? v.whereType<String>().toList() : <String>[];
  }

  /// Converts a Supabase profiles row into the shape [FullProfileScreen] expects.
  Map<String, dynamic> _mapProfile(Map<String, dynamic> p) {
    // ── Name ──
    final name = '${_str(p, "first_name")} ${_str(p, "last_name")}'.trim();

    // ── Photos ──
    final images = _lst(p, 'photos');

    // ── Height → feet/inches display string ──
    final heightCm = (p['height_cm'] as num?)?.toInt();
    String heightStr = '';
    if (heightCm != null && heightCm > 0) {
      final totalInches = (heightCm / 2.54).round();
      final feet   = totalInches ~/ 12;
      final inches = totalInches % 12;
      heightStr = "$feet'$inches\"";
    }

    return {
      'images':           images,
      'name':             name,
      'age':              (p['age'] as num?)?.toInt() ?? 0,
      'location':         _str(p, 'location'),
      'distance':         '',
      'bio':              _str(p, 'bio'),
      'gender':           _str(p, 'gender'),
      'height':           heightStr,
      'zodiac':           _str(p, 'zodiac'),
      'drinking_habit':   _str(p, 'drinking_habit'),
      'smoking_habit':    _str(p, 'smoking_habit'),
      'workout_habit':    _str(p, 'workout_habit'),
      'pets':             _str(p, 'pets'),
      'interests':        _lst(p, 'interests'),
      'looking_for':      _lst(p, 'looking_for'),
      'photo_captions':   <String>[],
      'featured_photo':   images.isNotEmpty ? images[0] : '',
      'featured_caption': '',
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(
          child: CircularProgressIndicator(color: _purple),
        ),
      );
    }

    if (_error != null || _mapped == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            _error ?? 'Could not load profile.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FullProfileScreen(
      profile: _mapped!,
      isPreview: true,
      // No like/pass/superlike callbacks — preview only
    );
  }
}
