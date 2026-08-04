class FlowerModel {
  final String flowerId;
  final String name;
  final String category;
  final double pricePerStem;
  final int stockQuantity;
  final String imageUrl;
  final bool isAvailable;

  FlowerModel({
    required this.flowerId,
    required this.name,
    required this.category,
    required this.pricePerStem,
    required this.stockQuantity,
    required this.imageUrl,
    this.isAvailable = true,
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
    };
  }

  factory FlowerModel.fromMap(Map<String, dynamic> map, String docId) {
    return FlowerModel(
      flowerId: docId,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      pricePerStem: (map['pricePerStem'] ?? 0.0).toDouble(),
      stockQuantity: map['stockQuantity'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
    );
  }
}