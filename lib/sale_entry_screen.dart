import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';
import 'party_picker_sheet.dart';
import 'party_statement_screen.dart';  // ADD THIS IMPORT

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

  // Percentage fields
  double percentageValue = 0.0;
  double amountBeforePercentage = 0.0;

  // ── Inline rate / percentage override (editable per-sale, right on this screen) ──
  String overrideAdjType = '=';
  final _overrideAdjCtrl = TextEditingController();
  String? overridePercType;
  final _overridePercCtrl = TextEditingController();
  final _overridePercMinQtyCtrl = TextEditingController(); // NEW
  bool _saveAsDefault = false;
  Party? _previewParty; // transient Party built from the override fields above, used only for calculation

  // NEW: Payment received right on this screen (e.g. sold 200 eggs on
  // credit, customer paid ₹100 now) — creates a Payment record alongside
  // the Sale so the ledger/statement immediately reflect what's still due.
  final _paymentReceivedCtrl = TextEditingController();
  // NEW: date + notes for the payment itself (separate from the sale's
  // own Notes field below) — matches the Add Payment dialog on the
  // Party Ledger screen (date picker, optional notes).
  DateTime _paymentDate = DateTime.now();
  final _paymentNotesCtrl = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  int? _lastRateRevision;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quantityController.addListener(_calculateAmount);
    _overrideAdjCtrl.addListener(_calculateAmount);
    _overridePercCtrl.addListener(_calculateAmount);
    _overridePercMinQtyCtrl.addListener(_calculateAmount); // NEW
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
    _overrideAdjCtrl.dispose();
    _overridePercCtrl.dispose();
    _overridePercMinQtyCtrl.dispose(); // NEW
    _paymentReceivedCtrl.dispose(); // NEW
    _paymentNotesCtrl.dispose(); // NEW
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

  String _trimZero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  /// Pre-fills the inline override controls from the party's saved
  /// adjustment/percentage settings. Called whenever a party is selected.
  void _setOverrideFromParty(Party p) {
    overrideAdjType = p.adjustmentType;
    _overrideAdjCtrl.text = p.adjustmentValue == 0 ? '' : _trimZero(p.adjustmentValue);
    overridePercType = p.percentageType;
    _overridePercCtrl.text = p.percentageValue == 0 ? '' : _trimZero(p.percentageValue);
    _overridePercMinQtyCtrl.text =
        p.percentageMinQuantity == 0 ? '' : _trimZero(p.percentageMinQuantity); // NEW
    _saveAsDefault = false;
    _paymentReceivedCtrl.clear(); // NEW: fresh payment field per party/sale
    _paymentDate = DateTime.now(); // NEW
    _paymentNotesCtrl.clear(); // NEW
  }

  void _calculateAmount() {
    if (selectedParty == null || todayRate == null) {
      setState(() {
        adjustedRate = 0;
        totalAmount = 0;
        amountBeforePercentage = 0;
        percentageValue = 0;
        _previewParty = null;
      });
      return;
    }
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final adjVal = double.tryParse(_overrideAdjCtrl.text) ?? 0.0;
    final percVal = double.tryParse(_overridePercCtrl.text) ?? 0.0;
    final percMinQty = double.tryParse(_overridePercMinQtyCtrl.text) ?? 0.0; // NEW

    // Build a transient Party from the on-screen override values and reuse
    // the exact same calculation methods the model already defines, so the
    // math here can never drift from the rest of the app.
    _previewParty = Party.now(
      name: selectedParty!.name,
      adjustmentType: overrideAdjType,
      adjustmentValue: adjVal,
      type: selectedParty!.type,
      percentageType: percVal > 0 ? overridePercType : null,
      percentageValue: percVal,
      percentageMinQuantity: percMinQty, // NEW
    );

    adjustedRate = _previewParty!.calculateAdjustedRate(todayRate!.baseRate);
    amountBeforePercentage = (adjustedRate * qty) / 100;

    // Only apply the percentage if the entered quantity meets the
    // party's minimum-quantity threshold (0/empty = always applies).
    if (_previewParty!.percentageActiveForQuantity(qty)) {
      final breakdown = _previewParty!.getPercentageBreakdown(amountBeforePercentage, qty);
      totalAmount = breakdown['finalAmount'] ?? amountBeforePercentage;
      percentageValue = breakdown['percentageValue'] ?? 0;
    } else {
      totalAmount = amountBeforePercentage;
      percentageValue = 0;
    }

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

    // NEW: validate payment received (if any) before saving anything.
    final paymentAmt = double.tryParse(_paymentReceivedCtrl.text) ?? 0.0;
    if (paymentAmt < 0) {
      _snack('Payment received cannot be negative');
      return;
    }

    setState(() => isSaving = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final preview = _previewParty ?? selectedParty!;
    final saleRate = preview.calculateAdjustedRate(latestRate.baseRate);
    final baseSaleAmount = (saleRate * qty) / 100;
    final saleAmount = preview.applyPercentageToAmount(baseSaleAmount, qty); // NEW: pass qty
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

    // If asked, push the on-screen override back to the party's permanent
    // default so future sales to this party start from the new rate.
    if (result.success && _saveAsDefault) {
      selectedParty!.adjustmentType = preview.adjustmentType;
      selectedParty!.adjustmentValue = preview.adjustmentValue;
      selectedParty!.percentageType = preview.percentageType;
      selectedParty!.percentageValue = preview.percentageValue;
      selectedParty!.percentageMinQuantity = preview.percentageMinQuantity; // NEW
      await dbHelper.updateParty(selectedParty!);
    }

    // NEW: if a payment was received right now for this sale (e.g. sold
    // on credit, customer paid part now), create a matching Payment
    // record so the ledger/statement/balance reflect it immediately.
    if (result.success && paymentAmt > 0) {
      final paymentDateStr = DateFormat('yyyy-MM-dd').format(_paymentDate);
      final paymentNotes = _paymentNotesCtrl.text.trim().isEmpty
          ? 'Payment received against sale'
          : _paymentNotesCtrl.text.trim();
      await dbHelper.insertPayment(
        Payment.now(
          partyKey: selectedParty!.key as int,
          date: paymentDateStr,
          amount: paymentAmt,
          notes: paymentNotes,
          paymentType: 'received',
        ),
      );
    }

    setState(() => isSaving = false);
    if (result.success) {
      _quantityController.clear();
      _notesController.clear();
      setState(() {
        selectedParty = null;
        adjustedRate = 0;
        totalAmount = 0;
        amountBeforePercentage = 0;
        percentageValue = 0;
        overrideAdjType = '=';
        _overrideAdjCtrl.clear();
        overridePercType = null;
        _overridePercCtrl.clear();
        _overridePercMinQtyCtrl.clear(); // NEW
        _paymentReceivedCtrl.clear(); // NEW
        _paymentDate = DateTime.now(); // NEW
        _paymentNotesCtrl.clear(); // NEW
        _saveAsDefault = false;
        _previewParty = null;
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
                          _setOverrideFromParty(selectedParty!);
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
      backgroundColor: Colors.transparent,
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
                      // MODIFIED: Added Row with Statement button
                      Row(
                        children: [
                          Expanded(
                            child: PartySelectField(
                              selected: selectedParty,
                              label: 'Select Customer',
                              parties: parties,
                              onChanged: (p) {
                                setState(() {
                                  selectedParty = p;
                                  if (p != null) _setOverrideFromParty(p);
                                });
                                _calculateAmount();
                              },
                              onAddNew: _addPartyInline,
                            ),
                          ),
                          if (selectedParty != null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.receipt_long_rounded, size: 16),
                              label: const Text('Statement'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PartyStatementScreen(party: selectedParty!),
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
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, color: kText),
                        decoration: const InputDecoration(
                          hintText: 'Enter number of eggs',
                          suffixText: 'eggs',
                          suffixStyle: TextStyle(fontSize: 12, color: kTextSub),
                        ),
                      ),
                      if (selectedParty != null) ...[
                        const SizedBox(height: 14),
                        _RateAdjustmentCard(
                          partyName: selectedParty!.name,
                          adjType: overrideAdjType,
                          adjCtrl: _overrideAdjCtrl,
                          onAdjTypeChanged: (v) {
                            overrideAdjType = v;
                            _calculateAmount();
                          },
                          percType: overridePercType,
                          percCtrl: _overridePercCtrl,
                          onPercTypeChanged: (v) {
                            overridePercType = v;
                            _calculateAmount();
                          },
                          percMinQtyCtrl: _overridePercMinQtyCtrl, // NEW
                          saveAsDefault: _saveAsDefault,
                          onSaveAsDefaultChanged: (v) =>
                              setState(() => _saveAsDefault = v),
                          actionLabel: 'sale',
                        ),
                        // NEW: Payment Received card — sits right below the
                        // Rate Adjustment card, per the agreed screen order.
                        const SizedBox(height: 14),
                        _PaymentReceivedCard(
                          partyName: selectedParty!.name,
                          controller: _paymentReceivedCtrl,
                          paymentDate: _paymentDate,
                          onDateChanged: (d) => setState(() => _paymentDate = d),
                          notesController: _paymentNotesCtrl,
                        ),
                      ],
                      const SizedBox(height: 14),
                      const _SectionLabel('Notes (Optional)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13, color: kText),
                        decoration: const InputDecoration(hintText: 'Any remarks...'),
                      ),
                      if (selectedParty != null && todayRate != null && _previewParty != null) ...[
                        const SizedBox(height: 16),
                        _AmountSummary(
                          baseRate: todayRate!.baseRate,
                          adjustedRate: adjustedRate,
                          adjustmentLabel: _previewParty!.adjustmentLabel,
                          hasAdjustment: _previewParty!.hasAdjustment,
                          amountBeforePercentage: amountBeforePercentage,
                          percentageValue: percentageValue,
                          percentageLabel: _previewParty!.percentageLabel,
                          hasPercentage: _previewParty!.percentageActiveForQuantity(
                            double.tryParse(_quantityController.text) ?? 0.0,
                          ), // MODIFIED: gate on quantity threshold
                          total: totalAmount,
                          // NEW: shows what will remain due after the
                          // payment-received amount is applied.
                          paymentReceived: double.tryParse(_paymentReceivedCtrl.text) ?? 0.0,
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

/// Inline, editable rate-adjustment + percentage card shown right on the
/// Sale/Purchase entry screen. Lets the owner change the rate or
/// percentage for *this* transaction on the fly, and optionally save it
/// back as the party's new default via [onSaveAsDefaultChanged].
class _RateAdjustmentCard extends StatelessWidget {
  final String partyName;
  final String adjType;
  final TextEditingController adjCtrl;
  final ValueChanged<String> onAdjTypeChanged;
  final String? percType;
  final TextEditingController percCtrl;
  final ValueChanged<String?> onPercTypeChanged;
  final TextEditingController percMinQtyCtrl; // NEW
  final bool saveAsDefault;
  final ValueChanged<bool> onSaveAsDefaultChanged;
  final String actionLabel; // 'sale' or 'purchase'

  const _RateAdjustmentCard({
    required this.partyName,
    required this.adjType,
    required this.adjCtrl,
    required this.onAdjTypeChanged,
    required this.percType,
    required this.percCtrl,
    required this.onPercTypeChanged,
    required this.percMinQtyCtrl, // NEW
    required this.saveAsDefault,
    required this.onSaveAsDefaultChanged,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    const adjModes = ['=', '+', '-'];
    const percTypes = <String, String>{
      'discount': 'Discount',
      'markup': 'Markup',
      'tax': 'Tax',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate for this $actionLabel · $partyName',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Rate Adjustment', style: TextStyle(fontSize: 11, color: kTextSub)),
          const SizedBox(height: 6),
          Row(
            children: [
              ...adjModes.map((m) {
                final selected = adjType == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GestureDetector(
                    onTap: () => onAdjTypeChanged(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? kBlue : kSurface,
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
                    controller: adjCtrl,
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
          const SizedBox(height: 12),
          const Text(
            'Percentage (Discount / Markup / Tax)',
            style: TextStyle(fontSize: 11, color: kTextSub),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _PercChip(
                label: 'None',
                selected: percType == null,
                onTap: () => onPercTypeChanged(null),
              ),
              const SizedBox(width: 6),
              ...percTypes.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _PercChip(
                    label: e.value,
                    selected: percType == e.key,
                    onTap: () => onPercTypeChanged(e.key),
                  ),
                ),
              ),
            ],
          ),
          if (percType != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: percCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'e.g., 10',
                suffixText: '%',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
            // NEW: Minimum quantity field for this transaction's percentage
            const SizedBox(height: 8),
            TextField(
              controller: percMinQtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Minimum quantity (optional)',
                suffixText: 'eggs',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Leave empty or 0 to always apply the percentage.',
              style: TextStyle(fontSize: 10, color: kTextMuted),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => onSaveAsDefaultChanged(!saveAsDefault),
            child: Row(
              children: [
                Checkbox(
                  value: saveAsDefault,
                  onChanged: (v) => onSaveAsDefaultChanged(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Save this as default rate for $partyName',
                    style: const TextStyle(fontSize: 11, color: kTextSub),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// NEW: "Payment Received" card — sits below the Rate Adjustment card.
/// Lets the owner record how much the customer actually paid *right now*
/// for this sale (e.g. sold 200 eggs on credit, paid ₹100 now). Saving
/// the sale will create a matching Payment record automatically, so the
/// ledger/statement instantly show what's still due.
class _PaymentReceivedCard extends StatelessWidget {
  final String partyName;
  final TextEditingController controller;
  final DateTime paymentDate;
  final ValueChanged<DateTime> onDateChanged;
  final TextEditingController notesController;

  const _PaymentReceivedCard({
    required this.partyName,
    required this.controller,
    required this.paymentDate,
    required this.onDateChanged,
    required this.notesController,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.payments_rounded, size: 14, color: kGreen),
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Received (from $partyName)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // NEW: date picker row — same style as the Party Ledger's Add
          // Payment sheet, so a backdated payment can be recorded here too.
          GestureDetector(
            onTap: () => _pickDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: kGreen),
                  const SizedBox(width: 9),
                  Text(
                    DateFormat('d MMM yyyy').format(paymentDate),
                    style: const TextStyle(fontSize: 12.5, color: kText),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 15, color: kTextMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, color: kText),
            decoration: const InputDecoration(
              hintText: 'e.g., 100',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Leave empty or 0 if this is a full-credit sale (nothing paid '
            'now). Whatever isn\'t paid stays as balance due on this party.',
            style: TextStyle(fontSize: 10, color: kTextMuted),
          ),
          // NEW: optional notes for this payment specifically (separate
          // from the sale's own Notes field further down the screen).
          const SizedBox(height: 10),
          TextField(
            controller: notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: kText),
            decoration: const InputDecoration(
              labelText: 'Payment Notes (Optional)',
              hintText: 'e.g., Paid via UPI',
            ),
          ),
        ],
      ),
    );
  }
}

class _PercChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PercChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.cyan[600] : kSurface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? Colors.cyan[600]! : kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kTextSub,
            ),
          ),
        ),
      );
}

class _AmountSummary extends StatelessWidget {
  final double baseRate, adjustedRate, total;
  final double amountBeforePercentage, percentageValue;
  final String adjustmentLabel, percentageLabel;
  final bool hasAdjustment, hasPercentage;
  final double paymentReceived; // NEW

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
    this.paymentReceived = 0.0, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final due = (total - paymentReceived).clamp(0, double.infinity);
    return Container(
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

            // Percentage breakdown
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

            // NEW: shows Received / Balance Due when a payment amount has
            // been entered on this screen for this sale.
            if (paymentReceived > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    _Row('Received Now', '₹${paymentReceived.toStringAsFixed(2)}'),
                    _Row(
                      'Balance Due',
                      due == 0 ? 'Fully Paid' : '₹${due.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
  }
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