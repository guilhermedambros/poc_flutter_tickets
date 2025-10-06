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
    // Agrupa vendas por dia e ticket (sem separar por forma de pagamento na listagem)
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
      print('[RELATORIO VENDA] Relatorio vazio');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma venda encontrada.')));
      return;
    }
    
    print('[RELATORIO VENDA] Verificando conexão...');
    // Verificar se a impressora está conectada
    try {
      final isConnected = await bluetooth.isConnected;
      print('[RELATORIO VENDA] isConnected: $isConnected');
      if (isConnected == null || !isConnected) {
        print('[RELATORIO VENDA] Impressora não conectada');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impressora não conectada. Conecte a impressora nas configurações.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      print('[RELATORIO VENDA] Erro ao verificar conexão: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao verificar conexão com a impressora.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('[RELATORIO VENDA] Impressora conectada, iniciando impressão...');
    try {
      print('[RELATORIO VENDA] Buscando totais por forma de pagamento...');
      // Buscar totais por forma de pagamento do banco
      final db = await AppDatabase.instance.database;
      final totaisPorForma = await db.rawQuery('''
        SELECT 
          v.forma_pagamento,
          SUM(v.amount * COALESCE(v.valor_unitario, 0)) as total
        FROM vendas v
        GROUP BY v.forma_pagamento
      ''');
      
      print('[RELATORIO VENDA] Query retornou ${totaisPorForma.length} linhas');
      for (final row in totaisPorForma) {
        print('[RELATORIO VENDA] Row: $row');
      }
      
      double totalPix = 0;
      double totalDinheiro = 0;
      
      for (final row in totaisPorForma) {
        final formaPagamento = row['forma_pagamento'] as String?;
        final total = row['total'];
        double valor = 0;
        if (total is int) {
          valor = total.toDouble();
        } else if (total is double) {
          valor = total;
        } else if (total is String) {
          valor = double.tryParse(total) ?? 0;
        }
        
        print('[RELATORIO VENDA] forma_pagamento: $formaPagamento, valor: $valor');
        
        if (formaPagamento == 'pix') {
          totalPix = valor;
        } else if (formaPagamento == 'dinheiro') {
          totalDinheiro = valor;
        }
      }
      
      print('[RELATORIO VENDA] Total Pix: R\$ ${totalPix.toStringAsFixed(2)}');
      print('[RELATORIO VENDA] Total Dinheiro: R\$ ${totalDinheiro.toStringAsFixed(2)}');
      
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
      // Linha formatada sem forma de pagamento
      String linha = '${desc ?? ''}  x$total  Vlr: R\$ ${valorUnitarioNum.toStringAsFixed(2)}  Tot: R\$ ${somaReaisNum.toStringAsFixed(2)}';
      print('[RELATORIO VENDA] $linha');
      print("PQP");
      await bluetooth.printCustom(linha, 0, 0);
    }
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.printCustom('------------------------------', 1, 1);
    
    print('[RELATORIO VENDA] Imprimindo totais - Pix: ${totalPix.toStringAsFixed(2)}, Dinheiro: ${totalDinheiro.toStringAsFixed(2)}');
    
    // Mostrar totais por forma de pagamento
    if (totalPix > 0) {
      print('[RELATORIO VENDA] Imprimindo total Pix...');
      await bluetooth.printCustom('TOTAL PIX: R\$ ${totalPix.toStringAsFixed(2)}', 1, 1);
    }
    if (totalDinheiro > 0) {
      print('[RELATORIO VENDA] Imprimindo total Dinheiro...');
      await bluetooth.printCustom('TOTAL DINHEIRO: R\$ ${totalDinheiro.toStringAsFixed(2)}', 1, 1);
    }
    
    // Total geral
    double totalGeral = totalPix + totalDinheiro;
    print('[RELATORIO VENDA] Imprimindo total geral: ${totalGeral.toStringAsFixed(2)}');
    await bluetooth.printCustom('TOTAL GERAL: R\$ ${totalGeral.toStringAsFixed(2)}', 1, 1);
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.paperCut();
    
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relatório impresso!')));
    } catch (e) {
      print('[RELATORIO VENDA] Erro ao imprimir relatório: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao imprimir: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de Vendas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, double>>(
              future: _calcularTotaisPorFormaPagamento(),
              builder: (context, snapshot) {
                final totalPix = snapshot.data?['pix'] ?? 0;
                final totalDinheiro = snapshot.data?['dinheiro'] ?? 0;
                final totalGeral = totalPix + totalDinheiro;
                
                return Column(
                  children: [
                    // Card com totais
                    if (_relatorio.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          children: [
                            if (totalPix > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Pix:', style: TextStyle(fontSize: 16)),
                                  Text('R\$ ${totalPix.toStringAsFixed(2)}', 
                                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            if (totalPix > 0 && totalDinheiro > 0)
                              const SizedBox(height: 4),
                            if (totalDinheiro > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Dinheiro:', style: TextStyle(fontSize: 16)),
                                  Text('R\$ ${totalDinheiro.toStringAsFixed(2)}', 
                                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Geral:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('R\$ ${totalGeral.toStringAsFixed(2)}', 
                                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                                  padding: const EdgeInsets.only(top: 16, bottom: 4, left: 16),
                                  child: Text(
                                    'Vendas do dia ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data!))}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${desc ?? ''} x$total',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${somaReais.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
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
                );
              },
            ),
    );
  }
  
  Future<Map<String, double>> _calcularTotaisPorFormaPagamento() async {
    final db = await AppDatabase.instance.database;
    final totaisPorForma = await db.rawQuery('''
      SELECT 
        v.forma_pagamento,
        SUM(v.amount * COALESCE(v.valor_unitario, 0)) as total
      FROM vendas v
      GROUP BY v.forma_pagamento
    ''');
    
    double totalPix = 0;
    double totalDinheiro = 0;
    
    for (final row in totaisPorForma) {
      final formaPagamento = row['forma_pagamento'] as String?;
      final total = row['total'];
      double valor = 0;
      if (total is int) {
        valor = total.toDouble();
      } else if (total is double) {
        valor = total;
      } else if (total is String) {
        valor = double.tryParse(total) ?? 0;
      }
      
      if (formaPagamento == 'pix') {
        totalPix = valor;
      } else if (formaPagamento == 'dinheiro') {
        totalDinheiro = valor;
      }
    }
    
    return {'pix': totalPix, 'dinheiro': totalDinheiro};
  }
}
