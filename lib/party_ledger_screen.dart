import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'database_helper.dart';

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
    setState(() {
      isLoading = true;
      error = null;
    });
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

        // Sort by date
        allTransactions.sort((a, b) {
          final dateA = _getTransactionDate(a);
          final dateB = _getTransactionDate(b);
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
        setState(() {
          isLoading = false;
          error = 'Failed to load ledger: $e';
        });
      }
    }
  }

  DateTime _getTransactionDate(Map<String, dynamic> t) {
    if (t['type'] == 'sale') {
      final s = t['data'] as SaleWithParty;
      return DateFormat('yyyy-MM-dd').parse(s.sale.saleDate);
    } else if (t['type'] == 'purchase') {
      final p = t['data'] as PurchaseWithSupplier;
      return DateFormat('yyyy-MM-dd').parse(p.purchase.purchaseDate);
    } else {
      final p = t['data'] as PaymentWithParty;
      return DateFormat('yyyy-MM-dd').parse(p.payment.date);
    }
  }

  Future<void> _showPaymentDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String paymentType = widget.party.type == PartyType.customer ? 'received' : 'paid';
    DateTime selectedDate = DateTime.now();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setDateState) => ListTile(
                    title: Text(
                      DateFormat('MMM d, yyyy').format(selectedDate),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && picked != selectedDate) {
                        setDateState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentType,
                  decoration: const InputDecoration(
                    labelText: 'Payment Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'received', child: Text('Received')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        paymentType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                final notes = notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim();

                if (amount == null || amount <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                  }
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
                    Navigator.pop(dialogContext);
                    _loadTransactions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment added successfully!')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.error ?? 'Failed to add payment')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
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
              pw.Text(
                'Party Statement',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Party Name: ${widget.party.name}'),
              if (widget.party.phone != null) pw.Text('Phone: ${widget.party.phone}'),
              if (widget.party.address != null) pw.Text('Address: ${widget.party.address}'),
              pw.SizedBox(height: 8),
              pw.Text(
                'Current Balance: ₹${currentBalance.abs().toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 24),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Type', 'Description', 'Amount'],
                data: transactions.map((t) {
                  return _getTransactionRow(t);
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/statement.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share
    Share.shareXFiles([XFile(file.path)], text: 'Party statement for ${widget.party.name}');
  }

  List<String> _getTransactionRow(Map<String, dynamic> t) {
    if (t['type'] == 'sale') {
      final s = t['data'] as SaleWithParty;
      return [
        DateFormat('MMM d, yyyy').format(DateFormat('yyyy-MM-dd').parse(s.sale.saleDate)),
        'Sale',
        '${s.sale.eggQuantity.toStringAsFixed(0)} eggs',
        '+₹${s.sale.amount.toStringAsFixed(2)}'
      ];
    } else if (t['type'] == 'purchase') {
      final p = t['data'] as PurchaseWithSupplier;
      return [
        DateFormat('MMM d, yyyy').format(DateFormat('yyyy-MM-dd').parse(p.purchase.purchaseDate)),
        'Purchase',
        '${p.purchase.eggQuantity.toStringAsFixed(0)} eggs',
        '-₹${p.purchase.amount.toStringAsFixed(2)}'
      ];
    } else {
      final p = t['data'] as PaymentWithParty;
      final desc = p.payment.paymentType == 'received' ? 'Received' : 'Paid';
      final amount = p.payment.paymentType == 'received'
          ? '-₹${p.payment.amount.toStringAsFixed(2)}'
          : '+₹${p.payment.amount.toStringAsFixed(2)}';
      return [
        DateFormat('MMM d, yyyy').format(DateFormat('yyyy-MM-dd').parse(p.payment.date)),
        'Payment',
        desc,
        amount
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.party.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _shareStatement,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${currentBalance.abs().toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  currentBalance > 0
                      ? 'You will get'
                      : currentBalance < 0
                          ? 'You have to pay'
                          : 'No balance',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: isLoading
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
                                  onPressed: _loadTransactions,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : transactions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: transactions.length,
                              itemBuilder: (context, index) {
                                final t = transactions[index];
                                String date;
                                String type;
                                String desc;
                                String amount;
                                Color amountColor;
                                IconData icon;
                                Color iconColor;

                                if (t['type'] == 'sale') {
                                  final s = t['data'] as SaleWithParty;
                                  date = DateFormat('MMM d, yyyy').format(DateFormat('yyyy-MM-dd').parse(s.sale.saleDate));
                                  type = 'Sale';
                                  desc = '${s.sale.eggQuantity.toStringAsFixed(0)} eggs';
                                  amount = '+₹${s.sale.amount.toStringAsFixed(2)}';
                                  amountColor = Colors.green;
                                  icon = Icons.shopping_cart;
                                  iconColor = Colors.green;
                                } else if (t['type'] == 'purchase') {
                                  final p = t['data'] as PurchaseWithSupplier;
                                  date = DateFormat('MMM d, yyyy').format(DateFormat('yyyy-MM-dd').parse(p.purchase.purchaseDate));
                                  type = 'Purchase';
                                  desc = '${p.purchase.eggQuantity.toStringAsFixed(0)} eggs';
                                  amount = '-₹${p.purchase.amount.toStringAsFixed(2)}';
                                  amountColor = Colors.red;
                                  icon = Icons.shopping_bag;
                                  iconColor = Colors.red;
                                } else {
                                  final p = t['data'] as PaymentWithParty;
                                  date = DateFormat('MMM d, yyyy').format(DateFormat('yyyy-MM-dd').parse(p.payment.date));
                                  type = 'Payment';
                                  desc = p.payment.paymentType == 'received' ? 'Received' : 'Paid';
                                  if (p.payment.notes != null) {
                                    desc += ' - ${p.payment.notes}';
                                  }
                                  amount = p.payment.paymentType == 'received'
                                      ? '-₹${p.payment.amount.toStringAsFixed(2)}'
                                      : '+₹${p.payment.amount.toStringAsFixed(2)}';
                                  amountColor = p.payment.paymentType == 'received' ? Colors.red : Colors.green;
                                  icon = Icons.payment;
                                  iconColor = p.payment.paymentType == 'received' ? Colors.red : Colors.green;
                                }

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: iconColor.withValues(alpha: 0.1),
                                      child: Icon(icon, color: iconColor),
                                    ),
                                    title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(date),
                                        Text(desc),
                                      ],
                                    ),
                                    trailing: Text(
                                      amount,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: amountColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPaymentDialog,
        child: const Icon(Icons.payment),
      ),
    );
  }
}
