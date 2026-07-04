import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

/// Result wrapper matching DatabaseHelper's DatabaseResult pattern, so
/// every screen consuming this file can use the same success/error UI.
class StatsResult<T> {
  final T? data;
  final String? error;
  final bool success;

  StatsResult.success(this.data) : error = null, success = true;
  StatsResult.failure(this.error) : data = null, success = false;
}

/// One entry in a Top Parties ranking list.
class PartyRanked {
  final Party party;
  final double totalAmount; // total sale/purchase amount with this party
  final double totalQuantity; // total eggs sold/purchased

  PartyRanked({
    required this.party,
    required this.totalAmount,
    required this.totalQuantity,
  });
}

/// One entry in the Pending Dues list — a party with a non-zero balance,
/// plus the date of their oldest unsettled activity so the list can be
/// sorted "oldest pending first".
class PendingDue {
  final Party party;
  final double balance; // same sign convention as DatabaseHelper.getPartyBalance
  final DateTime oldestActivity;

  PendingDue({
    required this.party,
    required this.balance,
    required this.oldestActivity,
  });
}

/// One point on the last-30-days trend line.
class TrendPoint {
  final DateTime date;
  final double salesAmount;
  final double purchaseAmount;
  final double eggsSold;

  TrendPoint({
    required this.date,
    required this.salesAmount,
    required this.purchaseAmount,
    required this.eggsSold,
  });
}

/// Business-intelligence calculations for the dashboard. Every method
/// here does a single pass over the relevant Hive box(es) — no
/// per-party or per-day repeated fetching — so this stays fast even as
/// data grows. Mirrors the DatabaseResult/error-handling style already
/// used throughout database_helper.dart.
class StatsHelper {
  static final StatsHelper instance = StatsHelper._init();
  StatsHelper._init();

  final _dateFmt = DateFormat('yyyy-MM-dd');

  // ------------------------------
  // Current Stock
  // ------------------------------

  /// Current egg stock = total ever purchased − total ever sold.
  /// Single pass over each box.
  Future<StatsResult<double>> getCurrentStock() async {
    try {
      final saleBox = await Hive.openBox<Sale>(DatabaseHelper.boxSales);
      final purchaseBox =
          await Hive.openBox<Purchase>(DatabaseHelper.boxPurchases);

      double totalSold = 0;
      for (final s in saleBox.values) {
        totalSold += s.eggQuantity;
      }

      double totalPurchased = 0;
      for (final p in purchaseBox.values) {
        totalPurchased += p.eggQuantity;
      }

      return StatsResult.success(totalPurchased - totalSold);
    } catch (e) {
      return StatsResult.failure('Failed to calculate stock: $e');
    }
  }

  // ------------------------------
  // Profit & Loss (date range)
  // ------------------------------

