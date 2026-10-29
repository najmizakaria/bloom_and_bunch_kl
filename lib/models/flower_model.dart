class FlowerModel {
  final String flowerId;
  final String name;
  final String category;
  final double pricePerStem;
  final int stockQuantity;
  final int reservedQuantity;
  int get projectedBalance => stockQuantity - reservedQuantity;
  int get shortageQuantity => projectedBalance < 0 ? -projectedBalance : 0;
  final String imageUrl;
  final bool isAvailable;

  /// Customers can request this flower for a planned custom bouquet.
  /// This remains independent from the physical stock currently on hand.
  final bool availableForCustomOrder;

  FlowerModel({
    required this.flowerId,
    required this.name,
    required this.category,
    required this.pricePerStem,
    required this.stockQuantity,
    required this.imageUrl,
    this.isAvailable = true,
    this.reservedQuantity = 0,
    this.availableForCustomOrder = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'flowerId': flowerId,
      'name': name,
      'category': category,
      'pricePerStem': pricePerStem,
      'stockQuantity': stockQuantity,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'availableForCustomOrder': availableForCustomOrder,
    };
  }

  factory FlowerModel.fromMap(Map<String, dynamic> map, String docId) {
    return FlowerModel(
      flowerId: docId,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      pricePerStem: (map['pricePerStem'] as num? ?? 0).toDouble(),
      stockQuantity: (map['stockQuantity'] as num? ?? 0).toInt(),
      reservedQuantity: (map['reservedQuantity'] as num? ?? 0).toInt(),
      imageUrl: map['imageUrl'] as String? ?? '',
      isAvailable: map['isAvailable'] as bool? ?? true,
      // Old records default to sourceable. Their current stock must not block
      // a custom bouquet that the florist has 1-3 business days to prepare.
      availableForCustomOrder: map['availableForCustomOrder'] as bool? ?? true,
    );
  }
}
