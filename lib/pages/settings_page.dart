
import 'package:flutter/material.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
          ],
        ),
      ),
    );
  }
}
