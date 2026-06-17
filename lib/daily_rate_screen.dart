import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';

class DailyRateScreen extends StatefulWidget {
  const DailyRateScreen({super.key});

  @override
  State<DailyRateScreen> createState() => _DailyRateScreenState();
}

class _DailyRateScreenState extends State<DailyRateScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<DailyRate> rateHistory = [];
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
      if (mounted) setState(() { isLoading = false; error = 'Failed to load: $e'; });
    }
  }

  Future<void> _showRateDialog() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = await dbHelper.getDailyRateByDate(today);
    final ctrl = TextEditingController(
      text: existing.data?.baseRate.toStringAsFixed(2) ?? '',
    );
    final isEdit = existing.data != null;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RateBottomSheet(
        controller: ctrl,
        isEdit: isEdit,
        onSave: (rate) async {
          if (isEdit) {
            existing.data!.baseRate = rate;
            final r = await dbHelper.updateDailyRate(existing.data!);
            if (r.success && mounted) {
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rate updated')));
            }
          } else {
            final r = await dbHelper.insertDailyRate(DailyRate.now(today, rate));
            if (r.success && mounted) {
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rate saved')));
            } else if (!r.success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(r.error ?? 'Failed')));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      floatingActionButton: FloatingActionButton(
        onPressed: _showRateDialog,
        backgroundColor: kAmber,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: kAmber,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: kAmber))
            : error != null
                ? _ErrorState(message: error!, onRetry: _load)
                : rateHistory.isEmpty
                    ? _EmptyState(onAdd: _showRateDialog)
                    : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: rateHistory.length,
      itemBuilder: (context, index) {
        final rate = rateHistory[index];
        final isToday = rate.date == today;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isToday ? kAmber : kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isToday ? kAmber : kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, d MMM yyyy')
                          .format(DateTime.parse(rate.date)),
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isToday ? Colors.white : kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${rate.baseRate.toStringAsFixed(2)} per 100 eggs',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: isToday ? Colors.white : kAmber,
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Today',
                    style: TextStyle(fontSize: 11, color: Colors.white,
                      fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: kAmberLight,
                borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.egg_rounded, color: kAmber, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('No rates set yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
            const SizedBox(height: 6),
            const Text('Set today\'s egg rate to get started',
              style: TextStyle(fontSize: 13, color: kTextSub),
              textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Set Today\'s Rate'),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Text(message, style: const TextStyle(fontSize: 13, color: kRed),
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

class _RateBottomSheet extends StatelessWidget {
  final TextEditingController controller;
  final bool isEdit;
  final Function(double) onSave;

  const _RateBottomSheet({
    required this.controller, required this.isEdit, required this.onSave});

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
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder,
                borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text(isEdit ? 'Update Rate' : 'Set Today\'s Rate',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Rate per 100 eggs in ₹',
            style: TextStyle(fontSize: 12, color: kTextSub)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, color: kAmber),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: kAmber),
              hintText: '0.00',
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
                    const SnackBar(content: Text('Enter a valid rate')));
                  return;
                }
                Navigator.pop(context);
                onSave(rate);
              },
              child: Text(isEdit ? 'Update' : 'Save Rate'),
            ),
          ),
        ],
      ),
    );
  }
}