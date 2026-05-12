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
import 'services/firestore_service.dart';
import 'models/user_model.dart';


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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        final firebaseUser = authSnapshot.data;

        // ─────────────────────────────────────────────────────────
        // 🔹 CASE 1: Signed-in Firebase user (Google / Phone)
        // ─────────────────────────────────────────────────────────
        if (firebaseUser != null && !firebaseUser.isAnonymous) {
          return FutureBuilder<void>(
            future: _firestoreService.migrateLocalToCloud(),
            builder: (context, migrationSnapshot) {
              if (migrationSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const _LoadingScaffold();
              }

              // After migration attempt, stream Firestore for real-time data
              return StreamBuilder<UserModel?>(
                stream: _firestoreService.streamUserStats(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _LoadingScaffold();
                  }

                  final userData = userSnapshot.data;
                  // If cloud doc exists and has a budget set, baseline is done
                  final bool baselineDone =
                      userData != null && userData.baselineBudget > 0;

                  return baselineDone
                      ? const DashboardScreen()
                      : const BaselineScreen();
                },
              );
            },
          );
        }

        // ─────────────────────────────────────────────────────────
        // 🔹 CASE 2 & 3: Guest / Anonymous / No auth
        //    → Fall back to shared_preferences
        // ─────────────────────────────────────────────────────────
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, prefsSnapshot) {
            if (!prefsSnapshot.hasData) {
              return const _LoadingScaffold();
            }

            final prefs = prefsSnapshot.data!;
            // guest_name is the key written by GuestNameScreen
            final guestName = prefs.getString('guest_name') ??
                prefs.getString('guestName');
            final baselineComplete =
                prefs.getBool('baselineComplete') ?? false;

            // Anonymous Firebase user or local guest with a name set
            if (firebaseUser != null || guestName != null) {
              return baselineComplete
                  ? const DashboardScreen()
                  : const BaselineScreen();
            }

            // Brand-new user → show login
            return const LoginScreen();
          },
        );
      },
    );
  }
}

/// Reusable loading indicator matching the app theme.
class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppTheme.neonCyan,
        ),
      ),
    );
  }
}
