import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'review_page.dart';

class Activity extends StatefulWidget {
  const Activity({super.key});

  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  String selectedFilter = 'active';

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Just now';

    final dt = value.toDate();
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'on_the_way':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.deepPurple;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on_the_way':
        return 'On The Way';
      default:
        if (status.isEmpty) return 'Pending';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  bool _isActiveStatus(String status) {
    return status == 'pending' || status == 'accepted' || status == 'on_the_way';
  }

  bool _canCancel(String status) {
    return status == 'pending' || status == 'accepted';
  }

  Future<void> _cancelRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Request'),
          content: const Text('Are you sure you want to cancel this request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('service_requests')
        .doc(requestId)
        .update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request cancelled')),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = selectedFilter == key;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => selectedFilter = key);
      },
    );
  }

  void _openReviewPage({
    required String requestId,
    required String providerId,
    required String providerName,
    required String serviceType,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewPage(
          requestId: requestId,
          providerId: providerId,
          providerName: providerName,
          serviceType: serviceType,
        ),
      ),
    );
  }

  Widget _buildRequestCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final status = (data['status'] ?? 'pending').toString();
    final providerName = data['providerName']?.toString() ?? 'Provider';
    final providerId = data['providerId']?.toString() ?? '';
    final serviceType = data['serviceType']?.toString() ?? 'Service';
    final problem = data['problemDescription']?.toString() ?? '';
    final address = data['serviceAddress']?.toString() ?? '';
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

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
                    providerName,
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
                    color: _statusColor(status).withValues(alpha: 0.12),
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
            Text('Address: $address'),
            const SizedBox(height: 4),
            Text('Requested: ${_formatDate(createdAt)}'),
            const SizedBox(height: 4),
            Text('Last Update: ${_formatDate(updatedAt)}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_canCancel(status))
                  ElevatedButton(
                    onPressed: () => _cancelRequest(doc.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel Request'),
                  ),
                if (status == 'completed' && providerId.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _openReviewPage(
                      requestId: doc.id,
                      providerId: providerId,
                      providerName: providerName,
                      serviceType: serviceType,
                    ),
                    child: const Text('Rate & Review'),
                  ),
              ],
            ),
          ],
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
      appBar: AppBar(title: const Text('My Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('service_requests')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final allDocs = [...(snap.data?.docs ?? [])]
            ..sort((a, b) {
              final aTime = a.data()['updatedAt'] ?? a.data()['createdAt'];
              final bTime = b.data()['updatedAt'] ?? b.data()['createdAt'];
              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });

          final activeDocs = allDocs.where((doc) {
            final status = (doc.data()['status'] ?? 'pending').toString();
            return _isActiveStatus(status);
          }).toList();

          final historyDocs = allDocs.where((doc) {
            final status = (doc.data()['status'] ?? 'pending').toString();
            return !_isActiveStatus(status);
          }).toList();

          final docsToShow =
          selectedFilter == 'active' ? activeDocs : historyDocs;

          return Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _filterChip(
                        'active',
                        'Active (${activeDocs.length})',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _filterChip(
                        'history',
                        'History (${historyDocs.length})',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: docsToShow.isEmpty
                    ? Center(
                  child: Text(
                    selectedFilter == 'active'
                        ? 'No active requests'
                        : 'No request history yet',
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docsToShow.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(docsToShow[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}