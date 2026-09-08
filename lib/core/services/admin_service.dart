import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  Future<void> reviewRiderApplication({
    required String applicantId,
    required bool approve,
  }) async {
    await _functions.httpsCallable('reviewRiderApplication').call({
      'applicantId': applicantId,
      'decision': approve ? 'approved' : 'rejected',
    });
  }

  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'not-found') {
        return 'This application is no longer available.';
      }
      if (error.code == 'permission-denied') {
        return 'Administrator access is required.';
      }
      return error.message ?? 'Unable to review the application.';
    }
    return 'Unable to review the application. Check the connection and retry.';
  }
}
