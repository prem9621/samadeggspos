import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'database_helper.dart';

/// One row in the combined, time-ordered ledger for a party — a sale,
/// a purchase (relevant if the party is also a supplier), or a
/// payment, normalised into a single shape so they can be sorted
/// together by date and printed as one running statement.
class _LedgerEntry {
  final DateTime date;
  final String type; // 'Sale', 'Purchase', 'Payment In', 'Payment Out'
  final double quantity; // 0 for payments
  final double rate; // 0 for payments
  final double amount; // absolute amount of this transaction
  final double signedAmount; // the actual ledger delta, +/- by type
  final String? notes;

  _LedgerEntry({
    required this.date,
    required this.type,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.signedAmount,
    this.notes,
  });
}

class PartyStatementResult {
  final File file;
  final double finalBalance;
  PartyStatementResult({required this.file, required this.finalBalance});
}

/// Builds a complete ledger for [party] — every sale, purchase, and
/// payment, in date order, each showing the rate actually used for
/// that transaction and a running balance — then renders it as a PDF
/// invoice-style statement and saves it to the app's documents
/// directory, ready to be shared via [shareStatement].
///
/// Balance sign convention matches DatabaseHelper.getPartyBalance:
/// positive = party owes the shop (shop is "to receive"),
/// negative = shop owes the party (shop is "to pay").
Future<PartyStatementResult> generatePartyStatementPdf({
  required Party party,
  String? shopName,
  String? shopPhone,
  String? shopAddress,
}) async {
  final db = DatabaseHelper.instance;

  final salesR = await db.getSalesByParty(party);
  final purchasesR = await db.getPurchasesBySupplier(party);
  final paymentsR = await db.getPaymentsByParty(party);

  final entries = <_LedgerEntry>[];

  for (final s in salesR.data ?? []) {
    entries.add(_LedgerEntry(
      date: DateFormat('yyyy-MM-dd').parse(s.sale.saleDate),
      type: 'Sale',
      quantity: s.sale.eggQuantity,
      rate: s.sale.adjustedRate,
      amount: s.sale.amount,
      signedAmount: s.sale.amount, // sale increases what party owes us
      notes: s.sale.notes,
    ));
  }

  for (final p in purchasesR.data ?? []) {
    entries.add(_LedgerEntry(
      date: DateFormat('yyyy-MM-dd').parse(p.purchase.purchaseDate),
      type: 'Purchase',
      quantity: p.purchase.eggQuantity,
      rate: p.purchase.adjustedRate,
      amount: p.purchase.amount,
      signedAmount: -p.purchase.amount, // purchase reduces what they owe us
      notes: p.purchase.notes,
    ));
  }

  for (final pay in paymentsR.data ?? []) {
    final isReceived = pay.payment.paymentType == 'received';
    entries.add(_LedgerEntry(
      date: DateFormat('yyyy-MM-dd').parse(pay.payment.date),
      type: isReceived ? 'Payment In' : 'Payment Out',
      quantity: 0,
      rate: 0,
      amount: pay.payment.amount,
      // payment received from party reduces what they owe us;
      // payment paid to party increases what they owe us — mirrors
      // the sign convention in DatabaseHelper.getPartyBalance
      signedAmount: isReceived ? -pay.payment.amount : pay.payment.amount,
      notes: pay.payment.notes,
    ));
  }

  entries.sort((a, b) => a.date.compareTo(b.date));

  double running = 0;
  final rows = <List<String>>[];
  for (final e in entries) {
    running += e.signedAmount;
    rows.add([
      DateFormat('d MMM yyyy').format(e.date),
      e.type,
      e.quantity > 0 ? e.quantity.toStringAsFixed(0) : '-',
      e.rate > 0 ? 'Rs.${e.rate.toStringAsFixed(2)}' : '-',
      'Rs.${e.amount.toStringAsFixed(2)}',
      'Rs.${running.toStringAsFixed(2)}',
    ]);
  }

  final pdf = pw.Document();
  final dateGenerated = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shopName ?? 'Samad Eggs',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  if (shopAddress != null)
                    pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 9)),
                  if (shopPhone != null)
                    pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('STATEMENT',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateGenerated, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(party.name,
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    if (party.phone != null) pw.Text(party.phone!, style: const pw.TextStyle(fontSize: 9)),
                    if (party.address != null) pw.Text(party.address!, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(party.type == PartyType.customer ? 'Customer' : 'Supplier',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (party.hasAdjustment)
                      pw.Text('Rate adjustment: ${party.adjustmentLabel}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ),
      build: (ctx) => [
        if (rows.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 30),
            child: pw.Center(
              child: pw.Text('No transactions recorded yet.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Qty', 'Rate', 'Amount', 'Balance'],
            data: rows,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(1.7),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FlexColumnWidth(1.8),
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
          ),
        pw.SizedBox(height: 18),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  running >= 0 ? 'Balance Receivable: ' : 'Balance Payable: ',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Rs.${running.abs().toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final safeName = party.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final fileName = 'Statement_${safeName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());

  return PartyStatementResult(file: file, finalBalance: running);
}

/// Opens the native share sheet so the user can send the generated PDF
/// via WhatsApp, email, or save it wherever they like.
Future<void> shareStatement(PartyStatementResult result, {required String partyName}) async {
  await Share.shareXFiles(
    [XFile(result.file.path)],
    text: 'Statement for $partyName',
  );
}