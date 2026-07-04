import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'stats_helper.dart';
import 'party_statement_screen.dart';
import 'main.dart';

/// "View All" destination from the dashboard's Top Parties / Pending
/// Dues preview cards. Three tabs; tapping any party row opens the
/// existing PartyStatementScreen (no new statement UI duplicated).
class TopPartiesDuesScreen extends StatefulWidget {
  final int initialTab; // 0 = Top Customers, 1 = Top Suppliers, 2 = Pending Dues
  const TopPartiesDuesScreen({super.key, this.initialTab = 0});

  @override
  State<TopPartiesDuesScreen> createState() => _TopPartiesDuesScreenState();
}

class _TopPartiesDuesScreenState extends State<TopPartiesDuesScreen>
    with SingleTickerProviderStateMixin {
  final statsHelper = StatsHelper.instance;
  late final TabController _tabController;

  bool isLoading = true;
  String? error;
  List<PartyRanked> topCustomers = [];
  List<PartyRanked> topSuppliers = [];
  List<PendingDue> pendingDues = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final customersR = await statsHelper.getTopParties(
        type: PartyType.customer,
        limit: 20,
      );
      final suppliersR = await statsHelper.getTopParties(
        type: PartyType.supplier,
        limit: 20,
      );
      final duesR = await statsHelper.getPendingDues();

      if (!mounted) return;
      setState(() {
        isLoading = false;
        topCustomers = customersR.data ?? [];
        topSuppliers = suppliersR.data ?? [];
        pendingDues = duesR.data ?? [];
        error = customersR.error ?? suppliersR.error ?? duesR.error;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load: $e';
        });
      }
    }
  }

  void _openStatement(Party party) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyStatementScreen(party: party),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Parties & Dues'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kBlue,
          unselectedLabelColor: kTextSub,
          indicatorColor: kBlue,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Top Customers'),
            Tab(text: 'Top Suppliers'),
            Tab(text: 'Pending Dues'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kBlue))
          : error != null
              ? _ErrorState(message: error!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _TopPartiesList(
                      parties: topCustomers,
                      emptyText: 'No customer sales yet',
                      unitLabel: 'eggs sold',
                      onTap: _openStatement,
                    ),
                    _TopPartiesList(
                      parties: topSuppliers,
                      emptyText: 'No supplier purchases yet',
                      unitLabel: 'eggs bought',
                      onTap: _openStatement,
                    ),
                    _PendingDuesList(
                      dues: pendingDues,
                      onTap: _openStatement,
                    ),
                  ],
                ),
    );
  }
}

class _TopPartiesList extends StatelessWidget {
  final List<PartyRanked> parties;
  final String emptyText;
  final String unitLabel;
  final void Function(Party) onTap;

  const _TopPartiesList({
    required this.parties,
    required this.emptyText,
    required this.unitLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (parties.isEmpty) {
      return _EmptyState(text: emptyText);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: parties.length,
      itemBuilder: (context, i) {
        final p = parties[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(p.party),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < 3 ? kAmberLight : kBlueLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: i < 3 ? kAmberDark : kBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.party.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kText,
                          ),
                        ),
                        Text(
                          '${p.totalQuantity.toStringAsFixed(0)} $unitLabel',
                          style: const TextStyle(fontSize: 11, color: kTextSub),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${p.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PendingDuesList extends StatelessWidget {
  final List<PendingDue> dues;
  final void Function(Party) onTap;

  const _PendingDuesList({required this.dues, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (dues.isEmpty) {
      return _EmptyState(text: 'No pending dues — all settled!');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: dues.length,
      itemBuilder: (context, i) {
        final d = dues[i];
        final isReceivable = d.balance > 0; // party owes shop
        final color = isReceivable ? kGreen : kRed;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(d.party),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      isReceivable
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded,
                      color: color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.party.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kText,
                          ),
                        ),
                        Text(
                          'Since ${DateFormat('d MMM yyyy').format(d.oldestActivity)}',
                          style: const TextStyle(fontSize: 11, color: kTextSub),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${d.balance.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        isReceivable ? 'To receive' : 'To pay',
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kAmberLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.inbox_rounded, color: kAmber, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextSub),
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
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: kRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}