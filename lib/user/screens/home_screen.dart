import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'find_services.dart'; // <-- Updated to use FindServices
import 'setting.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String userName = "User";

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (doc.exists) {
      setState(() {
        userName = doc.data()?['name'] ?? "User";
      });
    }
  }

  void goToFindServices({String? serviceType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindServices(selectedType: serviceType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.only(
                  top: 50, left: 20, right: 20, bottom: 25),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff326178), Color(0xffdff1fc)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // USER + SETTINGS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Hello $userName 👋",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const Setting()),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            "lib/Assets/images/User.png",
                            height: 50,
                            width: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Which service do\nyou need?",
                    style: TextStyle(
                      color: Color(0xff284a79),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      serviceItem("Carpenter", "lib/Assets/images/carpenter.png"),
                      serviceItem("Cleaner", "lib/Assets/images/cleaner.png"),
                      serviceItem("Electrician", "lib/Assets/images/electrician.png"),
                      serviceItem("Plumber", "lib/Assets/images/plumber.png"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Services",
                  style: TextStyle(
                    color: Color(0xff284a79),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Recent Services using FindServices-style cards
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_requests')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No recent services"),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return providerCard(
                      providerName: data['providerName'] ?? 'Provider',
                      serviceType: data['serviceType'] ?? 'Service',
                      price: data['pricePerHour'],
                      onTap: () => goToFindServices(serviceType: data['serviceType']),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget serviceItem(String title, String image) {
    return GestureDetector(
      onTap: () => goToFindServices(serviceType: title.toLowerCase()),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(60),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Image.asset(image, height: 30, width: 30),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xff284a79),
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  Widget providerCard({
    required String providerName,
    required String serviceType,
    dynamic price,
    required VoidCallback onTap,
  }) {
    String priceText(dynamic value) {
      if (value == null) return 'Price not set';
      if (value is int) return 'Rs $value/hour';
      if (value is double) {
        return value % 1 == 0
            ? 'Rs ${value.toInt()}/hour'
            : 'Rs ${value.toStringAsFixed(2)}/hour';
      }
      final parsed = double.tryParse(value.toString());
      if (parsed == null) return 'Price not set';
      return parsed % 1 == 0
          ? 'Rs ${parsed.toInt()}/hour'
          : 'Rs ${parsed.toStringAsFixed(2)}/hour';
    }

    String capitalize(String text) =>
        text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            providerName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            capitalize(serviceType),
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            priceText(price),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff326178),
              ),
              child: const Text("Find Service"),
            ),
          ),
        ],
      ),
    );
  }
}