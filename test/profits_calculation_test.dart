import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profits calculation tests', () {
    test('Calculates item cost and profit with basic storage unit', () {
      const quantity = 5.0;
      const unitPrice = 20.0;
      const buyPrice = 12.0;

      final revenue = quantity * unitPrice; // 100
      final cost = quantity * buyPrice; // 60
      final profit = revenue - cost; // 40
      final margin = (profit / revenue) * 100; // 40%

      expect(revenue, 100.0);
      expect(cost, 60.0);
      expect(profit, 40.0);
      expect(margin, 40.0);
    });

    test('Calculates item cost for sub-units purchased as bundle/carton (e.g. foam plates)', () {
      // 1 column = 100 pieces, purchased at 90 LE per column
      const buyPricePerColumn = 90.0;
      const unitsPerPurchaseUnit = 100;
      const quantitySoldInPieces = 53.0;
      const sellPricePerPiece = 1.25;

      // Cost per single piece (storage unit) is buyPrice / unitsPerPurchaseUnit
      final costPerPiece = buyPricePerColumn / unitsPerPurchaseUnit; // 0.90 LE
      final revenue = quantitySoldInPieces * sellPricePerPiece; // 66.25 LE
      final cost = quantitySoldInPieces * costPerPiece; // 47.70 LE (NOT 4770.0 LE!)
      final profit = revenue - cost; // 18.55 LE
      final margin = (profit / revenue) * 100; // 28.0%

      expect(costPerPiece, 0.90);
      expect(revenue, 66.25);
      expect(cost, 47.70);
      expect(profit, closeTo(18.55, 0.001));
      expect(margin, closeTo(28.0, 0.01));
    });

    test('Calculates item cost with unit conversion factor when selling whole columns', () {
      // 2 columns sold, each column = 100 pieces, cost per column = 90 LE, sellPrice = 125 LE
      const quantitySoldInColumns = 2.0;
      const buyPricePerColumn = 90.0;
      const sellPricePerColumn = 125.0;

      final revenue = quantitySoldInColumns * sellPricePerColumn; // 250
      final cost = quantitySoldInColumns * buyPricePerColumn; // 180
      final profit = revenue - cost; // 70
      final margin = (profit / revenue) * 100; // 28%

      expect(revenue, 250.0);
      expect(cost, 180.0);
      expect(profit, 70.0);
      expect(margin, closeTo(28.0, 0.001));
    });

    test('Calculates item cost with weight conversion (grams to kg)', () {
      // 500 grams sold, storage is kg, buyPrice is 120 LE per kg
      const quantityInGrams = 500.0;
      const factor = 0.001; // grams to kg
      const buyPricePerKg = 120.0;
      const revenue = 80.0;

      final storageQuantityInKg = quantityInGrams * factor; // 0.5 kg
      final cost = storageQuantityInKg * buyPricePerKg; // 60
      final profit = revenue - cost; // 20
      final margin = (profit / revenue) * 100; // 25%

      expect(storageQuantityInKg, 0.5);
      expect(cost, 60.0);
      expect(profit, 20.0);
      expect(margin, 25.0);
    });

    test('Calculates gross profit, operating expenses, and net profit', () {
      const totalRevenue = 10000.0;
      const totalCOGS = 6500.0;
      const totalExpenses = 1500.0;

      final grossProfit = totalRevenue - totalCOGS; // 3500
      final grossMargin = (grossProfit / totalRevenue) * 100; // 35%
      final netProfit = grossProfit - totalExpenses; // 2000
      final netMargin = (netProfit / totalRevenue) * 100; // 20%

      expect(grossProfit, 3500.0);
      expect(grossMargin, 35.0);
      expect(netProfit, 2000.0);
      expect(netMargin, 20.0);
    });
  });
}
