import 'package:flutter/material.dart';
import 'models.dart';
import 'database_helper.dart';
import 'party_ledger_screen.dart';
import 'main.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper.instance;
  List<Party> allParties = [];
  Map<int, double> balances = {};
  bool isLoading = true;
  String? error;
  final searchCtrl = TextEditingController();
  String searchQuery = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { isLoading = true; error = null; });
    try {
      final r = await dbHelper.getAllParties();
      if (!mounted) return;
      if (r.success) {
        allParties = r.data ?? [];
        for (final p in allParties) {
          final b = await dbHelper.getPartyBalance(p);
          if (b.success) balances[p.key as int] = b.data ?? 0;
        }
        setState(() => isLoading = false);
      } else {
        setState(() { isLoading = false; error = r.error; });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = 'Failed: $e'; });
    }
  }

  List<Party> _filtered(PartyType? type) {
    var list = type == null ? allParties : allParties.where((p) => p.type == type).toList();
    if (searchQuery.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }
    return list;
  }

  Future<void> _showPartyDialog([Party? party]) async {
    final nameCtrl = TextEditingController(text: party?.name);
    final phoneCtrl = TextEditingController(text: party?.phone);
    final addrCtrl = TextEditingController(text: party?.address);
    final notesCtrl = TextEditingController(text: party?.notes);
    final adjCtrl = TextEditingController(text: party?.adjustmentValue.toString() ?? '0');
    String adjType = party?.adjustmentType ?? '=';
    PartyType pType = party?.type ?? PartyType.customer;

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
                Text(party == null ? 'Add Party' : 'Edit Party',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _Field(controller: nameCtrl, label: 'Name', hint: 'Enter party name'),
                const SizedBox(height: 10),
                _Field(controller: phoneCtrl, label: 'Phone (optional)',
                  hint: '10-digit number', keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _Field(controller: addrCtrl, label: 'Address (optional)', hint: 'Area / city'),
                const SizedBox(height: 10),
                // Party type chips
                Row(
                  children: [
                    const Text('Type', style: TextStyle(fontSize: 12, color: kTextSub)),
                    const SizedBox(width: 12),
                    _TypeChip(label: 'Customer', selected: pType == PartyType.customer,
                      onTap: () => setSheet(() => pType = PartyType.customer)),
                    const SizedBox(width: 8),
                    _TypeChip(label: 'Supplier', selected: pType == PartyType.supplier,
                      onTap: () => setSheet(() => pType = PartyType.supplier)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: adjType,
                      decoration: const InputDecoration(labelText: 'Rate Adj.'),
                      items: const [
                        DropdownMenuItem(value: '=', child: Text('No change')),
                        DropdownMenuItem(value: '+', child: Text('+ Fixed')),
                        DropdownMenuItem(value: '-', child: Text('- Fixed')),
                        DropdownMenuItem(value: '+%', child: Text('+ %')),
                        DropdownMenuItem(value: '-%', child: Text('- %')),
                      ],
                      onChanged: (v) => setSheet(() => adjType = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: adjCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Value'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _Field(controller: notesCtrl, label: 'Notes (optional)',
                  hint: 'Any remarks', maxLines: 2),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter party name')));
                        return;
                      }
                      final adjVal = double.tryParse(adjCtrl.text) ?? 0.0;
                      if (party == null) {
                        final r = await dbHelper.insertParty(Party.now(
                          name: name,
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                          adjustmentType: adjType,
                          adjustmentValue: adjVal,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          type: pType,
                        ));
                        if (r.success && mounted) {
                          Navigator.pop(ctx); _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Party added')));
                        }
                      } else {
                        await party.delete();
                        final r = await dbHelper.insertParty(Party(
                          name: name,
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                          adjustmentType: adjType,
                          adjustmentValue: adjVal,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          createdAt: party.createdAt,
                          updatedAt: DateTime.now(),
                          type: pType,
                        ));
                        if (r.success && mounted) {
                          Navigator.pop(ctx); _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Party updated')));
                        }
                      }
                    },
                    child: Text(party == null ? 'Save Party' : 'Update'),
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
        onPressed: () => _showPartyDialog(),
        backgroundColor: kAmber,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_rounded),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: searchCtrl,
              onChanged: (v) => setState(() => searchQuery = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search parties...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: kTextMuted),
                        onPressed: () => setState(() {
                          searchCtrl.clear();
                          searchQuery = '';
                        }),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tabs
          TabBar(
            controller: _tabCtrl,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            labelColor: kAmber,
            unselectedLabelColor: kTextSub,
            indicatorColor: kAmber,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Customers'),
              Tab(text: 'Suppliers'),
            ],
          ),
          const Divider(height: 1, color: kBorder),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: kAmber))
                : error != null
                    ? Center(child: Text(error!,
                        style: const TextStyle(fontSize: 13, color: kRed)))
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _PartyList(parties: _filtered(null), balances: balances,
                            onTap: (p) => _goLedger(p),
                            onEdit: (p) => _showPartyDialog(p),
                            onDelete: _deleteParty,
                          ),
                          _PartyList(parties: _filtered(PartyType.customer), balances: balances,
                            onTap: (p) => _goLedger(p),
                            onEdit: (p) => _showPartyDialog(p),
                            onDelete: _deleteParty,
                          ),
                          _PartyList(parties: _filtered(PartyType.supplier), balances: balances,
                            onTap: (p) => _goLedger(p),
                            onEdit: (p) => _showPartyDialog(p),
                            onDelete: _deleteParty,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _goLedger(Party p) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PartyLedgerScreen(party: p))).then((_) => _load());
  }

  Future<void> _deleteParty(Party p) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Party?', style: TextStyle(fontSize: 15)),
        content: Text('Remove ${p.name} from your party list.',
          style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Delete')),
        ],
      ));
    if (ok == true) {
      await dbHelper.deleteParty(p);
      _load();
    }
  }
}

class _PartyList extends StatelessWidget {
  final List<Party> parties;
  final Map<int, double> balances;
  final ValueChanged<Party> onTap;
  final ValueChanged<Party> onEdit;
  final ValueChanged<Party> onDelete;

  const _PartyList({
    required this.parties, required this.balances,
    required this.onTap, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(color: kAmberLight,
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.people_rounded, color: kAmber, size: 28)),
            const SizedBox(height: 12),
            const Text('No parties found',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: parties.length,
      itemBuilder: (context, index) {
        final p = parties[index];
        final bal = balances[p.key as int] ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: p.type == PartyType.customer
                          ? const Color(0xFFEFF6FF) : kAmberLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      p.type == PartyType.customer
                          ? Icons.person_rounded : Icons.local_shipping_rounded,
                      color: p.type == PartyType.customer ? kBlue : kAmber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                        if (p.phone != null)
                          Text(p.phone!, style: const TextStyle(
                            fontSize: 11, color: kTextSub)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              bal == 0 ? 'Settled' : '₹${bal.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: bal > 0 ? kGreen : bal < 0 ? kRed : kTextMuted,
                              ),
                            ),
                            if (bal != 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                bal > 0 ? '· to receive' : '· to pay',
                                style: const TextStyle(fontSize: 11, color: kTextSub),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => onEdit(p),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.edit_rounded, size: 16, color: kTextSub),
                        ),
                      ),
                      InkWell(
                        onTap: () => onDelete(p),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                        ),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _Field({
    required this.controller, required this.label, required this.hint,
    this.keyboardType, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? kAmber : kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? kAmber : kBorder),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: selected ? Colors.white : kTextSub,
      )),
    ),
  );
}