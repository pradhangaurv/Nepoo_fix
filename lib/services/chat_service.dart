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