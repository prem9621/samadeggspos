import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';

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
  bool isSaving = false;
  String? error;

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
    setState(() { isLoading = true; error = null; });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateR = await dbHelper.getDailyRateByDate(today);
      final partyR = await dbHelper.getAllParties();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        todayRate = rateR.data;
        parties = partyR.data?.where((p) => p.type == PartyType.customer).toList() ?? [];
        error = rateR.success && partyR.success ? null : (rateR.error ?? partyR.error);
      });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = 'Failed: $e'; });
    }
  }

  void _calculateAmount() {
    if (selectedParty == null || todayRate == null) {
      setState(() { adjustedRate = 0; totalAmount = 0; });
      return;
    }
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    adjustedRate = selectedParty!.calculateAdjustedRate(todayRate!.baseRate);
    totalAmount = (adjustedRate / 100) * qty;
    setState(() {});
  }

  Future<void> _saveSale() async {
    if (selectedParty == null) {
      _snack('Please select a customer'); return;
    }
    if (todayRate == null) {
      _snack('Please set today\'s rate first'); return;
    }
    final qty = double.tryParse(_quantityController.text);
    if (qty == null || qty <= 0) {
      _snack('Enter a valid quantity'); return;
    }

    setState(() => isSaving = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await dbHelper.insertSale(Sale.now(
      partyKey: selectedParty!.key as int,
      saleDate: today,
      eggQuantity: qty,
      baseRate: todayRate!.baseRate,
      adjustedRate: adjustedRate,
      amount: totalAmount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    ));

    setState(() => isSaving = false);
    if (result.success) {
      _quantityController.clear();
      _notesController.clear();
      setState(() { selectedParty = null; adjustedRate = 0; totalAmount = 0; });
      _snack('Sale saved successfully!');
    } else {
      _snack(result.error ?? 'Failed to save');
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
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(error!, style: const TextStyle(color: kRed, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry')),
                  ])))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Rate banner
                      if (todayRate == null)
                        _WarningBanner(msg: 'Set today\'s rate before adding a sale')
                      else
                        _RateBanner(rate: todayRate!),
                      const SizedBox(height: 14),

                      // Party selector
                      _SectionLabel('Customer'),
                      const SizedBox(height: 6),
                      _PartyDropdown(
                        parties: parties,
                        selected: selectedParty,
                        label: 'Select Customer',
                        onChanged: (p) {
                          setState(() => selectedParty = p);
                          _calculateAmount();
                        },
                      ),
                      const SizedBox(height: 14),

                      // Quantity
                      _SectionLabel('Egg Quantity'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 14, color: kText),
                        decoration: const InputDecoration(
                          hintText: 'Enter number of eggs',
                          suffixText: 'eggs',
                          suffixStyle: TextStyle(fontSize: 13, color: kTextSub),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      _SectionLabel('Notes (Optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14, color: kText),
                        decoration: const InputDecoration(hintText: 'Any remarks...'),
                      ),

                      // Amount summary
                      if (selectedParty != null && todayRate != null && totalAmount > 0) ...[
                        const SizedBox(height: 16),
                        _AmountSummary(
                          baseRate: todayRate!.baseRate,
                          adjustedRate: adjustedRate,
                          adjustmentType: selectedParty!.adjustmentType,
                          adjustmentValue: selectedParty!.adjustmentValue,
                          total: totalAmount,
                        ),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveSale,
                          child: isSaving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                              : const Text('Save Sale'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
      color: kTextSub, letterSpacing: 0.3));
}

class _WarningBanner extends StatelessWidget {
  final String msg;
  const _WarningBanner({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_rounded, color: kRed, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
          style: const TextStyle(fontSize: 12, color: kRed))),
      ],
    ),
  );
}

class _RateBanner extends StatelessWidget {
  final DailyRate rate;
  const _RateBanner({required this.rate});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: kAmberLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(
      children: [
        const Icon(Icons.egg_rounded, color: kAmber, size: 16),
        const SizedBox(width: 8),
        Text('Today\'s rate: ₹${rate.baseRate.toStringAsFixed(2)} per 100 eggs',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kAmberDark)),
      ],
    ),
  );
}

class _PartyDropdown extends StatelessWidget {
  final List<Party> parties;
  final Party? selected;
  final String label;
  final ValueChanged<Party?> onChanged;
  const _PartyDropdown({
    required this.parties, required this.selected,
    required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<Party>(
    value: selected,
    decoration: InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
    ),
    items: parties.map((p) => DropdownMenuItem(
      value: p,
      child: Text(p.name, style: const TextStyle(fontSize: 14, color: kText)),
    )).toList(),
    onChanged: onChanged,
  );
}

class _AmountSummary extends StatelessWidget {
  final double baseRate, adjustedRate, adjustmentValue, total;
  final String adjustmentType;
  const _AmountSummary({
    required this.baseRate, required this.adjustedRate,
    required this.adjustmentType, required this.adjustmentValue,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      children: [
        if (adjustmentType != '=') ...[
          _Row('Base Rate', '₹${baseRate.toStringAsFixed(2)}/100'),
          _Row('Adjustment', '$adjustmentType $adjustmentValue'),
          _Row('Adjusted Rate', '₹${adjustedRate.toStringAsFixed(2)}/100'),
          const Divider(height: 16, color: kBorder),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Amount',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
            Text('₹${total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kAmber)),
          ],
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSub)),
        Text(value, style: const TextStyle(fontSize: 12, color: kText, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}