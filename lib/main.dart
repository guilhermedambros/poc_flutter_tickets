
import 'package:flutter/material.dart';

import 'pages/settings_page.dart';

import 'pages/venda_page.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'database/app_database.dart';
import 'pages/crud_tickets_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tickets Printer',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Impressão de Tickets - CTG'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  Future<void> _selecionarDatasEImprimirRelatorio() async {
    final db = await AppDatabase.instance.database;
    // Buscar todas as datas distintas com vendas
    final datasResult = await db.rawQuery('''
      SELECT DISTINCT DATE(created_at) as data
      FROM vendas
      ORDER BY data DESC
    ''');
    if (datasResult.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma venda encontrada.')));
      return;
    }
    List<String> datas = datasResult.map((row) => row['data'] as String).toList();
    List<String> selecionadas = [];

    // Exibir modal de seleção
    final selecionadasResult = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecione os dias para o relatório'),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setState) {
                bool todosSelecionados = selecionadas.length == datas.length;
                return ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('Selecionar todos'),
                      value: todosSelecionados,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selecionadas = List.from(datas);
                          } else {
                            selecionadas.clear();
                          }
                        });
                      },
                    ),
                    ...datas.map((data) {
                      final selecionada = selecionadas.contains(data);
                      return CheckboxListTile(
                        title: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(data))),
                        value: selecionada,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selecionadas.add(data);
                            } else {
                              selecionadas.remove(data);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selecionadas),
              child: const Text('Imprimir'),
            ),
          ],
        );
      },
    );
    if (selecionadasResult == null || selecionadasResult.isEmpty) {
      return;
    }
    await _imprimirRelatorioVendas(datasSelecionadas: selecionadasResult);
  }

  Future<void> _imprimirRelatorioVendas({List<String>? datasSelecionadas}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final db = await AppDatabase.instance.database;
    final bluetooth = BlueThermalPrinter.instance;
    // Adiciona filtro de datas se necessário
    String whereDatas = '';
    List<dynamic> whereArgs = [];
    if (datasSelecionadas != null && datasSelecionadas.isNotEmpty) {
      whereDatas = 'WHERE DATE(v.created_at) IN (${List.filled(datasSelecionadas.length, '?').join(',')})';
      whereArgs = datasSelecionadas;
    }
    final relatorio = await db.rawQuery('''
      SELECT 
        DATE(v.created_at) as data,
        t.description,
        SUM(v.amount) as total,
        SUM(v.amount * COALESCE(v.valor_unitario, 0)) as soma_reais,
        CASE WHEN SUM(v.amount) > 0 THEN SUM(v.amount * COALESCE(v.valor_unitario, 0)) / SUM(v.amount) ELSE 0 END as valor_unitario_medio
      FROM vendas v
      JOIN tickets t ON t.id = v.ticket_id
      $whereDatas
      GROUP BY data, t.description
      ORDER BY data DESC, t.description ASC
    ''', whereArgs);
    if (relatorio.isEmpty) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma venda encontrada.')));
      return;
    }
    await bluetooth.printCustom('RELATÓRIO DE VENDAS', 1, 1);
    await bluetooth.printNewLine();
    String? lastDate;
    double totalGeral = 0;
    double totalDia = 0;
    for (final row in relatorio) {
      final data = row['data'] as String?;
      final desc = row['description'] as String?;
      final quantidade = row['total'] ?? 0;
      var somaReais = row['soma_reais'];
      double somaReaisNum;
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
      if (data != lastDate && lastDate != null) {
        // Imprime total do dia anterior
        await bluetooth.printCustom('------------------------------', 0, 0);
        await bluetooth.printCustom('TOTAL DO DIA: R\$ ' + totalDia.toStringAsFixed(2), 0, 0);
        await bluetooth.printNewLine();
        totalDia = 0;
      }
      if (data != lastDate) {
        await bluetooth.printNewLine();
        await bluetooth.printCustom('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data!))}', 0, 0);
        await bluetooth.printCustom('------------------------------', 0, 0);
        lastDate = data;
      }
      // Linha: descrição, quantidade, valor total
      final line = '${(desc ?? '').padRight(12).substring(0, 12)} ${quantidade.toString().padLeft(2)}  R\$ ${somaReaisNum.toStringAsFixed(2).padLeft(2)}';
      print('[RELATORIO VENDA] $line');
      await bluetooth.printCustom(line, 0, 0);
      totalGeral += somaReaisNum;
      totalDia += somaReaisNum;
    }
    // Imprime total do último dia
    await bluetooth.printCustom('------------------------------', 0, 0);
    await bluetooth.printCustom('TOTAL DO DIA: R\$ ' + totalDia.toStringAsFixed(2), 0, 0);
    await bluetooth.printNewLine();
    // Imprime total geral ao final
    await bluetooth.printCustom('------------------------------', 0, 0);
    await bluetooth.printCustom('TOTAL GERAL: R\$ ${totalGeral.toStringAsFixed(2)}', 0, 0);
    await bluetooth.printNewLine();
    await bluetooth.paperCut();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relatório impresso!')));
  }
  // Nenhuma funcionalidade padrão

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart, size: 36),
                  label: const Text(
                    'Venda',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VendaPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 28),
                  label: const Text(
                    'Gerenciar Tickets',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CrudTicketsPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart, size: 28),
                  label: const Text(
                    'Relatório de Vendas',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: _selecionarDatasEImprimirRelatorio,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
