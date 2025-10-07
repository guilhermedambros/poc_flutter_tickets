import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../utils/pix_qr_generator.dart';

class VendaPage extends StatefulWidget {
  const VendaPage({Key? key}) : super(key: key);

  @override
  State<VendaPage> createState() => _VendaPageState();
}

class _VendaPageState extends State<VendaPage> {
  // Dados Pix para geração do QR Code (carregados das configurações)
  String _pixChave = '';
  String _pixNome = '';
  String _pixCidade = '';
  String _pixDescricao = '';
  String? _pixPayload;
  String? _currentTxid; // Armazena o txid atual
  
  // Remove acentos para impressão térmica
  String _removerAcentos(String s) {
    return s
      .replaceAll(RegExp(r'[ÁÀÂÃÄ]'), 'A')
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[ÓÒÔÕÖ]'), 'O')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[Ç]'), 'C')
      .replaceAll(RegExp(r'[ç]'), 'c');
  }
  final List<Map<String, dynamic>> _iconOptions = [
    {'icon': Icons.local_activity, 'name': 'local_activity'},
    {'icon': Icons.egg, 'name': 'egg'},
    {'icon': Icons.local_drink, 'name': 'local_drink'},
    {'icon': Icons.sports_bar, 'name': 'sports_bar'},
    {'icon': Icons.lunch_dining, 'name': 'lunch_dining'},
    {'icon': Icons.restaurant, 'name': 'restaurant'},
    {'icon': Icons.icecream, 'name': 'icecream'},
    {'icon': Icons.water_drop, 'name': 'water_drop'},
    {'icon': Icons.fastfood, 'name': 'fastfood'},
    {'icon': Icons.cake, 'name': 'cake'},
    {'icon': Icons.local_cafe, 'name': 'local_cafe'},
    {'icon': Icons.local_pizza, 'name': 'local_pizza'},
    {'icon': Icons.local_bar, 'name': 'local_bar'},
    {'icon': Icons.emoji_food_beverage, 'name': 'emoji_food_beverage'},
    {'icon': Icons.emoji_events, 'name': 'emoji_events'},
    {'icon': Icons.emoji_nature, 'name': 'emoji_nature'},
    {'icon': Icons.emoji_people, 'name': 'emoji_people'},
    {'icon': Icons.emoji_symbols, 'name': 'emoji_symbols'},
    {'icon': Icons.emoji_transportation, 'name': 'emoji_transportation'},
    {'icon': Icons.local_dining, 'name': 'local_dining'},
    {'icon': Icons.ramen_dining, 'name': 'ramen_dining'},
    {'icon': Icons.set_meal, 'name': 'set_meal'},
    {'icon': Icons.bakery_dining, 'name': 'bakery_dining'},
    {'icon': Icons.brunch_dining, 'name': 'brunch_dining'},
    {'icon': Icons.dinner_dining, 'name': 'dinner_dining'},
    {'icon': Icons.wine_bar, 'name': 'wine_bar'},
    {'icon': Icons.celebration, 'name': 'celebration'},
    {'icon': Icons.coffee, 'name': 'coffee'},
    {'icon': Icons.icecream_outlined, 'name': 'icecream_outlined'},
    {'icon': Icons.cookie, 'name': 'cookie'},
    {'icon': Icons.soup_kitchen, 'name': 'soup_kitchen'},
    {'icon': Icons.bubble_chart, 'name': 'bubble_chart'},
    {'icon': Icons.casino, 'name': 'casino'},
    {'icon': Icons.sports_esports, 'name': 'sports_esports'},
    {'icon': Icons.music_note, 'name': 'music_note'},
    {'icon': Icons.star, 'name': 'star'},
    {'icon': Icons.local_florist, 'name': 'local_florist'},
    {'icon': Icons.shopping_basket, 'name': 'shopping_basket'},
    {'icon': Icons.shopping_cart, 'name': 'shopping_cart'},
    {'icon': Icons.card_giftcard, 'name': 'card_giftcard'},
    {'icon': Icons.attach_money, 'name': 'attach_money'},
    {'icon': Icons.monetization_on, 'name': 'monetization_on'},
  ];

  Future<List<int>> _carregarFontesImpressao() async {
    // [desc, valor, hora]
    final prefs = await SharedPreferences.getInstance();
    return [
      prefs.getInt('font_ticket_desc') ?? 2,
      prefs.getInt('font_ticket_valor') ?? 0,
      prefs.getInt('font_ticket_hora') ?? 0,
    ];
  }

  Future<void> _carregarConfiguracoesPix() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pixChave = prefs.getString('pix_chave') ?? '99921004000199';
      _pixNome = prefs.getString('pix_nome') ?? 'NOME DA EMPRESA';
      _pixCidade = prefs.getString('pix_cidade') ?? 'CIDADE';
      _pixDescricao = prefs.getString('pix_descricao') ?? 'Pagamento de venda';
    });
  }

  Future<void> _mostrarUltimaVenda(BuildContext context) async {
    final db = await AppDatabase.instance.database;
    // Busca a data/hora da última venda
    final ultimaVendaResult = await db.rawQuery('''
      SELECT MAX(created_at) as data
      FROM vendas
    ''');
    if (ultimaVendaResult.isEmpty || ultimaVendaResult.first['data'] == null) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Última venda'),
          content: Text('Nenhuma venda encontrada.'),
        ),
      );
      return;
    }
    final dataUltimaVenda = ultimaVendaResult.first['data'] as String;
    // Busca os itens da última venda
    final itens = await db.rawQuery('''
      SELECT t.description, v.amount, v.valor_unitario
      FROM vendas v
      JOIN tickets t ON t.id = v.ticket_id
      WHERE v.created_at = ?
    ''', [dataUltimaVenda]);
    double total = 0;
    for (var item in itens) {
      final qtd = item['amount'] ?? 0;
      final valor = item['valor_unitario'] ?? 0;
      total += (qtd is int ? qtd : int.tryParse(qtd.toString()) ?? 0) * (valor is num ? valor : double.tryParse(valor.toString()) ?? 0);
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Última venda realizada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data/hora: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dataUltimaVenda))}'),
            const SizedBox(height: 12),
            ...itens.map((item) => Text(
              '${item['description']}  x${item['amount']}  R\$ ${(item['valor_unitario'] as num).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            )),
            const SizedBox(height: 12),
            Text('Total: R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<Map<String, dynamic>> tickets = [];
  Map<int, int> quantities = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _carregarConfiguracoesPix();
  }

  Future<void> _loadTickets() async {
    final db = await AppDatabase.instance.database;
    final queryResult = await db.rawQuery('''
      SELECT * FROM tickets
      WHERE active = 1
    ''');
    // Cria uma cópia mutável para ordenar
    final result = List<Map<String, Object?>>.from(queryResult);
    // Ordenação em memória ignorando acentos e case
    String _normalize(String s) {
      return s
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[ÁÀÂÃÄ]'), 'A')
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[ÓÒÔÕÖ]'), 'O')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[Ç]'), 'C')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '') // remove outros caracteres especiais
        ;
    }
    result.sort((a, b) {
      final descA = _normalize((a['description'] ?? '').toString().toLowerCase());
      final descB = _normalize((b['description'] ?? '').toString().toLowerCase());
      return descA.compareTo(descB);
    });
    // Debug: print lista normalizada e ordenada
    print('--- Lista de tickets ordenada (normalizada) ---');
    for (var ticket in result) {
      final original = (ticket['description'] ?? '').toString();
      final norm = _normalize(original.toLowerCase());
      print('[$norm] ($original)');
    }
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
    final selected = tickets.where((t) => (quantities[t['id']] ?? 0) > 0).toList();
    
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um ticket para imprimir')),
      );
      return;
    }
    
    // Solicitar forma de pagamento
    final formaPagamento = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forma de Pagamento'),
        content: const Text('Selecione a forma de pagamento:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('dinheiro'),
            icon: const Icon(Icons.attach_money),
            label: const Text('Dinheiro'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('pix'),
            icon: const Icon(Icons.pix),
            label: const Text('Pix'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );
    
    if (formaPagamento == null) return; // Usuário cancelou
    
    final now = DateTime.now();
    final dataHora = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
    final db = await AppDatabase.instance.database;
    
    // Garantir que a coluna txid existe
    await AppDatabase.instance.ensureTxidColumn();
    
    double totalVenda = 0;
    String? vendaTxid; // txid da venda atual
    
    // Calcular total
    for (var ticket in selected) {
      final qtd = quantities[ticket['id']] ?? 0;
      final valorUnitario = ticket['valor'] ?? 0;
      totalVenda += qtd * valorUnitario;
    }
    
    // Gerar txid e payload APENAS se for pagamento via Pix
    if (formaPagamento == 'pix') {
      // Validar se as configurações Pix estão completas
      if (_pixChave.isEmpty || _pixNome.isEmpty || _pixCidade.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure os dados Pix nas configurações antes de usar pagamento Pix.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      
      print('[PIX] ========================================');
      print('[PIX] Iniciando geração de QR Code Pix');
      print('[PIX] Valor total: R\$ ${totalVenda.toStringAsFixed(2)}');
      print('[PIX] Chave configurada: $_pixChave');
      print('[PIX] Nome: $_pixNome');
      print('[PIX] Cidade: $_pixCidade');
      print('[PIX] ========================================');
      
      try {
        DateTime vencimento = DateTime.now().add(const Duration(hours: 24));
        
        var pixResult = PixQrGenerator.generatePayloadWithTxid(
          chave: _pixChave,
          valor: totalVenda,
          nome: _pixNome,
          cidade: _pixCidade,
          descricao: _pixDescricao,
          vencimento: vencimento,
        );
        
        vendaTxid = pixResult.txid;
        
        print('[PIX] ========================================');
        print('[PIX] QR Code gerado com sucesso!');
        print('[PIX] TXID: $vendaTxid');
        print('[PIX] Tamanho do payload: ${pixResult.payload.length} caracteres');
        print('[PIX] ========================================');
        
        // Atualizar o estado para exibir o QR Code na tela
        setState(() {
          _pixPayload = pixResult.payload;
          _currentTxid = vendaTxid;
        });
      } catch (e) {
        print('[PIX] ========================================');
        print('[PIX] ERRO ao gerar QR Code: $e');
        print('[PIX] ========================================');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar QR Code Pix: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }
    
    // Carregar fontes
    final fontes = await _carregarFontesImpressao();
    final fonteDesc = fontes[0];
    final fonteValor = fontes[1];
    final fonteHora = fontes[2];
    
    // Inserir vendas no banco com txid e forma de pagamento
    for (var ticket in selected) {
      final qtd = quantities[ticket['id']] ?? 0;
      final valorUnitario = ticket['valor'] ?? 0;
      
      try {
        await db.insert('vendas', {
          'ticket_id': ticket['id'],
          'amount': qtd,
          'valor_unitario': valorUnitario,
          'txid': vendaTxid, // Salvar o txid da transação
          'forma_pagamento': formaPagamento, // Salvar forma de pagamento
          // created_at será preenchido automaticamente
        });
      } catch (e) {
        print('Erro ao inserir com txid e forma_pagamento: $e');
        // Fallback: inserir sem txid se der erro
        await db.insert('vendas', {
          'ticket_id': ticket['id'],
          'amount': qtd,
          'valor_unitario': valorUnitario,
          'forma_pagamento': formaPagamento, // Salvar forma de pagamento
          // created_at será preenchido automaticamente
        });
        print('Venda inserida sem txid como fallback');
      }
    }
    // Linha superior
    await bluetooth.printCustom('------------------------------', 1, 1);
    await bluetooth.printCustom('', 1, 1);
    for (var ticket in selected) {
      final qtd = quantities[ticket['id']] ?? 0;
      final valorUnitario = ticket['valor'] ?? 0;
      for (int i = 0; i < qtd; i++) {
        // Centralizar descrição e valor unitário, um abaixo do outro
        String descricao = _removerAcentos((ticket['description'] ?? '').toString().toUpperCase());
        String valorStr = 'R\$ ${valorUnitario.toStringAsFixed(2)}';
        await bluetooth.printCustom(
          descricao,
          fonteDesc, // fonte configurável
          1  // centralizado
        );
        await bluetooth.printCustom(
          valorStr,
          fonteValor, // fonte configurável
          1  // centralizado
        );
        await bluetooth.printCustom('', 1, 1);
        // Data e hora centralizada, fonte configurável
        await bluetooth.printCustom(_removerAcentos(dataHora), fonteHora, 1);
        await bluetooth.printCustom('', 1, 1);
        await bluetooth.printCustom('------------------------------', 1, 1);
        if(i < (qtd - 1)) { // se não for o último item daquela quantidade
          await bluetooth.printCustom('', 1, 1);
          await bluetooth.printCustom('', 1, 1); // dobra espaçamento entre tickets
        }
      }
    }
    // Imprimir total da venda ao final, apenas se houver mais de um ticket
    int totalTickets = 0;
    for (var ticket in selected) {
      totalTickets += quantities[ticket['id']] ?? 0;
    }
    if (totalTickets > 1) {
      await bluetooth.printCustom(_removerAcentos('TOTAL DA VENDA: R\$ ${totalVenda.toStringAsFixed(2)}'), fonteValor, 1);
      await bluetooth.printCustom('', 1, 1);
    }
    
    // Gerar e imprimir QR Code Pix APENAS se a forma de pagamento for Pix
    if (formaPagamento == 'pix' && totalVenda > 0 && _pixPayload != null) {
      try {
        print('[PIX IMPRESSAO] ========================================');
        print('[PIX IMPRESSAO] Iniciando impressão do QR Code');
        print('[PIX IMPRESSAO] TXID: $_currentTxid');
        print('[PIX IMPRESSAO] Tamanho do payload: ${_pixPayload!.length} caracteres');
        print('[PIX IMPRESSAO] Primeiros 50 caracteres: ${_pixPayload!.substring(0, _pixPayload!.length > 50 ? 50 : _pixPayload!.length)}...');
        
        // Imprime o QR Code Pix
        await bluetooth.printCustom('', 1, 1);
        await bluetooth.printCustom('PAGUE VIA PIX', 2, 1);
        await bluetooth.printCustom('', 1, 1);
        
        // Usar tamanho máximo suportado pela impressora térmica
        await bluetooth.printQRcode(_pixPayload!, 250, 250, 1);
        await bluetooth.printCustom('', 1, 1);
        
        print('[PIX IMPRESSAO] QR Code enviado para impressão com sucesso');
        print('[PIX IMPRESSAO] ========================================');
      } catch (e) {
        print('[PIX IMPRESSAO] ========================================');
        print('[PIX IMPRESSAO] ERRO ao imprimir QR Code: $e');
        print('[PIX IMPRESSAO] ========================================');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao imprimir QR Code: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.printCustom('', 1, 1); 
    await bluetooth.printCustom('', 1, 1);

    await bluetooth.paperCut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda salva e impressão enviada!')));
    
    // Se for pagamento em dinheiro, zerar as quantidades imediatamente
    // Se for Pix, manter quantidades até fechar o QR Code
    if (formaPagamento == 'dinheiro') {
      setState(() {
        for (var id in quantities.keys) {
          quantities[id] = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    double totalVenda = 0;
    for (var ticket in tickets) {
      final qtd = quantities[ticket['id']] ?? 0;
      final valor = ticket['valor'] ?? 0;
      totalVenda += qtd * valor;
    }
    
    return WillPopScope(
      onWillPop: () async {
        // Se há QR Code sendo exibido, limpa ele e zera quantidades ao invés de sair da página
        if (_pixPayload != null && _pixPayload!.isNotEmpty) {
          setState(() {
            _pixPayload = null;
            _currentTxid = null; // Limpar txid também
            // Zerar quantidades para nova venda
            for (var id in quantities.keys) {
              quantities[id] = 0;
            }
          });
          return false; // Não sai da página
        }
        return true; // Permite sair da página normalmente
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Venda'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Última venda',
              onPressed: () => _mostrarUltimaVenda(context),
            ),
          ],
        ),
        body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final qtd = quantities[ticket['id']] ?? 0;
                final valor = ticket['valor'] ?? 0;
                final iconName = ticket['icon'] ?? 'local_activity';
                final iconData = _iconOptions.firstWhere(
                  (opt) => opt['name'] == iconName,
                  orElse: () => _iconOptions[0],
                )['icon'] as IconData;
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(iconData, size: 32, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ticket['description'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text('R\$ ${valor.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, size: 32),
                              onPressed: () => _decrement(ticket['id'] as int),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text('$qtd', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, size: 32),
                              onPressed: () => _increment(ticket['id'] as int),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Total da venda: R\$ ${totalVenda.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_pixPayload != null && _pixPayload!.isNotEmpty) 
                    ? null  // Desabilita o botão quando QR Code está sendo exibido
                    : _printTickets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_pixPayload != null && _pixPayload!.isNotEmpty)
                      ? Colors.grey[300]  // Cor cinza quando desabilitado
                      : null,  // Cor padrão quando habilitado
                ),
                child: Text(
                  (_pixPayload != null && _pixPayload!.isNotEmpty)
                      ? 'QR Code ativo - Feche para nova venda'
                      : 'Imprimir',
                  style: TextStyle(
                    color: (_pixPayload != null && _pixPayload!.isNotEmpty)
                        ? Colors.grey[600]  // Texto cinza quando desabilitado
                        : null,  // Cor padrão quando habilitado
                  ),
                ),
              ),
            ),
          ),
          if (_pixPayload != null && _pixPayload!.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pagamento via Pix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _pixPayload = null;
                            _currentTxid = null; // Limpar txid também
                            // Zerar quantidades para nova venda
                            for (var id in quantities.keys) {
                              quantities[id] = 0;
                            }
                          });
                        },
                        tooltip: 'Fechar QR Code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: PixQrGenerator.buildQrCode(_pixPayload!),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}
