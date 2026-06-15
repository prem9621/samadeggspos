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
                  decoration: const InputDecoration(
                    labelText: 'Party Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: adjustmentType,
                  decoration: const InputDecoration(
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
                const SizedBox(height: 12),
                TextField(
                  controller: adjustmentValueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Adjustment Value',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim();
                final address = addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim();
                final adjustmentValue =
                    double.tryParse(adjustmentValueController.text) ?? 0.0;

                if (name.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a party name')),
                    );
                  }
                  return;
                }

                final newParty = Party(
                  name: name,
                  phone: phone,
                  address: address,
                  adjustmentType: adjustmentType,
                  adjustmentValue: adjustmentValue,
                );

                if (party == null) {
                  await dbHelper.insertParty(newParty);
                } else {
                  // For update, we need to set the new values on the existing party
                  // Since HiveObject is mutable, but our model is immutable, let's create a new one and replace
                  await party.delete();
                  await dbHelper.insertParty(newParty);
                }

                if (mounted) {
                  Navigator.pop(dialogContext);
                  _loadParties();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        party == null
                            ? 'Party added successfully!'
                            : 'Party updated successfully!',
                      ),
                    ),
                  );
                }
              },
              child: Text(party == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPartyDialog(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : parties.isEmpty
              ? const Center(child: Text('No parties added yet'))
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
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showPartyDialog(party),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Party'),
                                    content: const Text('Are you sure you want to delete this party?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await dbHelper.deleteParty(party);
                                  _loadParties();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
