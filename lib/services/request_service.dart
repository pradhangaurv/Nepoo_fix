import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> userHasActiveRequest({
    required String userId,
  }) async {
    final snap = await _db
        .collection('service_requests')
        .where('userId', isEqualTo: userId)
        .where(
      'status',
      whereIn: [
        'pending',
        'accepted',
        'on_the_way',
        'arrived',
        'in_progress',
      ],
    )
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<String> createServiceRequest({
    required String userId,
    required String providerId,
    required Map<String, dynamic> providerData,
    required String problemDescription,
    required String serviceAddress,
    required double serviceLatitude,
    required double serviceLongitude,
  }) async {
    final hasActiveRequest = await userHasActiveRequest(userId: userId);

    if (hasActiveRequest) {
      throw Exception(
        'You already have an active service request. Please complete or cancel it first.',
      );
    }

    final userSnap = await _db.collection('users').doc(userId).get();
    final userData = userSnap.data() ?? <String, dynamic>{};

    final docRef = await _db.collection('service_requests').add({
      'userId': userId,
      'userName': userData['name'] ?? 'User',
      'userPhone': userData['phone'] ?? '',
      'userAddress': userData['address'] ?? '',
      'providerId': providerId,
      'providerName': providerData['name'] ?? 'Provider',
      'providerPhone': providerData['phone'] ?? '',
      'serviceType': providerData['serviceType'] ?? '',
      'providerServiceDescription': providerData['serviceDescription'] ?? '',
      'pricePerHour': providerData['pricePerHour'],
      'problemDescription': problemDescription,
      'serviceAddress': serviceAddress,
      'serviceLatitude': serviceLatitude,
      'serviceLongitude': serviceLongitude,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> cancelCustomerRequest({
    required String requestId,
  }) async {
    final requestRef = _db.collection('service_requests').doc(requestId);

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);

      if (!requestSnap.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestSnap.data() ?? <String, dynamic>{};
      final status = (requestData['status'] ?? '').toString();
      final providerId = (requestData['providerId'] ?? '').toString();

      if (status != 'pending' && status != 'accepted') {
        throw Exception(
          'Only pending or accepted requests can be cancelled.',
        );
      }

      transaction.update(requestRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'accepted' && providerId.isNotEmpty) {
        final providerRef = _db.collection('users').doc(providerId);
        final providerSnap = await transaction.get(providerRef);

        if (providerSnap.exists) {
          final providerData = providerSnap.data() ?? <String, dynamic>{};
          final currentRequestId =
          (providerData['currentRequestId'] ?? '').toString();

          if (currentRequestId == requestId) {
            transaction.update(providerRef, {
              'isAvailable': true,
              'currentRequestId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    });
  }

  Future<void> updateProviderRequestStatus({
    required String providerId,
    required String requestId,
    required String status,
  }) async {
    final requestRef = _db.collection('service_requests').doc(requestId);
    final providerRef = _db.collection('users').doc(providerId);
    final chatRef = _db.collection('chats').doc(requestId);

    await _db.runTransaction((transaction) async {
      final providerSnap = await transaction.get(providerRef);
      final requestSnap = await transaction.get(requestRef);

      final providerData = providerSnap.data() ?? <String, dynamic>{};
      final requestData = requestSnap.data() ?? <String, dynamic>{};

      final currentRequestId = providerData['currentRequestId']?.toString();
      final customerId = requestData['userId']?.toString() ?? '';

      final requestUpdate = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'in_progress') {
        requestUpdate['workStartedAt'] = FieldValue.serverTimestamp();
      }

      transaction.update(requestRef, requestUpdate);

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

        transaction.set(
          chatRef,
          {
            'requestId': requestId,
            'customerId': customerId,
            'providerId': providerId,
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': '',
            'lastMessageAt': null,
            'lastSenderId': '',
          },
          SetOptions(merge: true),
        );
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
  }

  Future<void> completeProviderRequest({
    required String providerId,
    required String requestId,
    required int workedMinutes,
    required double billedHours,
    required double finalAmount,
  }) async {
    final requestRef = _db.collection('service_requests').doc(requestId);
    final providerRef = _db.collection('users').doc(providerId);

    await _db.runTransaction((transaction) async {
      final providerSnap = await transaction.get(providerRef);
      final requestSnap = await transaction.get(requestRef);

      if (!requestSnap.exists) {
        throw Exception('Request not found');
      }

      final providerData = providerSnap.data() ?? <String, dynamic>{};
      final currentRequestId =
      (providerData['currentRequestId'] ?? '').toString();

      transaction.update(requestRef, {
        'status': 'completed',
        'workedMinutes': workedMinutes,
        'billedHours': billedHours,
        'finalAmount': finalAmount,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (currentRequestId == requestId || currentRequestId.isEmpty) {
        transaction.update(providerRef, {
          'isAvailable': true,
          'currentRequestId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}