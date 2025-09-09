
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vendasCTG.db');
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
      CREATE TABLE tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description VARCHAR(100) NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE vendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id INTEGER NOT NULL,
        amount INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(ticket_id) REFERENCES tickets(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE Pedidos (
        id_pedido INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER NOT NULL,
        data_pedido DATETIME DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(50) DEFAULT 'Pendente',
        FOREIGN KEY(id_usuario) REFERENCES Usuarios(id_usuario)
      )
    ''');
    // Inserts iniciais para tickets
  await db.insert('tickets', {'description': 'Caipira', 'active': 1});
  await db.insert('tickets', {'description': 'Refri lata', 'active': 1});
  await db.insert('tickets', {'description': 'Refri 600', 'active': 1});
  await db.insert('tickets', {'description': 'Cerveja', 'active': 1});
  await db.insert('tickets', {'description': 'Pastel', 'active': 1});
  await db.insert('tickets', {'description': 'Fritas', 'active': 1});
  await db.insert('tickets', {'description': 'Chocolate', 'active': 1});
  await db.insert('tickets', {'description': 'Tonica lata', 'active': 1});
  await db.insert('tickets', {'description': 'Água', 'active': 1});
  await db.insert('tickets', {'description': 'Refri 2L', 'active': 1});
  await db.insert('tickets', {'description': 'Salgadinho', 'active': 1});
    
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}