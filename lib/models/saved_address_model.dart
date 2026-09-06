class SavedAddressModel {
  final String id;
  final String label; // 'Home', 'Office', 'Partner's Apartment', custom
  final String address;
  final String recipientName;
  final String recipientPhone;
  final String note; // e.g. "Leave with receptionist"
  final bool isDefault;

  SavedAddressModel({
    required this.id,
    required this.label,
    required this.address,
    required this.recipientName,
    required this.recipientPhone,
    required this.note,
    this.isDefault = false,
  });

  factory SavedAddressModel.fromMap(Map<String, dynamic> map, String id) {
    return SavedAddressModel(
      id: id,
      label: map['label'] ?? '',
      address: map['address'] ?? '',
      recipientName: map['recipientName'] ?? '',
      recipientPhone: map['recipientPhone'] ?? '',
      note: map['note'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'address': address,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'note': note,
      'isDefault': isDefault,
    };
  }
}