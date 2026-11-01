import '../../admin/admin_theme.dart';
import '../../../core/widgets/firestore_page.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import '../../../core/services/product_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/bouquet_model.dart';
import '../../../models/flower_model.dart';

class FloristBouquetsTab extends StatefulWidget {
  const FloristBouquetsTab({super.key});

  @override
  State<FloristBouquetsTab> createState() => _FloristBouquetsTabState();
}

class _FloristBouquetsTabState extends State<FloristBouquetsTab> {
  bool _showArchived = false;

  Future<String> _uploadImage(ProductImage image) async {
    return image.upload('bouquets');
  }

  Future<void> _changeReadyStock(BouquetModel bouquet, int change) async {
    final reference = FirebaseFirestore.instance
        .collection('bouquets')
        .doc(bouquet.id);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;

        final data = snapshot.data() ?? {};
        final currentStock =
            (data['readyStock'] as num?)?.toInt() ??
            (data['stockCount'] as num?)?.toInt() ??
            0;
        final newStock = (currentStock + change).clamp(0, 999999).toInt();

        final updates = <String, dynamic>{
          'readyStock': newStock,
          'stockCount': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (newStock == 0) {
          updates['availableForReadyNow'] = false;
          updates['readyToSend'] = false;
        }

        transaction.update(reference, updates);
      });
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to update Ready-to-Send stock: $error');
    }
  }

  Future<void> _setPublished(BouquetModel bouquet, bool published) async {
    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
            'isPublished': published,
            'readyToSend':
                published &&
                bouquet.availableForReadyNow &&
                bouquet.readyStock > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to update publication: $error');
    }
  }

  Future<void> _setReadyNowAvailability(
    BouquetModel bouquet,
    bool available,
  ) async {
    if (available && bouquet.readyStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add assembled bouquet stock before enabling Ready to Send.',
          ),
          backgroundColor: AdminTheme.sharedColor(
            context,
            AppColors.primaryDark,
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
            'availableForReadyNow': available,
            'readyToSend':
                available && bouquet.isPublished && bouquet.readyStock > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to update Ready-to-Send availability: $error');
    }
  }

  Future<void> _archiveBouquet(BouquetModel bouquet) async {
    final confirmed = await _confirm(
      title: 'Archive bouquet?',
      message: '${bouquet.name} will be hidden from both customer catalogues.',
      confirmLabel: 'Archive',
    );
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
            'archived': true,
            'isPublished': false,
            'readyToSend': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to archive bouquet: $error');
    }
  }

  Future<void> _restoreBouquet(BouquetModel bouquet) async {
    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
            'archived': false,
            'isPublished': false,
            'readyToSend': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bouquet restored as unpublished. Review it before publishing.',
          ),
          backgroundColor: AdminTheme.sharedColor(
            context,
            AppColors.primaryDark,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to restore bouquet: $error');
    }
  }

  Future<void> _deleteBouquet(BouquetModel bouquet) async {
    final confirmed = await _confirm(
      title: 'Delete bouquet permanently?',
      message: '${bouquet.name} cannot be recovered after deletion.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .delete();
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to delete bouquet: $error');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? AdminTheme.sharedColor(context, AppColors.primaryDark)
                  : AdminTheme.sharedColor(context, AppColors.primary),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showBouquetForm({BouquetModel? existingBouquet}) async {
    final editing = existingBouquet != null;

    List<FlowerModel> flowers = [];
    try {
      final flowerSnapshot = await FirebaseFirestore.instance
          .collection('flowers')
          .orderBy('name')
          .get();
      flowers = flowerSnapshot.docs
          .map((document) => FlowerModel.fromMap(document.data(), document.id))
          .toList();
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to load flowers for the bouquet recipe: $error');
      return;
    }

    if (!mounted) return;

    const categories = ['Birthday', 'Anniversary', 'Sympathy', 'Romance'];

    final nameController = TextEditingController(
      text: existingBouquet?.name ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingBouquet?.description ?? '',
    );
    final priceController = TextEditingController(
      text: existingBouquet?.price.toStringAsFixed(2) ?? '',
    );
    final readyStockController = TextEditingController(
      text: existingBouquet?.readyStock.toString() ?? '0',
    );

    var selectedCategory = categories.contains(existingBouquet?.category)
        ? existingBouquet!.category
        : categories.first;
    var isPublished = existingBouquet?.isPublished ?? true;
    var availableForReadyNow = existingBouquet?.availableForReadyNow ?? true;
    var availableForPreOrder = existingBouquet?.availableForPreOrder ?? false;
    var leadTimeBusinessDays = (existingBouquet?.leadTimeBusinessDays ?? 2)
        .clamp(2, 3);
    final recipeStems = <String, int>{...?existingBouquet?.recipeStems};

    ProductImage? selectedImage;
    var imageUrl = existingBouquet?.imageUrl ?? '';
    var saving = false;
    final imagePicker = ImagePicker();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickImage() async {
            final source = await showModalBottomSheet<ImageSource>(
              context: dialogContext,
              builder: (sheetContext) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('Choose from gallery'),
                      onTap: () =>
                          Navigator.pop(sheetContext, ImageSource.gallery),
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined),
                      title: const Text('Take a photo'),
                      onTap: () =>
                          Navigator.pop(sheetContext, ImageSource.camera),
                    ),
                  ],
                ),
              ),
            );

            if (source == null || !dialogContext.mounted) return;
            final picked = await imagePicker.pickImage(
              source: source,
              imageQuality: 75,
            );
            if (!dialogContext.mounted || picked == null) return;
            try {
              final image = await ProductImage.read(picked);
              if (!dialogContext.mounted) return;
              setDialogState(() => selectedImage = image);
            } catch (error) {
              if (dialogContext.mounted) {
                _showDialogMessage(
                  dialogContext,
                  error is StateError
                      ? error.message.toString()
                      : 'Could not read this image.',
                  error: true,
                );
              }
            }
          }

          Future<void> save() async {
            final name = nameController.text.trim();
            final description = descriptionController.text.trim();
            final price = double.tryParse(priceController.text.trim());
            final readyStock = int.tryParse(readyStockController.text.trim());
            final cleanedRecipe = <String, int>{
              for (final entry in recipeStems.entries)
                if (entry.value > 0) entry.key: entry.value,
            };

            if (name.isEmpty ||
                price == null ||
                price < 0 ||
                readyStock == null ||
                readyStock < 0) {
              _showDialogMessage(
                dialogContext,
                'Enter a valid name, price, and Ready-to-Send stock.',
              );
              return;
            }

            if (!availableForReadyNow && !availableForPreOrder) {
              _showDialogMessage(
                dialogContext,
                'Enable Ready to Send, Pre-Order, or both.',
              );
              return;
            }

            if (cleanedRecipe.length > 30 ||
                cleanedRecipe.values.any((n) => n > 100) ||
                cleanedRecipe.values.fold(0, (total, n) => total + n) > 150) {
              _showDialogMessage(
                dialogContext,
                'Use up to 30 flower types, 100 stems each and 150 stems per bouquet.',
              );
              return;
            }
            if (availableForPreOrder && cleanedRecipe.isEmpty) {
              _showDialogMessage(
                dialogContext,
                'Select at least one flower stem for the pre-order recipe.',
              );
              return;
            }

            setDialogState(() => saving = true);

            try {
              if (selectedImage != null) {
                imageUrl = await _uploadImage(selectedImage!);
              }

              final effectiveReadyNow = availableForReadyNow && readyStock > 0;
              final data = <String, dynamic>{
                'name': name,
                'description': description,
                'price': price,
                'imageUrl': imageUrl,
                'category': selectedCategory,
                'isPublished': isPublished,
                'availableForReadyNow': effectiveReadyNow,
                'readyStock': readyStock,
                'availableForPreOrder': availableForPreOrder,
                'leadTimeBusinessDays': leadTimeBusinessDays,
                'recipeStems': cleanedRecipe,
                'archived': false,
                'updatedAt': FieldValue.serverTimestamp(),

                // Compatibility fields for screens not migrated yet.
                'readyToSend': isPublished && effectiveReadyNow,
                'stockCount': readyStock,
              };

              data.remove('updatedAt');
              await FirebaseFunctions.instanceFor(
                region: 'asia-southeast1',
              ).httpsCallable('saveBouquet').call({
                'bouquetId': existingBouquet?.id,
                'bouquet': data,
                'expectedReadyStock': existingBouquet?.readyStock,
              });

              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(editing ? 'Bouquet updated' : 'Bouquet added'),
                  backgroundColor: AdminTheme.sharedColor(
                    context,
                    AppColors.primaryDark,
                  ),
                ),
              );
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() => saving = false);
              _showDialogMessage(
                dialogContext,
                'Unable to save bouquet: $error',
                error: true,
              );
            }
          }

          return AlertDialog(
            title: Text(editing ? 'Edit Bouquet' : 'Add Bouquet'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: saving ? null : pickImage,
                      child: SizedBox(
                        width: double.infinity,
                        height: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _FormImage(
                            selectedImage: selectedImage,
                            imageUrl: imageUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Bouquet name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => selectedCategory = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Selling price',
                        prefixText: 'RM ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Published'),

                      value: isPublished,
                      activeThumbColor: AdminTheme.sharedColor(
                        context,
                        AppColors.primary,
                      ),
                      onChanged: saving
                          ? null
                          : (value) =>
                                setDialogState(() => isPublished = value),
                    ),
                    const Divider(height: 28),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ready to Send'),

                      value: availableForReadyNow,
                      activeThumbColor: AdminTheme.sharedColor(
                        context,
                        AppColors.primary,
                      ),
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(
                              () => availableForReadyNow = value,
                            ),
                    ),
                    TextField(
                      controller: readyStockController,
                      enabled: !saving && availableForReadyNow,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Assembled bouquet stock',
                        helperText: 'This count is shown only to the florist.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Divider(height: 32),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pre-Order'),

                      value: availableForPreOrder,
                      activeThumbColor: AdminTheme.sharedColor(
                        context,
                        AppColors.primaryDark,
                      ),
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(
                              () => availableForPreOrder = value,
                            ),
                    ),
                    if (availableForPreOrder) ...[
                      DropdownButtonFormField<int>(
                        initialValue: leadTimeBusinessDays,
                        decoration: const InputDecoration(
                          labelText: 'Preparation time',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 2,
                            child: Text('2 preparation days'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('3 preparation days'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => leadTimeBusinessDays = value,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Recipe for one bouquet',
                        style: AppTypography.label(),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Customers will not see stock or shortages.',
                        style: AppTypography.caption(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (flowers.isEmpty)
                        const Text('Add flowers to inventory first.')
                      else
                        ...flowers.map((flower) {
                          final count = recipeStems[flower.flowerId] ?? 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 7),
                            child: ListTile(
                              dense: true,
                              title: Text(flower.name),
                              subtitle: Text(
                                'On hand: ${flower.stockQuantity}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: count > 0 && !saving
                                        ? () => setDialogState(() {
                                            recipeStems[flower.flowerId] =
                                                count - 1;
                                          })
                                        : null,
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$count',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.label(),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        saving ||
                                            count >= 100 ||
                                            recipeStems.values.fold(
                                                  0,
                                                  (a, b) => a + b,
                                                ) >=
                                                150
                                        ? null
                                        : () => setDialogState(() {
                                            recipeStems[flower.flowerId] =
                                                count + 1;
                                          }),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTheme.sharedColor(
                    context,
                    AppColors.primary,
                  ),
                ),
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(editing ? 'Save Changes' : 'Add Bouquet'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    readyStockController.dispose();
  }

  void _showDialogMessage(
    BuildContext dialogContext,
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? AdminTheme.sharedColor(context, AppColors.primaryDark)
            : AdminTheme.sharedColor(context, AppColors.primaryDark),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AdminTheme.sharedColor(context, AppColors.primaryDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.sharedColor(context, AppColors.background),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AdminTheme.sharedColor(
                context,
                AppColors.primary,
              ),
              foregroundColor: AppColors.onPrimary,
              onPressed: _showBouquetForm,
              icon: const Icon(Icons.add),
              label: const Text('Add Bouquet'),
            ),
      body: FirestorePage(
        query: FirebaseFirestore.instance
            .collection('bouquets')
            .orderBy(FieldPath.documentId),
        emptyMessage: 'No bouquets yet. Use Add Bouquet to create one.',
        builder: (context, docs) {
          final bouquets =
              docs
                  .where((document) {
                    final archived = document.data()['archived'] == true;
                    return _showArchived ? archived : !archived;
                  })
                  .map(
                    (document) =>
                        BouquetModel.fromMap(document.data(), document.id),
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showArchived
                            ? 'Archived Bouquets'
                            : '${bouquets.length} Bouquets',
                        style: AppTypography.label(),
                      ),
                    ),
                    FilterChip(
                      selected: _showArchived,
                      label: const Text('Archived'),
                      avatar: const Icon(Icons.archive_outlined, size: 18),
                      onSelected: (value) =>
                          setState(() => _showArchived = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bouquets.isEmpty
                    ? Center(
                        child: Text(
                          _showArchived
                              ? 'No archived bouquets.'
                              : 'No active bouquets.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                        itemCount: bouquets.length,
                        itemBuilder: (context, index) {
                          final bouquet = bouquets[index];
                          return _BouquetCard(
                            bouquet: bouquet,
                            archived: _showArchived,
                            onEdit: () =>
                                _showBouquetForm(existingBouquet: bouquet),
                            onDecreaseStock: () =>
                                _changeReadyStock(bouquet, -1),
                            onIncreaseStock: () =>
                                _changeReadyStock(bouquet, 1),
                            onPublishedChanged: (value) =>
                                _setPublished(bouquet, value),
                            onReadyNowChanged: (value) =>
                                _setReadyNowAvailability(bouquet, value),
                            onArchive: () => _archiveBouquet(bouquet),
                            onRestore: () => _restoreBouquet(bouquet),
                            onDelete: () => _deleteBouquet(bouquet),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BouquetCard extends StatelessWidget {
  const _BouquetCard({
    required this.bouquet,
    required this.archived,
    required this.onEdit,
    required this.onDecreaseStock,
    required this.onIncreaseStock,
    required this.onPublishedChanged,
    required this.onReadyNowChanged,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  final BouquetModel bouquet;
  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback onDecreaseStock;
  final VoidCallback onIncreaseStock;
  final ValueChanged<bool> onPublishedChanged;
  final ValueChanged<bool> onReadyNowChanged;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 92,
                    height: 108,
                    child: bouquet.imageUrl.isEmpty
                        ? const _ImagePlaceholder()
                        : Image.network(
                            bouquet.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const _ImagePlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bouquet.name,
                              style: const AppTypography.productTitle(),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') onEdit();
                              if (value == 'archive') onArchive();
                              if (value == 'restore') onRestore();
                              if (value == 'delete') onDelete();
                            },
                            itemBuilder: (_) => archived
                                ? [
                                    PopupMenuItem(
                                      value: 'restore',
                                      child: Text('Restore'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete permanently',
                                        style: TextStyle(
                                          color: AdminTheme.sharedColor(
                                            context,
                                            AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                : [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text('Archive'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete permanently',
                                        style: TextStyle(
                                          color: AdminTheme.sharedColor(
                                            context,
                                            AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                          ),
                        ],
                      ),
                      Text(
                        '${bouquet.category} • RM ${bouquet.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AdminTheme.sharedColor(
                            context,
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ModeChip(
                            label: bouquet.availableForReadyNow
                                ? 'Ready Now: ${bouquet.readyStock}'
                                : 'Ready Now: Off',
                            enabled: bouquet.availableForReadyNow,
                            color: AdminTheme.sharedColor(
                              context,
                              AppColors.primary,
                            ),
                          ),
                          _ModeChip(
                            label: bouquet.availableForPreOrder
                                ? 'Pre-Order: ${bouquet.leadTimeBusinessDays}d'
                                : 'Pre-Order: Off',
                            enabled: bouquet.availableForPreOrder,
                            color: AdminTheme.sharedColor(
                              context,
                              AppColors.primaryDark,
                            ),
                          ),
                          _ModeChip(
                            label: bouquet.isPublished
                                ? 'Published'
                                : 'Unpublished',
                            enabled: bouquet.isPublished,
                            color: AdminTheme.sharedColor(
                              context,
                              AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!archived) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  const Text('Ready stock', style: AppTypography.label()),
                  IconButton(
                    onPressed: bouquet.readyStock > 0 ? onDecreaseStock : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '${bouquet.readyStock}',
                    style: const AppTypography.productTitle(),
                  ),
                  IconButton(
                    onPressed: onIncreaseStock,
                    icon: const Icon(Icons.add_circle_outline),
                  ),

                  const Text('Ready Now', style: AppTypography.caption()),
                  Switch.adaptive(
                    value:
                        bouquet.availableForReadyNow && bouquet.readyStock > 0,
                    activeThumbColor: AdminTheme.sharedColor(
                      context,
                      AppColors.primary,
                    ),
                    onChanged: onReadyNowChanged,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Published'),
              value: bouquet.isPublished,
              activeThumbColor: AdminTheme.sharedColor(
                context,
                AppColors.primary,
              ),
              onChanged: onPublishedChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.enabled,
    required this.color,
  });

  final String label;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: AppTypography.badge(color: effectiveColor)),
    );
  }
}

class _FormImage extends StatelessWidget {
  const _FormImage({required this.selectedImage, required this.imageUrl});

  final ProductImage? selectedImage;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (selectedImage != null) {
      return Image.memory(selectedImage!.bytes, fit: BoxFit.cover);
    }
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
      );
    }
    return const _ImagePlaceholder();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminTheme.sharedColor(context, AppColors.inputFill),
      child: Center(
        child: Icon(
          Icons.add_a_photo_outlined,
          color: AdminTheme.sharedColor(context, AppColors.primary),
          size: 40,
        ),
      ),
    );
  }
}
