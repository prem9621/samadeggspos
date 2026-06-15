import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class DailyRate extends HiveObject {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final double baseRate;

  DailyRate({
    required this.date,
    required this.baseRate,
  });
}

@HiveType(typeId: 1)
class Party extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String? phone;

  @HiveField(2)
  final String? address;

  @HiveField(3)
  final String adjustmentType;

  @HiveField(4)
  final double adjustmentValue;

  Party({
    required this.name,
    this.phone,
    this.address,
    required this.adjustmentType,
    required this.adjustmentValue,
  });

  double calculateAdjustedRate(double baseRate) {
    switch (adjustmentType) {
      case '+':
        return baseRate + adjustmentValue;
      case '-':
        return baseRate - adjustmentValue;
      case '=':
      default:
        return baseRate;
    }
  }
}

@HiveType(typeId: 2)
class Sale extends HiveObject {
  @HiveField(0)
  final int partyKey;

  @HiveField(1)
  final String saleDate;

  @HiveField(2)
  final double eggQuantity;

  @HiveField(3)
  final double baseRate;

  @HiveField(4)
  final double adjustedRate;

  @HiveField(5)
  final double amount;

  @HiveField(6)
  final String? notes;

  Sale({
    required this.partyKey,
    required this.saleDate,
    required this.eggQuantity,
    required this.baseRate,
    required this.adjustedRate,
    required this.amount,
    this.notes,
  });
}

class SaleWithParty {
  final Sale sale;
  final Party party;

  SaleWithParty({required this.sale, required this.party});
}
