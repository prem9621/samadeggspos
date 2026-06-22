import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';
import 'party_picker_sheet.dart';

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

  // No manual rate textbox. The rate paid to the supplier is always
  // today's base rate run through that supplier's saved adjustment
  // (set once on the Parties screen), exactly the same mechanism the
  // Sale screen uses for customers.
  double adjustedRate = 0.0;
  double totalAmount = 0.0;
  
  // NEW: Percentage fields
  double percentageValue = 0.0;
  double amountBeforePercentage = 0.0;
  
  bool isLoading = true;
  bool isSaving = false;
  String? error;
  int? _lastRateRevision;

  @override
  void initState() {
    super.initState();
    _loadData();
    _qtyCtrl.addListener(_calc);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateR = await dbHelper.getDailyRateByDate(today);
      final partyR = await dbHelper.getAllSuppliers();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        todayRate = rateR.data;
        suppliers = partyR.data ?? [];
        error = rateR.success && partyR.success
            ? null
            : (rateR.error ?? partyR.error);
      });
      _calc();
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed: $e';
        });
      }
    }
  }

  /// Recalculates the supplier's adjusted rate from today's base rate
  /// and updates the total. Runs whenever the supplier changes, today's
  /// rate loads, or the quantity changes.
  void _calc() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
    if (selectedSupplier == null || todayRate == null) {
      setState(() {
        adjustedRate = 0;
        totalAmount = 0;
        amountBeforePercentage = 0;
        percentageValue = 0;
      });
      return;
    }
    // calculateAdjustedRate applies adjustmentType (+, -, +%, -%, =)
    // against today's base rate — defined once in models.dart.
    adjustedRate = selectedSupplier!.calculateAdjustedRate(todayRate!.baseRate);
    // baseRate is per 100 eggs, so: amount = adjustedRate * qty / 100
    amountBeforePercentage = (adjustedRate * qty) / 100;
    
    // NEW: Apply percentage if supplier has one set
    if (selectedSupplier!.hasPercentage) {
      final breakdown = selectedSupplier!.getPercentageBreakdown(amountBeforePercentage);
      totalAmount = breakdown['finalAmount'] ?? amountBeforePercentage;
      percentageValue = breakdown['percentageValue'] ?? 0;
    } else {
      totalAmount = amountBeforePercentage;
      percentageValue = 0;
    }
    
    setState(() {});
  }

  Future<void> _save() async {
    if (selectedSupplier == null) {
      _snack('Select a supplier');
      return;
    }
    final latestRate = await _loadLatestRateForSave();
    if (latestRate == null) {
      _snack('Set today\'s rate first');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      _snack('Enter valid quantity');
      return;
    }
    final purchaseRate = selectedSupplier!.calculateAdjustedRate(
      latestRate.baseRate,
    );
    if (purchaseRate <= 0) {
      _snack('Invalid rate for this supplier');
      return;
    }
    final basePurchaseAmount = (purchaseRate * qty) / 100;
    final purchaseAmount = selectedSupplier!.applyPercentageToAmount(basePurchaseAmount);

    setState(() => isSaving = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await dbHelper.insertPurchase(
      Purchase.now(
        supplierKey: selectedSupplier!.key as int,
        purchaseDate: today,
        eggQuantity: qty,
        baseRate: latestRate.baseRate,
        adjustedRate: purchaseRate,
        amount: purchaseAmount,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );

    setState(() => isSaving = false);
    if (result.success) {
      _qtyCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        selectedSupplier = null;
        adjustedRate = 0;
        totalAmount = 0;
        amountBeforePercentage = 0;
        percentageValue = 0;
      });
      _snack('Purchase saved!');
    } else {
      _snack(result.error ?? 'Failed');
    }
  }

  Future<DailyRate?> _loadLatestRateForSave() async {
    final rateR = await dbHelper.getTodayRate();
    if (rateR.success && mounted) {
      setState(() {
        todayRate = rateR.data;
      });
      _calc();
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

  Future<void> _addSupplierInline() async {
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
                  'Add Supplier',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter supplier name',
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
                const SizedBox(height: 4),
                const Text(
                  'You can set this supplier\'s rate adjustment (+/-/%) '
                  'and percentage settings later from the Parties screen.',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter supplier name')),
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
                          type: PartyType.supplier,
                        ),
                      );
                      if (r.success && mounted) {
                        Navigator.pop(ctx);
                        await _loadData();
                        setState(() {
                          selectedSupplier = suppliers.firstWhere(
                            (p) => p.name == name,
                            orElse: () => suppliers.last,
                          );
                        });
                        _calc();
                        _snack('Supplier added!');
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (todayRate != null)
                    _RateBanner(rate: todayRate!)
                  else
                    const _WarningBanner(
                      msg: 'Set today\'s rate before adding a purchase',
                    ),
                  const SizedBox(height: 14),

                  const _SectionLabel('Supplier'),
                  const SizedBox(height: 6),
                  PartySelectField(
                    selected: selectedSupplier,
                    label: 'Select Supplier',
                    parties: suppliers,
                    onChanged: (p) {
                      setState(() => selectedSupplier = p);
                      _calc();
                    },
                    onAddNew: _addSupplierInline,
                  ),
                  const SizedBox(height: 14),

                  const _SectionLabel('Egg Quantity'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(fontSize: 13, color: kText),
                    decoration: const InputDecoration(
                      hintText: 'Enter number of eggs',
                      suffixText: 'eggs',
                    ),
                  ),

                  const SizedBox(height: 14),
                  const _SectionLabel('Notes (Optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, color: kText),
                    decoration: const InputDecoration(
                      hintText: 'Any remarks...',
                    ),
                  ),

                  // Show the rate summary card as soon as a supplier AND
                  // today's rate are both known — before qty is typed —
                  // so the user sees exactly what rate will be applied.
                  if (selectedSupplier != null && todayRate != null) ...[
                    const SizedBox(height: 16),
                    _AmountSummary(
                      baseRate: todayRate!.baseRate,
                      adjustedRate: adjustedRate,
                      adjustmentLabel: selectedSupplier!.adjustmentLabel,
                      hasAdjustment: selectedSupplier!.hasAdjustment,
                      amountBeforePercentage: amountBeforePercentage,
                      percentageValue: percentageValue,
                      percentageLabel: selectedSupplier!.percentageLabel,
                      hasPercentage: selectedSupplier!.hasPercentage,
                      total: totalAmount,
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _save,
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Purchase'),
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

/// Shows the base rate, the supplier's adjustment, and the resulting
/// rate paid — then the total. Shown as soon as a supplier is selected
/// so the user always sees the effective rate before entering qty.
/// 
/// NEW: Also shows percentage adjustments if the supplier has them set
class _AmountSummary extends StatelessWidget {
  final double baseRate, adjustedRate, total;
  final double amountBeforePercentage, percentageValue;
  final String adjustmentLabel, percentageLabel;
  final bool hasAdjustment, hasPercentage;
  
  const _AmountSummary({
    required this.baseRate,
    required this.adjustedRate,
    required this.adjustmentLabel,
    required this.hasAdjustment,
    required this.amountBeforePercentage,
    required this.percentageValue,
    required this.percentageLabel,
    required this.hasPercentage,
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
        _Row('Supplier Adjustment', adjustmentLabel),
        _Row('Rate Paid', '₹${adjustedRate.toStringAsFixed(2)} per 100 eggs'),
        
        // NEW: Percentage breakdown
        if (hasPercentage) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.cyan[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                _Row('Amount Before %', '₹${amountBeforePercentage.toStringAsFixed(2)}'),
                _Row('Percentage ($percentageLabel)', '₹${percentageValue.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
        
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
  final String label, value;
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
