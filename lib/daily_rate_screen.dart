import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

class DailyRateScreen extends StatefulWidget {
  const DailyRateScreen({super.key});

  @override
  State<DailyRateScreen> createState() => _DailyRateScreenState();
}

class _DailyRateScreenState extends State<DailyRateScreen> {
  final dbHelper = DatabaseHelper.instance;
  final _rateController = TextEditingController();
  List<DailyRate> rateHistory = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRateHistory();
  }

  Future<void> _loadRateHistory() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await dbHelper.getAllDailyRates();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (result.success) {
          rateHistory = result.data ?? [];
        } else {
          error = result.error;
        }
      });
    } catch (e) {
      debugPrint('Daily rates load error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load rates: $e';
        });
      }
    }
  }

  Future<void> _showRateDialog() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await dbHelper.getDailyRateByDate(today);
    if (result.success && result.data != null) {
      _rateController.text = result.data!.baseRate.toString();
    } else {
      _rateController.clear();
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Today\'s Rate'),
          content: SingleChildScrollView(
            child: TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rate per 100 eggs (₹)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final rate = double.tryParse(_rateController.text);
                if (rate == null || rate <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid rate')),
                    );
                  }
                  return;
                }
                final newRate = DailyRate.now(today, rate);
                final saveResult = await dbHelper.insertDailyRate(newRate);
                if (saveResult.success) {
                  if (mounted) {
                    Navigator.pop(context);
                    _loadRateHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rate saved successfully')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(saveResult.error ?? 'Failed to save rate')),
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

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadRateHistory,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daily Rate History',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  FloatingActionButton(
                    mini: true,
                    onPressed: _showRateDialog,
                    child: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (error != null) {
                  return Center(
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
                            onPressed: _loadRateHistory,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (rateHistory.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.price_change,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No rates set yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showRateDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Set Today\'s Rate'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rateHistory.length,
                    itemBuilder: (context, index) {
                      final rate = rateHistory[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            DateFormat('MMM d, yyyy').format(DateTime.parse(rate.date)),
                          ),
                          subtitle: Text('₹${rate.baseRate.toStringAsFixed(2)} per 100 eggs'),
                          trailing: rate.date == today
                              ? const Chip(label: Text('Today'))
                              : null,
                        ),
                      );
                    },
                  );
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }
}
