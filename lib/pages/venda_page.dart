import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class VendaPage extends StatefulWidget {
  const VendaPage({Key? key}) : super(key: key);

  @override
  State<VendaPage> createState() => _VendaPageState();
}

class _VendaPageState extends State<VendaPage> {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<Map<String, dynamic>> tickets = [];
  Map<int, int> quantities = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'tickets',
      where: 'active = ?',
      whereArgs: [1],
      orderBy: 'description COLLATE NOCASE ASC',
    );
    setState(() {
      tickets = result;
      for (var ticket in tickets) {
        quantities[ticket['id'] as int] = 0;
      }
      _loading = false;
    });
  }

  void _increment(int id) {
    setState(() {
      quantities[id] = (quantities[id] ?? 0) + 1;
    });
  }

  void _decrement(int id) {
    setState(() {
      if ((quantities[id] ?? 0) > 0) {
        quantities[id] = (quantities[id] ?? 0) - 1;
      }
    });
  }

  Future<void> _printTickets() async {
  final now = DateTime.now();
  final dataHora = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
    final selected = tickets.where((t) => (quantities[t['id']] ?? 0) > 0).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ao menos um item.')));
      return;
    }
    // Salvar vendas no banco
    final db = await AppDatabase.instance.database;
    for (var ticket in selected) {
      final qtd = quantities[ticket['id']] ?? 0;
      await db.insert('vendas', {
        'ticket_id': ticket['id'],
        'amount': qtd,
        // created_at será preenchido automaticamente
      });
    }
    // Linha superior
    await bluetooth.printCustom('------------------------------', 1, 1);
    await bluetooth.printNewLine();
    for (var ticket in selected) {
      final qtd = quantities[ticket['id']] ?? 0;
      for (int i = 0; i < qtd; i++) {
        await bluetooth.printCustom(
          (ticket['description'] ?? '').toString().toUpperCase(),
          2, // fonte maior
          1  // centralizado
        );
        await bluetooth.printNewLine();
        // Data e hora centralizada, fonte menor
        await bluetooth.printCustom(dataHora, 0, 1);
        await bluetooth.printNewLine();
        await bluetooth.printCustom('------------------------------', 1, 1);
        await bluetooth.printNewLine();
        await bluetooth.printNewLine(); // dobra espaçamento entre tickets
      }
    }
    await bluetooth.paperCut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda salva e impressão enviada!')));
    // Zerar quantidades para nova venda
    setState(() {
      for (var id in quantities.keys) {
        quantities[id] = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Venda')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final qtd = quantities[ticket['id']] ?? 0;
                return ListTile(
                  title: Text(ticket['description'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 32),
                        iconSize: 40,
                        onPressed: () => _decrement(ticket['id'] as int),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('$qtd', style: const TextStyle(fontSize: 20)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 32),
                        iconSize: 40,
                        onPressed: () => _increment(ticket['id'] as int),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _printTickets,
                child: const Text('Imprimir'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
