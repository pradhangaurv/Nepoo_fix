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

  static const Color providerDark = Color(0xff244687);
  static const Color providerLight = Color(0xff7fa7bd);
  static const Color pageBg = Color(0xffffffff);
  static const Color borderColor = Color(0xffe3dce8);

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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _moneyText(double value) {
    if (value % 1 == 0) return 'NPR ${value.toInt()}';
    return 'NPR ${value.toStringAsFixed(2)}';
  }

  String _workedTimeText(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  double _calculateBilledHours(int workedMinutes) {
    final rawHours = workedMinutes / 60.0;
    return rawHours <= 1 ? 1.0 : rawHours;
  }

  String _formatClock(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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

  Future<void> _completeRequestWithBilling({
    required String requestId,
    required int workedMinutes,
    required double billedHours,
    required double finalAmount,
  }) async {
    final provider = FirebaseAuth.instance.currentUser;
    if (provider == null) return;

    try {
      await _requestService.completeProviderRequest(
        providerId: provider.uid,
        requestId: requestId,
        workedMinutes: workedMinutes,
        billedHours: billedHours,
        finalAmount: finalAmount,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job completed. Total: ${_moneyText(finalAmount)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete request: $e')),
      );
    }
  }

  Future<void> _showCompleteDialog({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final startedAtValue = requestData['workStartedAt'];
    if (startedAtValue is! Timestamp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap Start Work first.'),
        ),
      );
      return;
    }

    final rate = _toDouble(requestData['pricePerHour']) ?? 0;
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hourly rate was not found for this request.'),
        ),
      );
      return;
    }

    final startedAt = startedAtValue.toDate();
    final endedAt = DateTime.now();

    int workedMinutes = endedAt.difference(startedAt).inMinutes;
    if (workedMinutes < 1) workedMinutes = 1;

    final billedHours = _calculateBilledHours(workedMinutes);
    final finalAmount = billedHours * rate;
    final firstHourMinimumApplied = workedMinutes < 60;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Complete Work'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Started: ${_formatClock(startedAt)}'),
              const SizedBox(height: 6),
              Text('Ended: ${_formatClock(endedAt)}'),
              const SizedBox(height: 6),
              Text('Worked Time: ${_workedTimeText(workedMinutes)}'),
              const SizedBox(height: 6),
              Text('Rate: ${_moneyText(rate)}/hour'),
              const SizedBox(height: 12),
              if (firstHourMinimumApplied)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'First-hour minimum charge applied.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (firstHourMinimumApplied) const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Total: ${_moneyText(finalAmount)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Completion'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _completeRequestWithBilling(
      requestId: requestId,
      workedMinutes: workedMinutes,
      billedHours: billedHours,
      finalAmount: finalAmount,
    );
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: providerDark,
                foregroundColor: Colors.white,
              ),
            ),
            if (unread > 0) _buildUnreadBadge(unread),
          ],
        );
      },
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
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Incoming Requests',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          NotificationBell(),
        ],
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

                    final allDocs = snap.data?.docs ?? [];

                    final activeDocs = allDocs.where((doc) {
                      final status =
                      (doc.data()['status'] ?? 'pending').toString();
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
                        .where(
                            (doc) => (doc.data()['status'] ?? '') == 'in_progress')
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green.withValues(alpha: 0.10)
                                  : Colors.red.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAvailable
                                      ? Icons.check_circle
                                      : Icons.work,
                                  color:
                                  isAvailable ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isAvailable
                                        ? 'You are currently available for new requests.'
                                        : 'You are busy right now, complete it before accepting another one.',
                                    style: TextStyle(
                                      color:
                                      isAvailable ? Colors.green : Colors.red,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemCount: activeDocs.length,
                            itemBuilder: (context, index) {
                              final doc = activeDocs[index];
                              final data = doc.data();
                              final status =
                              (data['status'] ?? 'pending').toString();
                              final userName =
                                  data['userName']?.toString() ?? 'User';
                              final userPhone =
                                  data['userPhone']?.toString() ?? '';
                              final userId =
                                  data['userId']?.toString() ?? '';
                              final providerId =
                                  data['providerId']?.toString() ?? '';
                              final serviceType =
                                  data['serviceType']?.toString() ?? 'Service';
                              final problem =
                                  data['problemDescription']?.toString() ?? '';
                              final address =
                                  data['serviceAddress']?.toString() ?? '';
                              final createdAt = data['createdAt'];
                              final pricePerHour = _toDouble(data['pricePerHour']);
                              final workStartedAt = data['workStartedAt'];

                              final isCurrentAssignedRequest =
                                  currentRequestId == doc.id;
                              final canAcceptThisRequest =
                                  !hasActiveAssignedRequest || isCurrentAssignedRequest;

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
                                    const SizedBox(height: 10),
                                    _infoLine('Service: ', serviceType),
                                    _infoLine('Problem: ', problem),
                                    _infoLine(
                                      'Address: ',
                                      address.isEmpty ? 'Not provided' : address,
                                    ),
                                    _infoLine(
                                      'Phone: ',
                                      userPhone.isEmpty
                                          ? 'Not provided'
                                          : userPhone,
                                    ),
                                    _infoLine(
                                      'Requested: ',
                                      _formatDate(createdAt),
                                    ),
                                    if (pricePerHour != null)
                                      _infoLine(
                                        'Rate: ',
                                        '${_moneyText(pricePerHour)}/hour',
                                      ),
                                    if (status == 'in_progress' &&
                                        workStartedAt is Timestamp)
                                      _infoLine(
                                        'Started: ',
                                        _formatDate(workStartedAt),
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: providerDark,
                                              foregroundColor: Colors.white,
                                            ),
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
                                            child:
                                            const Text('Mark On The Way'),
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
                                            child:
                                            const Text('Mark Arrived'),
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
                                            onPressed: () => _showCompleteDialog(
                                              requestId: doc.id,
                                              requestData: data,
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
      },
    );
  }
}