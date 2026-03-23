import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  String _priceText(dynamic value) {
    if (value == null) return "Not set";

    if (value is int) return "Rs $value / hour";
    if (value is double) {
      return value % 1 == 0
          ? "Rs ${value.toInt()} / hour"
          : "Rs ${value.toStringAsFixed(2)} / hour";
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) return "Not set";

    return parsed % 1 == 0
        ? "Rs ${parsed.toInt()} / hour"
        : "Rs ${parsed.toStringAsFixed(2)} / hour";
  }

  String _daysText(List<String> days) {
    if (days.isEmpty) return "Not set";
    return days.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No user found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Home"),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists || snap.data!.data() == null) {
            return const Center(child: Text("Provider data not found"));
          }

          final data = snap.data!.data()!;
          final name = data["name"]?.toString() ?? "Provider";
          final serviceType = data["serviceType"]?.toString() ?? "Not set";
          final description =
              data["serviceDescription"]?.toString() ?? "No description added";
          final price = data["pricePerHour"];
          final approved = (data["approved"] ?? false) == true;
          final isAvailable = (data["isAvailable"] ?? true) == true;
          final availableDays = ((data["availableDays"] ?? []) as List)
              .map((e) => e.toString())
              .toList();
          final startHour = data["startHour"]?.toString() ?? "Not set";
          final endHour = data["endHour"]?.toString() ?? "Not set";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $name",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Service Profile",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text("Service Type: $serviceType"),
                        const SizedBox(height: 8),
                        Text("Description: $description"),
                        const SizedBox(height: 8),
                        Text("Price: ${_priceText(price)}"),
                        const SizedBox(height: 8),
                        Text("Approval Status: ${approved ? "Approved" : "Pending"}"),
                        const SizedBox(height: 8),
                        Text("Availability: ${isAvailable ? "Available" : "Unavailable"}"),
                        const SizedBox(height: 8),
                        Text("Available Days: ${_daysText(availableDays)}"),
                        const SizedBox(height: 8),
                        Text("Working Hours: $startHour - $endHour"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}