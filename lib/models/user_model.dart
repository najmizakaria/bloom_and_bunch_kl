import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  static const allowedRoles = ['customer', 'florist', 'rider', 'admin'];

  final String uid;
  final String name;
  final String email;
  final String phone;

  /// Legacy primary role, retained so existing accounts remain readable.
  final String role;
  final List<String> roles;
  final String activeRole;
  final DateTime createdAt;
  final bool accountSuspended;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    List<String>? roles,
    String? activeRole,
    required this.createdAt,
    this.accountSuspended = false,
  }) : roles = List.unmodifiable(roles ?? [role]),
       activeRole = activeRole ?? role;

  bool hasRole(String value) => roles.contains(value) || role == value;

  // Convert Dart Object -> Firestore JSON Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'roles': roles,
      'activeRole': activeRole,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Convert Firestore JSON Map -> Dart Object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    if (map['role'] == null &&
        (map['roles'] is! List || (map['roles'] as List).isEmpty)) {
      throw const FormatException('Account roles are missing.');
    }
    final legacyRole =
        map['role']?.toString() ?? (map['roles'] as List).first.toString();
    if (!allowedRoles.contains(legacyRole)) {
      throw const FormatException('Invalid account role.');
    }
    if (map['roles'] != null &&
        (map['roles'] is! List ||
            (map['roles'] as List).any(
              (role) => role is! String || !allowedRoles.contains(role),
            ))) {
      throw const FormatException('Invalid account roles.');
    }
    final storedRoles = (map['roles'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where(allowedRoles.contains)
        .toSet()
        .toList();
    final roles = storedRoles.isEmpty ? [legacyRole] : storedRoles;
    final requestedActiveRole = map['activeRole']?.toString();

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: legacyRole,
      roles: roles,
      activeRole: roles.contains(requestedActiveRole)
          ? requestedActiveRole
          : roles.contains(legacyRole)
          ? legacyRole
          : roles.first,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accountSuspended: map['accountSuspended'] == true,
    );
  }
}
