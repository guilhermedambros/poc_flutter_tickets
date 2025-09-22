import 'package:intl/intl.dart';
import '../database/app_database.dart';

import 'package:flutter/material.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendas eliminadas com sucesso!')));
  }
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _initPrinters();
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
    await bluetooth.printNewLine();
    await bluetooth.printCustom('Impressora conectada!', 1, 1);
    await bluetooth.printNewLine();
    await bluetooth.paperCut();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conectado e teste de impressão enviado para ${device.name ?? device.address}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar lista',
            onPressed: _getBondedDevices,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Selecione a impressora térmica Bluetooth:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : DropdownButton<BluetoothDevice>(
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
          const SizedBox(height: 24),
          if (_selectedDevice != null)
            Text('Selecionado: ${_selectedDevice!.name ?? _selectedDevice!.address}'),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Eliminar vendas'),
            subtitle: const Text('Remover vendas por dia'),
            onTap: () => _eliminarVendas(context),
          ),
        ],
      ),
    );
  }
}
