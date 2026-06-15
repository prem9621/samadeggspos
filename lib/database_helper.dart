import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DailyRateAdapter());
    Hive.registerAdapter(PartyAdapter());
    Hive.registerAdapter(SaleAdapter());
    await Hive.openBox<DailyRate>('dailyRates');
    await Hive.openBox<Party>('parties');
    await Hive.openBox<Sale>('sales');
  }

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
    final allSales = await getAllSales();
    return allSales.where((s) => s.sale.saleDate == date).toList();
  }

  Future<List<SaleWithParty>> getSalesByParty(Party party) async {
    final allSales = await getAllSales();
    return allSales.where((s) => s.sale.partyKey == party.key).toList();
  }

  Future<double> getTotalEggsSoldOnDate(String date) async {
    final sales = await getSalesByDate(date);
    double total = 0;
    for (var s in sales) {
      total += s.sale.eggQuantity;
    }
    return total;
  }

  Future<double> getTotalSalesAmountOnDate(String date) async {
    final sales = await getSalesByDate(date);
    double total = 0;
    for (var s in sales) {
      total += s.sale.amount;
    }
    return total;
  }
}
