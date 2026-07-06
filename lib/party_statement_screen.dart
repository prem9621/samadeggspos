import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'models.dart';
import 'main.dart';

class PartyStatementScreen extends StatefulWidget {
  final Party party;

  const PartyStatementScreen({super.key, required this.party});

  @override
  State<PartyStatementScreen> createState() => _PartyStatementScreenState();
}

class _PartyStatementScreenState extends State<PartyStatementScreen> {
  final dbHelper = DatabaseHelper.instance;
  bool isLoading = true;
  String? error;
  List<PartyTransaction> transactions = [];
  double balance = 0;

  @override
  void initState() {
    super.initState();
    _loadPartyStatement();
  }

  Future<void> _loadPartyStatement() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Load all transactions for this party
      final salesResult = await dbHelper.getSalesByParty(widget.party);
      final purchasesResult =
          await dbHelper.getPurchasesBySupplier(widget.party);
      final paymentsResult = await dbHelper.getPaymentsByParty(widget.party);
      final balanceResult = await dbHelper.getPartyBalance(widget.party);

      if (!mounted) return;

      List<PartyTransaction> allTransactions = [];

      // Add sales as transactions
      if (salesResult.success) {
        for (final sale in salesResult.data ?? []) {
          allTransactions.add(
            PartyTransaction(
              type: 'sale',
              date: DateFormat('yyyy-MM-dd').parse(sale.sale.saleDate),
              description: 'Sale - ${sale.sale.eggQuantity.toStringAsFixed(0)} eggs',
              amount: sale.sale.amount,
              quantity: sale.sale.eggQuantity,
              rate: sale.sale.adjustedRate,
              notes: sale.sale.notes,
            ),
          );
        }
      }

      // Add purchases as transactions
      if (purchasesResult.success) {
        for (final purchase in purchasesResult.data ?? []) {
          allTransactions.add(
            PartyTransaction(
              type: 'purchase',
              date: DateFormat('yyyy-MM-dd').parse(purchase.purchase.purchaseDate),
              description:
                  'Purchase - ${purchase.purchase.eggQuantity.toStringAsFixed(0)} eggs',
              amount: -purchase.purchase.amount,
              quantity: purchase.purchase.eggQuantity,
              rate: purchase.purchase.adjustedRate,
              notes: purchase.purchase.notes,
            ),
          );
        }
      }

      // Add payments as transactions
      if (paymentsResult.success) {
        for (final payment in paymentsResult.data ?? []) {
          final isReceived = payment.payment.paymentType == 'received';
          allTransactions.add(
            PartyTransaction(
              type: isReceived ? 'payment_received' : 'payment_paid',
              date: DateFormat('yyyy-MM-dd').parse(payment.payment.date),
              description: isReceived ? 'Payment Received' : 'Payment Paid',
              amount: isReceived ? -payment.payment.amount : payment.payment.amount,
              quantity: 0,
              rate: 0,
              notes: payment.payment.notes,
            ),
          );
        }
      }

