import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

class SaleEntryScreen extends StatefulWidget {
  const SaleEntryScreen({super.key});

  @override
  State<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends State<SaleEntryScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Party> parties = [];
  Party? selectedParty;
  DailyRate? todayRate;
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  double adjustedRate = 0.0;
  double totalAmount = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quantityController.addListener(_calculateAmount);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rate = await dbHelper.getDailyRateByDate(today);
    final partyList = await dbHelper.getAllParties();
    setState(() {
      todayRate = rate;
      parties = partyList;
      isLoading = false;
    });
  }

  void _calculateAmount() {
    if (selectedParty == null || todayRate == null) return;
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    adjustedRate = selectedParty!.calculateAdjustedRate(todayRate!.baseRate);
    totalAmount = (adjustedRate / 100) * quantity;
    setState(() {});
  }

  Future<void> _saveSale() async {
    if (selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a party')),
      );
      return;
    }
    if (todayRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please set today\'s rate first')),
      );
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid quantity')),
      );
      return;
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sale = Sale(
      partyId: selectedParty!.id!,
      saleDate: today,
      eggQuantity: quantity,
      baseRate: todayRate!.baseRate,
      adjustedRate: adjustedRate,
      amount: totalAmount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    await dbHelper.insertSale(sale);
    _quantityController.clear();
    _notesController.clear();
    setState(() {
      selectedParty = null;
      adjustedRate = 0.0;
      totalAmount = 0.0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Sale'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (todayRate == null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Please set today\'s rate first!',
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<Party>(
                    initialValue: selectedParty,
                    decoration: InputDecoration(
                      labelText: 'Select Party',
                      border: OutlineInputBorder(),
                    ),
                    items: parties
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name),
                            ))
                        .toList(),
                    onChanged: (party) {
                      setState(() {
                        selectedParty = party;
                      });
                      _calculateAmount();
                    },
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Egg Quantity',
                      border: OutlineInputBorder(),
                      suffixText: 'eggs',
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 24),
                  if (selectedParty != null && todayRate != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Base Rate'),
                                Text('₹${todayRate!.baseRate.toStringAsFixed(2)} / 100 eggs'),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Adjusted Rate'),
                                Text('₹${adjustedRate.toStringAsFixed(2)} / 100 eggs'),
                              ],
                            ),
                            Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('₹${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  ElevatedButton(
                    onPressed: _saveSale,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Save Sale'),
                  ),
                ],
              ),
            ),
    );
  }
}
