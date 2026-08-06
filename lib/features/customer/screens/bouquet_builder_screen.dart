import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/flower_model.dart';

class BouquetBuilderScreen extends StatefulWidget {
  const BouquetBuilderScreen({super.key});

  @override
  State<BouquetBuilderScreen> createState() => _BouquetBuilderScreenState();
}

class _BouquetBuilderScreenState extends State<BouquetBuilderScreen> {
  // Stem quantities mapping: { flowerId : count }
  final Map<String, int> _stemCounts = {};
  
  // Customization Options
  String _selectedWrapper = 'Kraft Paper (Classic)';
  double _wrapperPrice = 5.00;

  String _selectedRibbon = 'Red Satin';
  double _ribbonPrice = 2.00;

  final TextEditingController _cardNoteController = TextEditingController();

  // Price Calculation Options
  final Map<String, double> _wrapperOptions = {
    'Kraft Paper (Classic)': 5.00,
    'Pastel Pink Waterproof': 8.00,
    'Minimalist Matte Black': 8.00,
    'Satin White Luxury': 10.00,
  };

  final Map<String, double> _ribbonOptions = {
    'Red Satin': 2.00,
    'Gold Silk': 3.50,
    'Rose Gold Organza': 3.50,
    'Minimalist Twine': 1.50,
  };

  // Helper method to calculate total live bouquet price
  double _calculateTotalPrice(List<FlowerModel> availableFlowers) {
    double stemsTotal = 0.0;

    for (var flower in availableFlowers) {
      final count = _stemCounts[flower.flowerId] ?? 0;
      stemsTotal += (flower.pricePerStem * count);
    }

    return stemsTotal + _wrapperPrice + _ribbonPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Bouquet Builder 💐'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('flowers').where('isAvailable', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No flower stems available right now.'));
          }

          final flowers = snapshot.data!.docs.map((doc) {
            return FlowerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          final totalPrice = _calculateTotalPrice(flowers);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD87093).withAlpha(100)),
                        ),
                        child: const Text(
                          'Select your flower stems, pick your arrangement style, and add a personal card message!',
                          style: TextStyle(fontSize: 14, color: Color(0xFF8B008B), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 1: Stem Selection
                      const Text('1. Choose Flower Stems', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: flowers.length,
                        itemBuilder: (context, index) {
                          final flower = flowers[index];
                          final count = _stemCounts[flower.flowerId] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              leading: flower.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(flower.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.local_florist, size: 40, color: Color(0xFFD87093)),
                              title: Text(flower.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('RM ${flower.pricePerStem.toStringAsFixed(2)} / stem'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: count > 0
                                        ? () {
                                            setState(() {
                                              _stemCounts[flower.flowerId] = count - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: count < flower.stockQuantity
                                        ? () {
                                            setState(() {
                                              _stemCounts[flower.flowerId] = count + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Wrapper Selection
                      const Text('2. Choose Wrapping Paper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedWrapper,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _wrapperOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text('${entry.key} (+RM ${entry.value.toStringAsFixed(2)})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedWrapper = val;
                              _wrapperPrice = _wrapperOptions[val]!;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Ribbon Selection
                      const Text('3. Choose Ribbon Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedRibbon,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _ribbonOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text('${entry.key} (+RM ${entry.value.toStringAsFixed(2)})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedRibbon = val;
                              _ribbonPrice = _ribbonOptions[val]!;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Gift Card Note
                      const Text('4. Gift Message Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cardNoteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write your personalized message here (e.g., Happy Birthday Sarah! Love, John)...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Real-Time Price & Order Button Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total Price', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          'RM ${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD87093),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD87093),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Add Bouquet', style: TextStyle(fontSize: 16)),
                      onPressed: totalPrice > (_wrapperPrice + _ribbonPrice)
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Custom Bouquet added! Total: RM ${totalPrice.toStringAsFixed(2)}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null, // Disabled if no stems selected!
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}