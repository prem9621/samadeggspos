import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('eggs_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        base_rate REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        adjustment_type TEXT NOT NULL DEFAULT '=',
        adjustment_value REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
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
  }

  // FIX: Helper to parse a SaleWithParty from a JOIN row with explicit aliases
  SaleWithParty _parseSaleWithParty(Map<String, dynamic> map) {
    final sale = Sale(
      id: map['s_id'] as int,
      partyId: map['party_id'] as int,
      saleDate: map['sale_date'] as String,
      eggQuantity: (map['egg_quantity'] as num).toDouble(),
      baseRate: (map['base_rate'] as num).toDouble(),
      adjustedRate: (map['adjusted_rate'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
    );

    final party = Party(
      id: map['p_id'] as int,
      name: map['p_name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      adjustmentType: map['adjustment_type'] as String,
      adjustmentValue: (map['adjustment_value'] as num).toDouble(),
    );

    return SaleWithParty(sale: sale, party: party);
  }

  Future<int> insertDailyRate(DailyRate rate) async {
    final db = await instance.database;
    return await db.insert(
      'daily_rates',
      rate.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailyRate?> getDailyRateByDate(String date) async {
    final db = await instance.database;
    final maps = await db.query(
      'daily_rates',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isEmpty) return null;
    return DailyRate.fromMap(maps.first);
  }

  Future<List<DailyRate>> getAllDailyRates() async {
    final db = await instance.database;
    final maps = await db.query('daily_rates', orderBy: 'date DESC');
    return maps.map((e) => DailyRate.fromMap(e)).toList();
  }

  Future<int> insertParty(Party party) async {
    final db = await instance.database;
    return await db.insert('parties', party.toMap());
  }

  Future<int> updateParty(Party party) async {
    final db = await instance.database;
    return await db.update(
      'parties',
      party.toMap(),
      where: 'id = ?',
      whereArgs: [party.id],
    );
  }

  Future<int> deleteParty(int id) async {
    final db = await instance.database;
    return await db.delete(
      'parties',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Party>> getAllParties() async {
    final db = await instance.database;
    final maps = await db.query('parties', orderBy: 'name ASC');
    return maps.map((e) => Party.fromMap(e)).toList();
  }

  Future<Party?> getPartyById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'parties',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Party.fromMap(maps.first);
  }

  Future<int> insertSale(Sale sale) async {
    final db = await instance.database;
    return await db.insert('sales', sale.toMap());
  }

  // FIX: Use explicit column aliases to avoid id/name collision between sales & parties
  Future<List<SaleWithParty>> getAllSales() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        s.id AS s_id, s.party_id, s.sale_date, s.egg_quantity,
        s.base_rate, s.adjusted_rate, s.amount, s.notes,
        p.id AS p_id, p.name AS p_name, p.phone, p.address,
        p.adjustment_type, p.adjustment_value
      FROM sales s
      JOIN parties p ON s.party_id = p.id
      ORDER BY s.sale_date DESC, s.id DESC
    ''');

    return result.map(_parseSaleWithParty).toList();
  }

  Future<List<SaleWithParty>> getSalesByDate(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        s.id AS s_id, s.party_id, s.sale_date, s.egg_quantity,
        s.base_rate, s.adjusted_rate, s.amount, s.notes,
        p.id AS p_id, p.name AS p_name, p.phone, p.address,
        p.adjustment_type, p.adjustment_value
      FROM sales s
      JOIN parties p ON s.party_id = p.id
      WHERE s.sale_date = ?
      ORDER BY s.id DESC
    ''', [date]);

    return result.map(_parseSaleWithParty).toList();
  }

  Future<List<SaleWithParty>> getSalesByParty(int partyId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        s.id AS s_id, s.party_id, s.sale_date, s.egg_quantity,
        s.base_rate, s.adjusted_rate, s.amount, s.notes,
        p.id AS p_id, p.name AS p_name, p.phone, p.address,
        p.adjustment_type, p.adjustment_value
      FROM sales s
      JOIN parties p ON s.party_id = p.id
      WHERE s.party_id = ?
      ORDER BY s.sale_date DESC, s.id DESC
    ''', [partyId]);

    return result.map(_parseSaleWithParty).toList();
  }

  Future<double> getTotalEggsSoldOnDate(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(egg_quantity) as total FROM sales
      WHERE sale_date = ?
    ''', [date]);
    final total = result.first['total'];
    return (total as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalSalesAmountOnDate(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM sales
      WHERE sale_date = ?
    ''', [date]);
    final total = result.first['total'];
    return (total as num?)?.toDouble() ?? 0.0;
  }

  Future<String> backupDatabase() async {
    final dbPath = await getDatabasesPath();
    final sourceFile = File(join(dbPath, 'eggs_pos.db'));
    final externalDir = Directory('/storage/emulated/0/Download');
    final backupFile = File(join(
        externalDir.path,
        'eggs_pos_backup_${DateTime.now().millisecondsSinceEpoch}.db'));
    await sourceFile.copy(backupFile.path);
    return backupFile.path;
  }

  Future<void> restoreDatabase(String backupPath) async {
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