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
  final locationAddressController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  static const Color providerDark = Color(0xff244657);
  static const Color providerLight = Color(0xff7fa7bd);
  static const Color pageBg = Color(0xfff4eff5);
  static const Color borderColor = Color(0xffe3dce8);

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
      descriptionController.text =
          data["serviceDescription"]?.toString() ?? "";
      locationAddressController.text =
          data["locationAddress"]?.toString() ?? "";

      final price = data["pricePerHour"];
      priceController.text = price == null ? "" : price.toString();

      final lat = data["latitude"];
      latitudeController.text = lat == null ? "" : lat.toString();

      final lng = data["longitude"];
      longitudeController.text = lng == null ? "" : lng.toString();
    });
  }

  Future<void> save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final description = descriptionController.text.trim();
    final locationAddress = locationAddressController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    final latitudeText = latitudeController.text.trim();
    final longitudeText = longitudeController.text.trim();

    final latitude =
    latitudeText.isEmpty ? null : double.tryParse(latitudeText);
    final longitude =
    longitudeText.isEmpty ? null : double.tryParse(longitudeText);

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

    if (locationAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your service location address"),
        ),
      );
      return;
    }

    if (latitudeText.isNotEmpty && latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid latitude")),
      );
      return;
    }

    if (longitudeText.isNotEmpty && longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid longitude")),
      );
      return;
    }

    try {
      setState(() => saving = true);

      await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
        "serviceType": serviceType,
        "serviceDescription": description,
        "pricePerHour": price,
        "locationAddress": locationAddress,
        "latitude": latitude,
        "longitude": longitude,
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
    locationAddressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: providerDark, width: 1.4),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _fieldDecoration(label: label, hint: hint),
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
          colors: [providerDark, providerLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Provider Setup",
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Complete your provider profile",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: serviceType,
                      items: services
                          .map(
                            (s) => DropdownMenuItem(
                          value: s.$1,
                          child: Text(s.$2),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setState(() => serviceType = v),
                      decoration: _fieldDecoration(label: "Service Type"),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: descriptionController,
                      label: "Service Description",
                      hint:
                      "Example: Home cleaning, kitchen cleaning, bathroom cleaning",
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: priceController,
                      label: "Price Per Hour",
                      hint: "Example: 500",
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: locationAddressController,
                      label: "Service Location Address",
                      hint: "Example: Baneshwor, Kathmandu",
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: latitudeController,
                      label: "Latitude (optional)",
                      hint: "Example: 27.7172",
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: longitudeController,
                      label: "Longitude (optional)",
                      hint: "Example: 85.3240",
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "You can leave latitude and longitude empty for now.",
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: providerDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text("Save and Continue"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}