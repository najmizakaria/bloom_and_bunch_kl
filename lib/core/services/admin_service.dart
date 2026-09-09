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

  Future<Map<String, int>> syncDeliveryJobs() async {
    final result = await _functions.httpsCallable('syncDeliveryJobs').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return {
      'eligible': (data['eligible'] as num?)?.toInt() ?? 0,
      'excluded': (data['excluded'] as num?)?.toInt() ?? 0,
    };
  }

  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'not-found') {
        return 'This application is no longer available.';
      }
      if (error.code == 'permission-denied') {
        return 'Administrator access is required.';
      }
      if (error.code == 'failed-precondition') {
        return error.message ?? 'This application has already been reviewed.';
      }
      if (error.code == 'internal' || error.code == 'unavailable') {
        return 'The server could not complete this action. Please retry. If it continues, ask the project owner to check the function logs and database permissions.';
      }
      return error.message ?? 'Unable to review the application.';
    }
    return 'Unable to review the application. Check the connection and retry.';
  }
}
