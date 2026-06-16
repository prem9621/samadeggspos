import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final dbHelper = DatabaseHelper.instance;
  DailyRate? todayRate;
  List<dynamic> todayTransactions = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final rateResult = await dbHelper.getDailyRateByDate(today);
      final salesResult = await dbHelper.getSalesByDate(today);
      final purchasesResult = await dbHelper.getPurchasesByDate(today);
      final paymentsResult = await dbHelper.getPaymentsByDate(today);

      if (!mounted) return;

      final List<dynamic> transactions = [];
      if (salesResult.data != null) {
        transactions.addAll(salesResult.data!.map((saleWithParty) => {'type': 'sale', 'data': saleWithParty}));
      }
      if (purchasesResult.data != null) {
        transactions.addAll(purchasesResult.data!.map((purchaseWithSupplier) => {'type': 'purchase', 'data': purchaseWithSupplier}));
      }
      if (paymentsResult.data != null) {
        transactions.addAll(paymentsResult.data!.map((paymentWithParty) => {'type': 'payment', 'data': paymentWithParty}));
      }

      setState(() {
        todayRate = rateResult.data;
        todayTransactions = transactions;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load dashboard: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF2563EB),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            error!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadDashboardData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Today\'s Rate',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            todayRate != null
                                                ? '₹${todayRate!.baseRate.toStringAsFixed(2)}'
                                                : 'Not set',
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: todayRate != null
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFFDC2626),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.price_change,
                                        color: const Color(0xFF2563EB),
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Today\'s Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (todayTransactions.isEmpty)
                          Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      size: 48,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No transactions yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add your first transaction',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF64748B).withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...todayTransactions.map((transaction) {
                            final type = transaction['type'];
                            final data = transaction['data'];

                            String title;
                            IconData icon;
                            Color iconColor;
                            Color bgColor;
                            String amount;
                            String? subtitle;

                            if (type == 'sale') {
                              final saleWithParty = data as SaleWithParty;
                              title = 'Sale';
                              icon = Icons.shopping_cart_outlined;
                              iconColor = const Color(0xFF10B981);
                              bgColor = const Color(0xFFECFDF5);
                              amount = '+₹${saleWithParty.sale.amount.toStringAsFixed(2)}';
                              subtitle = '${saleWithParty.sale.eggQuantity} eggs';
                            } else if (type == 'purchase') {
                              final purchaseWithSupplier = data as PurchaseWithSupplier;
                              title = 'Purchase';
                              icon = Icons.shopping_bag_outlined;
                              iconColor = const Color(0xFFF59E0B);
                              bgColor = const Color(0xFFFFF7ED);
                              amount = '-₹${purchaseWithSupplier.purchase.amount.toStringAsFixed(2)}';
                              subtitle = '${purchaseWithSupplier.purchase.eggQuantity} eggs';
                            } else {
                              final paymentWithParty = data as PaymentWithParty;
                              title = 'Payment';
                              icon = Icons.payment_outlined;
                              iconColor = const Color(0xFF2563EB);
                              bgColor = const Color(0xFFEFF6FF);
                              amount = paymentWithParty.payment.paymentType == 'received'
                                  ? '+₹${paymentWithParty.payment.amount.toStringAsFixed(2)}'
                                  : '-₹${paymentWithParty.payment.amount.toStringAsFixed(2)}';
                              subtitle = paymentWithParty.payment.paymentType == 'received'
                                  ? 'Received'
                                  : 'Paid';
                            }

                            return Card(
                              color: Colors.white,
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: iconColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (subtitle != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                subtitle,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      amount,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: amount.startsWith('+')
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
      ),
    );
  }
}
