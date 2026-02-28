import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../state/finance_state.dart';
import '../theme/app_theme.dart';
import 'baseline_screen.dart';
import 'general_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'security_screen.dart';
import '../utils/route_transitions.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLogoutLoading = false;
  bool _isNukeLoading = false;
  String _displayName = "Alex Chen"; // Default

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    // Check if real Google user
    if (user != null && !user.isAnonymous && user.displayName != null && user.displayName!.isNotEmpty) {
      setState(() {
        _displayName = user.displayName!;
      });
      return;
    }

    // Check SharedPreferences if Guest
    final prefs = await SharedPreferences.getInstance();
    final guestName = prefs.getString('guest_name');
    if (guestName != null && guestName.isNotEmpty) {
      setState(() {
        _displayName = guestName;
      });
    } else {
        setState(() {
            _displayName = "Guest User";
        });
    }
  }

  Future<void> _handleNuke() async {
    Navigator.pop(context); // Close the dialog
    setState(() => _isNukeLoading = true);
    try {
      await DatabaseService().nukeUserData();
      // After nuking, also sign them out to clear local state
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('🔴 Nuke error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to nuke data: $e'),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNukeLoading = false);
      }
    }
  }

  void _showNukeConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Nuke Account Data?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to delete all cloud data? This cannot be undone.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: _handleNuke,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("NUKE IT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLogoutLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.isAnonymous == true) {
         // Wipe guest cache completely
         final prefs = await SharedPreferences.getInstance();
         await prefs.remove('guest_name');
         await prefs.remove('guestAvatar');
         // Nuke the anonymous cloud identity
         await user?.delete();
      }

      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const FinePocketApp(isFirstTime: false)), (route) => false);
      }
    } catch (e) {
      debugPrint('🔴 Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout: $e'),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLogoutLoading = false);
      }
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null && mounted) {
      Provider.of<FinanceState>(context, listen: false).updateProfilePhoto(pickedFile.path);
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Update Profile Picture", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppTheme.neonCyan),
                  title: const Text("📷 Camera", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppTheme.neonPurple),
                  title: const Text("🖼️ Gallery", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ]
            ),
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 32),
          _buildFinancialEngine(context),
          const SizedBox(height: 32),
          _buildSettingsSection(context),
          const SizedBox(height: 32),
          _buildLogoutButton(),
          const SizedBox(height: 16),
          _buildNukeButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Consumer<FinanceState>(
            builder: (context, state, child) {
              return Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _showImagePickerModal,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.neonCyan, width: 2),
                        image: state.profilePhotoPath != null
                            ? DecorationImage(
                                image: FileImage(File(state.profilePhotoPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: state.profilePhotoPath == null
                          ? const Icon(Icons.person_outline, size: 40, color: Colors.white70)
                          : null,
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.success, width: 3),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            FirebaseAuth.instance.currentUser?.isAnonymous == true ? "@guest_fin" : "@premium_fin",
            style: const TextStyle(fontSize: 14, color: AppTheme.neonCyan),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: AppTheme.success, size: 16),
                const SizedBox(width: 8),
                Text("Premium Member", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFinancialEngine(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Financial Engine", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Updated today", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Consumer<FinanceState>(
                builder: (context, state, child) {
                  if (state.goals.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text("No active goals — set one up in Baseline!", style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  return Column(
                    children: state.goals.map((goal) {
                      final progress = (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(Icons.bar_chart, color: AppTheme.neonCyan, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text("₹${goal.savedAmount.toInt()} / ₹${goal.targetAmount.toInt()}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text("${(progress * 100).toInt()}%", style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.neonCyan,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, createSlideRoute(const BaselineScreen()));
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Edit Baseline & Goals"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildSettingsTile(
                Icons.notifications_none, 
                "Notifications", 
                () => Navigator.push(context, createSlideRoute(const NotificationSettingsScreen()))
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildSettingsTile(
                Icons.tune, 
                "General Settings",
                () => Navigator.push(context, createSlideRoute(const GeneralSettingsScreen()))
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildSettingsTile(
                Icons.shield_outlined, 
                "Security",
                () => Navigator.push(context, createSlideRoute(const SecurityScreen()))
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLogoutLoading ? null : _handleLogout,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _isLogoutLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
  Widget _buildNukeButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.shade700),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isNukeLoading ? null : _showNukeConfirmationDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _isNukeLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text("Nuke Account Data", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
