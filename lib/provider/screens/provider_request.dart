import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../services/request_service.dart';
import '../../shared/screen/chat_page.dart';
import '../../shared/widgets/notification_bell.dart';

class ProviderRequest extends StatefulWidget {
  const ProviderRequest({super.key});

  @override
  State<ProviderRequest> createState() => _ProviderRequestState();
}

class _ProviderRequestState extends State<ProviderRequest> {
  final RequestService _requestService = RequestService();
  final ChatService _chatService = ChatService();

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
      case 'arrived':
        return Colors.teal;
      case 'in_progress':
        return Colors.purple;
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
      case 'in_progress':
        return 'In Progress';
      case 'arrived':
        return 'Arrived';
      default:
        if (status.isEmpty) return 'Pending';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  bool _isActiveStatus(String status) {
    return status == 'pending' ||
        status == 'accepted' ||
        status == 'on_the_way' ||
        status == 'arrived' ||
        status == 'in_progress';
  }

  bool _canChat(String status) {
    return _chatService.canChatForStatus(status);
  }

  Future<void> _updateStatus(String requestId, String status) async {
    final provider = FirebaseAuth.instance.currentUser;
    if (provider == null) return;

    try {
      await _requestService.updateProviderRequestStatus(
        providerId: provider.uid,
        requestId: requestId,
        status: status,
      );

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

  Future<void> _openChatPage({
    required String requestId,
    required String customerId,
    required String providerId,
    required String customerName,
    required String customerPhone,
    required String status,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _chatService.markMessagesAsRead(
      requestId: requestId,
      currentUserId: currentUser.uid,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          requestId: requestId,
          customerId: customerId,
          providerId: providerId,
          currentUserId: currentUser.uid,
          currentUserRole: 'provider',
          otherUserName: customerName,
          otherUserPhone: customerPhone,
          requestStatus: status,
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
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
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label$value'),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Positioned(
      right: -6,
      top: -6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChatButton({
    required String requestId,
    required String customerId,
    required String providerId,
    required String customerName,
    required String customerPhone,
    required String status,
    required String currentUserId,
  }) {
    return StreamBuilder<int>(
      stream: _chatService.streamUnreadCount(
        requestId: requestId,
        currentUserId: currentUserId,
      ),
      builder: (context, snap) {
        final unread = snap.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openChatPage(
                requestId: requestId,
                customerId: customerId,
                providerId: providerId,
                customerName: customerName,
                customerPhone: customerPhone,
                status: status,
              ),
              icon: const Icon(Icons.chat),
              label: const Text('Chat'),
            ),
            if (unread > 0) _buildUnreadBadge(unread),
          ],
        );
      },
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
          appBar: AppBar(
            title: const Text('Incoming Requests'),
            actions: const [
              NotificationBell(),
            ],
          ),
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
                return _isActiveStatus(status);
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

              final travelCount = activeDocs.where((doc) {
                final status = (doc.data()['status'] ?? '').toString();
                return status == 'on_the_way' || status == 'arrived';
              }).length;

              final workingCount = activeDocs
                  .where((doc) => (doc.data()['status'] ?? '') == 'in_progress')
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
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _summaryCard(
                          'Pending',
                          pendingCount.toString(),
                          Icons.hourglass_top,
                          Colors.deepPurple,
                        ),
                        _summaryCard(
                          'Accepted',
                          acceptedCount.toString(),
                          Icons.check_circle_outline,
                          Colors.blue,
                        ),
                        _summaryCard(
                          'Traveling',
                          travelCount.toString(),
                          Icons.directions_car,
                          Colors.orange,
                        ),
                        _summaryCard(
                          'Working',
                          workingCount.toString(),
                          Icons.build_circle_outlined,
                          Colors.purple,
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
                                  : 'You are busy right now, complete it before accepting another one.',
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
                        final userId = data['userId']?.toString() ?? '';
                        final providerId = data['providerId']?.toString() ?? '';
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
                                const SizedBox(height: 10),
                                _infoLine('Service: ', serviceType),
                                _infoLine('Problem: ', problem),
                                _infoLine(
                                  'Address: ',
                                  address.isEmpty ? 'Not provided' : address,
                                ),
                                _infoLine(
                                  'Phone: ',
                                  userPhone.isEmpty ? 'Not provided' : userPhone,
                                ),
                                _infoLine(
                                  'Requested: ',
                                  _formatDate(createdAt),
                                ),
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
                                    if (_canChat(status) &&
                                        userId.isNotEmpty &&
                                        providerId.isNotEmpty)
                                      _buildChatButton(
                                        requestId: doc.id,
                                        customerId: userId,
                                        providerId: providerId,
                                        customerName: userName,
                                        customerPhone: userPhone,
                                        status: status,
                                        currentUserId: user.uid,
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
                                        child: const Text('Mark On The Way'),
                                      ),
                                    if (status == 'on_the_way')
                                      ElevatedButton(
                                        onPressed: () => _confirmAndUpdate(
                                          doc.id,
                                          'arrived',
                                          'Mark Arrived',
                                          'Have you arrived at the customer location?',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Mark Arrived'),
                                      ),
                                    if (status == 'arrived')
                                      ElevatedButton(
                                        onPressed: () => _confirmAndUpdate(
                                          doc.id,
                                          'in_progress',
                                          'Start Work',
                                          'Do you want to mark this job as in progress?',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Start Work'),
                                      ),
                                    if (status == 'in_progress')
                                      ElevatedButton(
                                        onPressed: () => _confirmAndUpdate(
                                          doc.id,
                                          'completed',
                                          'Complete Work',
                                          'Have you completed this job?',
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