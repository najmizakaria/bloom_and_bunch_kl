import '../../admin/admin_theme.dart';
import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/widgets/firestore_page.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import '../../../core/services/product_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/flower_model.dart';

class FloristInventoryScreen extends StatelessWidget {
  const FloristInventoryScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  Future<void> _updateStock(String documentId, int change) async {
    final documentReference = FirebaseFirestore.instance
        .collection('flowers')
        .doc(documentId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(documentReference);

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data() ?? {};

      final currentStock = (data['stockQuantity'] as num?)?.toInt() ?? 0;

      final newStock = (currentStock + change).clamp(0, 999999).toInt();

      final Map<String, dynamic> updates = {
        'stockQuantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.update(documentReference, updates);
    });
  }

  Future<void> _toggleAvailability(
    BuildContext context,
    FlowerModel flower,
    bool newValue,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('flowers')
          .doc(flower.flowerId)
          .update({
            'availableForCustomOrder': newValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update availability: $error'),
          backgroundColor: AdminTheme.sharedColor(
            context,
            AppColors.primaryDark,
          ),
        ),
      );
    }
  }

  Future<String> _uploadImage(ProductImage image) async {
    return image.upload('flowers');
  }

  void _showAddFlowerDialog(BuildContext context) {
    _showFlowerForm(context: context);
  }

  void _showEditFlowerDialog(BuildContext context, FlowerModel flower) {
    _showFlowerForm(context: context, existingFlower: flower);
  }

  Future<void> _showFlowerForm({
    required BuildContext context,
    FlowerModel? existingFlower,
  }) async {
    final isEditing = existingFlower != null;

    final nameController = TextEditingController(
      text: existingFlower?.name ?? '',
    );
    final categoryController = TextEditingController(
      text: existingFlower?.category ?? '',
    );
    final priceController = TextEditingController(
      text: existingFlower?.pricePerStem.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: existingFlower?.stockQuantity.toString() ?? '',
    );

    ProductImage? selectedImage;
    String imageUrl = existingFlower?.imageUrl ?? '';
    bool isUploading = false;

    final picker = ImagePicker();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> selectImage() async {
              final source = await showModalBottomSheet<ImageSource>(
                context: dialogContext,
                builder: (sheetContext) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Choose from gallery'),
                          onTap: () {
                            Navigator.pop(sheetContext, ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: const Text('Take a photo'),
                          onTap: () {
                            Navigator.pop(sheetContext, ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );

              if (source == null || !dialogContext.mounted) {
                return;
              }

              final selectedFile = await picker.pickImage(
                source: source,
                imageQuality: 75,
              );

              if (!dialogContext.mounted) {
                return;
              }

              if (selectedFile != null) {
                try {
                  final image = await ProductImage.read(selectedFile);
                  if (!dialogContext.mounted) return;
                  setDialogState(() => selectedImage = image);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          error is StateError
                              ? error.message.toString()
                              : 'Could not read this image.',
                        ),
                      ),
                    );
                  }
                }
              }
            }

            Future<void> saveFlower() async {
              final name = nameController.text.trim();
              final category = categoryController.text.trim();
              final price = double.tryParse(priceController.text.trim());
              final stock = int.tryParse(stockController.text.trim());

              if (name.isEmpty ||
                  category.isEmpty ||
                  price == null ||
                  price < 0 ||
                  stock == null ||
                  stock < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enter a valid name, category, price and stock.',
                    ),
                    backgroundColor: AdminTheme.sharedColor(
                      context,
                      AppColors.primaryDark,
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                isUploading = true;
              });

              try {
                if (selectedImage != null) {
                  imageUrl = await _uploadImage(selectedImage!);
                }

                final data = {
                  'name': name,
                  'category': category,
                  'pricePerStem': price,
                  'stockQuantity': stock,
                  'imageUrl': imageUrl,

                  // Custom ordering is independent from physical stock.
                  'availableForCustomOrder':
                      existingFlower?.availableForCustomOrder ?? true,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEditing) {
                  final ref = FirebaseFirestore.instance
                      .collection('flowers')
                      .doc(existingFlower.flowerId);
                  await FirebaseFirestore.instance.runTransaction((
                    transaction,
                  ) async {
                    final current = await transaction.get(ref);
                    if (!current.exists ||
                        current.data()?['stockQuantity'] !=
                            existingFlower.stockQuantity) {
                      throw StateError(
                        'Flower stock changed. Reopen the flower before saving.',
                      );
                    }
                    transaction.update(ref, data);
                  });
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();

                  await FirebaseFirestore.instance
                      .collection('flowers')
                      .add(data);
                }

                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Flower updated successfully'
                          : 'Flower added successfully',
                    ),
                    backgroundColor: AdminTheme.sharedColor(
                      context,
                      AppColors.primaryDark,
                    ),
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isUploading = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Unable to save flower: $error'),
                    backgroundColor: AdminTheme.sharedColor(
                      context,
                      AppColors.primaryDark,
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit Flower' : 'Add Flower'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : selectImage,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AdminTheme.sharedColor(
                              context,
                              AppColors.inputFill,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AdminTheme.sharedColor(
                                context,
                                AppColors.inputBorder,
                              ),
                            ),
                          ),
                          child: _buildFormImage(selectedImage, imageUrl),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        enabled: !isUploading,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Flower name',
                          hintText: 'Example: Red Rose',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: categoryController,
                        enabled: !isUploading,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'Example: Roses',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        enabled: !isUploading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price per stem',
                          prefixText: 'RM ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stockController,
                        enabled: !isUploading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock quantity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.sharedColor(
                      context,
                      AppColors.primary,
                    ),
                    foregroundColor: AppColors.onPrimary,
                  ),
                  onPressed: isUploading ? null : saveFlower,
                  child: isUploading
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Add Flower'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    stockController.dispose();
  }

  Widget _buildFormImage(ProductImage? selectedImage, String existingImageUrl) {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.memory(selectedImage.bytes, fit: BoxFit.cover),
      );
    }

    if (existingImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          existingImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const _FlowerImagePlaceholder();
          },
        ),
      );
    }

    return const _FlowerImagePlaceholder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.sharedColor(context, AppColors.background),
      appBar: showAppBar
          ? AppBar(
              leading: const PageBackButton(),
              centerTitle: false,
              title: const Text('Manage Flowers'),
              backgroundColor: AdminTheme.sharedColor(
                context,
                AppColors.primary,
              ),
              foregroundColor: AppColors.onPrimary,
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddFlowerDialog(context);
        },
        backgroundColor: AdminTheme.sharedColor(context, AppColors.primary),
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Flower'),
      ),
      body: FirestorePage(
        query: FirebaseFirestore.instance
            .collection('flowers')
            .orderBy('category'),
        emptyMessage: 'No flowers yet. Use Add Flower to create one.',
        builder: (context, docs) {
          final flowers = docs.map((document) {
            return FlowerModel.fromMap(document.data(), document.id);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
            itemCount: flowers.length,
            itemBuilder: (context, index) {
              final flower = flowers[index];

              return _FlowerInventoryCard(
                flower: flower,
                onEdit: () {
                  _showEditFlowerDialog(context, flower);
                },
                onDecreaseStock: () async {
                  try {
                    await _updateStock(flower.flowerId, -1);
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unable to update stock: $error'),
                        backgroundColor: AdminTheme.sharedColor(
                          context,
                          AppColors.primaryDark,
                        ),
                      ),
                    );
                  }
                },
                onIncreaseStock: () async {
                  try {
                    await _updateStock(flower.flowerId, 1);
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unable to update stock: $error'),
                        backgroundColor: AdminTheme.sharedColor(
                          context,
                          AppColors.primaryDark,
                        ),
                      ),
                    );
                  }
                },
                onAvailabilityChanged: (value) {
                  _toggleAvailability(context, flower, value);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FlowerInventoryCard extends StatelessWidget {
  const _FlowerInventoryCard({
    required this.flower,
    required this.onEdit,
    required this.onDecreaseStock,
    required this.onIncreaseStock,
    required this.onAvailabilityChanged,
  });

  final FlowerModel flower;
  final VoidCallback onEdit;
  final VoidCallback onDecreaseStock;
  final VoidCallback onIncreaseStock;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 78,
                  height: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: flower.imageUrl.isEmpty
                        ? const _FlowerImagePlaceholder()
                        : Image.network(
                            flower.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const _FlowerImagePlaceholder();
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flower.name.isEmpty ? 'Unnamed Flower' : flower.name,
                        style: const AppTypography.productTitle(),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        flower.category.isEmpty
                            ? 'Uncategorised'
                            : flower.category,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RM ${flower.pricePerStem.toStringAsFixed(2)} / stem',
                        style: AppTypography.price(
                          color: AdminTheme.sharedColor(
                            context,
                            AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Reserved: ${flower.reservedQuantity} · Balance: ${flower.projectedBalance}',
                      ),
                      if (flower.shortageQuantity > 0)
                        Text(
                          'Restock ${flower.shortageQuantity} stems',
                          style: TextStyle(
                            color: AdminTheme.sharedColor(
                              context,
                              AppColors.primaryDark,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _FlowerStockBadge(
                        stock: flower.stockQuantity,
                        available: flower.availableForCustomOrder,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit flower',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                const Text('Stock', style: AppTypography.label()),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Decrease stock',
                  onPressed: flower.stockQuantity > 0 ? onDecreaseStock : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 38),
                  alignment: Alignment.center,
                  child: Text(
                    '${flower.stockQuantity}',
                    style: AppTypography.productTitle(
                      color: flower.stockQuantity <= 5
                          ? AdminTheme.sharedColor(
                              context,
                              AppColors.primaryDark,
                            )
                          : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase stock',
                  onPressed: onIncreaseStock,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Text('Custom orders', style: AppTypography.caption()),
                Switch.adaptive(
                  value: flower.availableForCustomOrder,
                  activeThumbColor: AdminTheme.sharedColor(
                    context,
                    AppColors.primary,
                  ),
                  onChanged: onAvailabilityChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerStockBadge extends StatelessWidget {
  const _FlowerStockBadge({required this.stock, required this.available});

  final int stock;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;

    if (stock <= 0) {
      label = 'Out of stock';
      color = AdminTheme.sharedColor(context, AppColors.primaryDark);
      icon = Icons.cancel_outlined;
    } else if (!available) {
      label = 'Unavailable';
      color = Colors.grey;
      icon = Icons.visibility_off_outlined;
    } else if (stock <= 5) {
      label = 'Low stock';
      color = AdminTheme.sharedColor(context, AppColors.primaryDark);
      icon = Icons.warning_amber_rounded;
    } else {
      label = 'In stock';
      color = AdminTheme.sharedColor(context, AppColors.primaryDark);
      icon = Icons.check_circle_outline;
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.badge(color: color)),
      ],
    );
  }
}

class _FlowerImagePlaceholder extends StatelessWidget {
  const _FlowerImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminTheme.sharedColor(context, AppColors.inputFill),
      child: Center(
        child: Icon(
          Icons.local_florist_outlined,
          color: AdminTheme.sharedColor(context, AppColors.primary),
          size: 36,
        ),
      ),
    );
  }
}
