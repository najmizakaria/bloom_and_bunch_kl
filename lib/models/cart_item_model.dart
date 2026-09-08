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

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
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
