import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_helper.dart';
import 'party_ledger_screen.dart';
import 'main.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});
  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen>
    with SingleTickerProviderStateMixin {
  final dbHelper = DatabaseHelper.instance;
  List<Party> allParties = [];
  Map<dynamic, double> balances = {};
  bool isLoading = true;
  String? error;
  final searchCtrl = TextEditingController();
  String searchQuery = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    // FIX: Suppliers tab removed — only All / Customers remain now, so
    // the controller length must match the 2 tabs below (it was still 3,
    // which crashes with "controller.length != tabs.length"). Suppliers
    // are still saved normally (via Purchase Entry's inline Add Supplier,
    // or by picking "Supplier" type here) — they just show up under "All"
    // instead of having their own dedicated tab.
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final r = await dbHelper.getAllParties();
      if (!mounted) return;
      if (r.success) {
        allParties = r.data ?? [];
        final balanceResult = await dbHelper.getAllPartyBalances();
        if (!mounted) return;
        setState(() {
          balances = balanceResult.data ?? {};
          isLoading = false;
          error = balanceResult.success ? null : balanceResult.error;
        });
      } else {
        setState(() {
          isLoading = false;
          error = r.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed: $e';
        });
      }
    }
  }

  List<Party> _filtered(PartyType? type) {
    var list = type == null
        ? allParties
        : allParties.where((p) => p.type == type).toList();
    if (searchQuery.isNotEmpty) {
      list = list
          .where(
            (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }
    return list;
  }

  Future<void> _showPartyDialog([Party? party]) async {
    final nameCtrl = TextEditingController(text: party?.name);
    final phoneCtrl = TextEditingController(text: party?.phone);
    final addrCtrl = TextEditingController(text: party?.address);
    final notesCtrl = TextEditingController(text: party?.notes);
    final adjCtrl = TextEditingController(
      text: (party?.adjustmentValue ?? 0) == 0
          ? ''
          : party!.adjustmentValue.toString(),
    );
    // NEW: Advance Payment — only meaningful when creating a brand-new
    // party (an opening advance). Not shown when editing an existing one,
    // since re-entering an amount there would create a duplicate payment
    // every time the party is edited.
    final advanceCtrl = TextEditingController();

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
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  party == null ? 'Add Party' : 'Edit Party',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
                const SizedBox(height: 14),

                // Name
                _Field(
                  controller: nameCtrl,
                  label: 'Name *',
                  hint: 'Party name',
                ),
                const SizedBox(height: 9),

                // Phone + Address on one line each (compact)
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: phoneCtrl,
                        label: 'Phone',
                        hint: 'Optional',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Field(
                        controller: addrCtrl,
                        label: 'Address',
                        hint: 'Optional',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),

                // Type chips
                Row(
                  children: [
                    const Text(
                      'Type  ',
                      style: TextStyle(fontSize: 11, color: kTextSub),
                    ),
                    _TypeChip(
                      label: 'Customer',
                      selected: pType == PartyType.customer,
                      onTap: () => setSheet(() => pType = PartyType.customer),
                    ),
                    const SizedBox(width: 7),
                    _TypeChip(
                      label: 'Supplier',
                      selected: pType == PartyType.supplier,
                      onTap: () => setSheet(() => pType = PartyType.supplier),
                    ),
                  ],
                ),
                const SizedBox(height: 9),

                // Rate Adjustment – inline compact row
                _RateAdjRow(
                  adjType: adjType,
                  adjCtrl: adjCtrl,
                  onTypeChanged: (v) => setSheet(() => adjType = v),
                ),
                const SizedBox(height: 14),

                // NEW: Advance Payment (only for a brand-new party). Shows
                // whether this will be money we RECEIVED (customer advance)
                // or PAID (supplier advance) based on the Type chip above.
                if (party == null) ...[
                  Text(
                    pType == PartyType.customer
                        ? 'Advance Payment (Received from customer)'
                        : 'Advance Payment (Paid to supplier)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: advanceCtrl,
                    label: 'Advance Amount (Optional)',
                    hint: 'e.g., 5000',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Leave empty or 0 if there\'s no advance. A payment '
                    'entry will be created automatically for this amount.',
                    style: TextStyle(fontSize: 10, color: kTextMuted),
                  ),
                  const SizedBox(height: 14),
                ],

                // Notes
                _Field(
                  controller: notesCtrl,
                  label: 'Notes',
                  hint: 'Optional',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter party name')),
                        );
                        return;
                      }
                      final adjVal = double.tryParse(adjCtrl.text) ?? 0.0;
                      final advanceAmt = party == null
                          ? (double.tryParse(advanceCtrl.text) ?? 0.0)
                          : 0.0;

                      if (advanceAmt < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Advance amount cannot be negative'),
                          ),
                        );
                        return;
                      }

                      DatabaseResult<Party> r;
                      if (party == null) {
                        r = await dbHelper.insertParty(
                          Party.now(
                            name: name,
                            phone: _nullIfEmpty(phoneCtrl.text),
                            address: _nullIfEmpty(addrCtrl.text),
                            adjustmentType: adjType,
                            adjustmentValue: adjVal,
                            notes: _nullIfEmpty(notesCtrl.text),
                            type: pType,
                          ),
                        );
                      } else {
                        // Update in-place (preserves Hive key, so linked records stay intact)
                        party.name = name;
                        party.phone = _nullIfEmpty(phoneCtrl.text);
                        party.address = _nullIfEmpty(addrCtrl.text);
                        party.adjustmentType = adjType;
                        party.adjustmentValue = adjVal;
                        party.notes = _nullIfEmpty(notesCtrl.text);
                        party.type = pType;
                        r = await dbHelper.updateParty(party);
                      }

                      if (r.success && mounted) {
                        // NEW: if an advance was entered for a brand-new
                        // party, create a matching Payment record so it
                        // shows up in the ledger and balance right away.
                        if (party == null && advanceAmt > 0 && r.data != null) {
                          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                          await dbHelper.insertPayment(
                            Payment.now(
                              partyKey: r.data!.key as int,
                              date: today,
                              amount: advanceAmt,
                              notes: 'Opening advance',
                              paymentType: pType == PartyType.customer
                                  ? 'received'
                                  : 'paid',
                            ),
                          );
                        }

                        Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              party == null ? 'Party added' : 'Party updated',
                            ),
                          ),
                        );
                      } else if (!r.success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(r.error ?? 'Failed')),
                        );
                      }
                    },
                    child: Text(party == null ? 'Save Party' : 'Update Party'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  /// NEW: Quick "Add Payment" popup, reachable directly from a party row
  /// on this screen — same date/type/amount/notes fields as the Party
  /// Ledger screen's Add Payment sheet, but without needing to open the
  /// ledger first.
  Future<void> _showQuickPaymentDialog(Party party) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String paymentType = party.type == PartyType.customer ? 'received' : 'paid';
    DateTime selectedDate = DateTime.now();

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
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add Payment · ${party.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
                const SizedBox(height: 16),

                // Date picker row
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: kAmber,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('d MMM yyyy').format(selectedDate),
                          style: const TextStyle(fontSize: 13, color: kText),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: kTextMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                const Text(
                  'Payment Type',
                  style: TextStyle(fontSize: 11.5, color: kTextSub),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceChip(
                        label: 'Received',
                        selected: paymentType == 'received',
                        onTap: () => setSheet(() => paymentType = 'received'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoiceChip(
                        label: 'Paid',
                        selected: paymentType == 'paid',
                        onTap: () => setSheet(() => paymentType = 'paid'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kAmber,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      final notes = notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim();

                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                          ),
                        );
                        return;
                      }

                      final dateStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(selectedDate);
                      final newPayment = Payment.now(
                        partyKey: party.key as int,
                        date: dateStr,
                        amount: amount,
                        notes: notes,
                        paymentType: paymentType,
                      );
                      final result = await dbHelper.insertPayment(newPayment);
                      if (result.success) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment added')),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.error ?? 'Failed to add payment',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Save Payment'),
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
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPartyDialog(),
        child: const Icon(Icons.person_add_rounded),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: TextField(
              controller: searchCtrl,
              onChanged: (v) => setState(() => searchQuery = v),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search parties...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: kTextMuted,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 14,
                          color: kTextMuted,
                        ),
                        onPressed: () => setState(() {
                          searchCtrl.clear();
                          searchQuery = '';
                        }),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TabBar(
            controller: _tabCtrl,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            labelColor: kBlue,
            unselectedLabelColor: kTextSub,
            indicatorColor: kBlue,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Customers'),
            ],
          ),
          Container(height: 1, color: kBorder),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: kBlue))
                : error != null
                ? Center(
                    child: Text(
                      error!,
                      style: const TextStyle(fontSize: 12, color: kRed),
                    ),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // "All" — includes both customers AND suppliers
                      // (suppliers no longer have their own tab, but any
                      // party saved with Type=Supplier, whether from here
                      // or from Purchase Entry's inline Add Supplier,
                      // still shows up here).
                      _PartyList(
                        parties: _filtered(null),
                        balances: balances,
                        onTap: _goLedger,
                        onEdit: _showPartyDialog,
                        onDelete: _deleteParty,
                        onPayment: _showQuickPaymentDialog,
                      ),
                      _PartyList(
                        parties: _filtered(PartyType.customer),
                        balances: balances,
                        onTap: _goLedger,
                        onEdit: _showPartyDialog,
                        onDelete: _deleteParty,
                        onPayment: _showQuickPaymentDialog,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _goLedger(Party p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PartyLedgerScreen(party: p)),
    ).then((_) => _load());
  }

  Future<void> _deleteParty(Party p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Party?', style: TextStyle(fontSize: 14)),
        content: Text(
          'Remove ${p.name}?',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await dbHelper.deleteParty(p);
      _load();
    }
  }
}

