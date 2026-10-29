class SavedAddressModel {
  final String id, label, address, recipientName, recipientPhone, note;
  final bool isDefault;
  final String locality, postcode, state;
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
    this.locality = '',
    this.postcode = '',
    this.state = '',
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
        locality: m['locality'] as String? ?? '',
        postcode: m['postcode'] as String? ?? '',
        state: m['state'] as String? ?? '',
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
    if (locality.isNotEmpty) 'locality': locality,
    if (postcode.isNotEmpty) 'postcode': postcode,
    if (state.isNotEmpty) 'state': state,
  };

  static const states = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Penang',
    'Perak',
    'Perlis',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Kuala Lumpur',
    'Putrajaya',
    'Labuan',
  ];
  static String canonicalState(String value) {
    final text = value.trim().replaceFirst(
      RegExp(r'^(?:w\.?p\.?|wilayah persekutuan)\s*', caseSensitive: false),
      '',
    );
    for (final state in states) {
      if (state.toLowerCase() == text.toLowerCase()) return state;
    }
    return {
          'kl': 'Kuala Lumpur',
          'pulau pinang': 'Penang',
          'malacca': 'Melaka',
        }[text.toLowerCase()] ??
        '';
  }
}
