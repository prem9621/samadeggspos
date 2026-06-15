import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      _database = await _initDB('eggs_pos.db');
      return _database!;
    } catch (e) {
      debugPrint('Database init error: $e');
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    try {
      String path;
      if (kIsWeb) {
        path = filePath; // On web, just use the filename
      } else {
        final dbPath = await getDatabasesPath();
        path = join(dbPath, filePath);
      }

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    } catch (e) {
      debugPrint('InitDB error: $e');
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_rates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          base_rate REAL NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS parties (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          adjustment_type TEXT NOT NULL DEFAULT '=',
          adjustment_value REAL NOT NULL DEFAULT 0.0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          party_id INTEGER NOT NULL,
          sale_date TEXT NOT NULL,
          egg_quantity REAL NOT NULL,
          base_rate REAL NOT NULL,
          adjusted_rate REAL NOT NULL,
          amount REAL NOT NULL,
          notes TEXT,
          FOREIGN KEY (party_id) REFERENCES parties (id)
        )
      ''');
    } catch (e) {
      debugPrint('CreateDB error: $e');
      rethrow;
    }
  }

  Future<int> insertDailyRate(DailyRate rate) async {
    try {
      final db = await instance.database;
      return await db.insert(
        'daily_rates',
        rate.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Insert daily rate error: $e');
      rethrow;
    }
  }

  Future<DailyRate?> getDailyRateByDate(String date) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'daily_rates',
        where: 'date = ?',
        whereArgs: [date],
      );
      if (maps.isEmpty) return null;
      return DailyRate.fromMap(maps.first);
    } catch (e) {
      debugPrint('Get daily rate error: $e');
      return null;
    }
  }

  Future<List<DailyRate>> getAllDailyRates() async {
    try {
      final db = await instance.database;
      final maps = await db.query('daily_rates', orderBy: 'date DESC');
      return maps.map((e) => DailyRate.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Get all daily rates error: $e');
      return [];
    }
  }

  Future<int> insertParty(Party party) async {
    try {
      final db = await instance.database;
      return await db.insert('parties', party.toMap());
    } catch (e) {
      debugPrint('Insert party error: $e');
      rethrow;
    }
  }

  Future<int> updateParty(Party party) async {
    try {
      final db = await instance.database;
      return await db.update(
        'parties',
        party.toMap(),
        where: 'id = ?',
        whereArgs: [party.id],
      );
    } catch (e) {
      debugPrint('Update party error: $e');
      rethrow;
    }
  }

  Future<int> deleteParty(int id) async {
    try {
      final db = await instance.database;
      return await db.delete(
        'parties',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Delete party error: $e');
      rethrow;
    }
  }

  Future<List<Party>> getAllParties() async {
    try {
      final db = await instance.database;
      final maps = await db.query('parties', orderBy: 'name ASC');
      return maps.map((e) => Party.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Get all parties error: $e');
      return [];
    }
  }

  Future<Party?> getPartyById(int id) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'parties',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return Party.fromMap(maps.first);
    } catch (e) {
      debugPrint('Get party by id error: $e');
      return null;
    }
  }

  Future<int> insertSale(Sale sale) async {
    try {
      final db = await instance.database;
      return await db.insert('sales', sale.toMap());
    } catch (e) {
      debugPrint('Insert sale error: $e');
      rethrow;
    }
  }

  Future<List<SaleWithParty>> getAllSales() async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT s.*, p.* FROM sales s
        JOIN parties p ON s.party_id = p.id
        ORDER BY s.sale_date DESC, s.id DESC
      ''');

      List<SaleWithParty> salesWithParties = [];
      for (var map in result) {
        try {
          final sale = Sale(
            id: map['id'] as int,
            partyId: map['party_id'] as int,
            saleDate: map['sale_date'] as String,
            eggQuantity: (map['egg_quantity'] as num?)?.toDouble() ?? 0.0,
            baseRate: (map['base_rate'] as num?)?.toDouble() ?? 0.0,
            adjustedRate: (map['adjusted_rate'] as num?)?.toDouble() ?? 0.0,
            amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
            notes: map['notes'] as String?,
          );

          final party = Party(
            id: map['id:1'] as int,
            name: map['name'] as String,
            phone: map['phone'] as String?,
            address: map['address'] as String?,
            adjustmentType: map['adjustment_type'] as String? ?? '=',
            adjustmentValue: (map['adjustment_value'] as num?)?.toDouble() ?? 0.0,
          );

          salesWithParties.add(SaleWithParty(sale: sale, party: party));
        } catch (e) {
          debugPrint('Parse sale error: $e');
        }
      }
      return salesWithParties;
    } catch (e) {
      debugPrint('Get all sales error: $e');
      return [];
    }
  }

  Future<List<SaleWithParty>> getSalesByDate(String date) async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT s.*, p.* FROM sales s
        JOIN parties p ON s.party_id = p.id
        WHERE s.sale_date = ?
        ORDER BY s.id DESC
      ''', [date]);

      List<SaleWithParty> salesWithParties = [];
      for (var map in result) {
        try {
          final sale = Sale(
            id: map['id'] as int,
            partyId: map['party_id'] as int,
            saleDate: map['sale_date'] as String,
            eggQuantity: (map['egg_quantity'] as num?)?.toDouble() ?? 0.0,
            baseRate: (map['base_rate'] as num?)?.toDouble() ?? 0.0,
            adjustedRate: (map['adjusted_rate'] as num?)?.toDouble() ?? 0.0,
            amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
            notes: map['notes'] as String?,
          );

          final party = Party(
            id: map['id:1'] as int,
            name: map['name'] as String,
            phone: map['phone'] as String?,
            address: map['address'] as String?,
            adjustmentType: map['adjustment_type'] as String? ?? '=',
            adjustmentValue: (map['adjustment_value'] as num?)?.toDouble() ?? 0.0,
          );

          salesWithParties.add(SaleWithParty(sale: sale, party: party));
        } catch (e) {
          debugPrint('Parse sale error: $e');
        }
      }
      return salesWithParties;
    } catch (e) {
      debugPrint('Get sales by date error: $e');
      return [];
    }
  }

  Future<List<SaleWithParty>> getSalesByParty(int partyId) async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT s.*, p.* FROM sales s
        JOIN parties p ON s.party_id = p.id
        WHERE s.party_id = ?
        ORDER BY s.sale_date DESC, s.id DESC
      ''', [partyId]);

      List<SaleWithParty> salesWithParties = [];
      for (var map in result) {
        try {
          final sale = Sale(
            id: map['id'] as int,
            partyId: map['party_id'] as int,
            saleDate: map['sale_date'] as String,
            eggQuantity: (map['egg_quantity'] as num?)?.toDouble() ?? 0.0,
            baseRate: (map['base_rate'] as num?)?.toDouble() ?? 0.0,
            adjustedRate: (map['adjusted_rate'] as num?)?.toDouble() ?? 0.0,
            amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
            notes: map['notes'] as String?,
          );

          final party = Party(
            id: map['id:1'] as int,
            name: map['name'] as String,
            phone: map['phone'] as String?,
            address: map['address'] as String?,
            adjustmentType: map['adjustment_type'] as String? ?? '=',
            adjustmentValue: (map['adjustment_value'] as num?)?.toDouble() ?? 0.0,
          );

          salesWithParties.add(SaleWithParty(sale: sale, party: party));
        } catch (e) {
          debugPrint('Parse sale error: $e');
        }
      }
      return salesWithParties;
    } catch (e) {
      debugPrint('Get sales by party error: $e');
      return [];
    }
  }

  // FIX: SUM() can return either int or double depending on the data,
  // so cast through `num` first and convert to double safely.
  Future<double> getTotalEggsSoldOnDate(String date) async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT SUM(egg_quantity) as total FROM sales
        WHERE sale_date = ?
      ''', [date]);
      final total = result.first['total'] as num?;
      return total?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Get total eggs sold error: $e');
      return 0.0;
    }
  }

  // FIX: same as above — avoid `as double?` cast which throws on int results.
  Future<double> getTotalSalesAmountOnDate(String date) async {
    try {
      final db = await instance.database;
      final result = await db.rawQuery('''
        SELECT SUM(amount) as total FROM sales
        WHERE sale_date = ?
      ''', [date]);
      final total = result.first['total'] as num?;
      return total?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Get total sales amount error: $e');
      return 0.0;
    }
  }

  // FIX: file-based backup/restore can't work on web (no dart:io filesystem).
  Future<String> backupDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Backup to file is not available on the web version. '
          'This feature requires the Android/iOS/desktop app.');
    }
    final dbPath = await getDatabasesPath();
    final sourceFile = File(join(dbPath, 'eggs_pos.db'));
    final externalDir = Directory('/storage/emulated/0/Download');
    final backupFile = File(join(externalDir.path, 'eggs_pos_backup_${DateTime.now().millisecondsSinceEpoch}.db'));
    await sourceFile.copy(backupFile.path);
    return backupFile.path;
  }

  Future<void> restoreDatabase(String backupPath) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Restore from file is not available on the web version. '
          'This feature requires the Android/iOS/desktop app.');
    }
    final dbPath = await getDatabasesPath();
    final targetFile = File(join(dbPath, 'eggs_pos.db'));
    final backupFile = File(backupPath);
    await backupFile.copy(targetFile.path);
    _database = null;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}