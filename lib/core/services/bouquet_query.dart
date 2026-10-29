import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/bouquet_model.dart';

enum BouquetMode { all, readyNow, preOrder }

Query<Map<String, dynamic>> bouquetQuery(String category, BouquetMode mode) {
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
    'bouquets',
  );
  if (category != 'All') query = query.where('category', isEqualTo: category);
  if (mode == BouquetMode.readyNow) {
    query = query.where(
      Filter.or(
        Filter('availableForReadyNow', isEqualTo: true),
        Filter('readyToSend', isEqualTo: true),
      ),
    );
  }
  if (mode == BouquetMode.preOrder) {
    query = query.where('availableForPreOrder', isEqualTo: true);
  }
  // Older products omit publication/stock fields; retain the model's compatibility checks.
  return query.orderBy(FieldPath.documentId);
}

bool matchesBouquetMode(BouquetModel bouquet, BouquetMode mode) =>
    bouquet.isPublished &&
    switch (mode) {
      BouquetMode.all => true,
      BouquetMode.readyNow =>
        bouquet.availableForReadyNow && bouquet.readyStock > 0,
      BouquetMode.preOrder => bouquet.availableForPreOrder,
    };
