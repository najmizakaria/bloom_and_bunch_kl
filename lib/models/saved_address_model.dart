class SavedAddressModel {
  final String id, label, address, recipientName, recipientPhone, note;
  final bool isDefault;
  final double? latitude, longitude;
  const SavedAddressModel({
    required this.id,
    required this.label,
    required this.address,
    required this.recipientName,
    required this.recipientPhone,
    required this.note,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });
  factory SavedAddressModel.fromMap(Map<String, dynamic> m, String id) =>
      SavedAddressModel(
        id: id,
        label: m['label'] ?? '',
        address: m['address'] ?? '',
        recipientName: m['recipientName'] ?? '',
        recipientPhone: m['recipientPhone'] ?? '',
        note: m['note'] ?? '',
        isDefault: m['isDefault'] == true,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toMap() => {
    'label': label,
    'address': address,
    'recipientName': recipientName,
    'recipientPhone': recipientPhone,
    'note': note,
    'isDefault': isDefault,
    'latitude': latitude,
    'longitude': longitude,
  };
}
