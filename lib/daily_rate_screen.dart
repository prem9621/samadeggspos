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

  @override
  void initState() {
    super.initState();
    _loadRateHistory();
  }

  Future<void> _loadRateHistory() async {
    setState(() {
      isLoading = true;
    });
    final history = await dbHelper.getAllDailyRates();
    setState(() {
      rateHistory = history;
      isLoading = false;
    });
  }

  Future<void> _showRateDialog() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRate = await dbHelper.getDailyRateByDate(today);
    if (todayRate != null) {
      _rateController.text = todayRate.baseRate.toString();
    } else {
      _rateController.clear();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Today\'s Rate'),
        content: TextField(
          controller: _rateController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Rate per 100 eggs (₹)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final rate = double.tryParse(_rateController.text);
              if (rate == null || rate <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid rate')),
                );
                return;
              }
              await dbHelper.insertDailyRate(
                DailyRate(date: today, baseRate: rate),
              );
              Navigator.pop(context);
              _loadRateHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Rate saved successfully')),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Rate'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _showRateDialog,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rateHistory.length,
              itemBuilder: (context, index) {
                final rate = rateHistory[index];
                return Card(
                  child: ListTile(
                    title: Text(DateFormat('MMM d, yyyy').format(DateTime.parse(rate.date))),
                    subtitle: Text('₹${rate.baseRate.toStringAsFixed(2)} per 100 eggs'),
                    trailing: rate.date == DateFormat('yyyy-MM-dd').format(DateTime.now())
                        ? Chip(label: Text('Today'))
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRateDialog,
        child: Icon(Icons.edit),
      ),
    );
  }
}
