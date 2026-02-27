class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final int preparationTime;

  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.rating,
    required this.preparationTime,
  });

  static List<FoodItem> mockItems() {
    return [
      FoodItem(
        id: '1',
        name: 'Margherita Pizza',
        description: 'Fresh tomatoes, mozzarella, basil',
        price: 12.99,
        imageUrl: 'assets/images/pizza.jpg',
        category: 'Italian',
        rating: 4.5,
        preparationTime: 20,
      ),
      FoodItem(
        id: '2',
        name: 'Classic Burger',
        description: 'Beef patty, lettuce, tomato, special sauce',
        price: 8.99,
        imageUrl: 'assets/images/burger.jpg',
        category: 'American',
        rating: 4.3,
        preparationTime: 15,
      ),
      FoodItem(
        id: '3',
        name: 'California Roll',
        description: 'Crab, avocado, cucumber',
        price: 10.99,
        imageUrl: 'assets/images/sushi.jpg',
        category: 'Japanese',
        rating: 4.7,
        preparationTime: 25,
      ),
      FoodItem(
        id: '4',
        name: 'Pasta Carbonara',
        description: 'Creamy pasta with bacon and cheese',
        price: 11.99,
        imageUrl: 'assets/images/pasta.jpg',
        category: 'Italian',
        rating: 4.6,
        preparationTime: 18,
      ),
      FoodItem(
        id: '5',
        name: 'Caesar Salad',
        description: 'Fresh romaine lettuce with caesar dressing',
        price: 7.99,
        imageUrl: 'assets/images/salad.jpg',
        category: 'Healthy',
        rating: 4.2,
        preparationTime: 10,
      ),
      FoodItem(
        id: '6',
        name: 'Chicken Wings',
        description: 'Spicy buffalo wings with dip',
        price: 9.99,
        imageUrl: 'assets/images/wings.jpg',
        category: 'American',
        rating: 4.4,
        preparationTime: 15,
      ),
    ];
  }
}