import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/bouquet_model.dart';

class FloristBouquetsTab extends StatefulWidget {
  const FloristBouquetsTab({super.key});

  @override
  State<FloristBouquetsTab> createState() =>
      _FloristBouquetsTabState();
}

class _FloristBouquetsTabState
    extends State<FloristBouquetsTab> {
  bool _showArchived = false;

  Future<String> _uploadImage(File image) async {
    final fileName =
        'bouquets/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final reference =
        FirebaseStorage.instance.ref().child(fileName);

    await reference.putFile(image);

    return reference.getDownloadURL();
  }

  Future<void> _changeStock(
    BouquetModel bouquet,
    int change,
  ) async {
    final newStock =
        (bouquet.stockCount + change).clamp(0, 999999);

    final Map<String, dynamic> changes = {
      'stockCount': newStock,
    };

    // Out-of-stock bouquets must disappear from customer catalogue.
    if (newStock == 0) {
      changes['readyToSend'] = false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update(changes);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update stock: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changeAvailability(
    BouquetModel bouquet,
    bool available,
  ) async {
    if (available && bouquet.stockCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add stock before making this bouquet available.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
        'readyToSend': available,
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to change availability: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _archiveBouquet(
    BouquetModel bouquet,
  ) async {
    final confirmed = await _showConfirmation(
      title: 'Archive bouquet?',
      message:
          '${bouquet.name} will be hidden from customers and moved to Archived.',
      confirmLabel: 'Archive',
    );

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
        'archived': true,
        'readyToSend': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bouquet archived'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to archive bouquet: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreBouquet(
    BouquetModel bouquet,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .update({
        'archived': false,

        // Keep it unavailable until florist checks it.
        'readyToSend': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bouquet restored. Turn availability on when ready.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to restore bouquet: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteBouquet(
    BouquetModel bouquet,
  ) async {
    final confirmed = await _showConfirmation(
      title: 'Delete bouquet permanently?',
      message:
          '${bouquet.name} will be permanently removed. This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('bouquets')
          .doc(bouquet.id)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bouquet deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete bouquet: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    destructive ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showBouquetForm({
    BouquetModel? existingBouquet,
  }) async {
    final editing = existingBouquet != null;

    final nameController = TextEditingController(
      text: existingBouquet?.name ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingBouquet?.description ?? '',
    );
    const bouquetCategories = [
      'Birthday',
      'Anniversary',
      'Sympathy',
      'Romance',
    ];

    String selectedCategory = bouquetCategories.contains(
      existingBouquet?.category,
    )
        ? existingBouquet!.category
        : bouquetCategories.first;
    final priceController = TextEditingController(
      text: existingBouquet?.price.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: existingBouquet?.stockCount.toString() ?? '',
    );

    File? selectedImage;
    String imageUrl = existingBouquet?.imageUrl ?? '';
    bool readyToSend = existingBouquet?.readyToSend ?? true;
    bool saving = false;

    final picker = ImagePicker();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> selectImage() async {
              final source =
                  await showModalBottomSheet<ImageSource>(
                context: dialogContext,
                builder: (sheetContext) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading:
                              const Icon(Icons.photo_library_outlined),
                          title:
                              const Text('Choose from gallery'),
                          onTap: () {
                            Navigator.pop(
                              sheetContext,
                              ImageSource.gallery,
                            );
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.camera_alt_outlined),
                          title: const Text('Take a photo'),
                          onTap: () {
                            Navigator.pop(
                              sheetContext,
                              ImageSource.camera,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );

              if (source == null) return;

              final selected = await picker.pickImage(
                source: source,
                imageQuality: 75,
              );

              if (selected != null) {
                setDialogState(() {
                  selectedImage = File(selected.path);
                });
              }
            }

            Future<void> saveBouquet() async {
              final name = nameController.text.trim();
              final description =
                  descriptionController.text.trim();
              final category =
                  selectedCategory;
              final price =
                  double.tryParse(priceController.text.trim());
              final stock =
                  int.tryParse(stockController.text.trim());

              if (name.isEmpty ||
                  category.isEmpty ||
                  price == null ||
                  price < 0 ||
                  stock == null ||
                  stock < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a valid name, category, price and stock.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                if (selectedImage != null) {
                  imageUrl =
                      await _uploadImage(selectedImage!);
                }

                final data = {
                  'name': name,
                  'description': description,
                  'category': category,
                  'price': price,
                  'stockCount': stock,
                  'imageUrl': imageUrl,

                  // Zero stock cannot be available.
                  'readyToSend':
                      stock > 0 && readyToSend,
                  'archived': false,
                  'updatedAt':
                      FieldValue.serverTimestamp(),
                };

                if (editing) {
                  await FirebaseFirestore.instance
                      .collection('bouquets')
                      .doc(existingBouquet.id)
                      .update(data);
                } else {
                  data['createdAt'] =
                      FieldValue.serverTimestamp();

                  await FirebaseFirestore.instance
                      .collection('bouquets')
                      .add(data);
                }

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      editing
                          ? 'Bouquet updated'
                          : 'Bouquet added',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Unable to save: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                editing ? 'Edit Bouquet' : 'Add Bouquet',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: saving ? null : selectImage,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.shade200,
                            ),
                          ),
                          child: _buildFormImage(
                            selectedImage,
                            imageUrl,
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
                          labelText: 'Bouquet category',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: bouquetCategories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedCategory = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        enabled: !saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: 'RM ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stockController,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock quantity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: readyToSend,
                        activeThumbColor: Colors.teal,
                        title: const Text(
                          'Available to customers',
                        ),
                        subtitle: const Text(
                          'Only available bouquets appear in the customer catalogue.',
                        ),
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  readyToSend = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving ? null : saveBouquet,
                  child: saving
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          editing
                              ? 'Save Changes'
                              : 'Add Bouquet',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
  }

  Widget _buildFormImage(
    File? selectedImage,
    String existingImageUrl,
  ) {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.file(
          selectedImage,
          fit: BoxFit.cover,
        ),
      );
    }

    if (existingImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          existingImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const _ImagePlaceholder();
          },
        ),
      );
    }

    return const _ImagePlaceholder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onPressed: () => _showBouquetForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Bouquet'),
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bouquets')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load bouquets.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final documents = snapshot.data?.docs.where((document) {
                final data =
                    document.data() as Map<String, dynamic>;

                final archived =
                    data['archived'] == true;

                return _showArchived ? archived : !archived;
              }).toList() ??
              [];

          final bouquets = documents.map((document) {
            return BouquetModel.fromMap(
              document.data() as Map<String, dynamic>,
              document.id,
            );
          }).toList()
            ..sort((first, second) {
              return first.name
                  .toLowerCase()
                  .compareTo(second.name.toLowerCase());
            });

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showArchived
                            ? 'Archived Bouquets'
                            : '${bouquets.length} Bouquets',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilterChip(
                      selected: _showArchived,
                      selectedColor: Colors.teal.shade100,
                      label: const Text('Archived'),
                      avatar: const Icon(
                        Icons.archive_outlined,
                        size: 18,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _showArchived = selected;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bouquets.isEmpty
                    ? _EmptyBouquets(
                        archived: _showArchived,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          90,
                        ),
                        itemCount: bouquets.length,
                        itemBuilder: (context, index) {
                          final bouquet = bouquets[index];

                          return _BouquetManagementCard(
                            bouquet: bouquet,
                            archived: _showArchived,
                            onEdit: () {
                              _showBouquetForm(
                                existingBouquet: bouquet,
                              );
                            },
                            onDecreaseStock: () {
                              _changeStock(bouquet, -1);
                            },
                            onIncreaseStock: () {
                              _changeStock(bouquet, 1);
                            },
                            onAvailabilityChanged: (value) {
                              _changeAvailability(
                                bouquet,
                                value,
                              );
                            },
                            onArchive: () {
                              _archiveBouquet(bouquet);
                            },
                            onRestore: () {
                              _restoreBouquet(bouquet);
                            },
                            onDelete: () {
                              _deleteBouquet(bouquet);
                            },
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

class _BouquetManagementCard extends StatelessWidget {
  const _BouquetManagementCard({
    required this.bouquet,
    required this.archived,
    required this.onEdit,
    required this.onDecreaseStock,
    required this.onIncreaseStock,
    required this.onAvailabilityChanged,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  final BouquetModel bouquet;
  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback onDecreaseStock;
  final VoidCallback onIncreaseStock;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  height: 105,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: bouquet.imageUrl.isEmpty
                        ? const _ImagePlaceholder()
                        : Image.network(
                            bouquet.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const _ImagePlaceholder();
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bouquet.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit();
                                  break;
                                case 'archive':
                                  onArchive();
                                  break;
                                case 'restore':
                                  onRestore();
                                  break;
                                case 'delete':
                                  onDelete();
                                  break;
                              }
                            },
                            itemBuilder: (context) {
                              if (archived) {
                                return const [
                                  PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Restore'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete permanently',
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ];
                              }

                              return const [
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
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                      Text(
                        bouquet.category,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'RM ${bouquet.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _ProductStatus(
                        archived: archived,
                        available: bouquet.readyToSend,
                        stock: bouquet.stockCount,
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
              padding:
                  const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'Stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Decrease stock',
                    onPressed: bouquet.stockCount > 0
                        ? onDecreaseStock
                        : null,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                    ),
                  ),
                  Container(
                    constraints:
                        const BoxConstraints(minWidth: 35),
                    alignment: Alignment.center,
                    child: Text(
                      '${bouquet.stockCount}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Increase stock',
                    onPressed: onIncreaseStock,
                    icon:
                        const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  const Text(
                    'Available',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  Switch.adaptive(
                    value: bouquet.readyToSend &&
                        bouquet.stockCount > 0,
                    activeThumbColor: Colors.teal,
                    onChanged: onAvailabilityChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductStatus extends StatelessWidget {
  const _ProductStatus({
    required this.archived,
    required this.available,
    required this.stock,
  });

  final bool archived;
  final bool available;
  final int stock;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (archived) {
      label = 'Archived';
      color = Colors.grey;
    } else if (stock <= 0) {
      label = 'Out of stock';
      color = Colors.red;
    } else if (!available) {
      label = 'Unavailable';
      color = Colors.orange;
    } else {
      label = 'Available';
      color = Colors.green;
    }

    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 9,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.teal.shade50,
      child: const Center(
        child: Icon(
          Icons.add_a_photo_outlined,
          color: Colors.teal,
          size: 38,
        ),
      ),
    );
  }
}

class _EmptyBouquets extends StatelessWidget {
  const _EmptyBouquets({
    required this.archived,
  });

  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived
                  ? Icons.archive_outlined
                  : Icons.local_florist_outlined,
              size: 68,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              archived
                  ? 'No archived bouquets'
                  : 'No bouquets yet',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              archived
                  ? 'Archived bouquets will appear here.'
                  : 'Use Add Bouquet to create your first product.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}