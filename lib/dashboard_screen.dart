import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rateR = await dbHelper.getDailyRateByDate(today);
      final salesR = await dbHelper.getSalesByDate(today);
      final purchR = await dbHelper.getPurchasesByDate(today);
      final paymR = await dbHelper.getPaymentsByDate(today);
      if (!mounted) return;

      final txns = <dynamic>[];
      double sales = 0, purch = 0;

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
        }
      }

      // Sort by createdAt descending (most recent first)
      txns.sort((a, b) {
        final ta = _txnTime(a);
        final tb = _txnTime(b);
        return tb.compareTo(ta);
      });

      setState(() {
        todayRate = rateR.data;
        todayTransactions = txns;
        totalSales = sales;
        totalPurchases = purch;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load: $e';
        });
      }
    }
  }

  DateTime _txnTime(dynamic t) {
    final type = t['type'] as String;
    if (type == 'sale') return (t['data'] as SaleWithParty).sale.createdAt;
    if (type == 'purchase') {
      return (t['data'] as PurchaseWithSupplier).purchase.createdAt;
    }
    return (t['data'] as PaymentWithParty).payment.createdAt;
  }

  Future<void> _showSetRateDialog() async {
    final ctrl = TextEditingController(
      text: todayRate?.baseRate.toStringAsFixed(2) ?? '',
    );
    final isEdit = todayRate != null;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RateBottomSheet(
        controller: ctrl,
        isEdit: isEdit,
        onSave: (rate) async {
          final result = await dbHelper.setTodayRate(rate);
          if (result.success && mounted) {
            context.read<AppState>().notifyRatesChanged();
          } else if (!result.success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.error ?? 'Failed to save rate')),
            );
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
        color: kBlue,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: kBlue))
            : error != null
            ? _ErrorState(message: error!, onRetry: _load)
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(now);
    final timeLabel = DateFormat('h:mm a').format(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        // ── Date + Time
        Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 11,
              color: kTextMuted,
            ),
            const SizedBox(width: 5),
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 11, color: kTextSub),
            ),
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: kTextMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.access_time_rounded, size: 11, color: kTextMuted),
            const SizedBox(width: 5),
            Text(
              timeLabel,
              style: const TextStyle(fontSize: 11, color: kTextSub),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Rate Line (clean, no box)
        _RateLine(rate: todayRate, onTap: _showSetRateDialog),
        const SizedBox(height: 12),

        // ── Summary Row
        if (totalSales > 0 || totalPurchases > 0) ...[
          _SummaryRow(totalSales: totalSales, totalPurchases: totalPurchases),
          const SizedBox(height: 14),
        ],

        // ── Transactions header
        Row(
          children: [
            const Text(
              "Today's History",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kText,
              ),
            ),
            const Spacer(),
            Text(
              '${todayTransactions.length} entries',
              style: const TextStyle(fontSize: 11, color: kTextSub),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Transaction list
        if (todayTransactions.isEmpty)
          _EmptyTransactions()
        else
          ...todayTransactions.map((t) => _TransactionRow(transaction: t)),
      ],
    );
  }
}

// ─── Rate Line ────────────────────────────────────────────────────────────────
class _RateLine extends StatelessWidget {
  final DailyRate? rate;
  final VoidCallback onTap;
  const _RateLine({required this.rate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kAmberLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.egg_rounded, color: kAmber, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: rate != null
                  ? Row(
                      children: [
                        Text(
                          'Today\'s Rate',
                          style: const TextStyle(fontSize: 11, color: kTextSub),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${rate!.baseRate.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kAmber,
                          ),
                        ),
                        Text(
                          ' / 100 eggs',
                          style: const TextStyle(fontSize: 10, color: kTextSub),
                        ),
                      ],
                    )
                  : const Text(
                      'Tap to set today\'s rate',
                      style: TextStyle(fontSize: 12, color: kTextSub),
                    ),
            ),
            Icon(
              rate != null ? Icons.edit_rounded : Icons.add_rounded,
              size: 15,
              color: kTextMuted,
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
        Expanded(
          child: _SummaryCard(
            label: 'Sales',
            value: totalSales,
            color: kGreen,
            icon: Icons.trending_up_rounded,
            bgColor: const Color(0xFFDCFCE7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Purchases',
            value: totalPurchases,
            color: const Color(0xFFF97316),
            icon: Icons.trending_down_rounded,
            bgColor: const Color(0xFFFFF7ED),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color, bgColor;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: kTextSub),
                ),
                Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
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

// ─── Transaction Row ──────────────────────────────────────────────────────────
class _TransactionRow extends StatelessWidget {
  final dynamic transaction;
  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] as String;
    final data = transaction['data'];

    String title, sub, amount, timeStr;
    Color iconColor, iconBg, amtColor;
    IconData icon;

    if (type == 'sale') {
      final s = data as SaleWithParty;
      title = s.party.name;
      sub = '${s.sale.eggQuantity.toStringAsFixed(0)} eggs · Sale';
      amount = '+₹${s.sale.amount.toStringAsFixed(0)}';
      timeStr = DateFormat('h:mm a').format(s.sale.createdAt);
      icon = Icons.trending_up_rounded;
      iconColor = kGreen;
      iconBg = const Color(0xFFDCFCE7);
      amtColor = kGreen;
    } else if (type == 'purchase') {
      final p = data as PurchaseWithSupplier;
      title = p.supplier.name;
      sub = '${p.purchase.eggQuantity.toStringAsFixed(0)} eggs · Purchase';
      amount = '-₹${p.purchase.amount.toStringAsFixed(0)}';
      timeStr = DateFormat('h:mm a').format(p.purchase.createdAt);
      icon = Icons.trending_down_rounded;
      iconColor = const Color(0xFFF97316);
      iconBg = const Color(0xFFFFF7ED);
      amtColor = const Color(0xFFF97316);
    } else {
      final p = data as PaymentWithParty;
      final isRcv = p.payment.paymentType == 'received';
      title = p.party.name;
      sub = isRcv ? 'Payment Received' : 'Payment Paid';
      amount = isRcv
          ? '+₹${p.payment.amount.toStringAsFixed(0)}'
          : '-₹${p.payment.amount.toStringAsFixed(0)}';
      timeStr = DateFormat('h:mm a').format(p.payment.createdAt);
      icon = Icons.swap_horiz_rounded;
      iconColor = isRcv ? kBlue : kTextSub;
      iconBg = isRcv ? kBlueLight : const Color(0xFFF5F5F4);
      amtColor = isRcv ? kBlue : kTextSub;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 10, color: kTextSub),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: const BoxDecoration(
                        color: kTextMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10, color: kTextMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: amtColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────
class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kAmberLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: kAmber,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kText,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Sales and purchases will appear here',
            style: TextStyle(fontSize: 11, color: kTextSub),
          ),
        ],
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────
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
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: kRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 14),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEdit ? 'Update Today\'s Rate' : 'Set Today\'s Rate',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Rate per 100 eggs (₹)',
            style: TextStyle(fontSize: 11, color: kTextSub),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: kAmber,
            ),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kAmber,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kTextMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final rate = double.tryParse(controller.text);
                if (rate == null || rate <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid rate')),
                  );
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
