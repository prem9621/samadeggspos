import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class DatabaseResult<T> {
  final T? data;
  final String? error;
  final bool success;

  DatabaseResult.success(this.data)
      : error = null,
        success = true;

  DatabaseResult.failure(this.error)
      : data = null,
        success = false;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  static const String boxDailyRates = 'dailyRates';
  static const String boxParties = 'parties';
  static const String boxSales = 'sales';
  static const String boxExpenses = 'expenses';
  static const String boxPayments = 'payments';
  static const String boxPurchases = 'purchases';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DailyRateAdapter());
    Hive.registerAdapter(PartyAdapter());
    Hive.registerAdapter(PartyTypeAdapter());
    Hive.registerAdapter(SaleAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(PaymentAdapter());
    Hive.registerAdapter(PurchaseAdapter());
    await Hive.openBox<DailyRate>(boxDailyRates);
    await Hive.openBox<Party>(boxParties);
    await Hive.openBox<Sale>(boxSales);
    await Hive.openBox<Expense>(boxExpenses);
    await Hive.openBox<Payment>(boxPayments);
    await Hive.openBox<Purchase>(boxPurchases);
  }

  // ------------------------------
  // Daily Rates
  // ------------------------------

  Future<DatabaseResult<DailyRate>> insertDailyRate(DailyRate rate) async {
    try {
      if (rate.baseRate <= 0) {
        return DatabaseResult.failure('Rate must be greater than 0');
      }

      final box = await Hive.openBox<DailyRate>(boxDailyRates);
      if (box.containsKey(rate.date)) {
        return DatabaseResult.failure('Rate already exists for this date');
      }

      await box.put(rate.date, rate);
      return DatabaseResult.success(rate);
    } catch (e) {
      return DatabaseResult.failure('Failed to save rate: $e');
    }
  }

  Future<DatabaseResult<DailyRate>> updateDailyRate(DailyRate rate) async {
    try {
      if (rate.baseRate <= 0) {
        return DatabaseResult.failure('Rate must be greater than 0');
      }

      final box = await Hive.openBox<DailyRate>(boxDailyRates);
      rate.updatedAt = DateTime.now();
      await box.put(rate.date, rate);
      return DatabaseResult.success(rate);
    } catch (e) {
      return DatabaseResult.failure('Failed to update rate: $e');
    }
  }

  Future<DatabaseResult<DailyRate?>> getDailyRateByDate(String date) async {
    try {
      final box = await Hive.openBox<DailyRate>(boxDailyRates);
      return DatabaseResult.success(box.get(date));
    } catch (e) {
      return DatabaseResult.failure('Failed to load rate: $e');
    }
  }

  Future<DatabaseResult<List<DailyRate>>> getAllDailyRates() async {
    try {
      final box = await Hive.openBox<DailyRate>(boxDailyRates);
      final list = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      return DatabaseResult.success(list);
    } catch (e) {
      return DatabaseResult.failure('Failed to load rates: $e');
    }
  }

  // ------------------------------
  // Parties
  // ------------------------------

  Future<DatabaseResult<Party>> insertParty(Party party) async {
    try {
      if (party.name.trim().isEmpty) {
        return DatabaseResult.failure('Party name cannot be empty');
      }

      final box = await Hive.openBox<Party>(boxParties);
      for (final existing in box.values) {
        if (existing.name.toLowerCase().trim() == party.name.toLowerCase().trim() && existing.key != party.key) {
          return DatabaseResult.failure('Party with this name already exists');
        }
      }

      await box.add(party);
      return DatabaseResult.success(party);
    } catch (e) {
      return DatabaseResult.failure('Failed to save party: $e');
    }
  }

  Future<DatabaseResult<Party>> updateParty(Party party) async {
    try {
      if (party.name.trim().isEmpty) {
        return DatabaseResult.failure('Party name cannot be empty');
      }

      final box = await Hive.openBox<Party>(boxParties);
      for (final existing in box.values) {
        if (existing.name.toLowerCase().trim() == party.name.toLowerCase().trim() && existing.key != party.key) {
          return DatabaseResult.failure('Party with this name already exists');
        }
      }

      party.updatedAt = DateTime.now();
      await party.save();
      return DatabaseResult.success(party);
    } catch (e) {
      return DatabaseResult.failure('Failed to update party: $e');
    }
  }

  Future<DatabaseResult<void>> deleteParty(Party party) async {
    try {
      await party.delete();
      return DatabaseResult.success(null);
    } catch (e) {
      return DatabaseResult.failure('Failed to delete party: $e');
    }
  }

  Future<DatabaseResult<List<Party>>> getAllParties() async {
    try {
      final box = await Hive.openBox<Party>(boxParties);
      final list = box.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return DatabaseResult.success(list);
    } catch (e) {
      return DatabaseResult.failure('Failed to load parties: $e');
    }
  }

  Future<DatabaseResult<List<Party>>> getPartiesByType(PartyType type) async {
    try {
      final result = await getAllParties();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      return DatabaseResult.success(result.data?.where((p) => p.type == type).toList() ?? []);
    } catch (e) {
      return DatabaseResult.failure('Failed to load parties: $e');
    }
  }

  Future<DatabaseResult<List<Party>>> searchParties(String query) async {
    try {
      final result = await getAllParties();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }

      final searchLower = query.toLowerCase().trim();
      final filtered = result.data?.where((p) =>
          p.name.toLowerCase().contains(searchLower)).toList() ?? [];

      return DatabaseResult.success(filtered);
    } catch (e) {
      return DatabaseResult.failure('Failed to search parties: $e');
    }
  }

  // ------------------------------
  // Sales
  // ------------------------------

  Future<DatabaseResult<Sale>> insertSale(Sale sale) async {
    try {
      if (sale.eggQuantity <= 0) {
        return DatabaseResult.failure('Quantity must be greater than 0');
      }
      if (sale.baseRate <= 0) {
        return DatabaseResult.failure('Invalid base rate');
      }
      if (sale.amount <= 0) {
        return DatabaseResult.failure('Invalid amount');
      }

      final box = await Hive.openBox<Sale>(boxSales);
      await box.add(sale);
      return DatabaseResult.success(sale);
    } catch (e) {
      return DatabaseResult.failure('Failed to save sale: $e');
    }
  }

  Future<DatabaseResult<List<SaleWithParty>>> getAllSales() async {
    try {
      final saleBox = await Hive.openBox<Sale>(boxSales);
      final partyBox = await Hive.openBox<Party>(boxParties);

      List<SaleWithParty> result = [];
      for (final sale in saleBox.values) {
        final party = partyBox.getAt(sale.partyKey);
        if (party != null) {
          result.add(SaleWithParty(sale: sale, party: party));
        }
      }
      result.sort((a, b) => b.sale.createdAt.compareTo(a.sale.createdAt));
      return DatabaseResult.success(result);
    } catch (e) {
      return DatabaseResult.failure('Failed to load sales: $e');
    }
  }

  Future<DatabaseResult<List<SaleWithParty>>> getSalesByDate(String date) async {
    try {
      final result = await getAllSales();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      final filtered = result.data?.where((s) => s.sale.saleDate == date).toList() ?? [];
      return DatabaseResult.success(filtered);
    } catch (e) {
      return DatabaseResult.failure('Failed to load sales: $e');
    }
  }

  Future<DatabaseResult<List<SaleWithParty>>> getSalesByParty(Party party) async {
    try {
      final result = await getAllSales();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      final filtered = result.data?.where((s) => s.sale.partyKey == party.key).toList() ?? [];
      return DatabaseResult.success(filtered);
    } catch (e) {
      return DatabaseResult.failure('Failed to load sales: $e');
    }
  }

  Future<DatabaseResult<double>> getTotalEggsSoldOnDate(String date) async {
    try {
      final result = await getSalesByDate(date);
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      double total = 0;
      for (final s in result.data ?? []) {
        total += s.sale.eggQuantity;
      }
      return DatabaseResult.success(total);
    } catch (e) {
      return DatabaseResult.failure('Failed to calculate eggs sold: $e');
    }
  }

  Future<DatabaseResult<double>> getTotalSalesAmountOnDate(String date) async {
    try {
      final result = await getSalesByDate(date);
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      double total = 0;
      for (final s in result.data ?? []) {
        total += s.sale.amount;
      }
      return DatabaseResult.success(total);
    } catch (e) {
      return DatabaseResult.failure('Failed to calculate sales amount: $e');
    }
  }

  // ------------------------------
  // Expenses
  // ------------------------------

  Future<DatabaseResult<Expense>> insertExpense(Expense expense) async {
    try {
      if (expense.amount <= 0) {
        return DatabaseResult.failure('Amount must be greater than 0');
      }
      if (expense.category.trim().isEmpty) {
        return DatabaseResult.failure('Please select a category');
      }

      final box = await Hive.openBox<Expense>(boxExpenses);
      await box.add(expense);
      return DatabaseResult.success(expense);
    } catch (e) {
      return DatabaseResult.failure('Failed to save expense: $e');
    }
  }

  Future<DatabaseResult<List<Expense>>> getAllExpenses() async {
    try {
      final box = await Hive.openBox<Expense>(boxExpenses);
      final list = box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return DatabaseResult.success(list);
    } catch (e) {
      return DatabaseResult.failure('Failed to load expenses: $e');
    }
  }

  Future<DatabaseResult<List<Expense>>> getExpensesByDate(String date) async {
    try {
      final result = await getAllExpenses();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      final filtered = result.data?.where((e) => e.date == date).toList() ?? [];
      return DatabaseResult.success(filtered);
    } catch (e) {
      return DatabaseResult.failure('Failed to load expenses: $e');
    }
  }

  Future<DatabaseResult<double>> getTotalExpensesOnDate(String date) async {
    try {
      final result = await getExpensesByDate(date);
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      double total = 0;
      for (final e in result.data ?? []) {
        total += e.amount;
      }
      return DatabaseResult.success(total);
    } catch (e) {
      return DatabaseResult.failure('Failed to calculate expenses: $e');
    }
  }

  // ------------------------------
  // Payments
  // ------------------------------

  Future<DatabaseResult<Payment>> insertPayment(Payment payment) async {
    try {
      if (payment.amount <= 0) {
        return DatabaseResult.failure('Amount must be greater than 0');
      }

      final box = await Hive.openBox<Payment>(boxPayments);
      await box.add(payment);
      return DatabaseResult.success(payment);
    } catch (e) {
      return DatabaseResult.failure('Failed to save payment: $e');
    }
  }

  Future<DatabaseResult<List<PaymentWithParty>>> getAllPayments() async {
    try {
      final paymentBox = await Hive.openBox<Payment>(boxPayments);
      final partyBox = await Hive.openBox<Party>(boxParties);

      List<PaymentWithParty> result = [];
      for (final payment in paymentBox.values) {
        final party = partyBox.getAt(payment.partyKey);
        if (party != null) {
          result.add(PaymentWithParty(payment: payment, party: party));
        }
      }
      result.sort((a, b) => b.payment.createdAt.compareTo(a.payment.createdAt));
      return DatabaseResult.success(result);
    } catch (e) {
      return DatabaseResult.failure('Failed to load payments: $e');
    }
  }

  Future<DatabaseResult<List<PaymentWithParty>>> getPaymentsByParty(Party party) async {
    try {
      final result = await getAllPayments();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      final filtered = result.data?.where((p) => p.payment.partyKey == party.key).toList() ?? [];
      return DatabaseResult.success(filtered);
    } catch (e) {
      return DatabaseResult.failure('Failed to load payments: $e');
    }
  }

  // ------------------------------
  // Purchases
  // ------------------------------

  Future<DatabaseResult<Purchase>> insertPurchase(Purchase purchase) async {
    try {
      if (purchase.eggQuantity <= 0) {
        return DatabaseResult.failure('Quantity must be greater than 0');
      }
      if (purchase.baseRate <= 0) {
        return DatabaseResult.failure('Invalid base rate');
      }
      if (purchase.amount <= 0) {
        return DatabaseResult.failure('Invalid amount');
      }

      final box = await Hive.openBox<Purchase>(boxPurchases);
      await box.add(purchase);
      return DatabaseResult.success(purchase);
    } catch (e) {
      return DatabaseResult.failure('Failed to save purchase: $e');
    }
  }

  Future<DatabaseResult<List<PurchaseWithSupplier>>> getAllPurchases() async {
    try {
      final purchaseBox = await Hive.openBox<Purchase>(boxPurchases);
      final partyBox = await Hive.openBox<Party>(boxParties);

      List<PurchaseWithSupplier> result = [];
      for (final purchase in purchaseBox.values) {
        final supplier = partyBox.getAt(purchase.supplierKey);
        if (supplier != null) {
          result.add(PurchaseWithSupplier(purchase: purchase, supplier: supplier));
        }
      }
      result.sort((a, b) => b.purchase.createdAt.compareTo(a.purchase.createdAt));
      return DatabaseResult.success(result);
    } catch (e) {
      return DatabaseResult.failure('Failed to load purchases: $e');
    }
  }

  Future<DatabaseResult<List<PurchaseWithSupplier>>> getPurchasesBySupplier(Party supplier) async {
    try {
      final result = await getAllPurchases();
      if (!result.success) {
        return DatabaseResult.failure(result.error);
      }
      final filtered = result.data?.where((p) => p.purchase.supplierKey == supplier.key).toList() ?? [];
      return DatabaseResult.success(filtered);
    } catch (e) {
      return DatabaseResult.failure('Failed to load purchases: $e');
    }
  }

  // ------------------------------
  // Party Balance Calculation
  // ------------------------------

  Future<DatabaseResult<double>> getPartyBalance(Party party) async {
    try {
      final salesResult = await getSalesByParty(party);
      final paymentsResult = await getPaymentsByParty(party);
      final purchasesResult = await getPurchasesBySupplier(party);

      if (!salesResult.success || !paymentsResult.success || !purchasesResult.success) {
        return DatabaseResult.failure(salesResult.error ?? paymentsResult.error ?? purchasesResult.error);
      }

      double totalSales = 0;
      for (final s in salesResult.data ?? []) {
        totalSales += s.sale.amount;
      }

      double totalPurchases = 0;
      for (final p in purchasesResult.data ?? []) {
        totalPurchases += p.purchase.amount;
      }

      double totalPaymentsReceived = 0;
      double totalPaymentsPaid = 0;
      for (final p in paymentsResult.data ?? []) {
        if (p.payment.paymentType == 'received') {
          totalPaymentsReceived += p.payment.amount;
        } else if (p.payment.paymentType == 'paid') {
          totalPaymentsPaid += p.payment.amount;
        }
      }

      double balance = (totalSales - totalPurchases) - (totalPaymentsReceived - totalPaymentsPaid);

      return DatabaseResult.success(balance);
    } catch (e) {
      return DatabaseResult.failure('Failed to calculate balance: $e');
    }
  }

  // ------------------------------
  // Profit Calculation
  // ------------------------------

  Future<DatabaseResult<double>> getDailyProfit(String date) async {
    try {
      final salesResult = await getTotalSalesAmountOnDate(date);
      final expensesResult = await getTotalExpensesOnDate(date);
      if (!salesResult.success || !expensesResult.success) {
        return DatabaseResult.failure(salesResult.error ?? expensesResult.error);
      }
      final profit = (salesResult.data ?? 0) - (expensesResult.data ?? 0);
      return DatabaseResult.success(profit);
    } catch (e) {
      return DatabaseResult.failure('Failed to calculate profit: $e');
    }
  }

  Future<DatabaseResult<Map<String, double>>> getWeeklyStats() async {
    try {
      final now = DateTime.now();
      double totalRevenue = 0;
      double totalExpenses = 0;

      final allSales = await getAllSales();
      if (allSales.success) {
        for (final s in allSales.data ?? []) {
          final saleDate = DateFormat('yyyy-MM-dd').parse(s.sale.saleDate);
          if (saleDate.isAfter(now.subtract(const Duration(days: 7)))) {
            totalRevenue += s.sale.amount;
          }
        }
      }

      final allExpenses = await getAllExpenses();
      if (allExpenses.success) {
        for (final e in allExpenses.data ?? []) {
          final expenseDate = DateFormat('yyyy-MM-dd').parse(e.date);
          if (expenseDate.isAfter(now.subtract(const Duration(days: 7)))) {
            totalExpenses += e.amount;
          }
        }
      }

      return DatabaseResult.success({
        'revenue': totalRevenue,
        'expenses': totalExpenses,
        'profit': totalRevenue - totalExpenses,
      });
    } catch (e) {
      return DatabaseResult.failure('Failed to load stats: $e');
    }
  }

  Future<DatabaseResult<Map<String, double>>> getMonthlyStats() async {
    try {
      final now = DateTime.now();
      double totalRevenue = 0;
      double totalExpenses = 0;

      final allSales = await getAllSales();
      if (allSales.success) {
        for (final s in allSales.data ?? []) {
          final saleDate = DateFormat('yyyy-MM-dd').parse(s.sale.saleDate);
          if (saleDate.year == now.year && saleDate.month == now.month) {
            totalRevenue += s.sale.amount;
          }
        }
      }

      final allExpenses = await getAllExpenses();
      if (allExpenses.success) {
        for (final e in allExpenses.data ?? []) {
          final expenseDate = DateFormat('yyyy-MM-dd').parse(e.date);
          if (expenseDate.year == now.year && expenseDate.month == now.month) {
            totalExpenses += e.amount;
          }
        }
      }

      return DatabaseResult.success({
        'revenue': totalRevenue,
        'expenses': totalExpenses,
        'profit': totalRevenue - totalExpenses,
      });
    } catch (e) {
      return DatabaseResult.failure('Failed to load stats: $e');
    }
  }
}
