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
  String _icon = 'local_activity';
  void _openTicketForm({Map<String, dynamic>? ticket}) {
    if (ticket != null) {
      _descController.text = ticket['description'] ?? '';
      _valorController.text = (ticket['valor'] ?? 0).toString();
      _editingId = ticket['id'] as int;
      _active = (ticket['active'] ?? 1) == 1;
      _icon = ticket['icon'] ?? 'local_activity';
    } else {
      _descController.clear();
      _valorController.clear();
      _editingId = null;
      _active = true;
      _icon = 'local_activity';
    }
    showDialog(
      context: context,
      builder: (context) {
        String iconValue = _icon;
        bool activeValue = _active;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(_editingId == null ? 'Adicionar Ticket' : 'Editar Ticket'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(labelText: 'Descrição do ticket'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Ícone:'),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: iconValue,
                            items: _iconOptions.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt['name'],
                                child: Row(
                                  children: [
                                    Icon(opt['icon']),
                                    const SizedBox(width: 4),
                                    Text(opt['name']),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => iconValue = val);
                              }
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ativo'),
                          Switch(
                            value: activeValue,
                            onChanged: (val) {
                              setModalState(() => activeValue = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Atualiza os valores antes de salvar
                    setState(() {
                      _icon = iconValue;
                      _active = activeValue;
                    });
                    await _saveTicket();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(_editingId == null ? 'Adicionar' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
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
      await db.insert('tickets', {
        'description': desc,
        'valor': valor,
        'icon': _icon,
        'active': _active ? 1 : 0
      });
    } else {
      await db.update('tickets', {
        'description': desc,
        'valor': valor,
        'icon': _icon,
        'active': _active ? 1 : 0
      }, where: 'id = ?', whereArgs: [_editingId]);
    }
    _descController.clear();
    _valorController.clear();
    _editingId = null;
    _active = true;
    _icon = 'local_activity';
    await _loadTickets();
  }

  void _editTicket(Map<String, dynamic> ticket) {
    setState(() {
      _descController.text = ticket['description'] ?? '';
      _valorController.text = (ticket['valor'] ?? 0).toString();
      _editingId = ticket['id'] as int;
      _active = (ticket['active'] ?? 1) == 1;
      _icon = ticket['icon'] ?? 'local_activity';
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
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Ticket'),
                        onPressed: () => _openTicketForm(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        final isActive = (ticket['active'] ?? 1) == 1;
                        final valor = ticket['valor'] ?? 0;
                        final iconName = ticket['icon'] ?? 'local_activity';
                        final iconData = _iconOptions.firstWhere(
                          (opt) => opt['name'] == iconName,
                          orElse: () => _iconOptions[0],
                        )['icon'] as IconData;
                        return ListTile(
                          leading: Icon(iconData, color: isActive ? Colors.blue : Colors.grey),
                          title: Text(ticket['description'] ?? ''),
                          subtitle: Text('R\$ ${valor.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openTicketForm(ticket: ticket),
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
