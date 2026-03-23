import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../data/models/transaction.dart';
import '../utils/number_formatter.dart';

class ExportService {
  // ── CSV ─────────────────────────────────────────────────────────────────────

  Future<void> exportCsv(List<AppTransaction> transactions, String currency) async {
    final sb = StringBuffer();
    sb.writeln('Date,Merchant,Category,Type,Amount,Status,Note');
    for (final t in transactions) {
      final date = _fmt(t.date);
      final merchant = _escape(t.merchant);
      final note = _escape(t.note ?? '');
      final amount = NumberFormatter.formatCurrency(t.amount, currency);
      sb.writeln('$date,$merchant,${t.category.name},${t.type.name},$amount,${t.status.name},$note');
    }

    final file = await _writeTemp('echelon_transactions.csv', sb.toString());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Echelon Finance — Transaction Export',
    );
  }

  // ── PDF ─────────────────────────────────────────────────────────────────────

  Future<void> exportPdf(List<AppTransaction> transactions, String currency) async {
    final doc = pw.Document();

    final headers = ['Date', 'Merchant', 'Category', 'Type', 'Amount', 'Status'];
    final rows = transactions.map((t) => [
      _fmt(t.date),
      t.merchant,
      t.category.name,
      t.type.name,
      NumberFormatter.formatCurrency(t.amount, currency),
      t.status.name,
    ]).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Text(
          'Echelon Finance — Transaction Report',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated ${_fmt(DateTime.now())} • ${transactions.length} transactions',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final file = await _writeTemp('echelon_transactions.pdf', null, bytes: bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Echelon Finance — Transaction Report',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<File> _writeTemp(String name, String? text, {List<int>? bytes}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    if (text != null) {
      await file.writeAsString(text);
    } else if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file;
  }
}
