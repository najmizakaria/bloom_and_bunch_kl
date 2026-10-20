import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/firestore_service.dart';
import '../../models/product_model.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // =========================
        // STOCK LIST
        // =========================

        StreamBuilder<List<ProductModel>>(
          stream: _firestoreService.getAllProducts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Error loading stock:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return const Center(
                child: Text(
                  'No stock available.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(products[index]);
              },
            );
          },
        ),

        // =========================
        // ADD STOCK BUTTON
        // =========================
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.pink,
            onPressed: () {
              _showAddStockDialog(context);
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CAMERA
  // =========================================================

  Future<XFile?> _takePhoto() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }

      return null;
    }
  }

  // =========================================================
  // BROWSE IMAGE
  // =========================================================

  Future<XFile?> _browseImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to select image: $e')));
      }

      return null;
    }
  }

  // =========================================================
  // UPLOAD IMAGE
  // =========================================================

  Future<String> _uploadImage(XFile image) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('products')
        .child(fileName);

    if (kIsWeb) {
      final bytes = await image.readAsBytes();

      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      await storageRef.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    return await storageRef.getDownloadURL();
  }

  // =========================================================
  // ADD STOCK DIALOG
  // =========================================================

  void _showAddStockDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();

    XFile? selectedImage;

    String stockStatus = 'Available';

    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Stock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSelectedImagePreview(selectedImage),

                    const SizedBox(height: 10),

                    _buildImageButtons(
                      isDisabled: isUploading,
                      onCamera: () async {
                        final image = await _takePhoto();

                        if (image != null) {
                          setDialogState(() {
                            selectedImage = image;
                          });
                        }
                      },
                      onBrowse: () async {
                        final image = await _browseImage();

                        if (image != null) {
                          setDialogState(() {
                            selectedImage = image;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 15),

                    // PRODUCT NAME
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.local_florist),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // QUANTITY
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PRICE
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (RM)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // STATUS
                    _buildStatusDropdown(
                      value: stockStatus,
                      disabled: isUploading,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            stockStatus = value;
                          });
                        }
                      },
                    ),
                  ],
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
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              quantityController.text.trim().isEmpty ||
                              priceController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields.'),
                              ),
                            );

                            return;
                          }

                          final quantity =
                              int.tryParse(quantityController.text.trim()) ??
                              -1;

                          final price =
                              double.tryParse(priceController.text.trim()) ??
                              -1;

                          if (quantity < 0 || price < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter valid quantity and price.',
                                ),
                              ),
                            );

                            return;
                          }

                          setDialogState(() {
                            isUploading = true;
                          });

                          try {
                            String imageUrl = '';

                            if (selectedImage != null) {
                              imageUrl = await _uploadImage(selectedImage!);
                            }

                            final product = ProductModel(
                              productId: '',
                              name: nameController.text.trim(),
                              imageUrl: imageUrl,
                              quantity: quantity,
                              price: price,
                              stockStatus: stockStatus,
                              createdAt: DateTime.now(),
                            );

                            await _firestoreService.addProduct(product);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Stock added successfully.'),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isUploading = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add stock:\n$e'),
                                ),
                              );
                            }
                          }
                        },
                  child: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Stock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // EDIT STOCK DIALOG
  // =========================================================

  void _showEditStockDialog(BuildContext context, ProductModel product) {
    final nameController = TextEditingController(text: product.name);

    final quantityController = TextEditingController(
      text: product.quantity.toString(),
    );

    final priceController = TextEditingController(
      text: product.price.toString(),
    );

    XFile? selectedImage;

    String stockStatus = product.stockStatus;

    String currentImageUrl = product.imageUrl;

    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Update Stock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditImagePreview(selectedImage, currentImageUrl),

                    const SizedBox(height: 10),

                    _buildImageButtons(
                      isDisabled: isUpdating,
                      onCamera: () async {
                        final image = await _takePhoto();

                        if (image != null) {
                          setDialogState(() {
                            selectedImage = image;
                          });
                        }
                      },
                      onBrowse: () async {
                        final image = await _browseImage();

                        if (image != null) {
                          setDialogState(() {
                            selectedImage = image;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 15),

                    // NAME
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.local_florist),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // QUANTITY
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PRICE
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (RM)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // STATUS
                    _buildStatusDropdown(
                      value: stockStatus,
                      disabled: isUpdating,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            stockStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isUpdating
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              quantityController.text.trim().isEmpty ||
                              priceController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields.'),
                              ),
                            );

                            return;
                          }

                          final quantity =
                              int.tryParse(quantityController.text.trim()) ??
                              -1;

                          final price =
                              double.tryParse(priceController.text.trim()) ??
                              -1;

                          if (quantity < 0 || price < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter valid quantity and price.',
                                ),
                              ),
                            );

                            return;
                          }

                          setDialogState(() {
                            isUpdating = true;
                          });

                          try {
                            String newImageUrl = currentImageUrl;

                            if (selectedImage != null) {
                              newImageUrl = await _uploadImage(selectedImage!);
                            }

                            final updatedProduct = ProductModel(
                              productId: product.productId,
                              name: nameController.text.trim(),
                              imageUrl: newImageUrl,
                              quantity: quantity,
                              price: price,
                              stockStatus: stockStatus,
                              createdAt: product.createdAt,
                            );

                            await _firestoreService.updateProduct(
                              updatedProduct,
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Stock updated successfully.'),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isUpdating = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update stock:\n$e'),
                                ),
                              );
                            }
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // DELETE STOCK
  // =========================================================

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Stock?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text('Are you sure you want to delete "${product.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _firestoreService.deleteProduct(product.productId);

      if (product.imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(product.imageUrl).delete();
        } catch (_) {
          // Ignore image deletion error.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete stock:\n$e')));
      }
    }
  }

  // =========================================================
  // IMAGE PREVIEW - ADD
  // =========================================================

  Widget _buildSelectedImagePreview(XFile? image) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: image == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_florist, color: Colors.pink, size: 40),
                SizedBox(height: 8),
                Text('No image selected', style: TextStyle(color: Colors.grey)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(image.path, fit: BoxFit.cover)
                  : Image.file(File(image.path), fit: BoxFit.cover),
            ),
    );
  }

  // =========================================================
  // IMAGE PREVIEW - EDIT
  // =========================================================

  Widget _buildEditImagePreview(XFile? selectedImage, String currentImageUrl) {
    if (selectedImage != null) {
      return _buildSelectedImagePreview(selectedImage);
    }

    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: currentImageUrl.isEmpty
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_florist, color: Colors.pink, size: 40),
                SizedBox(height: 8),
                Text('No image', style: TextStyle(color: Colors.grey)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                currentImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey,
                    size: 40,
                  );
                },
              ),
            ),
    );
  }

  // =========================================================
  // CAMERA + BROWSE BUTTONS
  // =========================================================

  Widget _buildImageButtons({
    required bool isDisabled,
    required VoidCallback onCamera,
    required VoidCallback onBrowse,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDisabled ? null : onCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Camera'),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDisabled ? null : onBrowse,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Browse'),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // STATUS DROPDOWN
  // =========================================================

  Widget _buildStatusDropdown({
    required String value,
    required bool disabled,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Stock Status',
        prefixIcon: Icon(Icons.info_outline),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'Available', child: Text('Available')),
        DropdownMenuItem(value: 'Low Stock', child: Text('Low Stock')),
        DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock')),
      ],
      onChanged: disabled ? null : onChanged,
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(ProductModel product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE

              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: product.imageUrl.isEmpty
                    ? const Icon(
                        Icons.local_florist,
                        color: Colors.pink,
                        size: 30,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Stock: ${product.quantity}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
              ),

              // STATUS
              _buildStatus(product.stockStatus),
            ],
          ),

          const SizedBox(height: 12),

          const Divider(height: 1),

          const SizedBox(height: 10),

          // EDIT + DELETE
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showEditStockDialog(context, product);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () {
                    _deleteProduct(product);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STATUS
  // =========================================================

  Widget _buildStatus(String status) {
    Color color;

    switch (status) {
      case 'Available':
        color = Colors.green;
        break;

      case 'Low Stock':
        color = Colors.orange;
        break;

      case 'Out of Stock':
        color = Colors.red;
        break;

      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
