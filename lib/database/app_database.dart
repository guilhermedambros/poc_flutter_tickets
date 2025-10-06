
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vendasCTG.db');
    
    // Garantir que a coluna txid existe após abrir o banco
    await _ensureTxidColumnExists(_database!);
    
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4, // Incrementa versão para adicionar forma_pagamento
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description VARCHAR(100) NOT NULL,
        valor REAL NOT NULL DEFAULT 0,
        icon VARCHAR(50) DEFAULT 'local_activity',
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
        txid VARCHAR(255), -- ID da transação Pix
        forma_pagamento VARCHAR(50), -- Forma de pagamento: 'pix' ou 'dinheiro'
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
    // Inserts iniciais para tickets (com ícones)
    await db.insert('tickets', {'description': 'Caipira', 'valor': 8, 'icon': 'egg', 'active': 1});
    await db.insert('tickets', {'description': 'Refri lata', 'valor': 5, 'icon': 'local_drink', 'active': 1});
    await db.insert('tickets', {'description': 'Refri 600', 'valor': 8, 'icon': 'local_drink', 'active': 1});
    await db.insert('tickets', {'description': 'Cerveja', 'valor': 8, 'icon': 'sports_bar', 'active': 1});
    await db.insert('tickets', {'description': 'Pastel', 'valor': 10, 'icon': 'lunch_dining', 'active': 1});
    await db.insert('tickets', {'description': 'Fritas', 'valor': 12, 'icon': 'restaurant', 'active': 1});
    await db.insert('tickets', {'description': 'Chocolate', 'valor': 5, 'icon': 'icecream', 'active': 1});
    await db.insert('tickets', {'description': 'Tonica lata', 'valor': 5, 'icon': 'local_drink', 'active': 1});
    await db.insert('tickets', {'description': 'Água', 'valor': 5, 'icon': 'water_drop', 'active': 1});
    await db.insert('tickets', {'description': 'Refri 2L', 'valor': 15, 'icon': 'local_drink', 'active': 1});
    await db.insert('tickets', {'description': 'Salgadinho', 'valor': 7, 'icon': 'fastfood', 'active': 1});
    
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('Fazendo upgrade do banco de dados da versão $oldVersion para $newVersion');
    
    // Adiciona coluna txid se não existir (versão 1 -> 2 ou superior)
    if (oldVersion < 2) {
      try {
        print('Adicionando coluna txid na tabela vendas (upgrade para v2)');
        await db.execute('ALTER TABLE vendas ADD COLUMN txid VARCHAR(255)');
        print('Coluna txid adicionada com sucesso');
      } catch (e) {
        print('Erro ao adicionar coluna txid na v2: $e');
      }
    }
    
    // Garantir que a coluna txid existe (versão 2 -> 3)
    if (oldVersion < 3) {
      try {
        // Verifica se a coluna txid já existe
        final result = await db.rawQuery("PRAGMA table_info(vendas)");
        final hasTxidColumn = result.any((column) => column['name'] == 'txid');
        
        if (!hasTxidColumn) {
          print('Adicionando coluna txid na tabela vendas (upgrade para v3)');
          await db.execute('ALTER TABLE vendas ADD COLUMN txid VARCHAR(255)');
          print('Coluna txid adicionada com sucesso');
        } else {
          print('Coluna txid já existe na tabela vendas');
        }
      } catch (e) {
        print('Erro ao verificar/adicionar coluna txid na v3: $e');
      }
    }
    
    // Adicionar coluna forma_pagamento (versão 3 -> 4)
    if (oldVersion < 4) {
      try {
        // Verifica se a coluna forma_pagamento já existe
        final result = await db.rawQuery("PRAGMA table_info(vendas)");
        final hasFormaPagamentoColumn = result.any((column) => column['name'] == 'forma_pagamento');
        
        if (!hasFormaPagamentoColumn) {
          print('Adicionando coluna forma_pagamento na tabela vendas (upgrade para v4)');
          await db.execute('ALTER TABLE vendas ADD COLUMN forma_pagamento VARCHAR(50)');
          print('Coluna forma_pagamento adicionada com sucesso');
        } else {
          print('Coluna forma_pagamento já existe na tabela vendas');
        }
      } catch (e) {
        print('Erro ao verificar/adicionar coluna forma_pagamento na v4: $e');
      }
    }
  }

  static Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vendasCTG.db');
    print('Deletando banco de dados em: $path');
    await deleteDatabase(path);
    print('Banco de dados deletado');
  }

  static Future<void> resetDatabase() async {
    // Fechar conexão existente se existir
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Deletar o arquivo do banco
    await deleteDatabaseFile();
    
    // A próxima chamada para database criará um novo banco
    print('Banco resetado - próxima chamada criará nova estrutura');
  }

  Future<void> _ensureTxidColumnExists(Database db) async {
    try {
      // Verifica se a coluna txid existe
      final result = await db.rawQuery("PRAGMA table_info(vendas)");
      final hasTxidColumn = result.any((column) => column['name'] == 'txid');
      
      if (!hasTxidColumn) {
        print('Coluna txid não encontrada, adicionando...');
        await db.execute('ALTER TABLE vendas ADD COLUMN txid VARCHAR(255)');
        print('Coluna txid adicionada com sucesso via _ensureTxidColumnExists');
      } else {
        print('Coluna txid já existe na tabela vendas');
      }
    } catch (e) {
      print('Erro ao verificar/adicionar coluna txid: $e');
    }
  }

  Future<void> ensureTxidColumn() async {
    final db = await database;
    try {
      // Verifica se a coluna txid existe
      final result = await db.rawQuery("PRAGMA table_info(vendas)");
      final hasTxidColumn = result.any((column) => column['name'] == 'txid');
      
      if (!hasTxidColumn) {
        print('Coluna txid não encontrada, adicionando...');
        await db.execute('ALTER TABLE vendas ADD COLUMN txid VARCHAR(255)');
        print('Coluna txid adicionada com sucesso');
      }
    } catch (e) {
      print('Erro ao verificar/adicionar coluna txid: $e');
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}