import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';

const _categories = ['Transport', 'Labour', 'Electricity', 'Rent', 'Miscellaneous'];

final _categoryIcons = {
  'Transport': Icons.directions_car_rounded,
  'Labour': Icons.handyman_rounded,
  'Electricity': Icons.bolt_rounded,
  'Rent': Icons.home_rounded,
  'Miscellaneous': Icons.category_rounded,
};

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Expense> expenses = [];
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
      final r = await dbHelper.getAllExpenses();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        expenses = r.data ?? [];
        error = r.success ? null : r.error;
      });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = 'Failed: $e'; });
    }
  }

  double get _totalThisMonth {
    final now = DateTime.now();
    return expenses.fold(0, (sum, e) {
      final d = DateFormat('yyyy-MM-dd').parse(e.date);
      return d.year == now.year && d.month == now.month ? sum + e.amount : sum;
    });
  }

  Future<void> _showDialog([Expense? expense]) async {
    final amtCtrl = TextEditingController(text: expense?.amount.toString());
    final notesCtrl = TextEditingController(text: expense?.notes);
    String category = expense?.category ?? 'Transport';
    DateTime date = expense != null
        ? DateFormat('yyyy-MM-dd').parse(expense.date)
        : DateTime.now();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: kBorder,
                    borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(expense == null ? 'Add Expense' : 'Edit Expense',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                // Date picker row
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: kAmber),
                        const SizedBox(width: 10),
                        Text(DateFormat('d MMM yyyy').format(date),
                          style: const TextStyle(fontSize: 13, color: kText)),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category
                const Text('Category', style: TextStyle(fontSize: 12, color: kTextSub)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: _categories.map((c) => GestureDetector(
                    onTap: () => setSheet(() => category = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: category == c ? kAmber : kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: category == c ? kAmber : kBorder),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_categoryIcons[c] ?? Icons.category_rounded,
                          size: 13, color: category == c ? Colors.white : kTextSub),
                        const SizedBox(width: 5),
                        Text(c, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: category == c ? Colors.white : kText)),
                      ]),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 10),

                // Amount
                TextField(
                  controller: amtCtrl,
                  autofocus: expense == null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kRed),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: kRed),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amt = double.tryParse(amtCtrl.text);
                      if (amt == null || amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid amount')));
                        return;
                      }
                      final dateStr = DateFormat('yyyy-MM-dd').format(date);
                      if (expense == null) {
                        await dbHelper.insertExpense(Expense.now(
                          date: dateStr, category: category, amount: amt,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        ));
                      } else {
                        await expense.delete();
                        await dbHelper.insertExpense(Expense.now(
                          date: dateStr, category: category, amount: amt,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        ));
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(expense == null ? 'Expense added' : 'Updated')));
                      }
                    },
                    child: Text(expense == null ? 'Save Expense' : 'Update'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        backgroundColor: kAmber,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kAmber))
          : RefreshIndicator(
              onRefresh: _load,
              color: kAmber,
              child: expenses.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        // Monthly summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded,
                                color: kRed, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('This Month',
                                style: TextStyle(fontSize: 11, color: kTextSub)),
                              Text('₹${_totalThisMonth.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w700, color: kRed)),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        ...expenses.map((e) => _ExpenseTile(
                          expense: e, onTap: () => _showDialog(e))),
                      ],
                    ),
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: kRed, size: 28)),
          const SizedBox(height: 12),
          const Text('No expenses yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tap + to add an expense',
            style: TextStyle(fontSize: 12, color: kTextSub)),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  const _ExpenseTile({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcons[expense.category] ?? Icons.category_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: kAmber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.category,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(DateFormat('d MMM yyyy')
                      .format(DateFormat('yyyy-MM-dd').parse(expense.date)),
                      style: const TextStyle(fontSize: 11, color: kTextSub)),
                    if (expense.notes != null)
                      Text(expense.notes!,
                        style: const TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
              ),
              Text('-₹${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kRed)),
            ],
          ),
        ),
      ),
    );
  }
}