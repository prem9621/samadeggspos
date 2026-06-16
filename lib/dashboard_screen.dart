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
      appBar: AppBar(
        title: Text(context.watch<AppState>().shopName ?? 'Samad Eggs POS'),
        actions: [
          IconButton(
            icon: Icon(context.watch<AppState>().darkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              context.read<AppState>().toggleDarkMode();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
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
                            onPressed: _loadDashboardData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(
                                  "Today's Rate",
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  todayRate != null
                                      ? '₹${todayRate!.baseRate.toStringAsFixed(2)} per 100 eggs'
                                      : 'No rate set for today',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: todayRate != null
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.error,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Eggs Sold',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        totalEggs.toStringAsFixed(0),
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Total Revenue',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '₹${totalRevenue.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: Theme.of(context).colorScheme.errorContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Total Expenses',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onErrorContainer,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '₹${totalExpenses.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onErrorContainer,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: Theme.of(context).colorScheme.primaryContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Profit',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '₹${totalProfit.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
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
                              label: 'Add Sale',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(3);
                              },
                            ),
                            _QuickActionButton(
                              icon: Icons.money_off,
                              label: 'Add Expense',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(5);
                              },
                            ),
                            _QuickActionButton(
                              icon: Icons.history,
                              label: 'View History',
                              onTap: () {
                                context.read<AppState>().setSelectedIndex(4);
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
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
