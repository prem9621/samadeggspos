import 'package:flutter/material.dart';
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
  String? error;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final result = await dbHelper.getAllExpenses();
      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (result.success) {
          expenses = result.data ?? [];
        } else {
          error = result.error;
        }
      });
    } catch (e) {
      debugPrint('Expenses load error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load expenses: $e';
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
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                  }
                  return;
                }

                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                if (expense == null) {
                  final newExpense = Expense.now(
                    date: dateStr,
                    category: category,
                    amount: amount,
                    notes: notes,
                  );
                  final result = await dbHelper.insertExpense(newExpense);
                  if (result.success) {
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _loadExpenses();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense added successfully!')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.error ?? 'Failed to add expense')),
                      );
                    }
                  }
                } else {
                  final updatedExpense = Expense(
                    date: dateStr,
                    category: category,
                    amount: amount,
                    notes: notes,
                    createdAt: expense.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await expense.delete();
                  final result = await dbHelper.insertExpense(updatedExpense);
                  if (result.success) {
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _loadExpenses();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense updated successfully!')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.error ?? 'Failed to update expense')),
                      );
                    }
                  }
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Expenses',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                FloatingActionButton(
                  mini: true,
                  onPressed: () => _showExpenseDialog(),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
        onRefresh: _loadExpenses,
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
                            onPressed: _loadExpenses,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : expenses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.money_off,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No expenses added yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showExpenseDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Expense'),
                              ),
                            ],
                          ),
                        ),
                      )
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
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
