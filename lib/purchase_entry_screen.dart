import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';
import 'party_picker_sheet.dart';
import 'party_statement_screen.dart';  // ADD THIS IMPORT

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
  final _adjValueController = TextEditingController();
  final _percValueController = TextEditingController();

  // No manual rate textbox. The rate paid to the supplier is today's
  // base rate run through an adjustment — normally the supplier's saved
  // default, but editable right here for this one purchase only.
  double adjustedRate = 0.0;
  double totalAmount = 0.0;

  double percentageValue = 0.0;
  double amountBeforePercentage = 0.0;

  // Per-purchase rate override. Starts as the selected supplier's saved
  // adjustment/percentage but is fully editable on screen — does not
  // write back to the Party object or change the supplier's saved default.
  String _adjType = '=';
  double _adjValue = 0.0;
  String? _percType;
  double _percValue = 0.0;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  int? _lastRateRevision;

  @override
  void initState() {
    super.initState();
    _loadData();
    _qtyCtrl.addListener(_calc);
    _adjValueController.addListener(_onAdjValueChanged);
    _percValueController.addListener(_onPercValueChanged);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _adjValueController.dispose();
    _percValueController.dispose();
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

  void _onAdjValueChanged() {
    _adjValue = double.tryParse(_adjValueController.text) ?? 0.0;
    _calc();
  }

  void _onPercValueChanged() {
    _percValue = double.tryParse(_percValueController.text) ?? 0.0;
    _calc();
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

  /// Loads this supplier's saved adjustment + percentage into the
  /// on-screen override fields. Called whenever the supplier is
  /// selected/changed, so fields start at the normal default.
  void _applySupplierDefaults(Party? p) {
    _adjType = p?.adjustmentType ?? '=';
    _adjValue = p?.adjustmentValue ?? 0.0;
    _adjValueController.text = _adjValue == 0 ? '' : _adjValue.toString();
    _percType = p?.percentageType;
    _percValue = p?.percentageValue ?? 0.0;
    _percValueController.text = _percValue == 0 ? '' : _percValue.toString();
  }

  void _resetToSupplierDefault() {
    if (selectedSupplier == null) return;
    setState(() => _applySupplierDefaults(selectedSupplier));
    _calc();
  }

  double _adjustedRateFor(double baseRate) {
    switch (_adjType) {
      case '+':
        return baseRate + _adjValue;
      case '-':
        final r = baseRate - _adjValue;
        return r < 0 ? 0 : r;
      case '+%':
        return baseRate * (1 + _adjValue / 100);
      case '-%':
        final r = baseRate * (1 - _adjValue / 100);
        return r < 0 ? 0 : r;
      case '=':
      default:
        return baseRate;
    }
  }

  double _percentageAmountFor(double amount) {
    if (_percType == null || _percValue == 0) return 0;
    return (amount * _percValue) / 100;
  }

  double _applyPercentageFor(double amount) {
    if (_percType == null || _percValue == 0) return amount;
    final pv = (amount * _percValue) / 100;
    switch (_percType) {
      case 'discount':
        return amount - pv;
      case 'markup':
        return amount + pv;
      case 'tax':
        return amount + pv;
      default:
        return amount;
    }
  }

  String get _adjLabel {
    switch (_adjType) {
      case '+':
        return '+₹${_adjValue.toStringAsFixed(_adjValue % 1 == 0 ? 0 : 2)}';
      case '-':
        return '-₹${_adjValue.toStringAsFixed(_adjValue % 1 == 0 ? 0 : 2)}';
      case '+%':
        return '+${_adjValue.toStringAsFixed(_adjValue % 1 == 0 ? 0 : 1)}%';
      case '-%':
        return '-${_adjValue.toStringAsFixed(_adjValue % 1 == 0 ? 0 : 1)}%';
      case '=':
      default:
        return '=';
    }
  }

  String get _percLabel {
    if (_percType == null || _percValue == 0) return 'None';
    final t = _percType![0].toUpperCase() + _percType!.substring(1);
    return '$t: ${_percValue.toStringAsFixed(_percValue % 1 == 0 ? 0 : 1)}%';
  }

  /// Recalculates the supplier's effective rate from today's base rate
  /// (run through the on-screen override) and updates the total. Runs
  /// whenever the supplier changes, today's rate loads, the quantity
  /// changes, or the override fields change.
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
    adjustedRate = _adjustedRateFor(todayRate!.baseRate);
    // baseRate is per 100 eggs, so: amount = adjustedRate * qty / 100
    amountBeforePercentage = (adjustedRate * qty) / 100;

    if (_percType != null && _percValue != 0) {
      percentageValue = _percentageAmountFor(amountBeforePercentage);
      totalAmount = _applyPercentageFor(amountBeforePercentage);
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
    final purchaseRate = _adjustedRateFor(latestRate.baseRate);
    if (purchaseRate <= 0) {
      _snack('Invalid rate for this supplier');
      return;
    }
    final basePurchaseAmount = (purchaseRate * qty) / 100;
    final purchaseAmount = _applyPercentageFor(basePurchaseAmount);

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
        _adjType = '=';
        _adjValue = 0;
        _adjValueController.clear();
        _percType = null;
        _percValue = 0;
        _percValueController.clear();
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
                          _applySupplierDefaults(selectedSupplier);
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
                  // MODIFIED: Added Row with Statement button
                  Row(
                    children: [
                      Expanded(
                        child: PartySelectField(
                          selected: selectedSupplier,
                          label: 'Select Supplier',
                          parties: suppliers,
                          onChanged: (p) {
                            setState(() {
                              selectedSupplier = p;
                              _applySupplierDefaults(p);
                            });
                            _calc();
                          },
                          onAddNew: _addSupplierInline,
                        ),
                      ),
                      if (selectedSupplier != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                          label: const Text('Statement'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PartyStatementScreen(party: selectedSupplier!),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
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

                  if (selectedSupplier != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel('Rate Adjustment (this purchase)'),
                        InkWell(
                          onTap: _resetToSupplierDefault,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, size: 12, color: kBlue),
                                SizedBox(width: 3),
                                Text(
                                  'Reset to default',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: kBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _AdjustmentEditor(
                      adjType: _adjType,
                      controller: _adjValueController,
                      onTypeChanged: (v) {
                        setState(() => _adjType = v);
                        _calc();
                      },
                    ),
                    const SizedBox(height: 14),
                    const _SectionLabel('Percentage (this purchase)'),
                    const SizedBox(height: 6),
                    _PercentageEditor(
                      percType: _percType,
                      controller: _percValueController,
                      onTypeChanged: (v) {
                        setState(() => _percType = v == 'none' ? null : v);
                        _calc();
                      },
                    ),
                  ],

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
                      adjustmentLabel: _adjLabel,
                      hasAdjustment: _adjType != '=' && _adjValue != 0,
                      amountBeforePercentage: amountBeforePercentage,
                      percentageValue: percentageValue,
                      percentageLabel: _percLabel,
                      hasPercentage: _percType != null && _percValue != 0,
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

/// Chip row for choosing the adjustment mode (=, +, -, +%, -%) plus an
/// inline value field. Editable per-transaction — does not write back
/// to the Party object or change the supplier's saved default.
class _AdjustmentEditor extends StatelessWidget {
  final String adjType;
  final TextEditingController controller;
  final ValueChanged<String> onTypeChanged;

  const _AdjustmentEditor({
    required this.adjType,
    required this.controller,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const modes = ['=', '+', '-', '+%', '-%'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...modes.map((m) {
              final selected = adjType == m;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => onTypeChanged(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kBlue : kCard,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: selected ? kBlue : kBorder),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : kTextSub,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (adjType != '=') ...[
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: adjType.contains('%') ? '% value' : '₹ value',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (adjType == '=')
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Same as today\'s base rate',
              style: TextStyle(fontSize: 10, color: kTextMuted),
            ),
          ),
      ],
    );
  }
}

/// Chip row for choosing percentage type (none/discount/markup/tax) plus
/// an inline value field. Editable per-transaction.
class _PercentageEditor extends StatelessWidget {
  final String? percType;
  final TextEditingController controller;
  final ValueChanged<String> onTypeChanged;

  const _PercentageEditor({
    required this.percType,
    required this.controller,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const types = ['none', 'discount', 'markup', 'tax'];
    final current = percType ?? 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: types.map((t) {
            final selected = current == t;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onTypeChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? kBlue : kCard,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: selected ? kBlue : kBorder),
                  ),
                  child: Text(
                    t == 'none' ? 'None' : t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : kTextSub,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (current != 'none') ...[
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'e.g., 10',
              suffixText: '%',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shows the base rate, the on-screen adjustment override, and the
/// resulting rate paid — then the total. Shown as soon as a supplier is
/// selected so the user always sees the effective rate before entering qty.
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