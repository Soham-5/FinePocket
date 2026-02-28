import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/goal.dart';
import '../state/finance_state.dart';
import '../screens/analytics_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/baseline_screen.dart';
import '../services/sms_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _hasSmsPermission = true;
  bool _isScanning = false;
  final SmsService _smsService = SmsService();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<FinanceState>(context, listen: false);
      _smsService.initSmsListener(state);
    });
  }

  Future<void> _checkPermissions() async {
    bool hasPerm = await _smsService.hasPermissions();
    setState(() {
      _hasSmsPermission = hasPerm;
    });
    if (hasPerm) {
      _smsService.listenToSms();
    }
  }

  Future<void> _requestPermissions() async {
    bool granted = await _smsService.requestPermissions();
    setState(() {
      _hasSmsPermission = granted;
    });
    if (granted) {
      final state = Provider.of<FinanceState>(context, listen: false);
      _smsService.initSmsListener(state);
    }
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeBody();
      case 1:
        return const AnalyticsScreen();
      case 2:
        return const ChatScreen();
      case 3:
        return const Center(child: Text("Friends/Social features coming soon", style: TextStyle(color: Colors.white)));
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Consumer<FinanceState>(
            builder: (context, state, child) {
              if (state.profilePhotoPath != null) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.neonCyan, width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundImage: FileImage(File(state.profilePhotoPath!)),
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.person_outline, size: 20),
              );
            },
          ),
        ),
        title: _currentIndex == 1
            ? const Text("Analytics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            : _currentIndex == 2
                ? Column(
                    children: [
                      const Text("Wingman Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, color: AppTheme.success, size: 8),
                          const SizedBox(width: 4),
                          Text("Online & Ready to Roast", style: TextStyle(fontSize: 10, color: AppTheme.success)),
                        ],
                      )
                    ],
                  )
                : _currentIndex == 4
                    ? const Text("Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("FinePocket", style: TextStyle(color: AppTheme.neonCyan, fontSize: 10)),
                          const Text("Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
        centerTitle: _currentIndex == 1 || _currentIndex == 2 || _currentIndex == 4,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
               decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: IconButton(
                icon: Icon(_currentIndex == 1 ? Icons.settings_outlined : Icons.delete_outline, size: 20, color: _currentIndex == 1 ? Colors.white : Colors.redAccent),
                onPressed: () {
                  if (_currentIndex != 1) {
                    _showResetDialog();
                  }
                },
              ),
            ),
          )
        ],
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text("Reset App Data?", style: TextStyle(color: Colors.white)),
          content: const Text("This will wipe all goals, income, and activity strictly returning you to the baseline setup.", style: TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final state = Provider.of<FinanceState>(context, listen: false);
                await state.resetApp();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BaselineScreen()), (route) => false);
                }
              },
              child: const Text("Nuke It", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  // ─── CASH SPEND DIALOG ────────────────────────────────────────────────────
  void _showCashSpendDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Log Cash Spend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "What did you spend on?",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.title, color: AppTheme.textSecondary),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter a title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Amount (₹)",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.textSecondary),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return "Enter a valid amount";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonCyan, foregroundColor: Colors.black),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(amountCtrl.text);
                Provider.of<FinanceState>(context, listen: false)
                    .addManualSpend(amount, titleCtrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("₹${amount.toStringAsFixed(0)} logged for \"${titleCtrl.text.trim()}\""),
                    backgroundColor: AppTheme.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text("Log Spend"),
          ),
        ],
      ),
    );
  }

  // ─── SKIP DAILY COMMUTE ────────────────────────────────────────────────────
  void _skipDailyCommute() {
    final state = Provider.of<FinanceState>(context, listen: false);
    if (state.dailyCommute <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No daily commute set in your Baseline."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    state.skipDailyCommute();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Commute skipped! ₹${state.dailyCommute.toStringAsFixed(0)} added back to Safe Balance 🎉"),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── SCAN RECEIPT ─────────────────────────────────────────────────────────
  Future<void> _scanReceipt() async {
    // Let user pick source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Scan Receipt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.neonCyan),
              title: const Text("📷 Camera", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.neonPurple),
              title: const Text("🖼️ Gallery", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;

    // Show loading dialog
    if (mounted) {
      setState(() => _isScanning = true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          backgroundColor: Color(0xFF1C1C2E),
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.neonCyan),
              SizedBox(width: 16),
              Text("Scanning receipt...", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final result = await _apiService.scanReceipt(base64Image);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() => _isScanning = false);

        if (result != null) {
          final amount = result['amount'] as double;
          final title = result['title'] as String;
          Provider.of<FinanceState>(context, listen: false).addManualSpend(amount, title);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Scanned: \"$title\" — ₹${amount.toStringAsFixed(0)} logged!"),
              backgroundColor: AppTheme.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Couldn't read the receipt. Try again with better lighting."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('SCAN ERROR: $e');
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🔌 Scan failed. Check server connection."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ─── HOME BODY ─────────────────────────────────────────────────────────────
  Widget _buildHomeBody() {
    return Consumer<FinanceState>(
      builder: (context, state, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_hasSmsPermission)
                GestureDetector(
                  onTap: _requestPermissions,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.neonPurple.withOpacity(0.1),
                      border: Border.all(color: AppTheme.neonPurple),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sms_failed_outlined, color: AppTheme.neonPurple),
                        const SizedBox(width: 8),
                        Text("Enable SMS Sync", style: TextStyle(color: AppTheme.neonPurple, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text("TOTAL SAFE BALANCE", style: TextStyle(color: AppTheme.neonCyan, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("₹", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(state.safeBalance.toStringAsFixed(0), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Text(".${(state.safeBalance.abs() % 1 * 100).toInt()}", style: const TextStyle(fontSize: 24, color: AppTheme.textSecondary)),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, color: AppTheme.neonCyan, size: 16),
                    const SizedBox(width: 8),
                    Text("+8.4% this week", style: TextStyle(color: AppTheme.neonCyan, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // ── GOALS ───────────────────────────────────────────────────
              if (state.goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: const Center(
                      child: Text("No active savings goals.\nSet one up in your Baseline!", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                )
              else
                ...state.goals.map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildGoalSection(goal),
                )),
              const SizedBox(height: 32),

              // ── ACTION BUTTONS ──────────────────────────────────────────
              _buildActionRow(),
              const SizedBox(height: 48),

              // ── RECENT ACTIVITY ─────────────────────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              if (state.recentActivity.isEmpty)
                Center(
                  child: Text("No recent activity. Scan a receipt or use Cash Spend!", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                ...state.recentActivity.reversed.take(8).map((activity) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: activity.isExpense ? Colors.redAccent.withOpacity(0.1) : AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              activity.isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                              color: activity.isExpense ? Colors.redAccent : AppTheme.success,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(activity.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(activity.category, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        "${activity.isExpense ? '-' : '+'}₹${activity.amount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: activity.isExpense ? Colors.redAccent : AppTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }


  // ─── GOAL CARD ─────────────────────────────────────────────────────────────
  Widget _buildGoalSection(Goal goal) {
    final progress = (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(goal.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              "₹${goal.savedAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}",
              style: TextStyle(color: AppTheme.neonCyan, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 30,
          width: double.infinity,
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.neonCyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${(progress * 100).toInt()}% saved", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text("Target: ${goal.monthsToAchieve} months", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  // ─── ACTION ROW ────────────────────────────────────────────────────────────
  Widget _buildActionRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildActionButton(Icons.money, "CASH\nSPEND", _showCashSpendDialog)),
        const SizedBox(width: 12),
        Expanded(child: _buildActionButton(Icons.qr_code_scanner, "SCAN", _isScanning ? null : _scanReceipt)),
        const SizedBox(width: 12),
        Expanded(child: _buildActionButton(Icons.directions_bike, "SKIP\nDAILY", _skipDailyCommute)),
        const SizedBox(width: 12),
        Expanded(child: _buildActionButton(Icons.bar_chart, "STATS", () => setState(() => _currentIndex = 1))),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    final isActive = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.surface : AppTheme.surface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? Colors.white24 : Colors.white10),
              ),
              child: Center(
                child: Icon(icon, color: isActive ? AppTheme.neonCyan : Colors.white24, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isActive ? AppTheme.textSecondary : Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
