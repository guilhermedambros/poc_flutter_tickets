import 'package:flutter/material.dart';
import '../database/app_database.dart';

class CrudTicketsPage extends StatefulWidget {
  const CrudTicketsPage({Key? key}) : super(key: key);

  @override
  State<CrudTicketsPage> createState() => _CrudTicketsPageState();
}

class _CrudTicketsPageState extends State<CrudTicketsPage> {
  List<Map<String, dynamic>> tickets = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _valorController = TextEditingController();
  int? _editingId;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final db = await AppDatabase.instance.database;
    final result = await db.query('tickets', orderBy: 'description ASC');
    setState(() {
      tickets = result;
      _loading = false;
    });
  }

  Future<void> _saveTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await AppDatabase.instance.database;
    final desc = _descController.text.trim();
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    // Verifica duplicidade
    final exists = await db.query('tickets', where: 'LOWER(description) = ?', whereArgs: [desc.toLowerCase()]);
    if (exists.isNotEmpty && (exists.first['id'] != _editingId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já existe um ticket com essa descrição.')));
      return;
    }
    if (_editingId == null) {
      await db.insert('tickets', {'description': desc, 'valor': valor, 'active': _active ? 1 : 0});
    } else {
      await db.update('tickets', {'description': desc, 'valor': valor, 'active': _active ? 1 : 0}, where: 'id = ?', whereArgs: [_editingId]);
    }
    _descController.clear();
    _valorController.clear();
    _editingId = null;
    _active = true;
    await _loadTickets();
  }

  void _editTicket(Map<String, dynamic> ticket) {
    setState(() {
      _descController.text = ticket['description'] ?? '';
      _valorController.text = (ticket['valor'] ?? 0).toString();
      _editingId = ticket['id'] as int;
      _active = (ticket['active'] ?? 1) == 1;
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Tickets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Form(
                    key: _formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _descController,
                            decoration: const InputDecoration(labelText: 'Descrição do ticket'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _valorController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Valor'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Informe o valor';
                              final value = double.tryParse(v.replaceAll(',', '.'));
                              if (value == null || value < 0) return 'Valor inválido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Ativo'),
                            Switch(
                              value: _active,
                              onChanged: (val) {
                                setState(() {
                                  _active = val;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveTicket,
                          child: Text(_editingId == null ? 'Adicionar' : 'Salvar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        final isActive = (ticket['active'] ?? 1) == 1;
                        final valor = ticket['valor'] ?? 0;
                        return ListTile(
                          leading: Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            color: isActive ? Colors.green : Colors.red,
                          ),
                          title: Text(ticket['description'] ?? ''),
                          subtitle: Text('R\$ ${valor.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editTicket(ticket),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
