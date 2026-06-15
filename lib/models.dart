class DailyRate {
  final int? id;
  final String date;
  final double baseRate;

  DailyRate({
    this.id,
    required this.date,
    required this.baseRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'base_rate': baseRate,
    };
  }

  factory DailyRate.fromMap(Map<String, dynamic> map) {
    return DailyRate(
      id: map['id'] as int?,
      date: map['date'] as String,
      baseRate: (map['base_rate'] as num).toDouble(),
    );
  }
}

class Party {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String adjustmentType;
  final double adjustmentValue;

  Party({
    this.id,
    required this.name,
    this.phone,
    this.address,
    required this.adjustmentType,
    required this.adjustmentValue,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'adjustment_type': adjustmentType,
      'adjustment_value': adjustmentValue,
    };
  }

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      adjustmentType: map['adjustment_type'] as String,
      adjustmentValue: (map['adjustment_value'] as num).toDouble(),
    );
  }

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

class Sale {
  final int? id;
  final int partyId;
  final String saleDate;
  final double eggQuantity;
  final double baseRate;
  final double adjustedRate;
  final double amount;
  final String? notes;

  Sale({
    this.id,
    required this.partyId,
    required this.saleDate,
    required this.eggQuantity,
    required this.baseRate,
    required this.adjustedRate,
    required this.amount,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'party_id': partyId,
      'sale_date': saleDate,
      'egg_quantity': eggQuantity,
      'base_rate': baseRate,
      'adjusted_rate': adjustedRate,
      'amount': amount,
      'notes': notes,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      partyId: map['party_id'] as int,
      saleDate: map['sale_date'] as String,
      eggQuantity: (map['egg_quantity'] as num).toDouble(),
      baseRate: (map['base_rate'] as num).toDouble(),
      adjustedRate: (map['adjusted_rate'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class SaleWithParty {
  final Sale sale;
  final Party party;

  SaleWithParty({required this.sale, required this.party});
}