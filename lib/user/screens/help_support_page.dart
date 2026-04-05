import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

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

  Widget _infoTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        bool canCopy = false,
      }) {
    final color = Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
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
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
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
          ),
          _infoTile(
            context,
            icon: Icons.email_outlined,
            title: 'Email',
            value: adminEmail,
            canCopy: true,
          ),
          _infoTile(
            context,
            icon: Icons.chat_outlined,
            title: 'WhatsApp',
            value: adminWhatsApp,
            canCopy: true,
          ),
          _infoTile(
            context,
            icon: Icons.access_time,
            title: 'Office Hours',
            value: officeHours,
          ),
        ],
      ),
    );
  }
}