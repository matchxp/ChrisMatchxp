import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/matchxp_background.dart';

class BiometricsScreen extends StatefulWidget {
  const BiometricsScreen({Key? key}) : super(key: key);
  @override
  State<BiometricsScreen> createState() => _BiometricsScreenState();
}

class _BiometricsScreenState extends State<BiometricsScreen>
    with SingleTickerProviderStateMixin {
  static const _bg      = Color(0xFF0C0B11);
  static const _purple  = Color(0xFF6C3FE8);
  static const _purple2 = Color(0xFF9D50BB);

  bool _faceIdEnabled      = false;
  bool _fingerprintEnabled = false;
  bool _isScanning         = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _simulateScan(String type) async {
    HapticFeedback.mediumImpact();
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    HapticFeedback.heavyImpact();
    setState(() {
      _isScanning = false;
      if (type == 'face')   _faceIdEnabled      = true;
      if (type == 'finger') _fingerprintEnabled = true;
    });
    _snack('${type == 'face' ? 'Face ID' : 'Fingerprint'} enabled!', color: _purple);
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: color ?? const Color(0xFF1A1228),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    // Hero icon
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Transform.scale(
                          scale: _isScanning ? _pulseAnim.value : 1.0,
                          child: Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                _purple.withOpacity(0.3),
                                _purple2.withOpacity(0.15),
                              ]),
                              border: Border.all(
                                color: _isScanning ? _purple : _purple.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Icon(Icons.fingerprint, size: 64,
                                color: _isScanning ? _purple : Colors.white54),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(_isScanning ? 'Scanning…' : 'Biometric Login',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            color: _isScanning ? _purple : Colors.white,
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Log in faster and more securely\nusing your device biometrics.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            color: Colors.white54, fontSize: 13, height: 1.5)),
                    const SizedBox(height: 32),

                    _biometricCard(
                      icon: Icons.face_retouching_natural,
                      title: 'Face ID',
                      subtitle: 'Unlock using your face',
                      enabled: _faceIdEnabled,
                      onToggle: (v) {
                        if (v) { _simulateScan('face'); }
                        else { setState(() => _faceIdEnabled = false); _snack('Face ID disabled'); }
                      },
                    ),
                    const SizedBox(height: 10),
                    _biometricCard(
                      icon: Icons.fingerprint,
                      title: 'Fingerprint',
                      subtitle: 'Unlock using your fingerprint',
                      enabled: _fingerprintEnabled,
                      onToggle: (v) {
                        if (v) { _simulateScan('finger'); }
                        else { setState(() => _fingerprintEnabled = false); _snack('Fingerprint disabled'); }
                      },
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _purple.withOpacity(0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Biometric data is stored securely on your device and is never shared with MatchXP servers.',
                              style: GoogleFonts.outfit(
                                  color: Colors.white54, fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text('Add Biometrics', textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _biometricCard({required IconData icon, required String title,
      required String subtitle, required bool enabled,
      required ValueChanged<bool> onToggle}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? _purple : _purple.withOpacity(0.42),
            width: enabled ? 2.0 : 1.0,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: enabled ? _purple.withOpacity(0.15) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: enabled ? _purple : Colors.white38, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
          ])),
          Switch(
            value: enabled, onChanged: onToggle,
            activeThumbColor: Colors.white, activeTrackColor: _purple,
            inactiveThumbColor: Colors.white38, inactiveTrackColor: Colors.white12,
          ),
        ]),
      );
}
