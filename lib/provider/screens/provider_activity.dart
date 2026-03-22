import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderActivity extends StatefulWidget {
  const ProviderActivity({super.key});

  @override
  State<ProviderActivity> createState() => _ProviderActivityState();
}

class _ProviderActivityState extends State<ProviderActivity> {
  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Just now';

    final dt = value.toDate();
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
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
      appBar: AppBar(title: const Text('Request History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

          final docs = (snap.data?.docs ?? []).where((doc) {
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

          if (docs.isEmpty) {
            return const Center(
              child: Text('No request history yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final status = (data['status'] ?? '').toString();
              final userName = data['userName']?.toString() ?? 'User';
              final serviceType = data['serviceType']?.toString() ?? 'Service';
              final address = data['serviceAddress']?.toString() ?? '';
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
                      Text('Address: $address'),
                      const SizedBox(height: 4),
                      Text('Updated: ${_formatDate(updatedAt)}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
