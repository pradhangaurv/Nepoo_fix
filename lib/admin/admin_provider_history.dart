import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminProviderHistoryPage extends StatefulWidget {
  final String providerId;
  final String providerName;

  const AdminProviderHistoryPage({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<AdminProviderHistoryPage> createState() =>
      _AdminProviderHistoryPageState();
}

class _AdminProviderHistoryPageState extends State<AdminProviderHistoryPage> {
  String selectedFilter = 'all';

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _moneyText(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == null) return 'NPR 0';
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

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Just now';

    final dt = value.toDate();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'on_the_way':
        return Colors.deepOrange;
      case 'arrived':
        return Colors.teal;
      case 'in_progress':
        return Colors.purple;
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = selectedFilter == key;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => selectedFilter = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueGrey.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blueGrey : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blueGrey.shade800 : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.providerName} History'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('service_requests')
            .where('providerId', isEqualTo: widget.providerId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];

          final sortedDocs = [...docs]
            ..sort((a, b) {
              final aTime = a.data()['updatedAt'] ?? a.data()['createdAt'];
              final bTime = b.data()['updatedAt'] ?? b.data()['createdAt'];
              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });

          final completedDocs = sortedDocs
              .where((doc) => (doc.data()['status'] ?? '') == 'completed')
              .toList();
          final cancelledDocs = sortedDocs
              .where((doc) => (doc.data()['status'] ?? '') == 'cancelled')
              .toList();
          final rejectedDocs = sortedDocs
              .where((doc) => (doc.data()['status'] ?? '') == 'rejected')
              .toList();

          double totalRevenue = 0;
          for (final doc in completedDocs) {
            totalRevenue += _toDouble(doc.data()['finalAmount']) ?? 0;
          }

          final filteredDocs = sortedDocs.where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            if (selectedFilter == 'all') return true;
            return status == selectedFilter;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.providerName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statCard(
                      title: 'Completed',
                      value: completedDocs.length.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: 'Cancelled',
                      value: cancelledDocs.length.toString(),
                      icon: Icons.cancel,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statCard(
                      title: 'Rejected',
                      value: rejectedDocs.length.toString(),
                      icon: Icons.block,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: 'Revenue',
                      value: _moneyText(totalRevenue),
                      icon: Icons.payments,
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('all', 'All (${sortedDocs.length})'),
                    _filterChip('completed', 'Completed (${completedDocs.length})'),
                    _filterChip('cancelled', 'Cancelled (${cancelledDocs.length})'),
                    _filterChip('rejected', 'Rejected (${rejectedDocs.length})'),
                  ],
                ),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No history found'),
                    ),
                  )
                else
                  ListView.builder(
                    itemCount: filteredDocs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index].data();
                      final status = (data['status'] ?? '').toString();
                      final customerName =
                          data['userName']?.toString() ?? 'User';
                      final userPhone =
                          data['userPhone']?.toString() ?? '';
                      final serviceType =
                          data['serviceType']?.toString() ?? 'Service';
                      final problem =
                          data['problemDescription']?.toString() ?? '';
                      final address =
                          data['serviceAddress']?.toString() ?? '';
                      final createdAt = data['createdAt'];
                      final updatedAt = data['updatedAt'];
                      final finalAmount = data['finalAmount'];
                      final workedMinutes = data['workedMinutes'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customerName,
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
                                      borderRadius: BorderRadius.circular(20),
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
                              Text(
                                'Address: ${address.isEmpty ? 'Not provided' : address}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Phone: ${userPhone.isEmpty ? 'Not provided' : userPhone}',
                              ),
                              const SizedBox(height: 4),
                              Text('Requested: ${_formatDate(createdAt)}'),
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