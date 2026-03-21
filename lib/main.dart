import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding/profile_details_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MatchXApp());
}

final supabase = Supabase.instance.client;

class MatchXApp extends StatelessWidget {
  const MatchXApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatchX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C3FE8),
        scaffoldBackgroundColor: const Color(0xFF0A0021),
        fontFamily: 'Inter',
      ),
      home: const SplashRouter(),
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
  @override
  void initState() {
    super.initState();
    _route();
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
          .maybeSingle();

      final done = profile?['profile_completed'] == true;
      _go(done ? const MainNavigation() : const ProfileDetailsScreen());
    } catch (_) {
      // If check fails, fall back to login to be safe
      _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
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
