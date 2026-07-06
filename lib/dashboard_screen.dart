import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'database_helper.dart';
import 'stats_helper.dart';
import 'top_parties_dues_screen.dart';
import 'main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final dbHelper = DatabaseHelper.instance;
  final statsHelper = StatsHelper.instance;

  DailyRate? todayRate;
  List<dynamic> todayTransactions = [];
  double totalSales = 0;
  double totalPurchases = 0;
  bool isLoading = true;
  String? error;

  // ── New: Business Intelligence state ──────────────────────────────
  double currentStock = 0;
  Map<String, double> monthProfitLoss = {};
  List<PartyRanked> topCustomers = [];
  List<PartyRanked> topSuppliers = [];
  List<PendingDue> pendingDues = [];
  List<TrendPoint> trendPoints = [];
  bool isStatsLoading = true;
  String? statsError;

  // Tracks the last AppState.rateRevision we've reloaded for. This
  // screen stays alive inside MainScreen's IndexedStack, so its own
  // initState()-only load never re-runs by itself when the rate is
  // set from a different screen (e.g. the Rate tab) — this watches
  // for that change and triggers a reload automatically.
  int? _lastRateRevision;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rev = context.watch<AppState>().rateRevision;
    if (_lastRateRevision == null) {
      _lastRateRevision = rev;
    } else if (rev != _lastRateRevision) {
      _lastRateRevision = rev;
      _load();
    }
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

  /// Loads all Business Intelligence data — stock, month profit-loss,
  /// top parties, pending dues, and the 30-day trend — in one batch,
  /// separate from the "today" load above so a slow stats fetch never
  /// blocks today's transaction list from showing.
  Future<void> _loadStats() async {
    setState(() {
      isStatsLoading = true;
      statsError = null;
    });
    try {
      final stockR = await statsHelper.getCurrentStock();
      final plR = await statsHelper.getThisMonthProfitLoss();
      final customersR =
          await statsHelper.getTopParties(type: PartyType.customer, limit: 5);
      final suppliersR =
          await statsHelper.getTopParties(type: PartyType.supplier, limit: 5);
      final duesR = await statsHelper.getPendingDues();
      final trendR = await statsHelper.getRecentTrend(days: 30);

      if (!mounted) return;
      setState(() {
        isStatsLoading = false;
        currentStock = stockR.data ?? 0;
        monthProfitLoss = plR.data ?? {};
        topCustomers = customersR.data ?? [];
        topSuppliers = suppliersR.data ?? [];
        pendingDues = duesR.data ?? [];
        trendPoints = trendR.data ?? [];
        statsError = stockR.error ??
            plR.error ??
            customersR.error ??
            suppliersR.error ??
            duesR.error ??
            trendR.error;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isStatsLoading = false;
          statsError = 'Failed to load stats: $e';
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadStats()]);
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
        onRefresh: _refreshAll,
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

        // ══════════════════════════════════════════════════════════
        // ── NEW: Business Intelligence section ──────────────────────
        // ══════════════════════════════════════════════════════════
        if (!isStatsLoading && statsError == null) ...[
          _StockAndProfitRow(
            currentStock: currentStock,
            profit: monthProfitLoss['profit'] ?? 0,
          ),
          const SizedBox(height: 14),

          if (trendPoints.isNotEmpty) ...[
            _TrendChartCard(points: trendPoints),
            const SizedBox(height: 14),
          ],

          _CompactStatsRow(
            topCustomers: topCustomers,
            topSuppliers: topSuppliers,
            dues: pendingDues,
            onCustomersTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TopPartiesDuesScreen(initialTab: 0),
              ),
            ),
            onSuppliersTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TopPartiesDuesScreen(initialTab: 1),
              ),
            ),
            onDuesTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TopPartiesDuesScreen(initialTab: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ] else if (isStatsLoading) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: kBlue, strokeWidth: 2),
            ),
          ),
        ],
        // ══════════════════════════════════════════════════════════

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

// ─── NEW: Stock + Profit Row ──────────────────────────────────────────────────
class _StockAndProfitRow extends StatelessWidget {
  final double currentStock;
  final double profit;
  const _StockAndProfitRow({required this.currentStock, required this.profit});