  /// Profit-loss between [from] and [to] (inclusive), single pass over
  /// sales, purchases, and expenses boxes filtered by date string.
  Future<StatsResult<Map<String, double>>> getProfitLossRange(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final fromStr = _dateFmt.format(from);
      final toStr = _dateFmt.format(to);

      final saleBox = await Hive.openBox<Sale>(DatabaseHelper.boxSales);
      final purchaseBox =
          await Hive.openBox<Purchase>(DatabaseHelper.boxPurchases);
      final expenseBox =
          await Hive.openBox<Expense>(DatabaseHelper.boxExpenses);

      double totalSales = 0;
      for (final s in saleBox.values) {
        if (s.saleDate.compareTo(fromStr) >= 0 &&
            s.saleDate.compareTo(toStr) <= 0) {
          totalSales += s.amount;
        }
      }

      double totalPurchases = 0;
      for (final p in purchaseBox.values) {
        if (p.purchaseDate.compareTo(fromStr) >= 0 &&
            p.purchaseDate.compareTo(toStr) <= 0) {
          totalPurchases += p.amount;
        }
      }

      double totalExpenses = 0;
      for (final e in expenseBox.values) {
        if (e.date.compareTo(fromStr) >= 0 && e.date.compareTo(toStr) <= 0) {
          totalExpenses += e.amount;
        }
      }

      final profit = totalSales - totalPurchases - totalExpenses;

      return StatsResult.success({
        'totalSales': totalSales,
        'totalPurchases': totalPurchases,
        'totalExpenses': totalExpenses,
        'profit': profit,
      });
    } catch (e) {
      return StatsResult.failure('Failed to calculate profit/loss: $e');
    }
  }

  /// Convenience: today's profit-loss.
  Future<StatsResult<Map<String, double>>> getTodayProfitLoss() {
    final today = DateTime.now();
    return getProfitLossRange(today, today);
  }

  /// Convenience: current month's profit-loss.
  Future<StatsResult<Map<String, double>>> getThisMonthProfitLoss() {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    return getProfitLossRange(firstOfMonth, now);
  }

  // ------------------------------
  // Top Parties (by business volume)
  // ------------------------------

  /// Top [limit] parties of [type] ranked by total transaction amount.
  /// For customers this ranks by total sale amount; for suppliers by
  /// total purchase amount. Single pass over the relevant box, then
  /// one pass over parties to sort — no repeated per-party queries.
  Future<StatsResult<List<PartyRanked>>> getTopParties({
    required PartyType type,
    int limit = 5,
  }) async {
    try {
      final partyBox = await Hive.openBox<Party>(DatabaseHelper.boxParties);
      final Map<dynamic, double> amountByKey = {};
      final Map<dynamic, double> quantityByKey = {};

      if (type == PartyType.customer) {
        final saleBox = await Hive.openBox<Sale>(DatabaseHelper.boxSales);
        for (final s in saleBox.values) {
          amountByKey[s.partyKey] = (amountByKey[s.partyKey] ?? 0) + s.amount;
          quantityByKey[s.partyKey] =
              (quantityByKey[s.partyKey] ?? 0) + s.eggQuantity;
        }
      } else {
        final purchaseBox =
            await Hive.openBox<Purchase>(DatabaseHelper.boxPurchases);
        for (final p in purchaseBox.values) {
          amountByKey[p.supplierKey] =
              (amountByKey[p.supplierKey] ?? 0) + p.amount;
          quantityByKey[p.supplierKey] =
              (quantityByKey[p.supplierKey] ?? 0) + p.eggQuantity;
        }
      }

      final ranked = <PartyRanked>[];
      for (final entry in amountByKey.entries) {
        final party = partyBox.get(entry.key);
        if (party != null && party.type == type) {
          ranked.add(PartyRanked(
            party: party,
            totalAmount: entry.value,
            totalQuantity: quantityByKey[entry.key] ?? 0,
          ));
        }
      }

      ranked.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      final top = ranked.take(limit).toList();

      return StatsResult.success(top);
    } catch (e) {
      return StatsResult.failure('Failed to load top parties: $e');
    }
  }

  // ------------------------------
  // Pending Dues (all parties, oldest first)
  // ------------------------------

  /// Every party with a non-zero balance, sorted with the oldest
  /// unsettled activity first. Reuses the same accumulation approach
  /// as DatabaseHelper.getAllPartyBalances (one pass per box) and adds
  /// oldest-activity tracking in the same passes.
  Future<StatsResult<List<PendingDue>>> getPendingDues() async {
    try {
      final partyBox = await Hive.openBox<Party>(DatabaseHelper.boxParties);
      final saleBox = await Hive.openBox<Sale>(DatabaseHelper.boxSales);
      final purchaseBox =
          await Hive.openBox<Purchase>(DatabaseHelper.boxPurchases);
      final paymentBox =
          await Hive.openBox<Payment>(DatabaseHelper.boxPayments);

      final Map<dynamic, double> balances = {};
      final Map<dynamic, DateTime> oldestActivity = {};

      void trackOldest(dynamic key, DateTime date) {
        final existing = oldestActivity[key];
        if (existing == null || date.isBefore(existing)) {
          oldestActivity[key] = date;
        }
      }

      for (final sale in saleBox.values) {
        balances[sale.partyKey] = (balances[sale.partyKey] ?? 0) + sale.amount;
        trackOldest(sale.partyKey, sale.createdAt);
      }
      for (final purchase in purchaseBox.values) {
        balances[purchase.supplierKey] =
            (balances[purchase.supplierKey] ?? 0) - purchase.amount;
        trackOldest(purchase.supplierKey, purchase.createdAt);
      }
      for (final payment in paymentBox.values) {
        final delta = payment.paymentType == 'received'
            ? -payment.amount
            : payment.amount;
        balances[payment.partyKey] =
            (balances[payment.partyKey] ?? 0) + delta;
        trackOldest(payment.partyKey, payment.createdAt);
      }

      final dues = <PendingDue>[];
      for (final entry in balances.entries) {
        if (entry.value.abs() < 0.01) continue; // settled, skip
        final party = partyBox.get(entry.key);
        if (party == null) continue;
        dues.add(PendingDue(
          party: party,
          balance: entry.value,
          oldestActivity: oldestActivity[entry.key] ?? DateTime.now(),
        ));
      }

      // Oldest pending activity first.
      dues.sort((a, b) => a.oldestActivity.compareTo(b.oldestActivity));

      return StatsResult.success(dues);
    } catch (e) {
      return StatsResult.failure('Failed to load pending dues: $e');
    }
  }

  // ------------------------------
  // Last 30 Days Trend
  // ------------------------------

  /// Sales/purchase trend for the last [days] days (default 30),
  /// oldest to newest, one point per calendar day — including days
  /// with zero activity so the chart has a continuous x-axis. Single
  /// pass over each box, grouped by date string into a map, then
  /// walked day-by-day to fill gaps.
  Future<StatsResult<List<TrendPoint>>> getRecentTrend({int days = 30}) async {
    try {
      final saleBox = await Hive.openBox<Sale>(DatabaseHelper.boxSales);
      final purchaseBox =
          await Hive.openBox<Purchase>(DatabaseHelper.boxPurchases);

      final Map<String, double> salesByDate = {};
      final Map<String, double> eggsByDate = {};
      final Map<String, double> purchasesByDate = {};

      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: days - 1));
      final cutoffStr = _dateFmt.format(DateTime(cutoff.year, cutoff.month, cutoff.day));

      for (final s in saleBox.values) {
        if (s.saleDate.compareTo(cutoffStr) >= 0) {
          salesByDate[s.saleDate] = (salesByDate[s.saleDate] ?? 0) + s.amount;
          eggsByDate[s.saleDate] = (eggsByDate[s.saleDate] ?? 0) + s.eggQuantity;
        }
      }
      for (final p in purchaseBox.values) {
        if (p.purchaseDate.compareTo(cutoffStr) >= 0) {
          purchasesByDate[p.purchaseDate] =
              (purchasesByDate[p.purchaseDate] ?? 0) + p.amount;
        }
      }

      final points = <TrendPoint>[];
      for (int i = days - 1; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayOnly = DateTime(day.year, day.month, day.day);
        final key = _dateFmt.format(dayOnly);
        points.add(TrendPoint(
          date: dayOnly,
          salesAmount: salesByDate[key] ?? 0,
          purchaseAmount: purchasesByDate[key] ?? 0,
          eggsSold: eggsByDate[key] ?? 0,
        ));
      }

      return StatsResult.success(points);
    } catch (e) {
      return StatsResult.failure('Failed to load trend: $e');
    }
  }
}