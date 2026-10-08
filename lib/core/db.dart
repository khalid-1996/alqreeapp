import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/models.dart';

/// Local SQLite storage: favorites and a JSON response cache.
class AppDb {
  final Database _db;
  AppDb._(this._db);

  static const _version = 1;

  static Future<AppDb> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'alqari.db'),
      version: _version,
      onCreate: (db, version) async {
        await _migrateToV1(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Future migrations go here, one step per version.
      },
    );
    return AppDb._(db);
  }

  static Future<void> _migrateToV1(Database db) async {
    await db.execute('''
      CREATE TABLE favorites (
        key TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        payload TEXT NOT NULL,
        created INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated INTEGER NOT NULL
      )
    ''');
  }

  // Favorites
  Future<List<FavoriteItem>> favorites() async {
    final rows = await _db.query('favorites', orderBy: 'created DESC');
    return rows.map(FavoriteItem.fromRow).toList();
  }

  Future<void> addFavorite(FavoriteItem item) =>
      _db.insert('favorites', item.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> removeFavorite(String key) => _db.delete('favorites', where: 'key = ?', whereArgs: [key]);

  // Cache
  Future<String?> cached(String key) async {
    final rows = await _db.query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<DateTime?> cachedAt(String key) async {
    final rows = await _db.query('cache', columns: ['updated'], where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['updated'] as int);
  }

  Future<void> putCache(String key, String value) => _db.insert(
        'cache',
        {'key': key, 'value': value, 'updated': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