  @override
  Widget build(BuildContext context) {
    final isNegativeStock = currentStock < 0;
    final isProfit = profit >= 0;
    return Row(
      children: [
        Expanded(
          child: Container(
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
                    color: isNegativeStock
                        ? const Color(0xFFFEE2E2)
                        : kAmberLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: isNegativeStock ? kRed : kAmber,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stock',
                        style: TextStyle(fontSize: 10, color: kTextSub),
                      ),
                      Text(
                        '${currentStock.toStringAsFixed(0)} eggs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isNegativeStock ? kRed : kText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
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
                    color: isProfit
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    isProfit
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: isProfit ? kGreen : kRed,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This Month',
                        style: TextStyle(fontSize: 10, color: kTextSub),
                      ),
                      Text(
                        '₹${profit.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isProfit ? kGreen : kRed,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── NEW: Trend Chart Card ────────────────────────────────────────────────────
class _TrendChartCard extends StatelessWidget {
  final List<TrendPoint> points;
  const _TrendChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxSales = points.fold<double>(
      0,
      (max, p) => p.salesAmount > max ? p.salesAmount : max,
    );
    final maxY = maxSales <= 0 ? 100.0 : maxSales * 1.2;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Trend (30 days)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kText,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: maxSales <= 0
                ? const Center(
                    child: Text(
                      'No sales yet in this period',
                      style: TextStyle(fontSize: 11, color: kTextSub),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots.map((s) {
                            final point = points[s.x.toInt()];
                            final label =
                                DateFormat('d MMM').format(point.date);
                            return LineTooltipItem(
                              '$label\n₹${point.salesAmount.toStringAsFixed(0)}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].salesAmount),
                          ],
                          isCurved: true,
                          color: kBlue,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: kBlue.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── NEW: Compact Parties & Dues Row ──────────────────────────────────────────
// Replaces three stacked cards (Top Customers / Top Suppliers / Pending
// Dues) with a single low-height row — three tappable segments sharing
// one card, each showing just the top highlight. Full lists live in
// TopPartiesDuesScreen via "View All", reached by tapping a segment.
class _CompactStatsRow extends StatelessWidget {
  final List<PartyRanked> topCustomers;
  final List<PartyRanked> topSuppliers;
  final List<PendingDue> dues;
  final VoidCallback onCustomersTap;
  final VoidCallback onSuppliersTap;
  final VoidCallback onDuesTap;

  const _CompactStatsRow({
    required this.topCustomers,
    required this.topSuppliers,
    required this.dues,
    required this.onCustomersTap,
    required this.onSuppliersTap,
    required this.onDuesTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalDueAmount =
        dues.fold<double>(0, (sum, d) => sum + d.balance.abs());

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CompactStatSegment(
                icon: Icons.people_alt_rounded,
                iconColor: kGreen,
                label: 'Customers',
                value: topCustomers.isEmpty
                    ? '—'
                    : '₹${topCustomers.first.totalAmount.toStringAsFixed(0)}',
                subLabel: topCustomers.isEmpty
                    ? 'No data'
                    : topCustomers.first.party.name,
                onTap: onCustomersTap,
              ),
            ),
            const VerticalDivider(width: 1, color: kBorder),
            Expanded(
              child: _CompactStatSegment(
                icon: Icons.local_shipping_rounded,
                iconColor: kBlue,
                label: 'Suppliers',
                value: topSuppliers.isEmpty
                    ? '—'
                    : '₹${topSuppliers.first.totalAmount.toStringAsFixed(0)}',
                subLabel: topSuppliers.isEmpty
                    ? 'No data'
                    : topSuppliers.first.party.name,
                onTap: onSuppliersTap,
              ),
            ),
            const VerticalDivider(width: 1, color: kBorder),
            Expanded(
              child: _CompactStatSegment(
                icon: Icons.warning_amber_rounded,
                iconColor: dues.isEmpty ? kTextMuted : kRed,
                label: 'Dues',
                value: dues.isEmpty
                    ? '₹0'
                    : '₹${totalDueAmount.toStringAsFixed(0)}',
                subLabel: dues.isEmpty
                    ? 'Settled'
                    : '${dues.length} pending',
                onTap: onDuesTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStatSegment extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subLabel;
  final VoidCallback onTap;

  const _CompactStatSegment({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: kTextSub),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subLabel,
              style: const TextStyle(fontSize: 9, color: kTextMuted),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
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