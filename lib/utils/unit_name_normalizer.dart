class UnitNameNormalizer {
  static const List<String> defaultUnits = [
    'قطعة',
    'كرتونة',
    'دستة',
    'رزمة',
    'باكو',
    'كيلو',
    'جرام',
    'طن',
    'رول',
    'شوال',
    'متر',
    'متر مربع',
    'متر مكعب',
    'صندوق',
    'بالة',
    'عبوة',
    'زجاجة',
    'كيس',
  ];

  static String normalize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }
}
