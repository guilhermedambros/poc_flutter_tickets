
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';


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
    _getBondedDevices();
  }

  Future<void> _getBondedDevices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        _devices = devices;
        if (_devices.isNotEmpty) {
          _selectedDevice = _devices.first;
        }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conectado a ${device.name ?? device.address}')),
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
