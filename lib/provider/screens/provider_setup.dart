import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/login_screen.dart';
import '../provider_bottomnav.dart';

class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({super.key});

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  String? serviceType;
  bool saving = false;

  final descriptionController = TextEditingController();
  final priceController = TextEditingController();

  final services = const [
    ("plumber", "Plumber"),
    ("electrician", "Electrician"),
    ("cleaner", "Cleaner"),
    ("carpenter", "Carpenter"),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (!snap.exists || snap.data() == null) return;

    final data = snap.data()!;
    if (!mounted) return;

    setState(() {
      serviceType = data["serviceType"]?.toString();
      descriptionController.text = data["serviceDescription"]?.toString() ?? "";
      final price = data["pricePerHour"];
      priceController.text = price == null ? "" : price.toString();
    });
  }

  Future<void> save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final description = descriptionController.text.trim();
    final price = double.tryParse(priceController.text.trim());

    if (serviceType == null || serviceType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your service type")),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter service description")),
      );
      return;
    }

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid price per hour")),
      );
      return;
    }

    try {
      setState(() => saving = true);

      await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
        "serviceType": serviceType,
        "serviceDescription": description,
        "pricePerHour": price,
        "setupComplete": true,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProviderBottomNav()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyLogin()),
          (_) => false,
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Setup"),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Complete your provider profile",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: serviceType,
              items: services
                  .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                  .toList(),
              onChanged: (v) => setState(() => serviceType = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Service Type",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Service Description",
                hintText: "Example: Home cleaning, kitchen cleaning, bathroom cleaning",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Price Per Hour",
                hintText: "Example: 500",
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Save and Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}