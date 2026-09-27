class ConversionTemplate {
  ConversionTemplate({
    required this.fromUnit,
    required this.toUnit,
    required this.factor,
  });

  final String fromUnit;
  final String toUnit;
  final double factor;
}

class ConversionManager {
  ConversionManager._();

  static final ConversionManager instance = ConversionManager._();

  factory ConversionManager() => instance;

  static final List<ConversionTemplate> _templates = <ConversionTemplate>[];

  List<ConversionTemplate> get templates => List.unmodifiable(_templates);

  void addTemplate(String fromUnit, String toUnit, double factor) {
    final normalizedFrom = fromUnit.trim();
    final normalizedTo = toUnit.trim();
    if (normalizedFrom.isEmpty || normalizedTo.isEmpty) return;

    _templates.removeWhere(
      (template) =>
          template.fromUnit == normalizedFrom &&
          template.toUnit == normalizedTo,
    );
    _templates.add(
      ConversionTemplate(
        fromUnit: normalizedFrom,
        toUnit: normalizedTo,
        factor: factor,
      ),
    );
  }

  void updateTemplate(String fromUnit, String toUnit, double factor) {
    addTemplate(fromUnit, toUnit, factor);
  }

  void renameUnit(String oldUnit, String newUnit) {
    final normalizedOld = oldUnit.trim();
    final normalizedNew = newUnit.trim();
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) return;

    for (final template in List<ConversionTemplate>.from(_templates)) {
      if (template.fromUnit == normalizedOld) {
        _templates.remove(template);
        _templates.add(
          ConversionTemplate(
            fromUnit: normalizedNew,
            toUnit: template.toUnit,
            factor: template.factor,
          ),
        );
      } else if (template.toUnit == normalizedOld) {
        _templates.remove(template);
        _templates.add(
          ConversionTemplate(
            fromUnit: template.fromUnit,
            toUnit: normalizedNew,
            factor: template.factor,
          ),
        );
      }
    }
  }

  void deleteUnit(String unit) {
    final normalized = unit.trim();
    if (normalized.isEmpty) return;

    _templates.removeWhere(
      (template) =>
          template.fromUnit == normalized || template.toUnit == normalized,
    );
  }

  void deleteTemplate(String fromUnit, String toUnit) {
    _templates.removeWhere(
      (template) => template.fromUnit == fromUnit && template.toUnit == toUnit,
    );
  }

  double? findFactor(String fromUnit, String toUnit) {
    final match = _templates.firstWhere(
      (template) => template.fromUnit == fromUnit && template.toUnit == toUnit,
      orElse: () => ConversionTemplate(fromUnit: '', toUnit: '', factor: -1),
    );
    return match.factor == -1 ? null : match.factor;
  }
}
