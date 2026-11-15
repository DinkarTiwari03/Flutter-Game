import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/city_demographics.dart';

void main() {
  group('CityDemographics Model Tests', () {
    test('default demographics and computed rates', () {
      const demo = CityDemographics();
      expect(demo.totalPopulation, 0);
      expect(demo.housingCapacity, 0);
      expect(demo.totalJobs, 0);
      expect(demo.employedCount, 0);
      expect(demo.occupancyRate, 0.0);
      expect(demo.employmentRate, 100.0);
    });

    test('computed occupancy and employment rates with non-zero data', () {
      const demo = CityDemographics(
        totalPopulation: 100,
        housingCapacity: 120,
        totalJobs: 80,
        employedCount: 52,
        healthcareRating: 90,
        educationRating: 85,
        safetyRating: 80,
      );

      expect(demo.occupancyRate, 83);
      expect(demo.employmentRate, 80);
    });

    test('JSON serialization and deserialization', () {
      const demo = CityDemographics(
        totalPopulation: 150,
        housingCapacity: 200,
        totalJobs: 110,
        employedCount: 95,
        healthcareRating: 75,
        educationRating: 80,
        safetyRating: 90,
        housingDemand: 40,
        commercialDemand: 20,
        industrialDemand: 10,
        migrationRate: 5,
      );

      final json = demo.toJson();
      final revived = CityDemographics.fromJson(json);

      expect(revived.totalPopulation, 150);
      expect(revived.housingCapacity, 200);
      expect(revived.totalJobs, 110);
      expect(revived.employedCount, 95);
      expect(revived.healthcareRating, 75);
      expect(revived.educationRating, 80);
      expect(revived.safetyRating, 90);
      expect(revived.housingDemand, 40);
      expect(revived.commercialDemand, 20);
      expect(revived.industrialDemand, 10);
      expect(revived.migrationRate, 5);
    });
  });
}