      // Sort by date (newest first)
      allTransactions.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        isLoading = false;
        transactions = allTransactions;
        balance = balanceResult.data ?? 0;
        error = salesResult.error ??
            purchasesResult.error ??
            paymentsResult.error ??
            balanceResult.error;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load statement: $e';
        });
      }
    }
  }

  String _getPartyTypeLabel() {
    return widget.party.type == PartyType.customer ? 'Customer' : 'Supplier';
  }

  String _getBalanceLabel() {
    if (widget.party.type == PartyType.customer) {
      return balance > 0 ? 'Due from Customer' : 'Advance/Overpaid';
    } else {
      return balance > 0 ? 'Amount Owed to Supplier' : 'Advance Paid';
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
        title: const Text('Party Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPartyStatement,
          ),
        ],
      ),
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
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadPartyStatement,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Party Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.party.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: kText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getPartyTypeLabel(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: kTextSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: balance.abs() > 0
                                      ? (balance > 0 ? kGreen : kBlue)
                                          .withValues(alpha: 0.1)
                                      : kTextMuted.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _getBalanceLabel(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: kTextSub,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${balance.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: balance.abs() > 0
                                            ? (balance > 0 ? kGreen : kBlue)
                                            : kTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (widget.party.phone != null &&
                              widget.party.phone!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded,
                                    size: 14, color: kTextSub),
                                const SizedBox(width: 8),
                                Text(
                                  widget.party.phone!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kTextSub,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.party.address != null &&
                              widget.party.address!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 14, color: kTextSub),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.party.address!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kTextSub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Transactions Summary
                    _buildSummaryCards(),
                    const SizedBox(height: 16),

                    // Transactions List
                    if (transactions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No transactions yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextSub,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...transactions
                              .map((transaction) =>
                                  _buildTransactionCard(transaction))
                              ,
                        ],
                      ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCards() {
    double totalSales = 0;
    double totalPurchases = 0;
    double totalPaymentsReceived = 0;
    double totalPaymentsPaid = 0;
    double totalEggsSold = 0;
    double totalEggsPurchased = 0;

    for (final txn in transactions) {
      if (txn.type == 'sale') {
        totalSales += txn.amount;
        totalEggsSold += txn.quantity;
      } else if (txn.type == 'purchase') {
        totalPurchases += txn.amount.abs();
        totalEggsPurchased += txn.quantity;
      } else if (txn.type == 'payment_received') {
        totalPaymentsReceived += txn.amount.abs();
      } else if (txn.type == 'payment_paid') {
        totalPaymentsPaid += txn.amount.abs();
      }
    }

    return Column(
      children: [
        if (widget.party.type == PartyType.customer) ...[
          // Customer summary
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Sales',
                  value: '₹${totalSales.toStringAsFixed(2)}',
                  color: kGreen,
                  icon: Icons.point_of_sale_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Paid',
                  value: '₹${totalPaymentsReceived.toStringAsFixed(2)}',
                  color: kBlue,
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Eggs Sold',
                  value: totalEggsSold.toStringAsFixed(0),
                  color: kAmber,
                  icon: Icons.egg_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Remaining',
                  value: '₹${(totalSales - totalPaymentsReceived).toStringAsFixed(2)}',
                  color: kRed,
                  icon: Icons.warning_rounded,
                ),
              ),
            ],
          ),
        ] else ...[
          // Supplier summary
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Purchases',
                  value: '₹${totalPurchases.toStringAsFixed(2)}',
                  color: kBlue,
                  icon: Icons.shopping_bag_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Paid',
                  value: '₹${totalPaymentsPaid.toStringAsFixed(2)}',
                  color: kGreen,
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Eggs Purchased',
                  value: totalEggsPurchased.toStringAsFixed(0),
                  color: kAmber,
                  icon: Icons.egg_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Amount Owed',
                  value:
                      '₹${(totalPurchases - totalPaymentsPaid).toStringAsFixed(2)}',
                  color: kRed,
                  icon: Icons.warning_rounded,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionCard(PartyTransaction transaction) {
    Color getTypeColor(String type) {
      switch (type) {
        case 'sale':
          return kGreen;
        case 'purchase':
          return kBlue;
        case 'payment_received':
          return kGreen;
        case 'payment_paid':
          return kBlue;
        default:
          return kAmber;
      }
    }

    IconData getTypeIcon(String type) {
      switch (type) {
        case 'sale':
          return Icons.point_of_sale_rounded;
        case 'purchase':
          return Icons.shopping_bag_rounded;
        case 'payment_received':
          return Icons.arrow_downward_rounded;
        case 'payment_paid':
          return Icons.arrow_upward_rounded;
        default:
          return Icons.info_rounded;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: getTypeColor(transaction.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getTypeIcon(transaction.type),
                    color: getTypeColor(transaction.type),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM yyyy, h:mm a')
                            .format(transaction.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: kTextSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.amount > 0 ? '+' : ''}₹${transaction.amount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: getTypeColor(transaction.type),
                      ),
                    ),
                    if (transaction.quantity > 0)
                      Text(
                        '${transaction.quantity.toStringAsFixed(0)} eggs',
                        style: const TextStyle(
                          fontSize: 10,
                          color: kTextSub,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${transaction.notes}',
                style: const TextStyle(
                  fontSize: 11,
                  color: kTextSub,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PartyTransaction {
  final String type; // 'sale', 'purchase', 'payment_received', 'payment_paid'
  final DateTime date;
  final String description;
  final double amount; // Positive for incoming, negative for outgoing
  final double quantity;
  final double rate;
  final String? notes;

  PartyTransaction({
    required this.type,
    required this.date,
    required this.description,
    required this.amount,
    required this.quantity,
    required this.rate,
    this.notes,
  });
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: kTextSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}