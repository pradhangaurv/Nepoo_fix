import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xffffffff);
  static const Color borderColor = Color(0xffe3dce8);

  static const String adminName = 'Admin Support';
  static const String adminPhone = '+977 9813134585';
  static const String adminEmail = 'supportservice@gmail.com';
  static const String adminWhatsApp = '+977 9813134585';
  static const String officeHours = 'Sun - Fri, 9:00 AM - 6:00 PM';

  void _copyText(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
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
              'Help & Support',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xff284a79),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        bool canCopy = false,
        Color color = primary,
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
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(value),
        trailing: canCopy
            ? IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () => _copyText(context, value, title),
        )
            : null,
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
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'If you have any problem with booking, account, payment, or app usage, contact the admin below.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _infoTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Admin Name',
                  value: adminName,
                ),
                _infoTile(
                  context,
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  value: adminPhone,
                  canCopy: true,
                  color: const Color(0xff5b8def),
                ),
                _infoTile(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: adminEmail,
                  canCopy: true,
                  color: const Color(0xff7c5ac7),
                ),
                _infoTile(
                  context,
                  icon: Icons.chat_outlined,
                  title: 'WhatsApp',
                  value: adminWhatsApp,
                  canCopy: true,
                  color: Colors.green,
                ),
                _infoTile(
                  context,
                  icon: Icons.access_time,
                  title: 'Office Hours',
                  value: officeHours,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}