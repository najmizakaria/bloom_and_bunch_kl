import 'package:cloud_functions/cloud_functions.dart';
import '../utils/malaysian_phone.dart';

class RiderContact {
  const RiderContact({required this.name, required this.phone});
  final String name, phone;
}

class RiderContactService {
  Future<RiderContact> getForOrder(String orderId) async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('getAssignedRiderContact').call({'orderId': orderId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return RiderContact(
      name: data['name'] as String,
      phone: MalaysianPhone.normalize(data['phone'] as String),
    );
  }
}
