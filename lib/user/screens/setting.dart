import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/login_screen.dart';
import '../../shared/screen/notification_page.dart';
import 'edit_profile_page.dart';
import 'help_support_page.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _CustomerSettingsState();
}

class _CustomerSettingsState extends State<Setting> {
  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xfff4eff5);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color titleColor = Color(0xff284a79);

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MyLogin()),
          (_) => false,
    );
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationPage()),
    );
  }

  void _openHelpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpSupportPage()),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 16,
        left: 18,
        right: 18,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff326178), Color(0xffdff1fc)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor ?? Colors.black87,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _buildTopHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSettingTile(
                  icon: Icons.person_outline,
                  title: "Edit Profile",
                  subtitle: "Update your personal information",
                  onTap: _openEditProfile,
                  iconColor: primary,
                ),
                _buildSettingTile(
                  icon: Icons.notifications_none,
                  title: "Notifications",
                  subtitle: "View your app notifications",
                  onTap: _openNotifications,
                  iconColor: const Color(0xff5b8def),
                ),
                _buildSettingTile(
                  icon: Icons.help_outline,
                  title: "Help & Support",
                  subtitle: "Contact admin and get help",
                  onTap: _openHelpSupport,
                  iconColor: const Color(0xff7c5ac7),
                ),
                const SizedBox(height: 10),
                _buildSettingTile(
                  icon: Icons.logout,
                  title: "Logout",
                  subtitle: "Sign out from your account",
                  onTap: _logout,
                  iconColor: Colors.red,
                  textColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}