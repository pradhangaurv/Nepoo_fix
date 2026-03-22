import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_dash.dart';
import '../provider/provider_bottomnav.dart';
import '../provider/screens/provider_setup.dart';
import '../user/bottomnav.dart';
import 'login_screen.dart';
import 'pending_approval.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool _hasText(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  bool _hasValidPrice(dynamic value) {
    if (value == null) return false;
    if (value is num) return value > 0;
    final parsed = double.tryParse(value.toString());
    return parsed != null && parsed > 0;
  }

  Future<Widget> _route() async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;

    final user = auth.currentUser;
    if (user == null) return const MyLogin();

    final snap = await db.collection('users').doc(user.uid).get();

    if (!snap.exists || snap.data() == null) {
      await auth.signOut();
      return const MyLogin();
    }

    final data = snap.data()!;
    final role = (data['role'] ?? 'user').toString();
    final approved = (data['approved'] ?? false) == true;
    final blocked = (data['blocked'] ?? false) == true;

    if (blocked) {
      await auth.signOut();
      return const BlockedScreen();
    }

    if (role == 'admin') {
      return const AdminDash();
    }

    if (role == 'provider') {
      if (!approved) {
        return const PendingApprovalScreen();
      }

      final setupComplete = (data['setupComplete'] ?? false) == true;
      final serviceType = data['serviceType'];
      final serviceDescription = data['serviceDescription'];
      final pricePerHour = data['pricePerHour'];

      final profileComplete = setupComplete &&
          _hasText(serviceType) &&
          _hasText(serviceDescription) &&
          _hasValidPrice(pricePerHour);

      if (!profileComplete) {
        return const ProviderSetupScreen();
      }

      return const ProviderBottomNav();
    }

    return const BottomNav();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _route(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data ?? const MyLogin();
      },
    );
  }
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64),
              const SizedBox(height: 16),
              const Text(
                "Your account is blocked.\nContact admin/support.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MyLogin()),
                        (_) => false,
                  );
                },
                child: const Text("Back to Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}