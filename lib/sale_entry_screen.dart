import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rate = await dbHelper.getDailyRateByDate(today);
      final partyList = await dbHelper.getAllParties();
      if (!mounted) return;
      setState(() {
        todayRate = rate;
        parties = partyList;
      });
    } catch (e) {
      debugPrint('Sale entry load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
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

  void _calculateAmount() {
    if (selectedParty == null || todayRate == null) {
      setState(() {
        adjustedRate = 0.0;
        totalAmount = 0.0;
      });
      return;
    }
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    adjustedRate = selectedParty!.calculateAdjustedRate(todayRate!.baseRate);
    totalAmount = (adjustedRate / 100) * quantity;
    setState(() {});
  }

  Future<void> _saveSale() async {
    if (selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a party')),
      );
      return;
    }
    if (todayRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set today\'s rate first')),
      );
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid quantity')),
      );
      return;
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sale = Sale(
      partyKey: selectedParty!.key as int,
      saleDate: today,
      eggQuantity: quantity,
      baseRate: todayRate!.baseRate,
      adjustedRate: adjustedRate,
      amount: totalAmount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
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
          const SnackBar(content: Text('Sale saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save sale: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
                  if (todayRate != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Today\'s Rate',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${todayRate!.baseRate.toStringAsFixed(2)} per 100 eggs',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Party>(
                    value: selectedParty,
                    decoration: const InputDecoration(
                      labelText: 'Select Party',
                      border: OutlineInputBorder(),
                    ),
                    items: parties.map((party) {
                      return DropdownMenuItem<Party>(
                        value: party,
                        child: Text(party.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedParty = value;
                      });
                      _calculateAmount();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Egg Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (selectedParty != null && todayRate != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Rate Adjustment',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Adjustment: ${selectedParty!.adjustmentType} ${selectedParty!.adjustmentValue}'),
                            Text('Adjusted Rate: ₹${adjustedRate.toStringAsFixed(2)} per 100 eggs'),
                            Text(
                              'Total Amount: ₹${totalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveSale,
                    child: const Text('Save Sale'),
                  ),
                ],
              ),
            ),
    );
  }
}
