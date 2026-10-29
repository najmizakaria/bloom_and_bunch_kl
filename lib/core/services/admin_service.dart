import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_environment.dart';

class AdminService {
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

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
    if (error is StateError) return error.message.toString();
    if (error is FirebaseFunctionsException) {
      final serverMessage = error.message?.trim();
      final generic =
          serverMessage == null ||
          serverMessage.isEmpty ||
          RegExp(
            r'^(internal|unknown|unavailable|not-found|unauthenticated|permission-denied)(\s*\[\d+\])?$',
            caseSensitive: false,
          ).hasMatch(serverMessage);
      if (error.code == 'unauthenticated') {
        return 'Your session has expired. Please sign in again.';
      }
      if (error.code == 'not-found') {
        return generic
            ? 'This admin service is not available yet. Please contact the store administrator.'
            : serverMessage;
      }
      if (error.code == 'permission-denied') {
        return generic
            ? 'Administrator access is required. Please sign in with an admin account.'
            : serverMessage;
      }
      if (error.code == 'failed-precondition') {
        return generic
            ? 'This action is not ready yet. Refresh the page and retry.'
            : serverMessage;
      }
      if ([
        'internal',
        'unavailable',
        'unknown',
        'deadline-exceeded',
      ].contains(error.code)) {
        return AppEnvironment.isDemo
            ? 'The local admin service could not be reached. Start the Firebase emulators, then retry.'
            : 'The admin service could not be reached. Please retry or contact the store administrator.';
      }
      return generic
          ? 'Could not complete this admin action. Please retry.'
          : serverMessage;
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'You do not have access to this admin information. Please sign in with an admin account.';
    }
    return 'Could not load admin information. Check your connection and retry.';
  }
}
