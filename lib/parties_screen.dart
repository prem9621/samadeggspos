import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'models.dart';
import 'database_helper.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Party> parties = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() {
      isLoading = true;
    });
    try {
      final list = await dbHelper.getAllParties();
      if (!mounted) return;
      setState(() {
        parties = list;
      });
    } catch (e) {
      debugPrint('Parties load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load parties: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showPartyDialog([Party? party]) async {
    final nameController = TextEditingController(text: party?.name);
    final phoneController = TextEditingController(text: party?.phone);
    final addressController = TextEditingController(text: party?.address);
    String adjustmentType = party?.adjustmentType ?? '=';
    final adjustmentValueController =
        TextEditingController(text: party?.adjustmentValue.toString() ?? '0');

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(party == null ? 'Add Party' : 'Edit Party'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Party Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Address (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: adjustmentType,
                  decoration: InputDecoration(
                    labelText: 'Rate Adjustment Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '=', child: Text('Equal (=)')),
                    DropdownMenuItem(value: '+', child: Text('Plus (+)')),
                    DropdownMenuItem(value: '-', child: Text('Minus (-)')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        adjustmentType = value;
                      });
                    }
                  },
                ),
                if (adjustmentType != '=')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: adjustmentValueController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Adjustment Value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Please enter party name')),
                  );
                  return;
                }
                final adjustmentValue = double.tryParse(adjustmentValueController.text) ?? 0.0;
                final newParty = Party(
                  id: party?.id,
                  name: name,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                  adjustmentType: adjustmentType,
                  adjustmentValue: adjustmentValue,
                );

                try {
                  if (party == null) {
                    await dbHelper.insertParty(newParty);
                  } else {
                    await dbHelper.updateParty(newParty);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to save party: $e')),
                  );
                  return;
                }

                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);
                _loadParties();
                messenger.showSnackBar(
                  SnackBar(content: Text('Party saved successfully')),
                );
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );

    // FIX: dispose dialog controllers after the dialog closes
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    adjustmentValueController.dispose();
  }

  Future<void> _deleteParty(Party party) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Party'),
        content: Text('Are you sure you want to delete ${party.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await dbHelper.deleteParty(party.id!);
        _loadParties();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Party deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete party: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parties'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : parties.isEmpty
              ? Center(child: Text('No parties added yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parties.length,
                  itemBuilder: (context, index) {
                    final party = parties[index];
                    return Card(
                      child: ListTile(
                        title: Text(party.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (party.phone != null) Text('Phone: ${party.phone}'),
                            if (party.address != null) Text('Address: ${party.address}'),
                            Text('Adjustment: ${party.adjustmentType}${party.adjustmentValue.toStringAsFixed(0)}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _showPartyDialog(party),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _deleteParty(party),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPartyDialog(),
        child: Icon(Icons.add),
      ),
    );
  }
}