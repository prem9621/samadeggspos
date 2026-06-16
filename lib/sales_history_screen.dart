import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'main.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<SaleWithParty> sales = [];
  List<Party> parties = [];
  Party? filterParty;
  DateTime? filterDate;
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
      final partyR = await dbHelper.getAllParties();
      List<SaleWithParty> saleList;

      if (filterParty != null) {
        saleList = (await dbHelper.getSalesByParty(filterParty!)).data ?? [];
      } else if (filterDate != null) {
        saleList = (await dbHelper.getSalesByDate(
          DateFormat('yyyy-MM-dd').format(filterDate!))).data ?? [];
      } else {
        saleList = (await dbHelper.getAllSales()).data ?? [];
      }

      if (!mounted) return;
      setState(() {
        parties = partyR.data ?? [];
        sales = saleList;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = 'Failed: $e'; });
    }
  }

  double get _totalAmount => sales.fold(0, (s, e) => s + e.sale.amount);

  @override
  Widget build(BuildContext context) {
    final hasFilter = filterParty != null || filterDate != null;
    return Scaffold(
      backgroundColor: kSurface,
      body: Column(
        children: [
          // Filter bar
          Container(
            color: kCard,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: filterDate != null
                              ? DateFormat('d MMM').format(filterDate!)
                              : 'Date',
                          icon: Icons.calendar_today_rounded,
                          active: filterDate != null,
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: filterDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) {
                              setState(() { filterDate = d; filterParty = null; });
                              _load();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: filterParty?.name ?? 'Party',
                          icon: Icons.person_rounded,
                          active: filterParty != null,
                          onTap: () => _showPartyPicker(),
                        ),
                        if (hasFilter) ...[
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Clear',
                            icon: Icons.clear_rounded,
                            active: false,
                            onTap: () {
                              setState(() { filterDate = null; filterParty = null; });
                              _load();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),

          // Summary
          if (!isLoading && sales.isNotEmpty)
            Container(
              color: kCard,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${sales.length} sales',
                    style: const TextStyle(fontSize: 12, color: kTextSub)),
                  Text('Total: ₹${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGreen)),
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: kAmber))
                : sales.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: kAmber,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: sales.length,
                          itemBuilder: (_, i) => _SaleTile(
                            item: sales[i],
                            onTap: () => _showDetail(sales[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPartyPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: kBorder,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Filter by Party',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: parties.map((p) => ListTile(
                dense: true,
                title: Text(p.name, style: const TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() { filterParty = p; filterDate = null; });
                  _load();
                },
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(SaleWithParty item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Sale Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DetailRow('Party', item.party.name),
            _DetailRow('Date', DateFormat('d MMM yyyy')
              .format(DateTime.parse(item.sale.saleDate))),
            _DetailRow('Quantity', '${item.sale.eggQuantity.toStringAsFixed(0)} eggs'),
            _DetailRow('Base Rate', '₹${item.sale.baseRate.toStringAsFixed(2)} / 100'),
            _DetailRow('Adjusted Rate', '₹${item.sale.adjustedRate.toStringAsFixed(2)} / 100'),
            const Divider(height: 16, color: kBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('₹${item.sale.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kGreen)),
              ],
            ),
            if (item.sale.notes != null) ...[
              const SizedBox(height: 10),
              Text('Note: ${item.sale.notes}',
                style: const TextStyle(fontSize: 12, color: kTextSub)),
            ],
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
            decoration: BoxDecoration(color: kAmberLight,
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.receipt_long_rounded, color: kAmber, size: 28)),
          const SizedBox(height: 12),
          const Text('No sales found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final SaleWithParty item;
  final VoidCallback onTap;
  const _SaleTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
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
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.trending_up_rounded, color: kGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.party.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${item.sale.eggQuantity.toStringAsFixed(0)} eggs · '
                  '${DateFormat('d MMM').format(DateTime.parse(item.sale.saleDate))}',
                  style: const TextStyle(fontSize: 11, color: kTextSub)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${item.sale.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreen)),
              Text('₹${item.sale.adjustedRate.toStringAsFixed(0)}/100',
                style: const TextStyle(fontSize: 11, color: kTextSub)),
            ],
          ),
        ]),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? kAmber : kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? kAmber : kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: active ? Colors.white : kTextSub),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: active ? Colors.white : kText)),
      ]),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSub)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}