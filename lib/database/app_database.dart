
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
    await db.insert('tickets', {'description': 'Caipira'});
    await db.insert('tickets', {'description': 'Refri lata'});
    await db.insert('tickets', {'description': 'Refri 600'});
    await db.insert('tickets', {'description': 'Cerveja'});
    await db.insert('tickets', {'description': 'Pastel'});
    await db.insert('tickets', {'description': 'Fritas'});
    await db.insert('tickets', {'description': 'Chocolate'});
    await db.insert('tickets', {'description': 'Tonica lata'});
    await db.insert('tickets', {'description': 'Água'});
    await db.insert('tickets', {'description': 'Refri 2L'});
    await db.insert('tickets', {'description': 'Salgadinho'});
    
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}