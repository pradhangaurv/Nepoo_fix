import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderActivity extends StatefulWidget {
  const ProviderActivity({super.key});

  @override
  State<ProviderActivity> createState() => _ProviderActivityState();
}

class _ProviderActivityState extends State<ProviderActivity> {
  String selectedFilter = 'all';

  static const Color providerDark = Color(0xff244687);
  static const Color providerLight = Color(0xff7fa7bd);
  static const Color pageBg = Color(0xffffffff);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color chipSelectedBg = Color(0xffd6e2ea);
  static const Color chipSelectedText = Color(0xff1f3d4d);

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Just now';

    final dt = value.toDate();
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _moneyText(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == null) return 'Not set';
    if (parsed % 1 == 0) return 'NPR ${parsed.toInt()}';
    return 'NPR ${parsed.toStringAsFixed(2)}';
  }

  String _workedTimeText(dynamic value) {
    final minutes = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (minutes == null) return 'Not set';

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on_the_way':
        return 'On The Way';
      case 'in_progress':
        return 'In Progress';
      case 'arrived':
        return 'Arrived';
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _filterChip(String key, String label) {
    final isSelected = selectedFilter == key;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => selectedFilter = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? chipSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipSelectedBg : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipSelectedText : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
      child: const Text(
        'Request History',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in again.')),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _buildTopHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('service_requests')
                  .where('providerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final historyDocs = (snap.data?.docs ?? []).where((doc) {
                  final status = (doc.data()['status'] ?? '').toString();
                  return status == 'completed' ||
                      status == 'cancelled' ||
                      status == 'rejected';
                }).toList()
                  ..sort((a, b) {
                    final aTime = a.data()['updatedAt'];
                    final bTime = b.data()['updatedAt'];
                    if (aTime is Timestamp && bTime is Timestamp) {
                      return bTime.compareTo(aTime);
                    }
                    return 0;
                  });

                final filteredDocs = historyDocs.where((doc) {
                  final status = (doc.data()['status'] ?? '').toString();
                  if (selectedFilter == 'all') return true;
                  return status == selectedFilter;
                }).toList();

                final completedCount = historyDocs
                    .where((doc) => (doc.data()['status'] ?? '') == 'completed')
                    .length;
                final cancelledCount = historyDocs
                    .where((doc) => (doc.data()['status'] ?? '') == 'cancelled')
                    .length;
                final rejectedCount = historyDocs
                    .where((doc) => (doc.data()['status'] ?? '') == 'rejected')
                    .length;

                return Column(
                  children: [
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _filterChip('all', 'All (${historyDocs.length})'),
                          _filterChip('completed', 'Completed ($completedCount)'),
                          _filterChip('cancelled', 'Cancelled ($cancelledCount)'),
                          _filterChip('rejected', 'Rejected ($rejectedCount)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? const Center(
                        child: Text('No request history yet'),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data();
                          final status = (data['status'] ?? '').toString();
                          final userName =
                              data['userName']?.toString() ?? 'User';
                          final userPhone =
                              data['userPhone']?.toString() ?? '';
                          final serviceType =
                              data['serviceType']?.toString() ?? 'Service';
                          final problem =
                              data['problemDescription']?.toString() ?? '';
                          final address =
                              data['serviceAddress']?.toString() ?? '';
                          final updatedAt = data['updatedAt'];
                          final workedMinutes = data['workedMinutes'];
                          final finalAmount = data['finalAmount'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        userName,
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
                                        color: _statusColor(status)
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Service: $serviceType'),
                                const SizedBox(height: 4),
                                Text('Problem: $problem'),
                                const SizedBox(height: 4),
                                Text('Address: $address'),
                                const SizedBox(height: 4),
                                Text('Phone: $userPhone'),
                                const SizedBox(height: 4),
                                Text('Updated: ${_formatDate(updatedAt)}'),
                                if (status == 'completed') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Worked Time: ${_workedTimeText(workedMinutes)}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total: ${_moneyText(finalAmount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}