import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'api_service.dart';

class InvoicePdfService {
  /// Gets invoice data as JSON and renders the PDF on the device. This keeps
  /// download, share and print independent of the server's PDF runtime.
  static Future<Uint8List> fetch(int invoiceId) async {
    final response = await ApiService.get('/invoices/$invoiceId');
    if (response is! Map ||
        response['success'] != true ||
        response['data'] is! Map) {
      throw Exception('Could not load invoice details for the PDF.');
    }

    return _generate(Map<String, dynamic>.from(response['data'] as Map));
  }

  static Future<Uint8List> _generate(Map<String, dynamic> invoice) async {
    final store = invoice['store'] is Map
        ? Map<String, dynamic>.from(invoice['store'] as Map)
        : const <String, dynamic>{};
    final items = (invoice['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final document = pw.Document();
    final invoiceNumber = _text(invoice['invoiceNumber'], fallback: 'Invoice');
    final date = _formatDate(invoice['invoiceDate'] ?? invoice['createdAt']);
    final isManualInvoice =
        items.isNotEmpty && items.every((item) => item['productId'] == null);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _header(store, invoiceNumber, date, invoice),
        footer: (_) => _footer(store),
        build: (_) => [
          pw.SizedBox(height: 20),
          _itemsTable(items, isManualInvoice),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 230,
              child: pw.Column(children: [
                _totalRow('Subtotal', _money(invoice['subtotal'])),
                pw.SizedBox(height: 5),
                _totalRow('Grand Total', _money(invoice['grandTotal']),
                    bold: true),
              ]),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _header(Map<String, dynamic> store, String invoiceNumber,
      String date, Map<String, dynamic> invoice) {
    final storeName = _text(store['storeName'], fallback: 'STORE MANAGEMENT');
    return pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(storeName,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800)),
                _optionalText('Owner: ', store['ownerName']),
                _optionalText('', store['address']),
                _optionalText(
                    '', _join([store['city'], store['pincode']], ' - ')),
                _optionalText('Phone: ', store['phone']),
                _optionalText('GSTIN: ', store['gstNumber']),
              ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('TAX INVOICE',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Invoice No: $invoiceNumber'),
          pw.Text('Date: $date'),
          if (_text(invoice['customerName']).isNotEmpty) ...[
            pw.SizedBox(height: 7),
            pw.Text('Bill To',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(_text(invoice['customerName'])),
          ],
          if (_text(invoice['customerMobileNumber']).isNotEmpty)
            pw.Text('Mobile: ${_text(invoice['customerMobileNumber'])}'),
        ]),
      ]),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Divider(color: PdfColors.grey400),
      ),
    ]);
  }

  static pw.Widget _itemsTable(
      List<Map<String, dynamic>> items, bool isManualInvoice) {
    final headers = <String>['#'];
    if (!isManualInvoice) headers.add('Product');
    headers.addAll(['Price', 'Qty', 'Total']);

    final data = <List<String>>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final row = <String>['${index + 1}'];
      if (!isManualInvoice) {
        row.add(_text(item['productName'], fallback: 'Item'));
      }
      row.addAll([
        _money(item['sellingPrice']),
        '${_number(item['quantity'])} ${_text(item['unit'], fallback: 'Piece')}',
        _money(item['total']),
      ]);
      data.add(row);
    }

    if (data.isEmpty) {
      return pw.Text('No invoice items available.');
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.all(6),
      cellAlignment: pw.Alignment.centerLeft,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        if (!isManualInvoice) 1: const pw.FlexColumnWidth(3),
      },
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
        fontSize: bold ? 13 : 11,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: bold ? PdfColors.green800 : PdfColors.black);
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: style),
          pw.Text(value, style: style),
        ]);
  }

  static pw.Widget _footer(Map<String, dynamic> store) {
    final name = _text(store['storeName'], fallback: 'our store');
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 5),
      pw.Text('Thank you for shopping with $name!',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
    ]);
  }

  static pw.Widget _optionalText(String prefix, dynamic value) {
    final text = _text(value);
    return text.isEmpty
        ? pw.SizedBox()
        : pw.Text('$prefix$text', style: const pw.TextStyle(fontSize: 9));
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  static String _join(List<dynamic> values, String separator) {
    return values.map(_text).where((value) => value.isNotEmpty).join(separator);
  }

  static String _number(dynamic value) {
    if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 3);
    return _text(value, fallback: '0');
  }

  static String _money(dynamic value) {
    final amount =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }

  static String _formatDate(dynamic value) {
    final date = DateTime.tryParse(_text(value));
    if (date == null) return _text(value, fallback: '');
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  static Future<bool> save(Uint8List bytes, String filename) async {
    // Android/iOS use the platform's Save As dialog, which writes the exact
    // bytes to the location the user selects (normally Downloads).
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: bytes,
          fileName: filename,
          mimeTypesFilter: const ['application/pdf'],
        ),
      );
      return savedPath != null;
    }

    // Desktop saves directly to a local folder first so "Save PDF" behaves
    // like a real file export instead of unexpectedly opening print UI.
    if (!kIsWeb) {
      final saved = await _saveToLocalFolder(bytes, filename);
      if (saved != null) {
        return true;
      }
    }

    // Fall back to the platform print dialog when local file save is not
    // available, such as the web or a desktop write failure.
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename,
    );
  }

  static Future<File?> _saveToLocalFolder(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final baseDirectory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = await _uniqueLocalFile(baseDirectory, filename);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<File> _uniqueLocalFile(
    Directory directory,
    String filename,
  ) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dot = safeName.lastIndexOf('.');
    final baseName = dot > 0 ? safeName.substring(0, dot) : safeName;
    final extension = dot > 0 ? safeName.substring(dot) : '';

    var candidate = File('${directory.path}${Platform.pathSeparator}$safeName');
    var counter = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${directory.path}${Platform.pathSeparator}$baseName ($counter)$extension',
      );
      counter++;
    }
    return candidate;
  }
}
