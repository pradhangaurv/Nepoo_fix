import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/login_screen.dart';

class AdminDash extends StatelessWidget {
  const AdminDash({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyLogin()),
          (_) => false,
    );
  }

  Future<void> _toggleApproval(String uid, bool currentValue) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'approved': !currentValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleBlock(String uid, bool currentValue) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'blocked': !currentValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }

          final docs = snap.data?.docs ?? [];

          final users = docs.where((d) => d.data()['role'] == 'user').toList();
          final providers =
          docs.where((d) => d.data()['role'] == 'provider').toList();
          final pendingProviders = providers
              .where((d) => (d.data()['approved'] ?? false) == false)
              .toList();
          final blockedAccounts = docs
              .where((d) => (d.data()['blocked'] ?? false) == true)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overview",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statCard(
                      title: "Total Users",
                      value: users.length.toString(),
                      icon: Icons.person,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: "Providers",
                      value: providers.length.toString(),
                      icon: Icons.build,
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statCard(
                      title: "Pending Approval",
                      value: pendingProviders.length.toString(),
                      icon: Icons.hourglass_top,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: "Blocked",
                      value: blockedAccounts.length.toString(),
                      icon: Icons.block,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  "Manage Providers",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (providers.isEmpty)
                  const Text("No providers found")
                else
                  ListView.builder(
                    itemCount: providers.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final doc = providers[index];
                      final data = doc.data();
                      final uid = doc.id;

                      final name = data['name']?.toString() ?? 'No name';
                      final email = data['email']?.toString() ?? 'No email';
                      final serviceType =
                          data['serviceType']?.toString() ?? 'Not set';
                      final approved = (data['approved'] ?? false) == true;
                      final blocked = (data['blocked'] ?? false) == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(email),
                              const SizedBox(height: 4),
                              Text("Service: $serviceType"),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton(
                                    onPressed: () =>
                                        _toggleApproval(uid, approved),
                                    child: Text(
                                      approved ? "Remove Approval" : "Approve",
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _toggleBlock(uid, blocked),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      blocked ? Colors.green : Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      blocked ? "Unblock" : "Block",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}