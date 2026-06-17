import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';

class PartyLedgerScreen extends StatefulWidget {
  final Party party;

  const PartyLedgerScreen({super.key, required this.party});

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> transactions = [];
  double currentBalance = 0.0;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() { isLoading = true; error = null; });
    try {
      final salesResult = await dbHelper.getSalesByParty(widget.party);
      final purchasesResult = await dbHelper.getPurchasesBySupplier(widget.party);
      final paymentsResult = await dbHelper.getPaymentsByParty(widget.party);
      final balanceResult = await dbHelper.getPartyBalance(widget.party);

      if (!mounted) return;

      if (salesResult.success && purchasesResult.success && paymentsResult.success && balanceResult.success) {
        final allTransactions = <Map<String, dynamic>>[
          ...salesResult.data?.map((s) => {'type': 'sale', 'data': s}).toList() ?? [],
          ...purchasesResult.data?.map((p) => {'type': 'purchase', 'data': p}).toList() ?? [],
          ...paymentsResult.data?.map((p) => {'type': 'payment', 'data': p}).toList() ?? [],
        ];

        allTransactions.sort((a, b) {
          final dateA = _getCreatedAt(a);
          final dateB = _getCreatedAt(b);
          return dateB.compareTo(dateA);
        });

        setState(() {
          transactions = allTransactions;
          currentBalance = balanceResult.data ?? 0.0;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          error = salesResult.error ?? purchasesResult.error ?? paymentsResult.error ?? balanceResult.error;
        });
      }
    } catch (e) {
      debugPrint('Ledger load error: $e');
      if (mounted) {
        setState(() { isLoading = false; error = 'Failed to load ledger: $e'; });
      }
    }
  }

  // Used for sorting — actual createdAt timestamp (has time), not just the date string.
  DateTime _getCreatedAt(Map<String, dynamic> t) {
    if (t['type'] == 'sale') {
      return (t['data'] as SaleWithParty).sale.createdAt;
    } else if (t['type'] == 'purchase') {
      return (t['data'] as PurchaseWithSupplier).purchase.createdAt;
    } else {
      return (t['data'] as PaymentWithParty).payment.createdAt;
    }
  }

  Future<void> _showPaymentDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String paymentType = widget.party.type == PartyType.customer ? 'received' : 'paid';
    DateTime selectedDate = DateTime.now();

    if (!mounted) return;

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
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: kBorder,
                    borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                const Text('Add Payment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
                const SizedBox(height: 16),

                // Date picker row
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: kAmber),
                        const SizedBox(width: 10),
                        Text(DateFormat('d MMM yyyy').format(selectedDate),
                          style: const TextStyle(fontSize: 13, color: kText)),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Payment type — clean chips, not a dropdown
                const Text('Payment Type', style: TextStyle(fontSize: 11.5, color: kTextSub)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceChip(
                        label: 'Received', selected: paymentType == 'received',
                        onTap: () => setSheet(() => paymentType = 'received'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoiceChip(
                        label: 'Paid', selected: paymentType == 'paid',
                        onTap: () => setSheet(() => paymentType = 'paid'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kAmber),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      final notes = notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim();

                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')));
                        return;
                      }

                      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                      final newPayment = Payment.now(
                        partyKey: widget.party.key as int,
                        date: dateStr,
                        amount: amount,
                        notes: notes,
                        paymentType: paymentType,
                      );
                      final result = await dbHelper.insertPayment(newPayment);
                      if (result.success) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadTransactions();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment added')));
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.error ?? 'Failed to add payment')));
                        }
                      }
                    },
                    child: const Text('Save Payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareStatement() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Party Statement',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Party Name: ${widget.party.name}'),
              if (widget.party.phone != null) pw.Text('Phone: ${widget.party.phone}'),
              if (widget.party.address != null) pw.Text('Address: ${widget.party.address}'),
              pw.SizedBox(height: 8),
              pw.Text('Current Balance: ₹${currentBalance.abs().toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 24),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Time', 'Type', 'Description', 'Amount'],
                data: transactions.map((t) => _getTransactionRow(t)).toList(),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/statement.pdf');
    await file.writeAsBytes(await pdf.save());

    Share.shareXFiles([XFile(file.path)], text: 'Party statement for ${widget.party.name}');
  }

  List<String> _getTransactionRow(Map<String, dynamic> t) {
    final createdAt = _getCreatedAt(t);
    final dateStr = DateFormat('MMM d, yyyy').format(createdAt);
    final timeStr = DateFormat('h:mm a').format(createdAt);

    if (t['type'] == 'sale') {
      final s = t['data'] as SaleWithParty;
      return [dateStr, timeStr, 'Sale', '${s.sale.eggQuantity.toStringAsFixed(0)} eggs',
        '+₹${s.sale.amount.toStringAsFixed(2)}'];
    } else if (t['type'] == 'purchase') {
      final p = t['data'] as PurchaseWithSupplier;
      return [dateStr, timeStr, 'Purchase', '${p.purchase.eggQuantity.toStringAsFixed(0)} eggs',
        '-₹${p.purchase.amount.toStringAsFixed(2)}'];
    } else {
      final p = t['data'] as PaymentWithParty;
      final desc = p.payment.paymentType == 'received' ? 'Received' : 'Paid';
      final amount = p.payment.paymentType == 'received'
          ? '-₹${p.payment.amount.toStringAsFixed(2)}'
          : '+₹${p.payment.amount.toStringAsFixed(2)}';
      return [dateStr, timeStr, 'Payment', desc, amount];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: kText,
        title: Text(widget.party.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: kTextSub),
            onPressed: _shareStatement,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPaymentDialog,
        backgroundColor: kAmber,
        foregroundColor: Colors.white,
        child: const Icon(Icons.payment_rounded),
      ),
      body: Column(
        children: [
          // Balance card — single clean line, no red box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            color: kCard,
            child: Column(
              children: [
                const Text('Current Balance',
                  style: TextStyle(fontSize: 11.5, color: kTextSub, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('₹${currentBalance.abs().toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kText)),
                const SizedBox(height: 2),
                Text(
                  currentBalance > 0
                      ? 'You will get'
                      : currentBalance < 0
                          ? 'You have to pay'
                          : 'No balance due',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: currentBalance > 0 ? kGreen : currentBalance < 0 ? kRed : kTextSub,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kBorder),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              color: kAmber,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: kAmber))
                  : error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(error!,
                                  style: const TextStyle(color: kTextSub, fontSize: 12),
                                  textAlign: TextAlign.center),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _loadTransactions,
                                  icon: const Icon(Icons.refresh_rounded, size: 15),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : transactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 52, height: 52,
                                    decoration: BoxDecoration(color: kAmberLight,
                                      borderRadius: BorderRadius.circular(14)),
                                    child: const Icon(Icons.receipt_long_rounded,
                                      color: kAmber, size: 26)),
                                  const SizedBox(height: 12),
                                  const Text('No transactions yet',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: kText)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: transactions.length,
                              itemBuilder: (context, index) {
                                final t = transactions[index];
                                final createdAt = _getCreatedAt(t);
                                final dateLabel = DateFormat('d MMM yyyy').format(createdAt);
                                final timeLabel = DateFormat('h:mm a').format(createdAt);

                                String type, desc, amount;
                                Color amtColor, iconColor, iconBg;
                                IconData icon;

                                if (t['type'] == 'sale') {
                                  final s = t['data'] as SaleWithParty;
                                  type = 'Sale';
                                  desc = '${s.sale.eggQuantity.toStringAsFixed(0)} eggs';
                                  amount = '+₹${s.sale.amount.toStringAsFixed(2)}';
                                  amtColor = kGreen;
                                  icon = Icons.trending_up_rounded;
                                  iconColor = kGreen;
                                  iconBg = const Color(0xFFDCFCE7);
                                } else if (t['type'] == 'purchase') {
                                  final p = t['data'] as PurchaseWithSupplier;
                                  type = 'Purchase';
                                  desc = '${p.purchase.eggQuantity.toStringAsFixed(0)} eggs';
                                  amount = '-₹${p.purchase.amount.toStringAsFixed(2)}';
                                  amtColor = kRed;
                                  icon = Icons.trending_down_rounded;
                                  iconColor = kRed;
                                  iconBg = const Color(0xFFFEE2E2);
                                } else {
                                  final p = t['data'] as PaymentWithParty;
                                  type = 'Payment';
                                  desc = p.payment.paymentType == 'received' ? 'Received' : 'Paid';
                                  if (p.payment.notes != null) desc += ' · ${p.payment.notes}';
                                  amount = p.payment.paymentType == 'received'
                                      ? '-₹${p.payment.amount.toStringAsFixed(2)}'
                                      : '+₹${p.payment.amount.toStringAsFixed(2)}';
                                  amtColor = p.payment.paymentType == 'received' ? kRed : kGreen;
                                  icon = Icons.swap_horiz_rounded;
                                  iconColor = p.payment.paymentType == 'received' ? kRed : kGreen;
                                  iconBg = p.payment.paymentType == 'received'
                                      ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: kCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          color: iconBg, borderRadius: BorderRadius.circular(9)),
                                        child: Icon(icon, color: iconColor, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(type, style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                                            const SizedBox(height: 1),
                                            Text(desc, style: const TextStyle(
                                              fontSize: 11, color: kTextSub)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(amount, style: TextStyle(
                                            fontSize: 13.5, fontWeight: FontWeight.w700, color: amtColor)),
                                          const SizedBox(height: 1),
                                          Text('$dateLabel · $timeLabel', style: const TextStyle(
                                            fontSize: 10.5, color: kTextMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? kAmber : kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? kAmber : kBorder),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12.5, fontWeight: FontWeight.w600,
        color: selected ? Colors.white : kTextSub,
      )),
    ),
  );
}