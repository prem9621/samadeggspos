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
  double totalEggs = 0.0;
  double totalRevenue = 0.0;
  double totalExpenses = 0.0;
  double totalProfit = 0.0;
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
      final eggsResult = await dbHelper.getTotalEggsSoldOnDate(today);
      final revenueResult = await dbHelper.getTotalSalesAmountOnDate(today);
      final expensesResult = await dbHelper.getTotalExpensesOnDate(today);
      final profitResult = await dbHelper.getDailyProfit(today);

      if (!mounted) return;

      setState(() {
        todayRate = rateResult.data;
        totalEggs = eggsResult.data ?? 0.0;
        totalRevenue = revenueResult.data ?? 0.0;
        totalExpenses = expensesResult.data ?? 0.0;
        totalProfit = profitResult.data ?? 0.0;
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
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildStatCard(
                              icon: Icons.egg,
                              title: 'Eggs Sold',
                              value: totalEggs.toStringAsFixed(0),
                              iconColor: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFFFF7ED),
                            ),
                            _buildStatCard(
                              icon: Icons.currency_rupee,
                              title: 'Total Revenue',
                              value: '₹${totalRevenue.toStringAsFixed(2)}',
                              iconColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFFECFDF5),
                            ),
                            _buildStatCard(
                              icon: Icons.money_off,
                              title: 'Total Expenses',
                              value: '₹${totalExpenses.toStringAsFixed(2)}',
                              iconColor: const Color(0xFFDC2626),
                              bgColor: const Color(0xFFFEF2F2),
                            ),
                            _buildStatCard(
                              icon: Icons.trending_up,
                              title: 'Profit',
                              value: '₹${totalProfit.toStringAsFixed(2)}',
                              iconColor: const Color(0xFF2563EB),
                              bgColor: const Color(0xFFEFF6FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _QuickActionButton(
                              icon: Icons.price_change,
                              label: 'Update Rate',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(1);
                              },
                            ),
                            _QuickActionButton(
                              icon: Icons.add_shopping_cart,
                              label: 'New Sale',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(3);
                              },
                            ),
                            _QuickActionButton(
                              icon: Icons.shopping_bag,
                              label: 'New Purchase',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(4);
                              },
                            ),
                            _QuickActionButton(
                              icon: Icons.people,
                              label: 'Parties',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(2);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  icon,
                  color: const Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
