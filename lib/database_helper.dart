import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DailyRateAdapter());
    Hive.registerAdapter(PartyAdapter());
    Hive.registerAdapter(SaleAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(PaymentAdapter());
    await Hive.openBox<DailyRate>('dailyRates');
    await Hive.openBox<Party>('parties');
    await Hive.openBox<Sale>('sales');
    await Hive.openBox<Expense>('expenses');
    await Hive.openBox<Payment>('payments');
  }

  // Daily Rates

  Future<void> insertDailyRate(DailyRate rate) async {
    final box = await Hive.openBox<DailyRate>('dailyRates');
    await box.put(rate.date, rate);
  }

  Future<DailyRate?> getDailyRateByDate(String date) async {
    final box = await Hive.openBox<DailyRate>('dailyRates');
    return box.get(date);
  }

  Future<List<DailyRate>> getAllDailyRates() async {
    final box = await Hive.openBox<DailyRate>('dailyRates');
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // Parties

  Future<void> insertParty(Party party) async {
    final box = await Hive.openBox<Party>('parties');
    await box.add(party);
  }

  Future<void> updateParty(Party party) async {
    await party.save();
  }

  Future<void> deleteParty(Party party) async {
    await party.delete();
  }

  Future<List<Party>> getAllParties() async {
    final box = await Hive.openBox<Party>('parties');
    return box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<Party>> searchParties(String query) async {
    final all = await getAllParties();
    return all
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Sales

  Future<void> insertSale(Sale sale) async {
    final box = await Hive.openBox<Sale>('sales');
    await box.add(sale);
  }

  Future<List<SaleWithParty>> getAllSales() async {
    final saleBox = await Hive.openBox<Sale>('sales');
    final partyBox = await Hive.openBox<Party>('parties');

    List<SaleWithParty> result = [];
    for (var sale in saleBox.values) {
      final party = partyBox.getAt(sale.partyKey);
      if (party != null) {
        result.add(SaleWithParty(sale: sale, party: party));
      }
    }
    result.sort((a, b) => b.sale.saleDate.compareTo(a.sale.saleDate));
    return result;
  }

  Future<List<SaleWithParty>> getSalesByDate(String date) async {
    final all = await getAllSales();
    return all.where((s) => s.sale.saleDate == date).toList();
  }

  Future<List<SaleWithParty>> getSalesByParty(Party party) async {
    final all = await getAllSales();
    return all.where((s) => s.sale.partyKey == party.key).toList();
  }

  Future<List<SaleWithParty>> getSalesBetweenDates(String startDate, String endDate) async {
    final all = await getAllSales();
    return all.where((s) =>
        s.sale.saleDate.compareTo(startDate) >= 0 &&
        s.sale.saleDate.compareTo(endDate) <= 0).toList();
  }

  Future<double> getTotalEggsSoldOnDate(String date) async {
    final sales = await getSalesByDate(date);
    double total = 0;
    for (var s in sales) total += s.sale.eggQuantity;
    return total;
  }

  Future<double> getTotalSalesAmountOnDate(String date) async {
    final sales = await getSalesByDate(date);
    double total = 0;
    for (var s in sales) total += s.sale.amount;
    return total;
  }

  // Expenses

  Future<void> insertExpense(Expense expense) async {
    final box = await Hive.openBox<Expense>('expenses');
    await box.add(expense);
  }

  Future<List<Expense>> getAllExpenses() async {
    final box = await Hive.openBox<Expense>('expenses');
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<Expense>> getExpensesByDate(String date) async {
    final all = await getAllExpenses();
    return all.where((e) => e.date == date).toList();
  }

  Future<List<Expense>> getExpensesBetweenDates(String startDate, String endDate) async {
    final all = await getAllExpenses();
    return all.where((e) =>
        e.date.compareTo(startDate) >= 0 &&
        e.date.compareTo(endDate) <= 0).toList();
  }

  Future<double> getTotalExpensesOnDate(String date) async {
    final expenses = await getExpensesByDate(date);
    double total = 0;
    for (var e in expenses) total += e.amount;
    return total;
  }

  // Payments

  Future<void> insertPayment(Payment payment) async {
    final box = await Hive.openBox<Payment>('payments');
    await box.add(payment);
  }

  Future<List<PaymentWithParty>> getAllPayments() async {
    final paymentBox = await Hive.openBox<Payment>('payments');
    final partyBox = await Hive.openBox<Party>('parties');

    List<PaymentWithParty> result = [];
    for (var payment in paymentBox.values) {
      final party = partyBox.getAt(payment.partyKey);
      if (party != null) {
        result.add(PaymentWithParty(payment: payment, party: party));
      }
    }
    result.sort((a, b) => b.payment.date.compareTo(a.payment.date));
    return result;
  }

  Future<List<PaymentWithParty>> getPaymentsByParty(Party party) async {
    final all = await getAllPayments();
    return all.where((p) => p.payment.partyKey == party.key).toList();
  }

  Future<double> getPartyBalance(Party party) async {
    final sales = await getSalesByParty(party);
    final payments = await getPaymentsByParty(party);

    double totalSales = 0;
    for (var s in sales) totalSales += s.sale.amount;

    double totalPayments = 0;
    for (var p in payments) totalPayments += p.payment.amount;

    return totalSales - totalPayments;
  }

  // Profit Calculations

  Future<double> getDailyProfit(String date) async {
    final revenue = await getTotalSalesAmountOnDate(date);
    final expenses = await getTotalExpensesOnDate(date);
    return revenue - expenses;
  }

  Future<Map<String, dynamic>> getWeeklyStats() async {
    final now = DateTime.now();
    final startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
    final endDate = DateFormat('yyyy-MM-dd').format(now);

    final sales = await getSalesBetweenDates(startDate, endDate);
    final expenses = await getExpensesBetweenDates(startDate, endDate);

    double totalRevenue = 0;
    double totalExpenses = 0;

    for (var s in sales) totalRevenue += s.sale.amount;
    for (var e in expenses) totalExpenses += e.amount;

    return {
      'revenue': totalRevenue,
      'expenses': totalExpenses,
      'profit': totalRevenue - totalExpenses,
    };
  }

  Future<Map<String, dynamic>> getMonthlyStats() async {
    final now = DateTime.now();
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final endDate = DateFormat('yyyy-MM-dd').format(now);

    final sales = await getSalesBetweenDates(startDate, endDate);
    final expenses = await getExpensesBetweenDates(startDate, endDate);

    double totalRevenue = 0;
    double totalExpenses = 0;

    for (var s in sales) totalRevenue += s.sale.amount;
    for (var e in expenses) totalExpenses += e.amount;

    return {
      'revenue': totalRevenue,
      'expenses': totalExpenses,
      'profit': totalRevenue - totalExpenses,
    };
  }
}
