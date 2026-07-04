import 'package:flutter/material.dart';
import 'models.dart';
import 'main.dart';

/// Slide-up bottom sheet to pick a Party (customer or supplier).
///
/// FIX: row taps were unreliable inside DraggableScrollableSheet because
/// the sheet's own drag/scroll gesture recognizer could win the gesture
/// arena before a plain InkWell tap registered, especially on real
/// devices. Each row is now an explicit GestureDetector with
/// behavior: HitTestBehavior.opaque wrapped in its own Material, so a
/// tap anywhere on the row — not just the ripple area — always wins and
/// always returns a result through Navigator.pop.
Future<Party?> showPartyPickerSheet({
  required BuildContext context,
  required List<Party> parties,
  required String title,
  Party? current,
  VoidCallback? onAddNew,
}) {
  return showModalBottomSheet<Party>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => _PartyPickerSheet(
      parties: parties,
      title: title,
      current: current,
      onAddNew: onAddNew,
    ),
  );
}

class _PartyPickerSheet extends StatefulWidget {
  final List<Party> parties;
  final String title;
  final Party? current;
  final VoidCallback? onAddNew;

  const _PartyPickerSheet({
    required this.parties,
    required this.title,
    required this.current,
    this.onAddNew,
  });

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  String _query = '';

  List<Party> get _filtered {
    if (_query.trim().isEmpty) return widget.parties;
    final q = _query.toLowerCase();
    return widget.parties.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  /// Selecting a party always pops this sheet's own modal route with the
  /// chosen party as the result.
  void _select(Party p) {
    Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
                  ),
                  if (widget.onAddNew != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onAddNew!();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kAmberLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: kAmber),
                              SizedBox(width: 3),
                              Text('New', style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: kAmber)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('No parties found',
                        style: const TextStyle(fontSize: 13, color: kTextSub)),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        final isSelected = widget.current?.key == p.key;
                        return _PartyRow(
                          party: p,
                          isSelected: isSelected,
                          onTap: () => _select(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single row in the picker list. Pulled into its own widget with an
/// explicit, opaque GestureDetector + Material wrapper so the tap is
/// never swallowed by the parent DraggableScrollableSheet's own drag
/// gesture recognizer. This is the actual fix for "tapping a party does
/// nothing" — a plain InkWell nested this deep inside a draggable sheet
/// can lose the gesture arena on a real device even though it appears
/// to work fine in quick emulator testing.
class _PartyRow extends StatelessWidget {
  final Party party;
  final bool isSelected;
  final VoidCallback onTap;

  const _PartyRow({
    required this.party,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = party;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? kAmberLight : kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? kAmber : kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: p.type == PartyType.customer
                      ? const Color(0xFFEFF6FF) : kAmberLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  p.type == PartyType.customer
                      ? Icons.person_rounded : Icons.local_shipping_rounded,
                  size: 16,
                  color: p.type == PartyType.customer ? kBlue : kAmber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                    if (p.phone != null && p.phone!.isNotEmpty)
                      Text(p.phone!, style: const TextStyle(
                        fontSize: 11, color: kTextSub)),
                  ],
                ),
              ),
              // Inline adjustment pill — uses Party.adjustmentLabel from
              // models.dart so this always matches every other screen.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder),
                ),
                child: Text(p.adjustmentLabel, style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub)),
              ),
              // NEW: quantity pill — the minimum quantity set for this
              // party (percentageMinQuantity), independent of whether a
              // percentage is active, so it's always visible here too.
              if (p.percentageMinQuantity > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBlueLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qty ≥${p.percentageMinQuantity.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: kBlue),
                  ),
                ),
              ],
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, size: 16, color: kAmber),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tap-target that opens the picker sheet. Use this instead of
/// DropdownButtonFormField for party/supplier selection.
class PartySelectField extends StatelessWidget {
  final Party? selected;
  final String label;
  final List<Party> parties;
  final ValueChanged<Party?> onChanged;
  final VoidCallback? onAddNew;

  const PartySelectField({
    super.key,
    required this.selected,
    required this.label,
    required this.parties,
    required this.onChanged,
    this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await showPartyPickerSheet(
            context: context,
            parties: parties,
            title: label,
            current: selected,
            onAddNew: onAddNew,
          );
          if (picked != null) onChanged(picked);
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
              Icon(
                selected == null ? Icons.person_search_rounded : Icons.person_rounded,
                size: 17,
                color: selected == null ? kTextMuted : kAmber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected?.name ?? label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected == null ? FontWeight.w400 : FontWeight.w600,
                    color: selected == null ? kTextMuted : kText,
                  ),
                ),
              ),
              if (selected != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(selected!.adjustmentLabel, style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub)),
                ),
                // NEW: quantity chip next to the adjustment chip, shown
                // whenever this party has a minimum quantity set.
                if (selected!.percentageMinQuantity > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kBlueLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Qty ≥${selected!.percentageMinQuantity.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: kBlue),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}