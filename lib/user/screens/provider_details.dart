import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderDetailsPage extends StatefulWidget {
  final String providerId;

  const ProviderDetailsPage({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderDetailsPage> createState() => _ProviderDetailsPageState();
}

class _ProviderDetailsPageState extends State<ProviderDetailsPage> {
  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool bookingLoading = false;

  @override
  void dispose() {
    _problemController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _priceText(dynamic value) {
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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _submitBooking(Map<String, dynamic> providerData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final problem = _problemController.text.trim();
    final address = _addressController.text.trim();

    if (problem.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all booking fields')),
      );
      return;
    }

    try {
      setState(() => bookingLoading = true);

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnap.data() ?? <String, dynamic>{};

      await FirebaseFirestore.instance.collection('service_requests').add({
        'userId': user.uid,
        'userName': userData['name'] ?? 'User',
        'userPhone': userData['phone'] ?? '',
        'userAddress': userData['address'] ?? '',
        'providerId': widget.providerId,
        'providerName': providerData['name'] ?? 'Provider',
        'providerPhone': providerData['phone'] ?? '',
        'serviceType': providerData['serviceType'] ?? '',
        'providerServiceDescription':
        providerData['serviceDescription'] ?? '',
        'pricePerHour': providerData['pricePerHour'],
        'problemDescription': problem,
        'serviceAddress': address,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _problemController.clear();
      _addressController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service request sent successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => bookingLoading = false);
      }
    }
  }

  Widget _infoCard(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Details'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.providerId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (!snap.hasData || !snap.data!.exists || snap.data!.data() == null) {
            return const Center(child: Text('Provider not found'));
          }

          final data = snap.data!.data()!;
          final name = data['name']?.toString() ?? 'Unknown';
          final serviceType = data['serviceType']?.toString() ?? 'Not set';
          final description =
              data['serviceDescription']?.toString() ?? 'No description';
          final phone = data['phone']?.toString() ?? 'No phone';
          final address = data['address']?.toString() ?? 'No address';
          final price = data['pricePerHour'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _infoCard('Service Type', _capitalize(serviceType)),
                _infoCard('Description', description),
                _infoCard('Price Per Hour', _priceText(price)),
                _infoCard('Phone', phone),
                _infoCard('Address', address),
                const SizedBox(height: 18),
                const Text(
                  'Request This Service',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _problemController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Problem Description',
                    hintText: 'Describe the service you need',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Service Address',
                    hintText: 'Enter the address for this service',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: bookingLoading
                        ? null
                        : () => _submitBooking(data),
                    child: bookingLoading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Confirm Booking'),
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