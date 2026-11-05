import '../../database/database_helper.dart';
import '../../utils/unit_name_normalizer.dart';
import 'conversion_manager.dart';

class UnitsManager {
  UnitsManager._()
    : _units = List<String>.from(UnitNameNormalizer.defaultUnits);

  static final UnitsManager instance = UnitsManager._();

  factory UnitsManager() => instance;

  final List<String> _units;
  bool _isLoaded = false;

  List<String> get availableUnits => List.unmodifiable(_units);
  bool get isLoaded => _isLoaded;

  Future<void> loadUnits() async {
    final units = await DatabaseHelper.instance.getUnits();
    _units
      ..clear()
      ..addAll(units);
    _isLoaded = true;
  }

  Future<void> addUnit(String unit) async {
    await DatabaseHelper.instance.insertUnit(unit);
    await loadUnits();
  }

  Future<void> updateUnit(String oldUnit, String newUnit) async {
    await DatabaseHelper.instance.renameUnit(oldUnit, newUnit);
    ConversionManager.instance.renameUnit(oldUnit, newUnit);
    await loadUnits();
  }

  Future<void> deleteUnit(String unit) async {
    await DatabaseHelper.instance.deleteUnit(unit);
    ConversionManager.instance.deleteUnit(unit);
    await loadUnits();
  }

  bool contains(String unit) => _units.any(
    (existing) =>
        UnitNameNormalizer.normalize(existing) ==
        UnitNameNormalizer.normalize(unit),
  );
}