// ─── Rate Adjustment Row ──────────────────────────────────────────────────────
class _RateAdjRow extends StatelessWidget {
  final String adjType;
  final TextEditingController adjCtrl;
  final ValueChanged<String> onTypeChanged;

  const _RateAdjRow({
    required this.adjType,
    required this.adjCtrl,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const modes = ['=', '+', '-'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate Adjustment',
          style: TextStyle(fontSize: 11, color: kTextSub),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ...modes.map((m) {
              final selected = adjType == m;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => onTypeChanged(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? kBlue : kCard,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: selected ? kBlue : kBorder),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : kTextSub,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (adjType != '=') ...[
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: adjCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: adjType.contains('%') ? '% value' : '₹ value',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (adjType == '=')
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Same as today\'s base rate',
              style: TextStyle(fontSize: 10, color: kTextMuted),
            ),
          ),
      ],
    );
  }
}

// ─── Party List ───────────────────────────────────────────────────────────────
class _PartyList extends StatelessWidget {
  final List<Party> parties;
  final Map<dynamic, double> balances;
  final ValueChanged<Party> onTap;
  final ValueChanged<Party> onEdit;
  final ValueChanged<Party> onDelete;
  final ValueChanged<Party> onPayment;

  const _PartyList({
    required this.parties,
    required this.balances,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    if (parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.people_rounded, color: kBlue, size: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'No parties found',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kText,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      itemCount: parties.length,
      itemBuilder: (context, index) {
        final p = parties[index];
        final bal = balances[p.key] ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: kBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => onTap(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.type == PartyType.customer
                          ? kBlueLight
                          : kAmberLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      p.type == PartyType.customer
                          ? Icons.person_rounded
                          : Icons.local_shipping_rounded,
                      color: p.type == PartyType.customer ? kBlue : kAmber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kText,
                          ),
                        ),
                        if (p.phone != null)
                          Text(
                            p.phone!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: kTextSub,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              bal == 0
                                  ? 'Settled'
                                  : '₹${bal.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: bal > 0
                                    ? kGreen
                                    : bal < 0
                                    ? kRed
                                    : kTextMuted,
                              ),
                            ),
                            if (bal != 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                bal > 0 ? '· to receive' : '· to pay',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: kTextSub,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Adj badge
                  if (p.adjustmentType != '=')
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kAmberLight,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${p.adjustmentType}${p.adjustmentValue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kAmberDark,
                        ),
                      ),
                    ),
                  // Percentage badge — kept for parties that already had a
                  // percentage set before this field was removed from the
                  // form; the underlying Party fields still exist, we just
                  // no longer collect them here.
                  if (p.hasPercentage)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyan[100],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${p.percentageType![0].toUpperCase()} ${p.percentageValue.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.cyan[900],
                        ),
                      ),
                    ),
                  if (p.percentageMinQuantity > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kBlueLight,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Qty ≥${p.percentageMinQuantity.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kBlue,
                        ),
                      ),
                    ),
                  // NEW: quick Add Payment icon — opens the payment popup
                  // directly from this row, no need to open the Ledger.
                  InkWell(
                    onTap: () => onPayment(p),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.payments_rounded,
                        size: 14,
                        color: kGreen,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => onEdit(p),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: kTextSub,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => onDelete(p),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: kRed,
                      ),
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

// ─── Helper Widgets ───────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 12),
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? kBlue : kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? const Color.fromRGBO(37, 99, 235, 1) : kBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : kTextSub,
        ),
      ),
    ),
  );
}

/// Simple two-way toggle chip used in the quick Add Payment popup
/// (Received / Paid) — same visual style as the one in the Party Ledger
/// screen's own Add Payment sheet.
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? kAmber : kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? kAmber : kBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : kTextSub,
        ),
      ),
    ),
  );
}