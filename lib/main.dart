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
  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = !prefs.containsKey('monthlyIncome');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceState()),
      ],
      child: FinePocketApp(isFirstTime: isFirstTime),
    ),
  );
}

class FinePocketApp extends StatelessWidget {
  final bool isFirstTime;
  const FinePocketApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinePocket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(child: CircularProgressIndicator(color: AppTheme.neonCyan)),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return isFirstTime ? const BaselineScreen() : const DashboardScreen();
          }

          return const LoginScreen();
        }
      ),
    );
  }
}

