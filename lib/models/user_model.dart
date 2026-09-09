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

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    List<String>? roles,
    String? activeRole,
    required this.createdAt,
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
    final legacyRole = map['role']?.toString() ?? 'customer';
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
          : legacyRole,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
