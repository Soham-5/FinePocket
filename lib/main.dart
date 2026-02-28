import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'state/finance_state.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/baseline_screen.dart';
import 'screens/login_screen.dart';
import 'screens/guest_name_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceState()),
      ],
      child: const FinePocketApp(),
    ),
  );
}

class FinePocketApp extends StatelessWidget {
  const FinePocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinePocket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, prefsSnapshot) {
        if (!prefsSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.neonCyan,
              ),
            ),
          );
        }

        final prefs = prefsSnapshot.data!;
        final guestName = prefs.getString('guestName');
        final baselineComplete =
            prefs.getBool('baselineComplete') ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppTheme.background,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.neonCyan,
                  ),
                ),
              );
            }

            final firebaseUser = authSnapshot.data;

            // 🔹 CASE 1: Logged-in Firebase user
            if (firebaseUser != null) {
              return baselineComplete
                  ? const DashboardScreen()
                  : const BaselineScreen();
            }

            // 🔹 CASE 2: Guest user
            if (guestName != null) {
              return baselineComplete
                  ? const DashboardScreen()
                  : const BaselineScreen();
            }

            // 🔹 CASE 3: Brand new user → SHOW LOGIN
            return const LoginScreen();

          },
        );
      },
    );
  }
}
