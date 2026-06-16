import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<SaleWithParty> sales = [];
  List<Party> parties = [];
  Party? selectedPartyFilter;
  DateTime? selectedDateFilter;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final partyList = await dbHelper.getAllParties();
      List<SaleWithParty> saleList;
      if (selectedPartyFilter != null) {
        saleList = await dbHelper.getSalesByParty(selectedPartyFilter!);
      } else if (selectedDateFilter != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDateFilter!);
        saleList = await dbHelper.getSalesByDate(dateStr);
      } else {
        saleList = await dbHelper.getAllSales();
      }
      if (!mounted) return;
      setState(() {
        parties = partyList;
        sales = saleList;
      });
    } catch (e) {
      debugPrint('Sales history load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sales: $e')),
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDateFilter = picked;
        selectedPartyFilter = null;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.date_range),
                  title: Text('Filter by Date'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectDate();
                },
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.group),
                  title: Text('Filter by Party'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showPartyFilterDialog();
                },
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.clear),
                  title: Text('Clear Filters'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedPartyFilter = null;
                    selectedDateFilter = null;
                  });
                  _loadData();
                },
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : sales.isEmpty
              ? const Center(child: Text('No sales found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final item = sales[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.party.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('MMM d, yyyy').format(DateTime.parse(item.sale.saleDate))),
                            Text('${item.sale.eggQuantity.toStringAsFixed(0)} eggs'),
                            if (item.sale.notes != null) Text('Note: ${item.sale.notes}'),
                          ],
                        ),
                        trailing: Text('₹${item.sale.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => _showSaleDetail(item),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _showPartyFilterDialog() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Filter by Party'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: parties
                .map((p) => ListTile(
                      title: Text(p.name),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        setState(() {
                          selectedPartyFilter = p;
                          selectedDateFilter = null;
                        });
                        _loadData();
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showSaleDetail(SaleWithParty item) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Party: ${item.party.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Date: ${DateFormat('MMM d, yyyy').format(DateTime.parse(item.sale.saleDate))}'),
              const SizedBox(height: 8),
              Text('Quantity: ${item.sale.eggQuantity.toStringAsFixed(0)} eggs'),
              const SizedBox(height: 8),
              Text('Base Rate: ₹${item.sale.baseRate.toStringAsFixed(2)} / 100'),
              const SizedBox(height: 8),
              Text('Adjusted Rate: ₹${item.sale.adjustedRate.toStringAsFixed(2)} / 100'),
              const SizedBox(height: 8),
              Text('Total Amount: ₹${item.sale.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (item.sale.notes != null) ...[
                const SizedBox(height: 8),
                Text('Notes: ${item.sale.notes}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
