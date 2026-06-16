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
  final String adjustmentType; // "=", "+", "-", "+%", "-%"

  @HiveField(4)
  final double adjustmentValue;

  @HiveField(5)
  final String? notes;

  Party({
    required this.name,
    this.phone,
    this.address,
    required this.adjustmentType,
    required this.adjustmentValue,
    this.notes,
  });

  double calculateAdjustedRate(double baseRate) {
    switch (adjustmentType) {
      case '+':
        return baseRate + adjustmentValue;
      case '-':
        return baseRate - adjustmentValue;
      case '+%':
        return baseRate * (1 + adjustmentValue / 100);
      case '-%':
        return baseRate * (1 - adjustmentValue / 100);
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

@HiveType(typeId: 3)
class Expense extends HiveObject {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final String category; // Transport, Labour, Electricity, Rent, Miscellaneous

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String? notes;

  Expense({
    required this.date,
    required this.category,
    required this.amount,
    this.notes,
  });
}

@HiveType(typeId: 4)
class Payment extends HiveObject {
  @HiveField(0)
  final int partyKey;

  @HiveField(1)
  final String date;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String? notes;

  Payment({
    required this.partyKey,
    required this.date,
    required this.amount,
    this.notes,
  });
}

class PaymentWithParty {
  final Payment payment;
  final Party party;

  PaymentWithParty({required this.payment, required this.party});
}
