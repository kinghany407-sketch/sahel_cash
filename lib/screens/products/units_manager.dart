import 'conversion_manager.dart';

class UnitsManager {
  UnitsManager._() {
    if (_units.isEmpty) {
      _units.addAll(defaultUnits);
    }
  }

  static final UnitsManager instance = UnitsManager._();

  factory UnitsManager() => instance;

  static final List<String> _units = <String>[];

  static const List<String> defaultUnits = <String>[
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

  List<String> get availableUnits => List.unmodifiable(_units);

  void addUnit(String unit) {
    final normalized = unit.trim();
    if (normalized.isEmpty) return;
    if (!_units.contains(normalized)) {
      _units.add(normalized);
    }
  }

  void updateUnit(String oldUnit, String newUnit) {
    final normalizedOld = oldUnit.trim();
    final normalizedNew = newUnit.trim();
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) return;

    final index = _units.indexOf(normalizedOld);
    if (index == -1) return;

    _units[index] = normalizedNew;
    ConversionManager.instance.renameUnit(normalizedOld, normalizedNew);
  }

  void deleteUnit(String unit) {
    final normalized = unit.trim();
    if (normalized.isEmpty) return;

    _units.remove(normalized);
    ConversionManager.instance.deleteUnit(normalized);
  }

  bool contains(String unit) => _units.contains(unit);
}
