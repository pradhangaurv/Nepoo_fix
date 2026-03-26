import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool canChatForStatus(String status) {
    return status == 'accepted' ||
        status == 'on_the_way' ||
        status == 'arrived' ||
        status == 'in_progress';
  }

  Future<void> ensureChatExists({
    required String requestId,
    required String customerId,
    required String providerId,
  }) async {
    final chatRef = _db.collection('chats').doc(requestId);

    await chatRef.set({
      'requestId': requestId,
      'customerId': customerId,
      'providerId': providerId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageAt': null,
      'lastSenderId': '',
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages({
    required String requestId,
  }) {
    return _db
        .collection('chats')
        .doc(requestId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Stream<int> streamUnreadCount({
    required String requestId,
    required String currentUserId,
  }) {
    return _db
        .collection('chats')
        .doc(requestId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data();
        final senderId = data['senderId']?.toString() ?? '';
        return senderId.isNotEmpty && senderId != currentUserId;
      }).length;
    });
  }

  Future<void> markMessagesAsRead({
    required String requestId,
    required String currentUserId,
  }) async {
    final unreadSnap = await _db
        .collection('chats')
        .doc(requestId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadSnap.docs.isEmpty) return;

    final batch = _db.batch();

    for (final doc in unreadSnap.docs) {
      final data = doc.data();
      final senderId = data['senderId']?.toString() ?? '';
      final isRead = (data['isRead'] ?? false) == true;

      if (!isRead && senderId.isNotEmpty && senderId != currentUserId) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }
    }

    await batch.commit();
  }

  Future<void> sendMessage({
    required String requestId,
    required String customerId,
    required String providerId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = _db.collection('chats').doc(requestId);
    final messageRef = chatRef.collection('messages').doc();

    await ensureChatExists(
      requestId: requestId,
      customerId: customerId,
      providerId: providerId,
    );

    final batch = _db.batch();

    batch.set(messageRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    batch.set(
      chatRef,
      {
        'requestId': requestId,
        'customerId': customerId,
        'providerId': providerId,
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}