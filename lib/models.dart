import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class DailyRate extends HiveObject {
  @HiveField(0)
  String date;

  @HiveField(1)
  double baseRate;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  DailyRate({
    required this.date,
    required this.baseRate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyRate.now(String date, double baseRate) {
    final now = DateTime.now();
    return DailyRate(
      date: date,
      baseRate: baseRate,
      createdAt: now,
      updatedAt: now,
    );
  }
}

@HiveType(typeId: 1)
class Party extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String? phone;

  @HiveField(2)
  String? address;

  @HiveField(3)
  String adjustmentType; // "=", "+", "-", "+%", "-%"

  @HiveField(4)
  double adjustmentValue;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  Party({
    required this.name,
    this.phone,
    this.address,
    required this.adjustmentType,
    required this.adjustmentValue,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Party.now({
    required String name,
    String? phone,
    String? address,
    required String adjustmentType,
    required double adjustmentValue,
    String? notes,
  }) {
    final now = DateTime.now();
    return Party(
      name: name,
      phone: phone,
      address: address,
      adjustmentType: adjustmentType,
      adjustmentValue: adjustmentValue,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

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
  int partyKey;

  @HiveField(1)
  String saleDate;

  @HiveField(2)
  double eggQuantity;

  @HiveField(3)
  double baseRate;

  @HiveField(4)
  double adjustedRate;

  @HiveField(5)
  double amount;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  Sale({
    required this.partyKey,
    required this.saleDate,
    required this.eggQuantity,
    required this.baseRate,
    required this.adjustedRate,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sale.now({
    required int partyKey,
    required String saleDate,
    required double eggQuantity,
    required double baseRate,
    required double adjustedRate,
    required double amount,
    String? notes,
  }) {
    final now = DateTime.now();
    return Sale(
      partyKey: partyKey,
      saleDate: saleDate,
      eggQuantity: eggQuantity,
      baseRate: baseRate,
      adjustedRate: adjustedRate,
      amount: amount,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class SaleWithParty {
  final Sale sale;
  final Party party;

  SaleWithParty({required this.sale, required this.party});
}

@HiveType(typeId: 3)
class Expense extends HiveObject {
  @HiveField(0)
  String date;

  @HiveField(1)
  String category; // Transport, Labour, Electricity, Rent, Miscellaneous

  @HiveField(2)
  double amount;

  @HiveField(3)
  String? notes;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  Expense({
    required this.date,
    required this.category,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Expense.now({
    required String date,
    required String category,
    required double amount,
    String? notes,
  }) {
    final now = DateTime.now();
    return Expense(
      date: date,
      category: category,
      amount: amount,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}

@HiveType(typeId: 4)
class Payment extends HiveObject {
  @HiveField(0)
  int partyKey;

  @HiveField(1)
  String date;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String? notes;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  Payment({
    required this.partyKey,
    required this.date,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.now({
    required int partyKey,
    required String date,
    required double amount,
    String? notes,
  }) {
    final now = DateTime.now();
    return Payment(
      partyKey: partyKey,
      date: date,
      amount: amount,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class PaymentWithParty {
  final Payment payment;
  final Party party;

  PaymentWithParty({required this.payment, required this.party});
}
