import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isSmsEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSmsEnabled = prefs.getBool('isSmsEnabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleSmsSync(bool value) async {
    if (value) {
      // Request native SMS/Phone permissions before enabling
      final bool? granted = await Telephony.instance.requestPhoneAndSmsPermissions;
      if (granted != true) {
        // Permission denied — don't turn on the switch
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("SMS permission denied. Please allow it in Settings."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSmsEnabled', value);
    setState(() {
      _isSmsEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? "✅ SMS Sync enabled!" : "SMS Sync disabled."),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.neonCyan.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.sms_outlined, color: AppTheme.neonCyan),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "SMS Sync & Reading",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Allow FinePocket to read bank notifications",
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isSmsEnabled,
                              onChanged: _toggleSmsSync,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppTheme.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Automatically deducts expenses when your bank texts you. FinePocket intercepts the SMS locally and updates your Safe Balance instantly. No bank login required.",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "SMS is read entirely on-device. Your messages are never stored or sent anywhere.",
                            style: TextStyle(color: Colors.amber.withOpacity(0.9), fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
