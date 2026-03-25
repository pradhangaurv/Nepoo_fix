import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/login_screen.dart';
import '../../shared/screen/select_location_map.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyLogin()),
          (_) => false,
    );
  }

  Future<void> _openMapTest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectLocationMapPage(),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      final latitude = result['latitude'];
      final longitude = result['longitude'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lat: $latitude, Lng: $longitude'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openMapTest,
                icon: const Icon(Icons.map),
                label: const Text("Test Google Map"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}