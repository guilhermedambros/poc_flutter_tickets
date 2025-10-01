import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  // Controlador de abas
  late TabController _tabController;
  
  // Controladores para os campos Pix
  final TextEditingController _pixChaveController = TextEditingController();
  final TextEditingController _pixNomeController = TextEditingController();
  final TextEditingController _pixCidadeController = TextEditingController();
  final TextEditingController _pixDescricaoController = TextEditingController();

  Future<void> _salvarFonte(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<int> _carregarFonte(String key, int padrao) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? padrao;
  }

  Future<void> _carregarConfiguracoesPix() async {
    final prefs = await SharedPreferences.getInstance();
    _pixChaveController.text = prefs.getString('pix_chave') ?? '43821004000143';
    _pixNomeController.text = prefs.getString('pix_nome') ?? 'CTG UNIAO SERRA E CANTO';
    _pixCidadeController.text = prefs.getString('pix_cidade') ?? 'UNIAO DA SERRA';
    _pixDescricaoController.text = prefs.getString('pix_descricao') ?? 'Pagamento de venda';
  }

  Future<void> _salvarConfiguracoesPix() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pix_chave', _pixChaveController.text);
    await prefs.setString('pix_nome', _pixNomeController.text);
    await prefs.setString('pix_cidade', _pixCidadeController.text);
    await prefs.setString('pix_descricao', _pixDescricaoController.text);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações Pix salvas com sucesso!')),
    );
  }

  Future<void> _consultarVendaPorTxid(BuildContext context) async {
    final TextEditingController txidController = TextEditingController();
    
    final txid = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar venda por TXID'),
        content: TextField(
          controller: txidController,
          decoration: const InputDecoration(
            labelText: 'Digite o TXID da transação Pix',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(txidController.text),
            child: const Text('Consultar'),
          ),
        ],
      ),
    );
    
    if (txid == null || txid.isEmpty) return;
    
    final db = await AppDatabase.instance.database;
    final vendas = await db.rawQuery('''
      SELECT v.*, t.description as ticket_desc 
      FROM vendas v
      JOIN tickets t ON t.id = v.ticket_id
      WHERE v.txid = ?
    ''', [txid]);
    
    if (vendas.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('TXID não encontrado'),
          content: Text('Nenhuma venda encontrada com este TXID.'),
        ),
      );
      return;
    }
    
    double total = 0;
    for (var venda in vendas) {
      final qtd = venda['amount'] ?? 0;
      final valor = venda['valor_unitario'] ?? 0;
      total += (qtd is int ? qtd : int.tryParse(qtd.toString()) ?? 0) * 
               (valor is num ? valor : double.tryParse(valor.toString()) ?? 0);
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Venda TXID: $txid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(vendas.first['created_at'].toString()))}'),
            const SizedBox(height: 12),
            ...vendas.map((venda) => Text(
              '${venda['ticket_desc']} x${venda['amount']} - R\$ ${(venda['valor_unitario'] as num).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            )),
            const SizedBox(height: 12),
            Text('Total: R\$ ${total.toStringAsFixed(2)}', 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _eliminarVendas(BuildContext context) async {
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
          title: const Text('Selecione os dias para eliminar'),
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
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (selecionadasResult == null || selecionadasResult.isEmpty) {
      return;
    }
    // Confirmação
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminação'),
        content: Text('Deseja realmente eliminar as vendas dos dias selecionados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Eliminar vendas dos dias selecionados
    await db.delete(
      'vendas',
      where: 'DATE(created_at) IN (${List.filled(selecionadasResult.length, '?').join(',')})',
      whereArgs: selecionadasResult,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendas eliminadas com sucesso!')),
    );
  }

  Future<void> _resetarBancoDados(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar banco de dados'),
        content: const Text(
          'ATENÇÃO: Esta ação irá deletar TODOS os dados (vendas e tickets) e recriar o banco com a estrutura atualizada.\n\n'
          'Esta operação é IRREVERSÍVEL!\n\n'
          'Deseja continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESETAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      // Resetar o banco de dados
      await AppDatabase.resetDatabase();
      
      // Abrir novo banco (vai executar onCreate)
      await AppDatabase.instance.database;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banco de dados resetado com sucesso! Estrutura atualizada.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao resetar banco: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Reduzido para 3 abas
    _initPrinters();
    _carregarConfiguracoesPix();
  }

  Future<void> _initPrinters() async {
    await _getBondedDevices();
    await _loadSavedPrinter();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('selected_printer_address');
    if (savedAddress != null && _devices.isNotEmpty) {
      final found = _devices.where((d) => d.address == savedAddress);
      if (found.isNotEmpty) {
        setState(() {
          _selectedDevice = found.first;
        });
      }
    }
  }

  Future<void> _getBondedDevices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      setState(() {
        _devices = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _connectToDevice(BluetoothDevice? device) async {
    if (device == null) return;
    await bluetooth.connect(device);
    setState(() {
      _selectedDevice = device;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_address', device.address ?? '');
    // Imprimir teste de sucesso
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.printCustom('Impressora conectada!', 1, 1);
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.printCustom('', 1, 1);
    await bluetooth.paperCut();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conectado e teste de impressão enviado para ${device.name ?? device.address}')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pixChaveController.dispose();
    _pixNomeController.dispose();
    _pixCidadeController.dispose();
    _pixDescricaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar lista de impressoras',
            onPressed: _getBondedDevices,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Cor do texto/ícone quando selecionado
          unselectedLabelColor: Colors.black, // Cor do texto/ícone quando não selecionado
          indicatorColor: Colors.white, // Cor do indicador da aba selecionada
          tabs: const [
            Tab(icon: Icon(Icons.print), text: 'Impressora'),
            Tab(icon: Icon(Icons.pix), text: 'Pix'),
            Tab(icon: Icon(Icons.storage), text: 'Dados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImpressoraTab(),
          _buildPixTab(),
          _buildDadosTab(),
        ],
      ),
    );
  }

  // Aba de configurações da impressora (inclui impressão)
  Widget _buildImpressoraTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção Impressora Bluetooth
          const Text(
            'Impressora Térmica Bluetooth',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Selecione a impressora:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BluetoothDevice>(
                      isExpanded: true,
                      value: _selectedDevice,
                      hint: const Text('Nenhum dispositivo encontrado'),
                      items: _devices.map((d) {
                        return DropdownMenuItem(
                          value: d,
                          child: Text(d.name ?? d.address ?? 'Desconhecido'),
                        );
                      }).toList(),
                      onChanged: (device) {
                        _connectToDevice(device);
                      },
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          if (_selectedDevice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conectado: ${_selectedDevice!.name ?? _selectedDevice!.address}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _getBondedDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar Lista de Dispositivos'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          
          // Seção Configurações de Impressão
          const Text(
            'Tamanhos de Fonte',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<int>>(
            future: Future.wait([
              _carregarFonte('font_ticket_desc', 2),
              _carregarFonte('font_ticket_valor', 0),
              _carregarFonte('font_ticket_hora', 0),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final fontes = snapshot.data!;
              return Column(
                children: [
                  _buildFontConfig('Descrição do produto:', fontes[0], 'font_ticket_desc', [
                    const DropdownMenuItem(value: 0, child: Text('Pequena')),
                    const DropdownMenuItem(value: 1, child: Text('Média')),
                    const DropdownMenuItem(value: 2, child: Text('Grande')),
                    const DropdownMenuItem(value: 3, child: Text('Extra Grande')),
                  ]),
                  const SizedBox(height: 16),
                  _buildFontConfig('Valor do produto:', fontes[1], 'font_ticket_valor', [
                    const DropdownMenuItem(value: 0, child: Text('Pequena')),
                    const DropdownMenuItem(value: 1, child: Text('Média')),
                    const DropdownMenuItem(value: 2, child: Text('Grande')),
                  ]),
                  const SizedBox(height: 16),
                  _buildFontConfig('Data e hora:', fontes[2], 'font_ticket_hora', [
                    const DropdownMenuItem(value: 0, child: Text('Pequena')),
                    const DropdownMenuItem(value: 1, child: Text('Média')),
                    const DropdownMenuItem(value: 2, child: Text('Grande')),
                  ]),
                ],
              );
            },
          ),
          const SizedBox(height: 16), // Espaço extra no final
        ],
      ),
    );
  }

  // Aba de configurações Pix
  Widget _buildPixTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configurações Pix',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pixChaveController,
            decoration: const InputDecoration(
              labelText: 'Chave Pix',
              helperText: 'CPF, CNPJ, telefone, email ou chave aleatória',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pixNomeController,
            decoration: const InputDecoration(
              labelText: 'Nome do recebedor',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pixCidadeController,
            decoration: const InputDecoration(
              labelText: 'Cidade',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pixDescricaoController,
            decoration: const InputDecoration(
              labelText: 'Descrição do pagamento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _salvarConfiguracoesPix,
            icon: const Icon(Icons.save),
            label: const Text('Salvar Configurações Pix'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16), // Espaço extra no final
        ],
      ),
    );
  }

  // Aba de gerenciamento de dados
  Widget _buildDadosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gerenciamento de Dados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.search, color: Colors.blue),
              title: const Text('Consultar venda por TXID'),
              subtitle: const Text('Buscar venda pelo ID da transação Pix'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _consultarVendaPorTxid(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.orange),
              title: const Text('Eliminar vendas'),
              subtitle: const Text('Remover vendas por dia'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _eliminarVendas(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text('Resetar banco de dados'),
              subtitle: const Text('ATENÇÃO: Remove TODOS os dados'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _resetarBancoDados(context),
            ),
          ),
          const SizedBox(height: 16), // Espaço extra no final
        ],
      ),
    );
  }

  Widget _buildFontConfig(String label, int currentValue, String key, List<DropdownMenuItem<int>> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            isExpanded: true,
            value: currentValue,
            items: items,
            onChanged: (v) {
              if (v != null) {
                _salvarFonte(key, v).then((_) => setState(() {}));
              }
            },
          ),
        ],
      ),
    );
  }
}
