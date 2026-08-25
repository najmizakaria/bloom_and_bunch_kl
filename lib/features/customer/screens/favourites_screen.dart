import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/favourites_service.dart';
import '../../../core/theme/app_colors.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favouritesService = FavouritesService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favourites'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: AppColors.primaryRosewood,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primaryRosewood,
            tabs: [
              Tab(text: 'Saved Bouquets'),
              Tab(text: 'Saved Recipes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Saved ready-made bouquets
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: favouritesService.favouriteBouquetsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _emptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No saved bouquets yet',
                    subtitle: 'Tap the heart on any bouquet in Home to save it here.',
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final bouquetId = docs[index].id;
                    final name = data['name'] ?? '';
                    final imageUrl = data['imageUrl'] ?? '';
                    final price = (data['price'] ?? 0).toDouble();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: AppColors.secondarySurface,
                                  child: const Icon(Icons.local_florist, color: AppColors.primaryRosewood),
                                ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('RM ${price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart, color: AppColors.primaryRosewood),
                              onPressed: () {
                                context.read<CartProvider>().addReadyMadeItem(
                                      bouquetId: bouquetId,
                                      name: name,
                                      imageUrl: imageUrl,
                                      price: price,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$name added to cart'), duration: const Duration(seconds: 1)),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.redAccent),
                              onPressed: () => favouritesService.toggleBouquetFavourite(
                                bouquetId: bouquetId,
                                name: name,
                                imageUrl: imageUrl,
                                price: price,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Saved custom recipes
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: favouritesService.favouriteRecipesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _emptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'No saved recipes yet',
                    subtitle: 'Build a custom bouquet in Customize and tap Save Recipe.',
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final recipeId = docs[index].id;
                    final wrapper = data['wrapper'] ?? '';
                    final ribbon = data['ribbon'] ?? '';
                    final totalPrice = (data['totalPrice'] ?? 0).toDouble();
                    final stems = (data['stems'] as List<dynamic>? ?? []);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Custom Recipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => favouritesService.deleteRecipe(recipeId),
                                ),
                              ],
                            ),
                            Text('$wrapper · $ribbon', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('${stems.length} stem type(s)', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'RM ${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRosewood, fontSize: 16),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryRosewood),
                                  onPressed: () {
                                    final stemMap = <String, int>{
                                      for (final s in stems) (s['flowerId'] as String): (s['quantity'] as int)
                                    };
                                    context.read<CartProvider>().addCustomItem(
                                          unitPrice: totalPrice,
                                          stems: stemMap,
                                          wrapper: wrapper,
                                          ribbon: ribbon,
                                          cardNote: '',
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Recipe added to cart 🛒'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                  child: const Text('Re-order'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}