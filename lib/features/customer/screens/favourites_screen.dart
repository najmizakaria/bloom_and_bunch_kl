import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites'), centerTitle: true),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, size: 64, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'No favourites yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              SizedBox(height: 6),
              Text(
                'Save ready-made bouquets or custom recipes to find them here.',
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