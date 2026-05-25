import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding/profile_details_screen.dart';
import 'screens/splash_screen.dart';

// ── Global theme notifier — read / written from SettingsScreen ───────────────
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Restore saved preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? true;
  appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const MatchXApp());
}

final supabase = Supabase.instance.client;

class MatchXApp extends StatelessWidget {
  const MatchXApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'MatchX',
        debugShowCheckedModeBanner: false,
        themeMode: mode,

        // ── Dark theme (original) ──────────────────────────────────────────
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF6C3FE8),
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C3FE8),
            secondary: Color(0xFF9D50BB),
            surface: Color(0xFF1A1A1A),
          ),
          fontFamily: 'Inter',
          cardColor: const Color(0xFF1A1A1A),
          dividerColor: Colors.white12,
        ),

        // ── Light theme ────────────────────────────────────────────────────
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF6C3FE8),
          scaffoldBackgroundColor: const Color(0xFFF2F2F7),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6C3FE8),
            secondary: Color(0xFF9D50BB),
            surface: Color(0xFFFFFFFF),
          ),
          fontFamily: 'Inter',
          cardColor: Colors.white,
          dividerColor: Colors.black12,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF2F2F7),
            foregroundColor: Color(0xFF0A0A0A),
            elevation: 0,
          ),
        ),

        home: const SplashScreen(),
      ),
    );
  }
}

/// Checks auth state on startup and routes to the right screen:
/// - Not logged in           → LoginScreen
/// - Logged in, no profile   → ProfileDetailsScreen (finish onboarding)
/// - Logged in, profile done → MainNavigation (home)
class SplashRouter extends StatefulWidget {
  const SplashRouter({Key? key}) : super(key: key);

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  Timer? _forceNavTimer;

  @override
  void initState() {
    super.initState();
    // Hard fallback: no matter what, navigate away after 5 seconds
    _forceNavTimer = Timer(const Duration(seconds: 5), () {
      _go(const LoginScreen());
    });
    _route();
  }

  @override
  void dispose() {
    _forceNavTimer?.cancel();
    super.dispose();
  }

  Future<void> _route() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      // Not logged in → show login
      _go(const LoginScreen());
      return;
    }

    // Logged in — check whether onboarding is complete
    try {
      final profile = await supabase
          .from('profiles')
          .select('profile_completed')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      final done = profile?['profile_completed'] == true;
      _go(done ? const MainNavigation() : const ProfileDetailsScreen());
    } catch (_) {
      // If check fails or times out, fall back to login to be safe
      _go(const LoginScreen());
    }
  }

  bool _navigated = false;

  void _go(Widget screen) {
    if (_navigated) return;
    _navigated = true;
    _forceNavTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple branded splash while routing
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MATCH',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'XP',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6C3FE8),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF6C3FE8)),
          ],
        ),
      ),
    );
  }
}
