import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'main.dart';

class MonthlyDataScreen extends StatefulWidget {
  const MonthlyDataScreen({super.key});

  @override
  State<MonthlyDataScreen> createState() => _MonthlyDataScreenState();
}

class _MonthlyDataScreenState extends State<MonthlyDataScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<String> months = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await dbHelper.getAvailableMonths();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        months = result.data ?? [];
        error = result.error;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load months: $e';
        });
      }
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
        title: const Text('Monthly Data'),
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
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadMonths,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : months.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No data available yet',
                          style: TextStyle(color: kTextSub, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: months.length,
                      itemBuilder: (context, index) {
                        final month = months[index];
                        return _MonthCard(
                          month: month,
                          onTap: () => _showMonthDetails(month),
                        );
                      },
                    ),
    );
  }

  void _showMonthDetails(String yearMonth) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthDetailsScreen(yearMonth: yearMonth),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final String month;
  final VoidCallback onTap;

  const _MonthCard({required this.month, required this.onTap});

  String _formatMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateFormat.yMMMM().format(DateTime(year, month));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kAmberLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: kAmber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatMonth(month),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MonthDetailsScreen extends StatefulWidget {
  final String yearMonth;

  const MonthDetailsScreen({super.key, required this.yearMonth});

  @override
  State<MonthDetailsScreen> createState() => _MonthDetailsScreenState();
}

class _MonthDetailsScreenState extends State<MonthDetailsScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> dailyStats = [];
  Map<String, double> totals = {};
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final statsResult = await dbHelper.getMonthlyStats(widget.yearMonth);
      final totalsResult = await dbHelper.getMonthlyTotals(widget.yearMonth);
      
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        dailyStats = (statsResult.data as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        totals = (totalsResult.data as Map<dynamic, dynamic>?)?.map(
                  (key, value) => MapEntry(key as String, value as double),
                ) ??
            {};
        error = statsResult.error ?? totalsResult.error;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load month data: $e';
        });
      }
    }
  }

  String _formatMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateFormat.yMMMM().format(DateTime(year, month));
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
        title: Text(_formatMonth(widget.yearMonth)),
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
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadMonthData,
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
                    _TotalsCard(totals: totals),
                    const SizedBox(height: 14),
                    ...dailyStats
                        .where((day) =>
                            day['rate'] != null ||
                            day['totalSales'] > 0 ||
                            day['totalPurchases'] > 0 ||
                            day['totalExpenses'] > 0)
                        .map((day) => _DayCard(dayStats: day))
                        ,
                  ],
                ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final Map<String, double> totals;

  const _TotalsCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Month Totals',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TotalItem(
                  label: 'Total Sales',
                  value: '₹${totals['totalSales']?.toStringAsFixed(2) ?? '0.00'}',
                  color: kGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TotalItem(
                  label: 'Total Purchases',
                  value: '₹${totals['totalPurchases']?.toStringAsFixed(2) ?? '0.00'}',
                  color: kBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TotalItem(
                  label: 'Total Expenses',
                  value: '₹${totals['totalExpenses']?.toStringAsFixed(2) ?? '0.00'}',
                  color: kRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TotalItem(
                  label: 'Net Profit',
                  value: '₹${totals['totalProfit']?.toStringAsFixed(2) ?? '0.00'}',
                  color: (totals['totalProfit'] ?? 0) >= 0 ? kGreen : kRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TotalItem(
                  label: 'Eggs Sold',
                  value: totals['totalEggsSold']?.toStringAsFixed(0) ?? '0',
                  color: kText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TotalItem(
                  label: 'Eggs Purchased',
                  value: totals['totalEggsPurchased']?.toStringAsFixed(0) ?? '0',
                  color: kText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: kTextSub,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final Map<String, dynamic> dayStats;

  const _DayCard({required this.dayStats});

  String _formatDate(String dateStr) {
    final date = DateFormat('yyyy-MM-dd').parse(dateStr);
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = dayStats['rate'] != null ||
        dayStats['totalSales'] > 0 ||
        dayStats['totalPurchases'] > 0 ||
        dayStats['totalExpenses'] > 0;

    if (!hasData) return const SizedBox.shrink();

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
            Text(
              _formatDate(dayStats['date']),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
            const SizedBox(height: 10),
            if (dayStats['rate'] != null)
              _DayItem(
                label: 'Daily Rate',
                value: '₹${dayStats['rate'].toStringAsFixed(2)} per 100 eggs',
                icon: Icons.egg_rounded,
                color: kAmber,
              ),
            if (dayStats['totalSales'] > 0)
              _DayItem(
                label: 'Sales',
                value: '₹${dayStats['totalSales'].toStringAsFixed(2)} (${dayStats['eggsSold'].toStringAsFixed(0)} eggs)',
                icon: Icons.point_of_sale_rounded,
                color: kGreen,
              ),
            if (dayStats['totalPurchases'] > 0)
              _DayItem(
                label: 'Purchases',
                value: '₹${dayStats['totalPurchases'].toStringAsFixed(2)} (${dayStats['eggsPurchased'].toStringAsFixed(0)} eggs)',
                icon: Icons.shopping_bag_rounded,
                color: kBlue,
              ),
            if (dayStats['totalExpenses'] > 0)
              _DayItem(
                label: 'Expenses',
                value: '₹${dayStats['totalExpenses'].toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_rounded,
                color: kRed,
              ),
            if (dayStats['profit'] != 0)
              _DayItem(
                label: 'Profit',
                value: '₹${dayStats['profit'].toStringAsFixed(2)}',
                icon: Icons.trending_up_rounded,
                color: dayStats['profit'] >= 0 ? kGreen : kRed,
              ),
          ],
        ),
      ),
    );
  }
}

class _DayItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DayItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: kTextSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}