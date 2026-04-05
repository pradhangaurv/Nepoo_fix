import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../../shared/screen/chat_page.dart';
import '../../shared/widgets/notification_bell.dart';
import 'review_page.dart';

class Activity extends StatefulWidget {
  const Activity({super.key});

  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  final ChatService _chatService = ChatService();

  String selectedFilter = 'active';

  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xfff4eff5);
  static const Color chipSelectedBg = Color(0xffddd0f1);
  static const Color chipSelectedText = Color(0xff4a3a73);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color titleColor = Color(0xff284a79);

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
      case 'pending':
        return const Color(0xff7c5ac7);
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

  bool _canCancel(String status) {
    return status == 'pending';
  }

  bool _canChat(String status) {
    return _chatService.canChatForStatus(status);
  }

  Future<void> _cancelRequest({
    required String requestId,
    required String status,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (status != 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only pending requests can be cancelled.'),
        ),
      );
      return;
    }

    try {
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request: $e')),
      );
    }
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

  Future<void> _openChatPage({
    required String requestId,
    required String customerId,
    required String providerId,
    required String providerName,
    required String providerPhone,
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
          currentUserRole: 'customer',
          otherUserName: providerName,
          otherUserPhone: providerPhone,
          requestStatus: status,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = selectedFilter == key;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => selectedFilter = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? chipSelectedBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? chipSelectedBg : borderColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                const Icon(
                  Icons.check,
                  size: 16,
                  color: chipSelectedText,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? chipSelectedText : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatButtonWithBadge({
    required String requestId,
    required String currentUserId,
    required String customerId,
    required String providerId,
    required String providerName,
    required String providerPhone,
    required String status,
  }) {
    return StreamBuilder<int>(
      stream: _chatService.streamUnreadCount(
        requestId: requestId,
        currentUserId: currentUserId,
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openChatPage(
                requestId: requestId,
                customerId: customerId,
                providerId: providerId,
                providerName: providerName,
                providerPhone: providerPhone,
                status: status,
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    final data = doc.data()!;
    final status = (data['status'] ?? 'pending').toString();
    final providerName = data['providerName']?.toString() ?? 'Provider';
    final providerId = data['providerId']?.toString() ?? '';
    final providerPhone = data['providerPhone']?.toString() ?? '';
    final customerId = data['userId']?.toString() ?? '';
    final serviceType = data['serviceType']?.toString() ?? 'Service';
    final problem = data['problemDescription']?.toString() ?? '';
    final address = data['serviceAddress']?.toString() ?? '';
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                  providerName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Service: $serviceType'),
          const SizedBox(height: 4),
          Text('Problem: $problem'),
          const SizedBox(height: 4),
          Text('Address: $address'),
          const SizedBox(height: 4),
          Text('Requested: ${_formatDate(createdAt)}'),
          const SizedBox(height: 4),
          Text('Last Update: ${_formatDate(updatedAt)}'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_canCancel(status))
                ElevatedButton(
                  onPressed: () => _cancelRequest(
                    requestId: doc.id,
                    status: status,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Cancel Request'),
                ),
              if (_canChat(status) &&
                  providerId.isNotEmpty &&
                  customerId.isNotEmpty &&
                  currentUserId.isNotEmpty)
                _buildChatButtonWithBadge(
                  requestId: doc.id,
                  currentUserId: currentUserId,
                  customerId: customerId,
                  providerId: providerId,
                  providerName: providerName,
                  providerPhone: providerPhone,
                  status: status,
                ),
              if (status == 'completed' && providerId.isNotEmpty)
                ElevatedButton(
                  onPressed: () => _openReviewPage(
                    requestId: doc.id,
                    providerId: providerId,
                    providerName: providerName,
                    serviceType: serviceType,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff7c5ac7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Rate & Review'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 18,
        left: 18,
        right: 18,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xff326178),
            Color(0xffdff1fc),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            child: Text(
              'My Requests',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: titleColor,
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

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _buildTopHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'active',
                            'Active (${activeDocs.length})',
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip(
                            'history',
                            'History (${historyDocs.length})',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: docsToShow.isEmpty
                          ? Center(
                        child: Text(
                          selectedFilter == 'active'
                              ? 'No active requests'
                              : 'No request history yet',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
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
          ),
        ],
      ),
    );
  }
}