import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart'), centerTitle: true),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              SizedBox(height: 6),
              Text(
                'Add a ready-made bouquet or build a custom one to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}