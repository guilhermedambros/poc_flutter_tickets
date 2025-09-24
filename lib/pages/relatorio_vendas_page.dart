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
    // Agrupa vendas por dia e ticket, soma total em reais
    final result = await db.rawQuery('''
      SELECT 
        DATE(v.created_at) as data,
        t.description,
        SUM(v.amount) as total,
        SUM(v.amount * COALESCE(v.valor_unitario, 0)) as soma_reais,
        CASE WHEN SUM(v.amount) > 0 THEN SUM(v.amount * COALESCE(v.valor_unitario, 0)) / SUM(v.amount) ELSE 0 END as valor_unitario_medio
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
  print('[RELATORIO VENDA] _imprimirRelatorio chamado');
    if (_relatorio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma venda encontrada.')));
      return;
    }
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.printCustom('RELATÓRIO DE VENDAS', 1, 1);
    await bluetooth.printCustom('', 1, 1);
    String? lastDate;
    for (final row in _relatorio) {
      final data = row['data'] as String?;
      final desc = row['description'] as String?;
      final total = row['total'] ?? 0;
      var somaReais = row['soma_reais'];
      var valorUnitario = row['valor_unitario_medio'];
      double somaReaisNum;
      double valorUnitarioNum;
      if (somaReais == null) {
        somaReaisNum = 0;
      } else if (somaReais is int) {
        somaReaisNum = somaReais.toDouble();
      } else if (somaReais is double) {
        somaReaisNum = somaReais;
      } else if (somaReais is String) {
        somaReaisNum = double.tryParse(somaReais) ?? 0;
      } else {
        somaReaisNum = 0;
      }
      if (valorUnitario == null) {
        valorUnitarioNum = 0;
      } else if (valorUnitario is int) {
        valorUnitarioNum = valorUnitario.toDouble();
      } else if (valorUnitario is double) {
        valorUnitarioNum = valorUnitario;
      } else if (valorUnitario is String) {
        valorUnitarioNum = double.tryParse(valorUnitario) ?? 0;
      } else {
        valorUnitarioNum = 0;
      }
      if (data != lastDate) {
        await bluetooth.printCustom('', 1, 1);
        await bluetooth.printCustom('Vendas do dia ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data!))}', 0, 0);
        lastDate = data;
      }
      // Linha formatada: Descrição | Qtd | Valor unitário | Valor total
  String linha = '${desc ?? ''}  x$total  Vlr: R\$ ${valorUnitarioNum.toStringAsFixed(2)}  Tot: R\$ ${somaReaisNum.toStringAsFixed(2)}';
  print('[RELATORIO VENDA] $linha');
  await bluetooth.printCustom(linha, 0, 0);
    }
    await bluetooth.printCustom('', 1, 1);
    // Soma total geral
    double totalGeral = 0;
    for (final row in _relatorio) {
      final somaReais = row['soma_reais'] ?? 0;
      if (somaReais is int) {
        totalGeral += somaReais.toDouble();
      } else if (somaReais is double) {
        totalGeral += somaReais;
      } else if (somaReais is String) {
        totalGeral += double.tryParse(somaReais) ?? 0;
      }
    }
    await bluetooth.printCustom('------------------------------', 1, 1);
    await bluetooth.printCustom('TOTAL GERAL: R\$ ${totalGeral.toStringAsFixed(2)}', 1, 1);
    await bluetooth.printCustom('', 1, 1);
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
                      final somaReais = row['soma_reais'] ?? 0;
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
                            child: Text('${desc ?? ''} x$total  R\$ ${somaReais.toStringAsFixed(2)}'),
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
