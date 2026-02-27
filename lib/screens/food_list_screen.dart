import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/food_item.dart';
import 'cart_screen.dart';

class FoodListScreen extends StatefulWidget {
  const FoodListScreen({super.key});

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  final box = Hive.box("food_delivery");
  List<dynamic> cart = [];
  List<FoodItem> foodItems = FoodItem.mockItems();

  // Carousel variables
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  Timer? _carouselTimer;

  // Featured items (first 3 items for carousel)
  List<FoodItem> get featuredItems => foodItems.take(3).toList();

  @override
  void initState() {
    super.initState();
    if (box.get("cart") != null) {
      setState(() {
        cart = box.get("cart");
      });
    }
    _startCarousel();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < featuredItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  int getCartItemCount() {
    if (cart.isEmpty) return 0;
    return cart.fold(0, (sum, item) => sum + (item["quantity"] as int));
  }

  void _showAddedToCart(BuildContext context, String itemName) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Added to Cart'),
        content: Text('$itemName has been added to your cart.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Continue Shopping'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('View Cart'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => const CartScreen()),
              ).then((_) {
                setState(() {
                  cart = box.get("cart") ?? [];
                });
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey5.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        middle: const Text(
          'Food Menu',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const CartScreen()),
            ).then((_) {
              setState(() {
                cart = box.get("cart") ?? [];
              });
            });
          },
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              const Icon(CupertinoIcons.cart, size: 24),
              if (getCartItemCount() > 0)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: CupertinoColors.activeOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    getCartItemCount().toString(),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.activeOrange.withValues(alpha: 0.05),
              const Color(0xFFF2F2F7),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Welcome Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hungry?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover delicious food near you',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Featured Items Carousel
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: featuredItems.length,
                          itemBuilder: (context, index) {
                            final item = featuredItems[index];
                            return _buildCarouselItem(item);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          featuredItems.length,
                              (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? CupertinoColors.activeOrange
                                  : CupertinoColors.systemGrey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Popular Items Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Popular Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Food Items Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return _buildFoodGridItem(foodItems[index]);
                    },
                    childCount: foodItems.length,
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(FoodItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.activeOrange,
            const Color(0xFFFF9F0A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'FEATURED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.star_fill,
                                  size: 12,
                                  color: CupertinoColors.activeOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.rating.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.preparationTime} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.cart,
                          size: 40,
                          color: CupertinoColors.white,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  cart.add({
                    "id": item.id,
                    "name": item.name,
                    "price": item.price,
                    "quantity": 1,
                  });
                  box.put("cart", cart);
                });
                _showAddedToCart(context, item.name);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.add,
                  size: 16,
                  color: CupertinoColors.activeOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodGridItem(FoodItem item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: CupertinoColors.activeOrange.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.cart,
                        size: 40,
                        color: CupertinoColors.activeOrange,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.star_fill,
                              size: 10,
                              color: CupertinoColors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item.rating.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.clock,
                              size: 10,
                              color: CupertinoColors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item.preparationTime} min',
                              style: const TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            cart.add({
                              "id": item.id,
                              "name": item.name,
                              "price": item.price,
                              "quantity": 1,
                            });
                            box.put("cart", cart);
                          });
                          _showAddedToCart(context, item.name);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            CupertinoIcons.add,
                            size: 16,
                            color: CupertinoColors.white,
                          ),
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
    );
  }
}