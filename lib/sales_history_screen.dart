import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final partyResult = await dbHelper.getAllParties();
      if (!partyResult.success) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          error = partyResult.error;
        });
        return;
      }

      List<SaleWithParty> saleList;
      if (selectedPartyFilter != null) {
        final salesResult = await dbHelper.getSalesByParty(selectedPartyFilter!);
        if (!salesResult.success) {
          if (!mounted) return;
          setState(() {
            isLoading = false;
            error = salesResult.error;
          });
          return;
        }
        saleList = salesResult.data ?? [];
      } else if (selectedDateFilter != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDateFilter!);
        final salesResult = await dbHelper.getSalesByDate(dateStr);
        if (!salesResult.success) {
          if (!mounted) return;
          setState(() {
            isLoading = false;
            error = salesResult.error;
          });
          return;
        }
        saleList = salesResult.data ?? [];
      } else {
        final salesResult = await dbHelper.getAllSales();
        if (!salesResult.success) {
          if (!mounted) return;
          setState(() {
            isLoading = false;
            error = salesResult.error;
          });
          return;
        }
        saleList = salesResult.data ?? [];
      }

      if (!mounted) return;
      setState(() {
        parties = partyResult.data ?? [];
        sales = saleList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Sales history load error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load sales: $e';
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
      body: RefreshIndicator(
        onRefresh: _loadData,
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
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : sales.isEmpty
                    ? const Center(child: Text('No sales found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sales.length,
                        itemBuilder: (context, index) {
                          final item = sales[index];
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(item.party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
