import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 6)
enum PartyType {
  @HiveField(0)
  customer,
  @HiveField(1)
  supplier
}

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

/// Supported rate adjustment modes for a party.
/// "=" same as base rate, "+"/"-" flat rupee amount, "+%"/"-%" percentage.
const List<String> kAdjustmentModes = ['=', '+', '-', '+%', '-%'];

/// Percentage adjustment types
const List<String> kPercentageTypes = ['discount', 'markup', 'tax'];

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

  @HiveField(8)
  PartyType type; // Customer or Supplier

  // Percentage fields for Party
  @HiveField(9)
  String? percentageType; // 'discount', 'markup', 'tax', or null

  @HiveField(10)
  double percentageValue; // The % amount (e.g., 10 for 10%)

  // NEW: Minimum egg quantity required before the percentage kicks in.
  // 0 (or less) means "no minimum" — percentage always applies.
  @HiveField(11)
  double percentageMinQuantity;

  Party({
    required this.name,
    this.phone,
    this.address,
    required this.adjustmentType,
    required this.adjustmentValue,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.type = PartyType.customer,
    this.percentageType,
    this.percentageValue = 0.0,
    this.percentageMinQuantity = 0.0,
  });

  factory Party.now({
    required String name,
    String? phone,
    String? address,
    required String adjustmentType,
    required double adjustmentValue,
    String? notes,
    PartyType type = PartyType.customer,
    String? percentageType,
    double percentageValue = 0.0,
    double percentageMinQuantity = 0.0,
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
      type: type,
      percentageType: percentageType,
      percentageValue: percentageValue,
      percentageMinQuantity: percentageMinQuantity,
    );
  }

  /// Returns the rate this party actually pays/receives for a given
  /// day's base rate, after applying their adjustment.
  double calculateAdjustedRate(double baseRate) {
    switch (adjustmentType) {
      case '+':
        return baseRate + adjustmentValue;
      case '-':
        final result = baseRate - adjustmentValue;
        return result < 0 ? 0 : result;
      case '+%':
        return baseRate * (1 + adjustmentValue / 100);
      case '-%':
        final result = baseRate * (1 - adjustmentValue / 100);
        return result < 0 ? 0 : result;
      case '=':
      default:
        return baseRate;
    }
  }

  /// True if a percentage is configured AND, given [quantity] of eggs in
  /// this transaction, the minimum-quantity requirement (if any) is met.
  /// Pass the transaction's egg quantity here — not just [hasPercentage].
  bool percentageActiveForQuantity(double quantity) {
    if (!hasPercentage) return false;
    if (percentageMinQuantity <= 0) return true;
    return quantity >= percentageMinQuantity;
  }

  /// Apply percentage adjustment to an amount.
  /// [quantity] is the egg quantity for this transaction — needed so the
  /// minimum-quantity threshold can be checked. Defaults to a value that
  /// always passes the threshold check for callers that don't track
  /// quantity-gated percentages.
  double applyPercentageToAmount(double amount, [double? quantity]) {
    final qty = quantity ?? double.infinity;
    if (!percentageActiveForQuantity(qty)) {
      return amount;
    }

    switch (percentageType) {
      case 'discount':
        final discountValue = (amount * percentageValue) / 100;
        return amount - discountValue;
      case 'markup':
        final markupValue = (amount * percentageValue) / 100;
        return amount + markupValue;
      case 'tax':
        final taxValue = (amount * percentageValue) / 100;
        return amount + taxValue;
      default:
        return amount;
    }
  }

  /// Get percentage breakdown for display.
  /// [quantity] is the egg quantity for this transaction — needed so the
  /// minimum-quantity threshold can be checked.
  Map<String, double> getPercentageBreakdown(double amount, [double? quantity]) {
    final qty = quantity ?? double.infinity;
    if (!percentageActiveForQuantity(qty)) {
      return {
        'baseAmount': amount,
        'percentageValue': 0,
        'finalAmount': amount,
        'percentage': 0,
      };
    }

    final percentageAmount = (amount * percentageValue) / 100;
    double finalAmount = applyPercentageToAmount(amount, qty);

    return {
      'baseAmount': amount,
      'percentageValue': percentageAmount,
      'finalAmount': finalAmount,
      'percentage': percentageValue,
    };
  }

  /// Short display label for the adjustment, e.g. "+10%", "-₹5", "=".
  /// Centralised here so every screen/widget shows the exact same text
  /// instead of each file re-implementing its own switch statement.
  String get adjustmentLabel {
    switch (adjustmentType) {
      case '+':
        return '+₹${adjustmentValue.toStringAsFixed(adjustmentValue % 1 == 0 ? 0 : 2)}';
      case '-':
        return '-₹${adjustmentValue.toStringAsFixed(adjustmentValue % 1 == 0 ? 0 : 2)}';
      case '+%':
        return '+${adjustmentValue.toStringAsFixed(adjustmentValue % 1 == 0 ? 0 : 1)}%';
      case '-%':
        return '-${adjustmentValue.toStringAsFixed(adjustmentValue % 1 == 0 ? 0 : 1)}%';
      case '=':
      default:
        return '=';
    }
  }

  /// Get percentage label for display
  String get percentageLabel {
    if (percentageType == null || percentageValue == 0) {
      return 'None';
    }
    final typeLabel = percentageType![0].toUpperCase() + percentageType!.substring(1);
    final base = '$typeLabel: ${percentageValue.toStringAsFixed(percentageValue % 1 == 0 ? 0 : 1)}%';
    if (percentageMinQuantity > 0) {
      final qtyStr = percentageMinQuantity % 1 == 0
          ? percentageMinQuantity.toStringAsFixed(0)
          : percentageMinQuantity.toString();
      return '$base (min $qtyStr eggs)';
    }
    return base;
  }

  /// True if this party has any adjustment away from the base rate.
  bool get hasAdjustment => adjustmentType != '=' && adjustmentValue != 0;

  /// True if this party has percentage adjustment configured at all
  /// (regardless of any minimum-quantity threshold — use
  /// [percentageActiveForQuantity] to check against a specific sale).
  bool get hasPercentage => percentageType != null && percentageValue != 0;
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

  @HiveField(6)
  String paymentType; // "received" (from customer) or "paid" (to supplier)

  Payment({
    required this.partyKey,
    required this.date,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentType,
  });

  factory Payment.now({
    required int partyKey,
    required String date,
    required double amount,
    String? notes,
    required String paymentType,
  }) {
    final now = DateTime.now();
    return Payment(
      partyKey: partyKey,
      date: date,
      amount: amount,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      paymentType: paymentType,
    );
  }
}

class PaymentWithParty {
  final Payment payment;
  final Party party;

  PaymentWithParty({required this.payment, required this.party});
}

@HiveType(typeId: 5)
class Purchase extends HiveObject {
  @HiveField(0)
  int supplierKey;

  @HiveField(1)
  String purchaseDate;

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

  Purchase({
    required this.supplierKey,
    required this.purchaseDate,
    required this.eggQuantity,
    required this.baseRate,
    required this.adjustedRate,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Purchase.now({
    required int supplierKey,
    required String purchaseDate,
    required double eggQuantity,
    required double baseRate,
    required double adjustedRate,
    required double amount,
    String? notes,
  }) {
    final now = DateTime.now();
    return Purchase(
      supplierKey: supplierKey,
      purchaseDate: purchaseDate,
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

class PurchaseWithSupplier {
  final Purchase purchase;
  final Party supplier;

  PurchaseWithSupplier({required this.purchase, required this.supplier});
}