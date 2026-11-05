class SalesCostSummary {
  double _knownCost = 0;
  int _unknownCostCount = 0;

  bool get isComplete => _unknownCostCount == 0;
  int get unknownCostCount => _unknownCostCount;
  double? get totalCost => isComplete ? _knownCost : null;

  double? profitFor(double revenue) {
    final cost = totalCost;
    if (cost == null || !revenue.isFinite) return null;

    final profit = revenue - cost;
    return profit.isFinite ? profit : null;
  }

  void addCost(double? cost) {
    if (cost == null || !cost.isFinite || cost < 0) {
      _unknownCostCount++;
      return;
    }

    final total = _knownCost + cost;
    if (!total.isFinite) {
      _unknownCostCount++;
      return;
    }

    _knownCost = total;
  }
}
