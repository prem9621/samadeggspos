import 'package:flutter/material.dart';
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
  double totalSales = 0;
  double totalPurchases = 0;
  double totalPayments = 0;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { isLoading = true; error = null; });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateR = await dbHelper.getDailyRateByDate(today);
      final salesR = await dbHelper.getSalesByDate(today);
      final purchR = await dbHelper.getPurchasesByDate(today);
      final paymR = await dbHelper.getPaymentsByDate(today);
      if (!mounted) return;

      final txns = <dynamic>[];
      double sales = 0, purch = 0, paym = 0;

      if (salesR.data != null) {
        for (final s in salesR.data!) {
          txns.add({'type': 'sale', 'data': s});
          sales += s.sale.amount;
        }
      }
      if (purchR.data != null) {
        for (final p in purchR.data!) {
          txns.add({'type': 'purchase', 'data': p});
          purch += p.purchase.amount;
        }
      }
      if (paymR.data != null) {
        for (final p in paymR.data!) {
          txns.add({'type': 'payment', 'data': p});
          paym += p.payment.amount;
        }
      }

      setState(() {
        todayRate = rateR.data;
        todayTransactions = txns;
        totalSales = sales;
        totalPurchases = purch;
        totalPayments = paym;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = 'Failed to load: $e'; });
    }
  }

  // ─── Set Rate Dialog ────────────────────────────────────────────────────────
  Future<void> _showSetRateDialog() async {
    final ctrl = TextEditingController(
      text: todayRate?.baseRate.toStringAsFixed(2) ?? '',
    );
    final isEdit = todayRate != null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RateBottomSheet(
        controller: ctrl,
        isEdit: isEdit,
        onSave: (rate) async {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          if (isEdit) {
            todayRate!.baseRate = rate;
            await dbHelper.updateDailyRate(todayRate!);
          } else {
            await dbHelper.insertDailyRate(DailyRate.now(today, rate));
          }
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: kAmber,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: kAmber))
            : error != null
                ? _ErrorState(message: error!, onRetry: _load)
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final today = DateTime.now();
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Date row
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: kTextSub),
            const SizedBox(width: 6),
            Text(dateLabel, style: const TextStyle(fontSize: 12, color: kTextSub)),
          ],
        ),
        const SizedBox(height: 14),

        // ── Rate Card
        _RateCard(rate: todayRate, onTap: _showSetRateDialog),
        const SizedBox(height: 14),

        // ── Summary Row
        if (todayTransactions.isNotEmpty) ...[
          _SummaryRow(
            totalSales: totalSales,
            totalPurchases: totalPurchases,
          ),
          const SizedBox(height: 20),
        ],

        // ── Transactions header
        Row(
          children: [
            const Text('Today\'s Transactions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
            const Spacer(),
            Text('${todayTransactions.length} entries',
              style: const TextStyle(fontSize: 12, color: kTextSub)),
          ],
        ),
        const SizedBox(height: 10),

        // ── Transaction list
        if (todayTransactions.isEmpty)
          _EmptyTransactions()
        else
          ...todayTransactions.map((t) => _TransactionTile(transaction: t)),
      ],
    );
  }
}

// ─── Rate Card ────────────────────────────────────────────────────────────────
class _RateCard extends StatelessWidget {
  final DailyRate? rate;
  final VoidCallback onTap;
  const _RateCard({required this.rate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasRate = rate != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hasRate ? kAmber : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasRate ? kAmber : kBorder),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasRate ? Colors.white.withValues(alpha: 0.2) : kAmberLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.egg_rounded,
                color: hasRate ? Colors.white : kAmber, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasRate ? 'Today\'s Rate' : 'Rate Not Set',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasRate ? Colors.white70 : kTextSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasRate
                        ? '₹${rate!.baseRate.toStringAsFixed(2)} / 100 eggs'
                        : 'Tap to set rate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: hasRate ? Colors.white : kAmber,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasRate ? Icons.edit_rounded : Icons.add_circle_rounded,
              color: hasRate ? Colors.white70 : kAmber,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final double totalSales;
  final double totalPurchases;
  const _SummaryRow({required this.totalSales, required this.totalPurchases});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(
          label: 'Sales', value: totalSales, color: kGreen,
          icon: Icons.trending_up_rounded,
        )),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(
          label: 'Purchases', value: totalPurchases, color: kRed,
          icon: Icons.trending_down_rounded,
        )),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _SummaryCard({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: kTextSub)),
                Text('₹${value.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final dynamic transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] as String;
    final data = transaction['data'];

    String title, subtitle, amount;
    IconData icon;
    Color iconColor, iconBg, amtColor;

    if (type == 'sale') {
      final s = data as SaleWithParty;
      title = s.party.name;
      subtitle = '${s.sale.eggQuantity.toStringAsFixed(0)} eggs · Sale';
      amount = '+₹${s.sale.amount.toStringAsFixed(0)}';
      icon = Icons.trending_up_rounded;
      iconColor = kGreen;
      iconBg = const Color(0xFFDCFCE7);
      amtColor = kGreen;
    } else if (type == 'purchase') {
      final p = data as PurchaseWithSupplier;
      title = p.supplier.name;
      subtitle = '${p.purchase.eggQuantity.toStringAsFixed(0)} eggs · Purchase';
      amount = '-₹${p.purchase.amount.toStringAsFixed(0)}';
      icon = Icons.trending_down_rounded;
      iconColor = kRed;
      iconBg = const Color(0xFFFEE2E2);
      amtColor = kRed;
    } else {
      final p = data as PaymentWithParty;
      final isReceived = p.payment.paymentType == 'received';
      title = p.party.name;
      subtitle = isReceived ? 'Payment Received' : 'Payment Paid';
      amount = isReceived
          ? '+₹${p.payment.amount.toStringAsFixed(0)}'
          : '-₹${p.payment.amount.toStringAsFixed(0)}';
      icon = Icons.swap_horiz_rounded;
      iconColor = isReceived ? kBlue : kTextSub;
      iconBg = isReceived ? const Color(0xFFEFF6FF) : const Color(0xFFF5F5F4);
      amtColor = isReceived ? kBlue : kTextSub;
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
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextSub)),
              ],
            ),
          ),
          Text(amount, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: amtColor)),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: kAmberLight, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.receipt_long_rounded, color: kAmber, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('No transactions yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
          const SizedBox(height: 4),
          const Text('Sales and purchases will appear here',
            style: TextStyle(fontSize: 12, color: kTextSub)),
        ],
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message,
              style: const TextStyle(fontSize: 13, color: kRed),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rate Bottom Sheet ────────────────────────────────────────────────────────
class _RateBottomSheet extends StatelessWidget {
  final TextEditingController controller;
  final bool isEdit;
  final Function(double) onSave;

  const _RateBottomSheet({
    required this.controller,
    required this.isEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(isEdit ? 'Update Today\'s Rate' : 'Set Today\'s Rate',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 4),
          const Text('Rate is per 100 eggs in ₹',
            style: TextStyle(fontSize: 12, color: kTextSub)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kAmber),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: kAmber),
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: kTextMuted),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final rate = double.tryParse(controller.text);
                if (rate == null || rate <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid rate')));
                  return;
                }
                Navigator.pop(context);
                onSave(rate);
              },
              child: Text(isEdit ? 'Update Rate' : 'Save Rate'),
            ),
          ),
        ],
      ),
    );
  }
}