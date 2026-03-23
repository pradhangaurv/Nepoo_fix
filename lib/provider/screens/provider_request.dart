import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderRequest extends StatefulWidget {
  const ProviderRequest({super.key});

  @override
  State<ProviderRequest> createState() => _ProviderRequestState();
}

class _ProviderRequestState extends State<ProviderRequest> {
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

  Future<void> _updateStatus(String requestId, String status) async {
    final provider = FirebaseAuth.instance.currentUser;
    if (provider == null) return;

    final db = FirebaseFirestore.instance;
    final requestRef = db.collection('service_requests').doc(requestId);
    final providerRef = db.collection('users').doc(provider.uid);

    try {
      await db.runTransaction((transaction) async {
        final providerSnap = await transaction.get(providerRef);
        final providerData = providerSnap.data() ?? <String, dynamic>{};

        final currentRequestId =
        providerData['currentRequestId']?.toString();

        transaction.update(requestRef, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (status == 'accepted') {
          if (currentRequestId != null &&
              currentRequestId.isNotEmpty &&
              currentRequestId != requestId) {
            throw Exception('You already have an active request.');
          }

          transaction.update(providerRef, {
            'isAvailable': false,
            'currentRequestId': requestId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (status == 'completed') {
          if (currentRequestId == requestId || currentRequestId == null) {
            transaction.update(providerRef, {
              'isAvailable': true,
              'currentRequestId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (status == 'rejected' || status == 'cancelled') {
          if (currentRequestId == requestId) {
            transaction.update(providerRef, {
              'isAvailable': true,
              'currentRequestId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request marked as ${_statusLabel(status)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
    }
  }

  Future<void> _confirmAndUpdate(
      String requestId,
      String status,
      String title,
      String message,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _updateStatus(requestId, status);
    }
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, providerSnap) {
        final providerData = providerSnap.data?.data() ?? <String, dynamic>{};
        final currentRequestId =
            providerData['currentRequestId']?.toString() ?? '';
        final isAvailable = (providerData['isAvailable'] ?? true) == true;
        final hasActiveAssignedRequest = currentRequestId.isNotEmpty;

        return Scaffold(
          appBar: AppBar(title: const Text('Incoming Requests')),
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

              final allDocs = snap.data?.docs ?? [];

              final activeDocs = allDocs.where((doc) {
                final status = (doc.data()['status'] ?? 'pending').toString();
                return status == 'pending' ||
                    status == 'accepted' ||
                    status == 'on_the_way';
              }).toList()
                ..sort((a, b) {
                  final aTime = a.data()['createdAt'];
                  final bTime = b.data()['createdAt'];
                  if (aTime is Timestamp && bTime is Timestamp) {
                    return bTime.compareTo(aTime);
                  }
                  return 0;
                });

              final pendingCount = activeDocs
                  .where((doc) => (doc.data()['status'] ?? '') == 'pending')
                  .length;
              final acceptedCount = activeDocs
                  .where((doc) => (doc.data()['status'] ?? '') == 'accepted')
                  .length;
              final onWayCount = activeDocs
                  .where((doc) => (doc.data()['status'] ?? '') == 'on_the_way')
                  .length;

              if (activeDocs.isEmpty) {
                return const Center(
                  child: Text('No active requests right now'),
                );
              }

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _summaryCard(
                          'Pending',
                          pendingCount.toString(),
                          Icons.hourglass_top,
                          Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          'Accepted',
                          acceptedCount.toString(),
                          Icons.check_circle_outline,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          'On The Way',
                          onWayCount.toString(),
                          Icons.directions_car,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: double.infinity,
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
                            isAvailable ? Icons.check_circle : Icons.work,
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAvailable
                                  ? 'You are currently available for new requests.'
                                  : 'You are busy with an active request. Complete it before accepting another one.',
                              style: TextStyle(
                                color: isAvailable ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: activeDocs.length,
                      itemBuilder: (context, index) {
                        final doc = activeDocs[index];
                        final data = doc.data();
                        final status = (data['status'] ?? 'pending').toString();
                        final userName = data['userName']?.toString() ?? 'User';
                        final userPhone = data['userPhone']?.toString() ?? '';
                        final serviceType =
                            data['serviceType']?.toString() ?? 'Service';
                        final problem =
                            data['problemDescription']?.toString() ?? '';
                        final address =
                            data['serviceAddress']?.toString() ?? '';
                        final createdAt = data['createdAt'];

                        final isCurrentAssignedRequest =
                            currentRequestId == doc.id;
                        final canAcceptThisRequest =
                            !hasActiveAssignedRequest || isCurrentAssignedRequest;

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
                                Text('Address: $address'),
                                const SizedBox(height: 4),
                                Text('Phone: $userPhone'),
                                const SizedBox(height: 4),
                                Text('Requested: ${_formatDate(createdAt)}'),
                                if (status == 'pending' &&
                                    hasActiveAssignedRequest &&
                                    !isCurrentAssignedRequest) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Finish your current accepted job before accepting another request.',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    if (status == 'pending')
                                      ElevatedButton(
                                        onPressed: canAcceptThisRequest
                                            ? () => _confirmAndUpdate(
                                          doc.id,
                                          'accepted',
                                          'Accept Request',
                                          'Do you want to accept this request? You will become unavailable to other users.',
                                        )
                                            : null,
                                        child: const Text('Accept'),
                                      ),
                                    if (status == 'pending')
                                      ElevatedButton(
                                        onPressed: () => _confirmAndUpdate(
                                          doc.id,
                                          'rejected',
                                          'Reject Request',
                                          'Do you want to reject this request?',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    if (status == 'accepted')
                                      ElevatedButton(
                                        onPressed: () => _confirmAndUpdate(
                                          doc.id,
                                          'on_the_way',
                                          'Mark On The Way',
                                          'Are you on the way to the customer?',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                        child:
                                        const Text('Mark On The Way'),
                                      ),
                                    if (status == 'accepted' ||
                                        status == 'on_the_way')
                                      ElevatedButton(
                                        onPressed: () => _confirmAndUpdate(
                                          doc.id,
                                          'completed',
                                          'Complete Request',
                                          'Mark this service as completed? You will become available again.',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Complete'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}