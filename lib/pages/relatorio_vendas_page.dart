import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class RelatorioVendasPage extends StatefulWidget {
  const RelatorioVendasPage({Key? key}) : super(key: key);

  @override
  State<RelatorioVendasPage> createState() => _RelatorioVendasPageState();
}

class _RelatorioVendasPageState extends State<RelatorioVendasPage> {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _relatorio = [];

  @override
  void initState() {
    super.initState();
    _loadRelatorio();
  }

  Future<void> _loadRelatorio() async {
    final db = await AppDatabase.instance.database;
    // Agrupa vendas por dia e ticket
    final result = await db.rawQuery('''
      SELECT 
        DATE(created_at) as data,
        t.description,
        SUM(v.amount) as total
      FROM vendas v
      JOIN tickets t ON t.id = v.ticket_id
      GROUP BY data, t.description
      ORDER BY data DESC, t.description ASC
    ''');
    setState(() {
      _relatorio = result;
      _loading = false;
    });
  }

  Future<void> _imprimirRelatorio() async {
    if (_relatorio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma venda encontrada.')));
      return;
    }
    await bluetooth.printNewLine();
    await bluetooth.printCustom('RELATÓRIO DE VENDAS', 1, 1);
    await bluetooth.printNewLine();
    String? lastDate;
    for (final row in _relatorio) {
      final data = row['data'] as String?;
      final desc = row['description'] as String?;
      final total = row['total'] ?? 0;
      if (data != lastDate) {
        await bluetooth.printNewLine();
        await bluetooth.printCustom('Vendas do dia ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data!))}', 0, 0);
        lastDate = data;
      }
      await bluetooth.printCustom('${desc ?? ''} x$total', 0, 0);
    }
    await bluetooth.printNewLine();
    await bluetooth.paperCut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relatório impresso!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de Vendas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _relatorio.length,
                    itemBuilder: (context, index) {
                      final row = _relatorio[index];
                      final data = row['data'] as String?;
                      final desc = row['description'] as String?;
                      final total = row['total'] ?? 0;
                      final showDate = index == 0 || _relatorio[index - 1]['data'] != data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate)
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 4),
                              child: Text(
                                'Vendas do dia ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data!))}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 2),
                            child: Text('${desc ?? ''} x$total'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir Relatório'),
                      onPressed: _imprimirRelatorio,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
