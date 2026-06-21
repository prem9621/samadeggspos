import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';
import 'party_picker_sheet.dart';

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
  int? _lastRateRevision;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quantityController.addListener(_calculateAmount);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<AppState>().rateRevision;
    if (_lastRateRevision == null) {
      _lastRateRevision = revision;
      return;
    }
    if (_lastRateRevision != revision) {
      _lastRateRevision = revision;
      _loadData();
    }
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
      error = null;
    });
    try {
      final rateR = await dbHelper.getTodayRate();
      final partyR = await dbHelper.getAllCustomers();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        todayRate = rateR.data;
        parties = partyR.data ?? [];
        error = rateR.success && partyR.success ? null : (rateR.error ?? partyR.error);
      });
      _calculateAmount();
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed: $e';
        });
      }
    }
  }

  void _calculateAmount() {
    if (selectedParty == null || todayRate == null) {
      setState(() {
        adjustedRate = 0;
        totalAmount = 0;
      });
      return;
    }
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    adjustedRate = selectedParty!.calculateAdjustedRate(todayRate!.baseRate);
    totalAmount = (adjustedRate * qty) / 100;
    setState(() {});
  }

  Future<void> _saveSale() async {
    if (selectedParty == null) {
      _snack('Please select a customer');
      return;
    }
    final latestRate = await _loadLatestRateForSave();
    if (latestRate == null) {
      _snack('Please set today\'s rate first');
      return;
    }
    final qty = double.tryParse(_quantityController.text);
    if (qty == null || qty <= 0) {
      _snack('Enter a valid quantity');
      return;
    }

    setState(() => isSaving = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final saleRate = selectedParty!.calculateAdjustedRate(latestRate.baseRate);
    final saleAmount = (saleRate * qty) / 100;
    final result = await dbHelper.insertSale(
      Sale.now(
        partyKey: selectedParty!.key as int,
        saleDate: today,
        eggQuantity: qty,
        baseRate: latestRate.baseRate,
        adjustedRate: saleRate,
        amount: saleAmount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );

    setState(() => isSaving = false);
    if (result.success) {
      _quantityController.clear();
      _notesController.clear();
      setState(() {
        selectedParty = null;
        adjustedRate = 0;
        totalAmount = 0;
      });
      _snack('Sale saved successfully!');
    } else {
      _snack(result.error ?? 'Failed to save');
    }
  }

  Future<DailyRate?> _loadLatestRateForSave() async {
    final rateR = await dbHelper.getTodayRate();
    if (rateR.success && mounted) {
      setState(() {
        todayRate = rateR.data;
      });
      _calculateAmount();
    }
    return rateR.data;
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12))),
      );
    }
  }

  Future<void> _addPartyInline() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Add Customer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter party name',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(fontSize: 13),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    hintText: '10-digit number',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter party name')),
                        );
                        return;
                      }
                      final r = await dbHelper.insertParty(
                        Party.now(
                          name: name,
                          phone: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          adjustmentType: '=',
                          adjustmentValue: 0,
                          type: PartyType.customer,
                        ),
                      );
                      if (r.success && mounted) {
                        Navigator.pop(ctx);
                        await _loadData();
                        setState(() {
                          selectedParty = parties.firstWhere(
                            (p) => p.name == name,
                            orElse: () => parties.last,
                          );
                        });
                        _calculateAmount();
                        _snack('Customer added!');
                      } else if (mounted) {
                        _snack(r.error ?? 'Failed to add');
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kAmber))
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          error!,
                          style: const TextStyle(color: kRed, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
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
                      if (todayRate == null)
                        const _WarningBanner(
                          msg: 'Set today\'s rate before adding a sale',
                        )
                      else
                        _RateBanner(rate: todayRate!),
                      const SizedBox(height: 14),
                      const _SectionLabel('Customer'),
                      const SizedBox(height: 6),
                      PartySelectField(
                        selected: selectedParty,
                        label: 'Select Customer',
                        parties: parties,
                        onChanged: (p) {
                          setState(() => selectedParty = p);
                          _calculateAmount();
                        },
                        onAddNew: _addPartyInline,
                      ),
                      const SizedBox(height: 14),
                      const _SectionLabel('Egg Quantity'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, color: kText),
                        decoration: const InputDecoration(
                          hintText: 'Enter number of eggs',
                          suffixText: 'eggs',
                          suffixStyle: TextStyle(fontSize: 12, color: kTextSub),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _SectionLabel('Notes (Optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13, color: kText),
                        decoration: const InputDecoration(hintText: 'Any remarks...'),
                      ),
                      if (selectedParty != null && todayRate != null) ...[
                        const SizedBox(height: 16),
                        _AmountSummary(
                          baseRate: todayRate!.baseRate,
                          adjustedRate: adjustedRate,
                          adjustmentLabel: selectedParty!.adjustmentLabel,
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
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Sale'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: kTextSub,
          letterSpacing: 0.3,
        ),
      );
}

class _WarningBanner extends StatelessWidget {
  final String msg;
  const _WarningBanner({required this.msg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: kTextSub, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontSize: 11.5, color: kTextSub),
              ),
            ),
          ],
        ),
      );
}

class _RateBanner extends StatelessWidget {
  final DailyRate rate;
  const _RateBanner({required this.rate});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kAmberLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.egg_rounded, color: kAmber, size: 15),
            const SizedBox(width: 8),
            Text(
              'Today\'s rate: ₹${rate.baseRate.toStringAsFixed(2)} per 100 eggs',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kAmberDark,
              ),
            ),
          ],
        ),
      );
}

class _AmountSummary extends StatelessWidget {
  final double baseRate;
  final double adjustedRate;
  final double total;
  final String adjustmentLabel;

  const _AmountSummary({
    required this.baseRate,
    required this.adjustedRate,
    required this.adjustmentLabel,
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
            _Row('Base Rate', '₹${baseRate.toStringAsFixed(2)} per 100 eggs'),
            _Row('Party Adjustment', adjustmentLabel),
            _Row('Sale Rate', '₹${adjustedRate.toStringAsFixed(2)} per 100 eggs'),
            const Divider(height: 14, color: kBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
                Text(
                  total > 0 ? '₹${total.toStringAsFixed(2)}' : '—',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kAmber,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: kTextSub)),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                color: kText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
