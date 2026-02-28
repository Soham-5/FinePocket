import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonPurple.withOpacity(0.1),
                border: Border.all(color: AppTheme.neonPurple.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.shield_outlined, size: 64, color: AppTheme.neonPurple),
            ),
            const SizedBox(height: 32),
            const Text(
              "Soham's eyes are watching",
              style: TextStyle(
                color: AppTheme.neonPurple,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
