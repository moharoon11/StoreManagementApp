import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';

import 'api_service.dart';

class InvoicePdfService {
  static Future<Uint8List> fetch(int invoiceId) async {
    final bytes = await ApiService.getBytes('/invoices/$invoiceId/pdf');

    // Do not save or share an empty/error response as a PDF. A PDF header is
    // allowed to appear after a short binary comment, so inspect the first KB.
    final headerLength = bytes.length < 1024 ? bytes.length : 1024;
    final isPdf =
        bytes.isNotEmpty && _containsPdfHeader(bytes.sublist(0, headerLength));
    if (!isPdf) {
      throw Exception('The server returned an invalid or empty PDF file.');
    }

    return bytes;
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

    // The save dialog plugin is mobile-only. Retain the existing native PDF
    // save/print flow on desktop and web instead of throwing MissingPlugin.
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename,
    );
  }

  static bool _containsPdfHeader(Uint8List bytes) {
    const header = <int>[0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
    for (var start = 0; start <= bytes.length - header.length; start++) {
      var matches = true;
      for (var index = 0; index < header.length; index++) {
        if (bytes[start + index] != header[index]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }
}
