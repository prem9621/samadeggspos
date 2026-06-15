import 'package:flutter/material.dart';
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
  double totalAmount = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
    });
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rate = await dbHelper.getDailyRateByDate(today);
    final eggs = await dbHelper.getTotalEggsSoldOnDate(today);
    final amount = await dbHelper.getTotalSalesAmountOnDate(today);
    setState(() {
      todayRate = rate;
      totalEggs = eggs;
      totalAmount = amount;
      isLoading = false;
    });
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    'Total Sales',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₹${totalAmount.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
