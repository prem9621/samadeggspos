import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Expense> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      isLoading = true;
    });
    try {
      final list = await dbHelper.getAllExpenses();
      if (!mounted) return;
      setState(() {
        expenses = list;
      });
    } catch (e) {
      debugPrint('Expenses load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showExpenseDialog([Expense? expense]) async {
    final amountController =
        TextEditingController(text: expense?.amount.toString());
    final notesController = TextEditingController(text: expense?.notes);
    String category = expense?.category ?? 'Transport';
    DateTime selectedDate = expense != null
        ? DateFormat('yyyy-MM-dd').parse(expense.date)
        : DateTime.now();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(expense == null ? 'Add Expense' : 'Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setDateState) => ListTile(
                    title: Text(
                      DateFormat('MMM d, yyyy').format(selectedDate),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && picked != selectedDate) {
                        setDateState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                    DropdownMenuItem(value: 'Labour', child: Text('Labour')),
                    DropdownMenuItem(value: 'Electricity', child: Text('Electricity')),
                    DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                    DropdownMenuItem(value: 'Miscellaneous', child: Text('Miscellaneous')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        category = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                final notes = notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim();

                if (amount == null || amount <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid amount')),
                    );
                  }
                  return;
                }

                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                final newExpense = Expense(
                  date: dateStr,
                  category: category,
                  amount: amount,
                  notes: notes,
                );

                if (expense == null) {
                  await dbHelper.insertExpense(newExpense);
                } else {
                  await expense.delete();
                  await dbHelper.insertExpense(newExpense);
                }

                if (mounted) {
                  Navigator.pop(dialogContext);
                  _loadExpenses();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        expense == null
                            ? 'Expense added successfully!'
                            : 'Expense updated successfully!',
                      ),
                    ),
                  );
                }
              },
              child: Text(expense == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showExpenseDialog(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : expenses.isEmpty
              ? const Center(child: Text('No expenses added yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          expense.category,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('MMM d, yyyy').format(
                              DateFormat('yyyy-MM-dd').parse(expense.date),
                            )),
                            if (expense.notes != null) Text(expense.notes!),
                          ],
                        ),
                        trailing: Text(
                          '₹${expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onTap: () => _showExpenseDialog(expense),
                      ),
                    );
                  },
                ),
    );
  }
}
