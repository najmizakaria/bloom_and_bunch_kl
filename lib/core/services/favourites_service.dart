import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavouritesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _bouquetFavourites =>
      _db.collection('users').doc(_uid).collection('favourite_bouquets');

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _db.collection('users').doc(_uid).collection('favourite_recipes');

  // ----- Saved ready-made bouquets -----

  Stream<QuerySnapshot<Map<String, dynamic>>> favouriteBouquetsStream() {
    if (_uid == null) return const Stream.empty();
    return _bouquetFavourites.orderBy('savedAt', descending: true).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> isBouquetFavourited(
    String bouquetId,
  ) {
    if (_uid == null) return const Stream.empty();
    return _bouquetFavourites.doc(bouquetId).snapshots();
  }

  Future<void> toggleBouquetFavourite({
    required String bouquetId,
    required String name,
    required String imageUrl,
    required double price,
  }) async {
    if (_uid == null) return;
    final doc = _bouquetFavourites.doc(bouquetId);
    final snapshot = await doc.get();

    if (snapshot.exists) {
      await doc.delete();
    } else {
      await doc.set({
        'name': name,
        'imageUrl': imageUrl,
        'price': price,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ----- Saved custom recipes -----

  Stream<QuerySnapshot<Map<String, dynamic>>> favouriteRecipesStream() {
    if (_uid == null) return const Stream.empty();
    return _recipes.orderBy('savedAt', descending: true).snapshots();
  }

  Future<void> saveRecipe({
    required Map<String, int> stems,
    required String wrapper,
    required String ribbon,
    required double totalPrice,
  }) async {
    if (_uid == null) return;
    await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('saveRecipe').call({
      'customStems': stems,
      'wrapper': wrapper,
      'ribbon': ribbon,
      'cardNote': '',
    });
  }

  Future<void> deleteRecipe(String recipeId) async {
    if (_uid == null) return;
    await _recipes.doc(recipeId).delete();
  }
}
