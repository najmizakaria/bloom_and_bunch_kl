import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_home_screen.dart';
import 'favourites_screen.dart';
import 'bouquet_builder_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    CustomerHomeScreen(),
    FavouritesScreen(),
    BouquetBuilderScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primaryRosewood,
            unselectedItemColor: AppColors.textMuted,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 0,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              const BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Favourites'),
              const BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'Customize'),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text('$cartCount'),
                  isLabelVisible: cartCount > 0,
                  backgroundColor: AppColors.primaryRosewood,
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}