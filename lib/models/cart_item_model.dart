import '../core/constants/fulfillment_constants.dart';

class CartItemModel {
  final String id;
  final String type;
  final String name;
  final String imageUrl;
  final double unitPrice;
  int quantity;

  final String fulfillmentType;
  final int leadTimeBusinessDays;

  final String? bouquetId;
  final Map<String, int>? customStems;
  final Map<String, String>? customStemNames;
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
    this.fulfillmentType = FulfillmentTypes.readyNow,
    this.leadTimeBusinessDays = 0,
    this.bouquetId,
    this.customStems,
    this.customStemNames,
    this.wrapper,
    this.ribbon,
    this.cardNote,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> data) => CartItemModel(
    id: data['id'] as String,
    type: data['type'] as String,
    name: data['name'] as String,
    imageUrl: data['imageUrl'] as String,
    unitPrice: (data['unitPrice'] as num).toDouble(),
    quantity: data['quantity'] as int,
    bouquetId: data['bouquetId'] as String?,
    fulfillmentType: data['fulfillmentType'] as String,
    leadTimeBusinessDays: data['leadTimeBusinessDays'] as int? ?? 0,
    customStems: data['customStems'] == null
        ? null
        : Map<String, int>.from(data['customStems'] as Map),
    customStemNames: data['customStemNames'] == null
        ? null
        : Map<String, String>.from(data['customStemNames'] as Map),
    wrapper: data['wrapper'] as String?,
    ribbon: data['ribbon'] as String?,
    cardNote: data['cardNote'] as String?,
  );

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'fulfillmentType': fulfillmentType,
      'leadTimeBusinessDays': leadTimeBusinessDays,
      'bouquetId': bouquetId,
      'customStems': customStems,
      'customStemNames': customStemNames,
      'wrapper': wrapper,
      'ribbon': ribbon,
      'cardNote': cardNote,
    };
  }
}
