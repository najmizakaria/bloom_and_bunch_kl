class CartItemModel {
  final String id; // unique cart line id
  final String type; // 'ready' or 'custom'
  final String name;
  final String imageUrl;
  final double unitPrice;
  int quantity;

  // Ready-made specific
  final String? bouquetId;

  // Custom specific
  final Map<String, int>? customStems; // flowerId -> qty
  final String? wrapper;
  final String? ribbon;
  final String? cardNote;

  CartItemModel({
    required this.id,
    required this.type,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    this.quantity = 1,
    this.bouquetId,
    this.customStems,
    this.wrapper,
    this.ribbon,
    this.cardNote,
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'bouquetId': bouquetId,
      'customStems': customStems,
      'wrapper': wrapper,
      'ribbon': ribbon,
      'cardNote': cardNote,
    };
  }
}