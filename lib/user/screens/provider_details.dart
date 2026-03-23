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

  String _daysText(List<String> days) {
    if (days.isEmpty) return 'Not set';
    return days.join(', ');
  }

  Future<bool> _userHasActiveRequest(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('service_requests')
        .where('userId', isEqualTo: userId)
        .where(
      'status',
      whereIn: [
        'pending',
        'accepted',
        'on_the_way',
        'arrived',
        'in_progress',
      ],
    )
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
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

      final hasActiveRequest = await _userHasActiveRequest(user.uid);

      if (hasActiveRequest) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an active service request. Please complete or cancel it first.',
            ),
          ),
        );
        return;
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

  Widget _buildStarRow(double averageRating) {
    final rounded = averageRating.round();

    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rounded ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 22,
        );
      }),
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
        builder: (context, providerSnap) {
          if (providerSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (providerSnap.hasError) {
            return Center(child: Text('Error: ${providerSnap.error}'));
          }

          if (!providerSnap.hasData ||
              !providerSnap.data!.exists ||
              providerSnap.data!.data() == null) {
            return const Center(child: Text('Provider not found'));
          }

          final data = providerSnap.data!.data()!;
          final name = data['name']?.toString() ?? 'Unknown';
          final serviceType = data['serviceType']?.toString() ?? 'Not set';
          final description =
              data['serviceDescription']?.toString() ?? 'No description';
          final phone = data['phone']?.toString() ?? 'No phone';
          final address = data['address']?.toString() ?? 'No address';
          final price = data['pricePerHour'];

          final isAvailable = (data['isAvailable'] ?? true) == true;
          final availableDays = ((data['availableDays'] ?? []) as List)
              .map((e) => e.toString())
              .toList();
          final startHour = data['startHour']?.toString() ?? 'Not set';
          final endHour = data['endHour']?.toString() ?? 'Not set';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('providerId', isEqualTo: widget.providerId)
                .snapshots(),
            builder: (context, reviewSnap) {
              final reviewDocs = reviewSnap.data?.docs ?? [];

              double averageRating = 0;
              if (reviewDocs.isNotEmpty) {
                double total = 0;
                for (final doc in reviewDocs) {
                  final value = doc.data()['rating'];
                  if (value is int) {
                    total += value.toDouble();
                  } else if (value is double) {
                    total += value;
                  } else {
                    total += double.tryParse(value.toString()) ?? 0;
                  }
                }
                averageRating = total / reviewDocs.length;
              }

              final recentReviews = [...reviewDocs]
                ..sort((a, b) {
                  final aTime = a.data()['createdAt'];
                  final bTime = b.data()['createdAt'];
                  if (aTime is Timestamp && bTime is Timestamp) {
                    return bTime.compareTo(aTime);
                  }
                  return 0;
                });

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
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildStarRow(averageRating),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              reviewDocs.isEmpty
                                  ? 'No ratings yet'
                                  : '${averageRating.toStringAsFixed(1)} / 5  (${reviewDocs.length} reviews)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.withValues(alpha: 0.10)
                            : Colors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isAvailable
                                ? 'Currently Available'
                                : 'Currently Unavailable',
                            style: TextStyle(
                              color: isAvailable ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _infoCard('Service Type', _capitalize(serviceType)),
                    _infoCard('Description', description),
                    _infoCard('Price Per Hour', _priceText(price)),
                    _infoCard('Phone', phone),
                    _infoCard('Address', address),
                    _infoCard('Available Days', _daysText(availableDays)),
                    _infoCard('Working Hours', '$startHour - $endHour'),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text('Confirm Booking'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recent Reviews',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (reviewDocs.isEmpty)
                      const Text('No reviews yet')
                    else
                      ...recentReviews.take(5).map((doc) {
                        final review = doc.data();
                        final userName =
                            review['userName']?.toString() ?? 'User';
                        final reviewText =
                            review['reviewText']?.toString() ?? '';
                        final ratingValue = review['rating'];
                        final reviewRating = ratingValue is int
                            ? ratingValue
                            : int.tryParse(ratingValue.toString()) ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < reviewRating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 20,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  reviewText.isEmpty
                                      ? 'No written review'
                                      : reviewText,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}