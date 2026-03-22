import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FindServices extends StatefulWidget {
  const FindServices({super.key});

  @override
  State<FindServices> createState() => _FindServicesState();
}

class _FindServicesState extends State<FindServices> {
  String selectedType = 'cleaner';
  bool bookingLoading = false;

  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final List<Map<String, String>> categories = const [
    {'key': 'cleaner', 'label': 'Cleaner'},
    {'key': 'plumber', 'label': 'Plumber'},
    {'key': 'electrician', 'label': 'Electrician'},
    {'key': 'carpenter', 'label': 'Carpenter'},
  ];

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

  Future<void> _submitBooking({
    required BuildContext bottomSheetContext,
    required String providerId,
    required Map<String, dynamic> providerData,
  }) async {
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
      if (mounted) {
        setState(() => bookingLoading = true);
      }

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
        'providerId': providerId,
        'providerName': providerData['name'] ?? 'Provider',
        'providerPhone': providerData['phone'] ?? '',
        'serviceType': providerData['serviceType'] ?? selectedType,
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

      Navigator.pop(bottomSheetContext);

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

  Future<void> _openBookingSheet(
      String providerId,
      Map<String, dynamic> providerData,
      ) async {
    _problemController.clear();
    _addressController.clear();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request ${providerData['name'] ?? 'Provider'}',
                  style: const TextStyle(
                    fontSize: 18,
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: bookingLoading
                        ? null
                        : () => _submitBooking(
                      bottomSheetContext: bottomSheetContext,
                      providerId: providerId,
                      providerData: providerData,
                    ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Services'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = categories[index];
                final isSelected = selectedType == item['key'];

                return ChoiceChip(
                  label: Text(item['label']!),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => selectedType = item['key']!);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'provider')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final docs = (snap.data?.docs ?? []).where((doc) {
                  final data = doc.data();
                  final approved = (data['approved'] ?? false) == true;
                  final blocked = (data['blocked'] ?? false) == true;
                  final setupComplete = (data['setupComplete'] ?? false) == true;
                  final serviceType =
                  (data['serviceType'] ?? '').toString().toLowerCase();

                  return approved &&
                      !blocked &&
                      setupComplete &&
                      serviceType == selectedType;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No providers found for this service'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final name = data['name']?.toString() ?? 'Unknown';
                    final description = data['serviceDescription']?.toString() ??
                        'No description available';
                    final price = data['pricePerHour'];
                    final phone = data['phone']?.toString() ?? 'No phone';

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
                            const SizedBox(height: 6),
                            Text(
                              _capitalize(selectedType),
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(description),
                            const SizedBox(height: 8),
                            Text(
                              _priceText(price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Phone: $phone'),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () => _openBookingSheet(doc.id, data),
                                child: const Text('Request Service'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}