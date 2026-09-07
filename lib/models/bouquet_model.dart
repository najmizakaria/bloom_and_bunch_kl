class BouquetModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;

  // Product publication is separate from fulfillment availability.
  final bool isPublished;

  // Ready-to-Send settings.
  final bool availableForReadyNow;
  final int readyStock;

  // Pre-Order settings.
  final bool availableForPreOrder;
  final int leadTimeBusinessDays;

  // Flower ID -> stems required to build one bouquet.
  final Map<String, int> recipeStems;

  const BouquetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.isPublished,
    required this.availableForReadyNow,
    required this.readyStock,
    required this.availableForPreOrder,
    required this.leadTimeBusinessDays,
    required this.recipeStems,
  });

  // Temporary compatibility getters for screens that have not been
  // migrated yet.
  bool get readyToSend => availableForReadyNow;
  int get stockCount => readyStock;

  factory BouquetModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final rawRecipe = map['recipeStems'];

    final recipe = rawRecipe is Map
        ? rawRecipe.map(
            (key, value) => MapEntry(
              key.toString(),
              (value as num?)?.toInt() ?? 0,
            ),
          )
        : <String, int>{};

    return BouquetModel(
      id: id,
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      category: (map['category'] ?? 'Birthday').toString(),
      isPublished:
          map['isPublished'] as bool? ?? map['archived'] != true,
      availableForReadyNow:
          map['availableForReadyNow'] as bool? ??
              map['readyToSend'] as bool? ??
              false,
      readyStock:
          (map['readyStock'] as num?)?.toInt() ??
              (map['stockCount'] as num?)?.toInt() ??
              0,
      availableForPreOrder:
          map['availableForPreOrder'] as bool? ?? false,
      leadTimeBusinessDays:
          ((map['leadTimeBusinessDays'] as num?)?.toInt() ?? 2)
              .clamp(1, 3),
      recipeStems: recipe,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isPublished': isPublished,
      'availableForReadyNow': availableForReadyNow,
      'readyStock': readyStock,
      'availableForPreOrder': availableForPreOrder,
      'leadTimeBusinessDays': leadTimeBusinessDays,
      'recipeStems': recipeStems,

      // Temporary compatibility fields. Remove only after every screen and
      // existing Firestore document has been migrated.
      'readyToSend': availableForReadyNow,
      'stockCount': readyStock,
    };
  }
}