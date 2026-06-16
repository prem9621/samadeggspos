import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';
import 'sale_entry_screen.dart' show _SectionLabel, _WarningBanner, _RateBanner, _PartyDropdown, _Row;

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
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  double adjustedRate = 0.0;
  double totalAmount = 0.0;
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _qtyCtrl.addListener(_calc);
    _rateCtrl.addListener(_calc);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; error = null; });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateR = await dbHelper.getDailyRateByDate(today);
      final partyR = await dbHelper.getAllParties();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        todayRate = rateR.data;
        if (todayRate != null) _rateCtrl.text = todayRate!.baseRate.toStringAsFixed(2);
        suppliers = partyR.data?.where((p) => p.type == PartyType.supplier).toList() ?? [];
      });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = 'Failed: $e'; });
    }
  }

  void _calc() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text) ?? 0.0;
    adjustedRate = rate;
    totalAmount = (rate / 100) * qty;
    setState(() {});
  }

  Future<void> _save() async {
    if (selectedSupplier == null) { _snack('Select a supplier'); return; }
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) { _snack('Enter valid quantity'); return; }
    final rate = double.tryParse(_rateCtrl.text);
    if (rate == null || rate <= 0) { _snack('Enter valid rate'); return; }

    setState(() => isSaving = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await dbHelper.insertPurchase(Purchase.now(
      supplierKey: selectedSupplier!.key as int,
      purchaseDate: today,
      eggQuantity: qty,
      baseRate: rate,
      adjustedRate: rate,
      amount: totalAmount,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));

    setState(() => isSaving = false);
    if (result.success) {
      _qtyCtrl.clear();
      _notesCtrl.clear();
      setState(() { selectedSupplier = null; adjustedRate = 0; totalAmount = 0; });
      _snack('Purchase saved!');
    } else {
      _snack(result.error ?? 'Failed');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 13))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (todayRate != null)
                    _RateBanner(rate: todayRate!)
                  else
                    const _WarningBanner(msg: 'No rate set today — enter rate manually'),
                  const SizedBox(height: 14),

                  _SectionLabel('Supplier'),
                  const SizedBox(height: 6),
                  _PartyDropdown(
                    parties: suppliers,
                    selected: selectedSupplier,
                    label: 'Select Supplier',
                    onChanged: (p) => setState(() => selectedSupplier = p),
                  ),
                  const SizedBox(height: 14),

                  _SectionLabel('Rate per 100 Eggs (₹)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, color: kText),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 14),

                  _SectionLabel('Egg Quantity'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, color: kText),
                    decoration: const InputDecoration(
                      hintText: 'Enter number of eggs',
                      suffixText: 'eggs',
                    ),
                  ),
                  const SizedBox(height: 14),

                  _SectionLabel('Notes (Optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14, color: kText),
                    decoration: const InputDecoration(hintText: 'Any remarks...'),
                  ),

                  if (totalAmount > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('₹${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                              color: kRed)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _save,
                      child: isSaving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Purchase'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}