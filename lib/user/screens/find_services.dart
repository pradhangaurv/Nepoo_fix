import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'provider_details.dart';

class FindServices extends StatefulWidget {
  const FindServices({super.key});

  @override
  State<FindServices> createState() => _FindServicesState();
}

class _FindServicesState extends State<FindServices> {
  String selectedType = 'cleaner';

  final List<Map<String, String>> categories = const [
    {'key': 'cleaner', 'label': 'Cleaner'},
    {'key': 'plumber', 'label': 'Plumber'},
    {'key': 'electrician', 'label': 'Electrician'},
    {'key': 'carpenter', 'label': 'Carpenter'},
  ];

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

  String _daysText(List<String> days) {
    if (days.isEmpty) return 'Not set';
    return days.join(', ');
  }

  void _openProviderDetails(String providerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsPage(providerId: providerId),
      ),
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
                }).toList()
                  ..sort((a, b) {
                    final aAvailable = (a.data()['isAvailable'] ?? true) == true;
                    final bAvailable = (b.data()['isAvailable'] ?? true) == true;

                    if (aAvailable == bAvailable) {
                      final aName = (a.data()['name'] ?? '').toString();
                      final bName = (b.data()['name'] ?? '').toString();
                      return aName.compareTo(bName);
                    }

                    return aAvailable ? -1 : 1;
                  });

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
                    final isAvailable = (data['isAvailable'] ?? true) == true;
                    final availableDays = ((data['availableDays'] ?? []) as List)
                        .map((e) => e.toString())
                        .toList();
                    final startHour = data['startHour']?.toString() ?? 'Not set';
                    final endHour = data['endHour']?.toString() ?? 'Not set';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openProviderDetails(doc.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAvailable
                                          ? Colors.green.withValues(alpha: 0.10)
                                          : Colors.red.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isAvailable ? 'Available Now' : 'On Job',
                                      style: TextStyle(
                                        color: isAvailable
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
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
                              const SizedBox(height: 4),
                              Text('Days: ${_daysText(availableDays)}'),
                              const SizedBox(height: 4),
                              Text('Hours: $startHour - $endHour'),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () => _openProviderDetails(doc.id),
                                  child: const Text('View Details'),
                                ),
                              ),
                            ],
                          ),
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