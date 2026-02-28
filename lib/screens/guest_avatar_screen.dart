import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/route_transitions.dart';
import 'baseline_screen.dart';

class GuestAvatarScreen extends StatefulWidget {
  const GuestAvatarScreen({super.key});

  @override
  State<GuestAvatarScreen> createState() => _GuestAvatarScreenState();
}

class _GuestAvatarScreenState extends State<GuestAvatarScreen> {
  String? _imagePath;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null && mounted) {
      setState(() {
        _imagePath = pickedFile.path;
      });
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
                const Text("Choose an Avatar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishOnboarding() async {
    if (_imagePath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guestAvatar', _imagePath!);
    }
    
    // AuthGate naturally expects the baseline on first load, so we just push it over the naming screens.
    if (mounted) {
      Navigator.pushReplacement(context, createSlideRoute(const BaselineScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Give them a skip button if they don't want a photo
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              "Skip", 
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Add a Profile Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Put a face to the budget. Or don\'t.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              GestureDetector(
                onTap: _showImagePickerModal,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surface,
                    border: Border.all(
                      color: _imagePath == null ? Colors.white12 : AppTheme.neonCyan, 
                      width: 2
                    ),
                    image: _imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imagePath == null
                      ? const Icon(Icons.add_a_photo_outlined, size: 48, color: AppTheme.neonCyan)
                      : null,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _finishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _imagePath == null ? AppTheme.surface : AppTheme.neonCyan,
                    foregroundColor: _imagePath == null ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: _imagePath == null ? Colors.white24 : Colors.transparent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _imagePath == null ? 'I\'ll do it later' : 'Finish',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: _imagePath == null ? 0 : 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
