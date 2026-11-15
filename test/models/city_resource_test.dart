import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/city_resource.dart';
import 'package:city_builder_2040/models/city_stats.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/models/resource_transaction.dart';

void main() {
  group('CityResource Models', () {
    test('UtilityBalance calculates net and satisfaction correctly', () {
      const balance = UtilityBalance(production: 150, consumption: 100);
      expect(balance.net, 50);
      expect(balance.isDeficit, isFalse);
      expect(balance.satisfactionRate, 100);

      const deficit = UtilityBalance(production: 60, consumption: 120);
      expect(deficit.net, -60);
      expect(deficit.isDeficit, isTrue);
      expect(deficit.satisfactionRate, 50);

      const zeroDemand = UtilityBalance(production: 0, consumption: 0);
      expect(zeroDemand.satisfactionRate, 100);
      expect(zeroDemand.isDeficit, isFalse);
    });

    test('CashflowSummary computes net and deficit states', () {
      const income = IncomeBreakdown(
        residentialTaxes: 100,
        commercialIncome: 200,
        industrialIncome: 150,
      );
      expect(income.total, 450);

      const expenses = ExpenseBreakdown(
        buildingMaintenance: 120,
        roadMaintenance: 10,
        electricityProductionCost: 20,
        waterProductionCost: 20,
      );
      expect(expenses.total, 170);

      const cashflow = CashflowSummary(income: income, expenses: expenses);
      expect(cashflow.net, 450 - 170);
      expect(cashflow.isDeficit, isFalse);

      const deficitCashflow = CashflowSummary(
        income: IncomeBreakdown(),
        expenses: ExpenseBreakdown(buildingMaintenance: 50),
      );
      expect(deficitCashflow.net, -50);
      expect(deficitCashflow.isDeficit, isTrue);
    });

    test('ResourceTransaction serializes and deserializes accurately', () {
      final now = DateTime.utc(2040, 1, 1, 10, 30);
      final tx = ResourceTransaction(
        id: 'tx-1',
        cityId: 'c1',
        type: TransactionType.construction,
        amount: -250,
        description: 'Built Shop',
        timestamp: now,
        buildingTypeId: 'shop',
      );

      expect(tx.isExpense, isTrue);
      expect(tx.isIncome, isFalse);

      final json = tx.toJson();
      final restored = ResourceTransaction.fromJson(json);

      expect(restored.id, tx.id);
      expect(restored.cityId, tx.cityId);
      expect(restored.type, tx.type);
      expect(restored.amount, tx.amount);
      expect(restored.description, tx.description);
      expect(restored.timestamp, tx.timestamp);
      expect(restored.buildingTypeId, tx.buildingTypeId);
    });

    test('ResourceLedger initial values and updateAmounts', () {
      final now = DateTime.utc(2040, 1, 1);
      final ledger = ResourceLedger.initial(
        'c1',
        startingCoins: 25000,
        startingHappiness: 75,
        now: now,
      );

      expect(ledger.coins, 25000);
      expect(ledger.population, 0);
      expect(ledger.happiness, 75);
      expect(ledger.pollution, 0);

      final updated = ledger.updateAmounts({
        ResourceLedger.coinsKey: 24000.0,
        ResourceLedger.populationKey: 50.0,
      });

      expect(updated.coins, 24000);
      expect(updated.population, 50);
      expect(updated.happiness, 75); // unchanged
    });

    test('CityStats warning flags trigger properly', () {
      final healthyStats = const CityStats(
        coins: 10000,
        population: 200,
        electricity: 100,
        water: 100,
        happiness: 80,
        pollution: 10,
      );

      expect(healthyStats.isLowCoins, isFalse);
      expect(healthyStats.isElectricityDeficit, isFalse);
      expect(healthyStats.isWaterDeficit, isFalse);
      expect(healthyStats.isUnhappy, isFalse);
      expect(healthyStats.isPolluted, isFalse);

      final troubledStats = const CityStats(
        coins: 250,
        population: 200,
        electricity: 70,
        water: 50,
        happiness: 35,
        pollution: 65,
      );

      expect(troubledStats.isLowCoins, isTrue);
      expect(troubledStats.isElectricityDeficit, isTrue);
      expect(troubledStats.isWaterDeficit, isTrue);
      expect(troubledStats.isUnhappy, isTrue);
      expect(troubledStats.isPolluted, isTrue);
    });
  });
}
