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
  List<Party> filteredParties = [];
  bool isLoading = true;
  String? error;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await dbHelper.getAllParties();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (result.success) {
          parties = result.data ?? [];
          filteredParties = parties;
        } else {
          error = result.error;
        }
      });
    } catch (e) {
      debugPrint('Parties load error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load parties: $e';
        });
      }
    }
  }

  void _searchParties(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredParties = parties;
      });
    } else {
      setState(() {
        final searchLower = query.toLowerCase().trim();
        filteredParties = parties
            .where((p) => p.name.toLowerCase().contains(searchLower))
            .toList();
      });
    }
  }

  Future<void> _showPartyDialog([Party? party]) async {
    final nameController = TextEditingController(text: party?.name);
    final phoneController = TextEditingController(text: party?.phone);
    final addressController = TextEditingController(text: party?.address);
    final notesController = TextEditingController(text: party?.notes);
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
                    DropdownMenuItem(value: '+%', child: Text('Plus Percentage (+%)')),
                    DropdownMenuItem(value: '-%', child: Text('Minus Percentage (-%)')),
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
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                final notes = notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim();
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

                if (party == null) {
                  final newParty = Party.now(
                    name: name,
                    phone: phone,
                    address: address,
                    adjustmentType: adjustmentType,
                    adjustmentValue: adjustmentValue,
                    notes: notes,
                  );
                  final result = await dbHelper.insertParty(newParty);
                  if (result.success) {
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _loadParties();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Party added successfully!')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.error ?? 'Failed to add party')),
                      );
                    }
                  }
                } else {
                  final updatedParty = Party(
                    name: name,
                    phone: phone,
                    address: address,
                    adjustmentType: adjustmentType,
                    adjustmentValue: adjustmentValue,
                    notes: notes,
                    createdAt: party.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await party.delete();
                  final result = await dbHelper.insertParty(updatedParty);
                  if (result.success) {
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _loadParties();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Party updated successfully!')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.error ?? 'Failed to update party')),
                      );
                    }
                  }
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
      body: RefreshIndicator(
        onRefresh: _loadParties,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadParties,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: searchController,
                          onChanged: _searchParties,
                          decoration: InputDecoration(
                            hintText: 'Search parties...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredParties.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.group,
                                        size: 64,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        parties.isEmpty ? 'No parties added yet' : 'No matching parties found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (parties.isEmpty)
                                        const SizedBox(height: 16),
                                      if (parties.isEmpty)
                                        ElevatedButton.icon(
                                          onPressed: _showPartyDialog,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Party'),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredParties.length,
                                itemBuilder: (context, index) {
                                  final party = filteredParties[index];
                                  return Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        party.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (party.phone != null) Text('Phone: ${party.phone}'),
                                          if (party.address != null) Text('Address: ${party.address}'),
                                          Text('Adjustment: ${party.adjustmentType} ${party.adjustmentValue}'),
                                          if (party.notes != null) Text('Notes: ${party.notes}'),
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
                                                final result = await dbHelper.deleteParty(party);
                                                if (result.success) {
                                                  _loadParties();
                                                } else {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(result.error ?? 'Failed to delete party')),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
