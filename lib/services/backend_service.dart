import 'package:cloud_functions/cloud_functions.dart';

class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> cancelAcceptedRequest(String requestId) async {
    final callable = _functions.httpsCallable('cancelAcceptedRequest');
    await callable.call({
      'requestId': requestId,
    });
  }
}