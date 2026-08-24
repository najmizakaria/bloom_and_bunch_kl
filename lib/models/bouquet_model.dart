class BouquetModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category; // e.g. 'Birthday', 'Anniversary', 'Sympathy'
  final bool readyToSend; // true = sitting on shelf, instant dispatch
  final int stockCount;

  BouquetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.readyToSend,
    required this.stockCount,
  });

  factory BouquetModel.fromMap(Map<String, dynamic> map, String id) {
    return BouquetModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? 'All',
      readyToSend: map['readyToSend'] ?? true,
      stockCount: map['stockCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'readyToSend': readyToSend,
      'stockCount': stockCount,
    };
  }
}