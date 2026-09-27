class DescriptionsManager {
  DescriptionsManager._();

  static final DescriptionsManager instance = DescriptionsManager._();

  factory DescriptionsManager() => instance;

  static final List<String> _descriptions = <String>[];

  List<String> get descriptions => List.unmodifiable(_descriptions);

  void addDescription(String description) {
    final normalized = description.trim();
    if (normalized.isEmpty) return;
    if (!_descriptions.contains(normalized)) {
      _descriptions.add(normalized);
    }
  }

  void updateDescription(String oldDescription, String newDescription) {
    final normalizedNew = newDescription.trim();
    if (normalizedNew.isEmpty) return;

    final index = _descriptions.indexOf(oldDescription);
    if (index == -1) return;

    _descriptions[index] = normalizedNew;
  }

  void deleteDescription(String description) {
    _descriptions.remove(description);
  }
}
