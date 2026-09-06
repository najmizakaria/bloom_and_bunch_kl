import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../models/flower_model.dart';

class FloristInventoryScreen extends StatelessWidget {
  const FloristInventoryScreen({super.key});

  // Helper to instantly update stock quantity
  Future<void> _updateStock(String docId, int currentStock, int change) async {
    int newStock = currentStock + change;
    if (newStock < 0) newStock = 0; // Prevent negative stock
    await FirebaseFirestore.instance.collection('flowers').doc(docId).update({
      'stockQuantity': newStock,
    });
  }

  // Helper to toggle availability
  Future<void> _toggleAvailability(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('flowers').doc(docId).update({
      'isAvailable': !currentStatus,
    });
  }

  // Function to upload image to Firebase Storage
  Future<String> _uploadImage(File image) async {
    final fileName = 'flowers/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  // Dialog to Add a Brand New Flower
  void _showAddFlowerDialog(BuildContext context) {
    _showFlowerForm(context: context);
  }

  // Dialog to Edit an Existing Flower
  void _showEditFlowerDialog(BuildContext context, FlowerModel flower) {
    _showFlowerForm(context: context, existingFlower: flower);
  }

  // Shared Form for both Add and Edit
  void _showFlowerForm({required BuildContext context, FlowerModel? existingFlower}) {
    final isEditing = existingFlower != null;
    
    final nameCtrl = TextEditingController(text: isEditing ? existingFlower.name : '');
    final categoryCtrl = TextEditingController(text: isEditing ? existingFlower.category : '');
    final priceCtrl = TextEditingController(text: isEditing ? existingFlower.pricePerStem.toString() : '');
    final stockCtrl = TextEditingController(text: isEditing ? existingFlower.stockQuantity.toString() : '');
    
    File? selectedImage;
    String existingImageUrl = isEditing ? existingFlower.imageUrl : '';
    bool isUploading = false;
    final picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          Future<void> pickImage(ImageSource source) async {
            final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
            if (pickedFile != null) {
              setState(() => selectedImage = File(pickedFile.path));
            }
          }

          return AlertDialog(
            title: Text(isEditing ? 'Edit Flower' : 'Add New Flower'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- IMAGE PICKER UI ---
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Take a Photo'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Choose from Gallery'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.gallery);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200, width: 2),
                      ),
                      child: selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(selectedImage!, fit: BoxFit.cover),
                            )
                          : (existingImageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(existingImageUrl, fit: BoxFit.cover),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: Colors.teal),
                                    SizedBox(height: 8),
                                    Text('Tap to add image', style: TextStyle(color: Colors.teal)),
                                  ],
                                )),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- TEXT FIELDS ---
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Flower Name (e.g. Red Rose)')),
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category (e.g. Roses, Lilies)')),
                  TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price per stem (RM)'), keyboardType: TextInputType.number),
                  TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Initial Stock Quantity'), keyboardType: TextInputType.number),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context), 
                child: const Text('Cancel')
              ),
              ElevatedButton(
                onPressed: isUploading ? null : () async {
                  if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || stockCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
                    return;
                  }

                  setState(() => isUploading = true); 

                  try {
                    String imageUrl = existingImageUrl;
                    
                    // Upload new image if one was selected
                    if (selectedImage != null) {
                      imageUrl = await _uploadImage(selectedImage!);
                    }

                    final data = {
                      'name': nameCtrl.text.trim(),
                      'category': categoryCtrl.text.trim(),
                      'pricePerStem': double.tryParse(priceCtrl.text) ?? 0.0,
                      'stockQuantity': int.tryParse(stockCtrl.text) ?? 0,
                      'imageUrl': imageUrl,
                      'isAvailable': isEditing ? existingFlower.isAvailable : true,
                    };

                    if (isEditing) {
                      await FirebaseFirestore.instance.collection('flowers').doc(existingFlower.flowerId).update(data);
                    } else {
                      await FirebaseFirestore.instance.collection('flowers').add(data);
                    }
                    
                    if (context.mounted) Navigator.pop(context); 
                  } catch (e) {
                    setState(() => isUploading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: isUploading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEditing ? 'Save Changes' : 'Add to Stock'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFlowerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Flower'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('flowers').orderBy('category').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No flowers in stock yet! Add some below.'));
          }

          final flowers = snapshot.data!.docs.map((doc) {
            return FlowerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 12),
            itemCount: flowers.length,
            itemBuilder: (context, index) {
              final flower = flowers[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // --- TAPPABLE IMAGE TO EDIT ---
                      GestureDetector(
                        onTap: () => _showEditFlowerDialog(context, flower),
                        child: Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                          ),
                          child: flower.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(flower.imageUrl, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.local_florist, color: Colors.grey),
                        ),
                      ),
                      
                      // Flower Info
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(flower.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${flower.category} • RM ${flower.pricePerStem.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('Available: ', style: TextStyle(fontSize: 12)),
                                Switch(
                                  value: flower.isAvailable,
                                  onChanged: (val) => _toggleAvailability(flower.flowerId, flower.isAvailable),
                                  activeThumbColor: Colors.teal,
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      
                      // Stock Controls
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _updateStock(flower.flowerId, flower.stockQuantity, -1),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                Text('${flower.stockQuantity}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () => _updateStock(flower.flowerId, flower.stockQuantity, 1),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}