
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
        valor REAL NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE vendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id INTEGER NOT NULL,
        amount INTEGER,
        valor_unitario REAL NOT NULL DEFAULT 0,
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
  await db.insert('tickets', {'description': 'Caipira', 'valor': 8, 'active': 1});
  await db.insert('tickets', {'description': 'Refri lata', 'valor': 5, 'active': 1});
  await db.insert('tickets', {'description': 'Refri 600', 'valor': 8, 'active': 1});
  await db.insert('tickets', {'description': 'Cerveja', 'valor': 8, 'active': 1});
  await db.insert('tickets', {'description': 'Pastel', 'valor': 10, 'active': 1});
  await db.insert('tickets', {'description': 'Fritas', 'valor': 12, 'active': 1});
  await db.insert('tickets', {'description': 'Chocolate', 'valor': 5, 'active': 1});
  await db.insert('tickets', {'description': 'Tonica lata', 'valor': 5, 'active': 1});
  await db.insert('tickets', {'description': 'Água', 'valor': 5, 'active': 1});
  await db.insert('tickets', {'description': 'Refri 2L', 'valor': 15, 'active': 1});
  await db.insert('tickets', {'description': 'Salgadinho', 'valor': 7, 'active': 1});
    
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}