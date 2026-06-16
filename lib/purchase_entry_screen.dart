import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

class PurchaseEntryScreen extends StatefulWidget {
  const PurchaseEntryScreen({super.key});

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Party> suppliers = [];
  Party? selectedSupplier;
  DailyRate? todayRate;
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _rateController = TextEditingController();
  double adjustedRate = 0.0;
  double totalAmount = 0.0;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quantityController.addListener(_calculateAmount);
    _rateController.addListener(_calculateAmount);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateResult = await dbHelper.getDailyRateByDate(today);
      final partyResult = await dbHelper.getAllParties();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (rateResult.success && partyResult.success) {
          todayRate = rateResult.data;
          if (todayRate != null) {
            _rateController.text = todayRate!.baseRate.toStringAsFixed(2);
          }
          suppliers = partyResult.data?.where((p) => p.type == PartyType.supplier).toList() ?? [];
        } else {
          error = rateResult.error ?? partyResult.error ?? 'Failed to load data';
        }
      });
    } catch (e) {
      debugPrint('Purchase entry load error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load data: $e';
        });
      }
    }
  }

  void _calculateAmount() {
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    adjustedRate = rate;
    totalAmount = (adjustedRate / 100) * quantity;
    setState(() {});
  }

  Future<void> _savePurchase() async {
    if (selectedSupplier == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a supplier')),
        );
      }
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid quantity')),
        );
      }
      return;
    }
    final rate = double.tryParse(_rateController.text);
    if (rate == null || rate <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid rate')),
        );
      }
      return;
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final purchase = Purchase.now(
      supplierKey: selectedSupplier!.key as int,
      purchaseDate: today,
      eggQuantity: quantity,
      baseRate: rate,
      adjustedRate: rate,
      amount: totalAmount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final result = await dbHelper.insertPurchase(purchase);
    if (result.success) {
      _quantityController.clear();
      _notesController.clear();
      setState(() {
        selectedSupplier = null;
        adjustedRate = 0.0;
        totalAmount = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase saved successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to save purchase')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
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
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<Party>(
                        initialValue: selectedSupplier,
                        decoration: const InputDecoration(
                          labelText: 'Select Supplier',
                          border: OutlineInputBorder(),
                        ),
                        items: suppliers.map((party) {
                          return DropdownMenuItem<Party>(
                            value: party,
                            child: Text(party.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSupplier = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Rate per 100 eggs (₹)',
                          border: OutlineInputBorder(),
                        ),
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
                      if (selectedSupplier != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${totalAmount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _savePurchase,
                        child: const Text('Save Purchase'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
