class CategoriesManager {
  CategoriesManager._() {
    if (_categories.isEmpty) {
      _categories.addAll(defaultCategories);
    }
  }

  static final CategoriesManager instance = CategoriesManager._();

  factory CategoriesManager() => instance;

  static final List<String> _categories = <String>[];

  static const List<String> defaultCategories = <String>[
    'شنط بلاستيك',
    'شنط قماش',
    'أكياس بلاستيك',
    'منتجات ورقية',
    'أطباق فويل',
    'أكواب ورقية',
    'ملاعق وشوك',
    'مناديل',
    'علب تغليف',
    'مستلزمات تغليف',
    'فوم',
    'كراتين',
    'منتجات تنظيف',
    'أخرى',
  ];

  List<String> get categories => List.unmodifiable(_categories);

  void addCategory(String category) {
    final normalized = category.trim();
    if (normalized.isEmpty) return;
    if (!_categories.contains(normalized)) {
      _categories.add(normalized);
    }
  }

  void updateCategory(String oldCategory, String newCategory) {
    final normalizedNew = newCategory.trim();
    if (normalizedNew.isEmpty) return;

    final index = _categories.indexOf(oldCategory);
    if (index == -1) return;

    _categories[index] = normalizedNew;
  }

  void deleteCategory(String category) {
    _categories.remove(category);
  }
}
