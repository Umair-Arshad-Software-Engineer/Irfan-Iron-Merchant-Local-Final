import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../models/customer.dart';

class SalePdfGenerator {
  static Future<Uint8List> generateSalePdf({
    required Map<String, dynamic> saleData,
    required Customer? customer,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountValue,
    required double grandTotal,
    required bool isPosMode,
    required String paymentMethod,
    required double amountPaid,
    DateTime? dueDate,
    String? notes,
    double? previousBalance,
  }) async {
    final pdf = pw.Document();

    // Load all images
    final logo = await _loadImage('hafizlogo.png');
    final nameImage = await _loadImage('name.png');
    final addressImage = await _loadImage('address.png');
    final discountImage = await _loadImage('discount.png');
    final mazdooriImage = await _loadImage('mazdoori.png');
    final filledAmountImage = await _loadImage('saryaamount.png');
    final previousAmountImage = await _loadImage('previousamount.png');
    final totalWithPreviousImage = await _loadImage('totalinvoicewithprevious.png');
    final paidAmountImage = await _loadImage('paidamount.png');
    final remainingAmountImage = await _loadImage('remainingamount.png');
    final lineImage = await _loadImage('line.png');
    final footerLogo = await _loadImage('logo.png');

    // Table header images
    final itemNameLogo = await _loadImage('itemName.png');
    final descriptionLogo = await _loadImage('description.png');
    final lengthLogo = await _loadImage('length.png');
    final rateLogo = await _loadImage('rate.png');
    final weightLogo = await _loadImage('weight.png');
    final totalLogo = await _loadImage('total.png');
    final qtyLogo = await _loadImage('qty.png');

    // Get invoice number
    final invoiceNumber = saleData['invoice_number'] ?? 'N/A';
    final referenceNumber = saleData['reference'] ?? saleData['reference_number'] ?? 'N/A';
    final isSarya = saleData['sale_category'] == 'sarya';

    // Calculate amounts
    double paidAmount = amountPaid;
    final double previousBalanceValue = previousBalance ?? 0.0;
    final double newBalance = previousBalanceValue + grandTotal;
    // double remainingAmount = grandTotal - paidAmount;
    double remainingAmount = newBalance - paidAmount;

    // Format date
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year}';
    final formattedTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // Generate customer details image
    final customerDetailsImage = await _createTextImage(
      'Customer Name: ${customer?.name ?? 'N/A'}\n'
          'Customer Address: ${customer?.address ?? 'N/A'}',
    );

    // ✅ Pre-generate images for all items with description
    List<pw.MemoryImage> itemNameImages = [];
    List<pw.MemoryImage> descriptionImages = [];
    List<pw.MemoryImage> lengthImages = [];
    List<pw.MemoryImage> combinedNameDescImages = []; // ✅ New: Combined name + description

    for (var item in items) {
      // Product name image
      final nameImage = await _createTextImage(item['product_name'] ?? 'N/A');
      itemNameImages.add(nameImage);

      // ✅ Description image - show full description or "N/A"
      final descriptionText = item['description']?.toString() ?? '';
      final descImage = await _createTextImage(
          descriptionText.isNotEmpty ? descriptionText : 'N/A'
      );
      descriptionImages.add(descImage);

      // ✅ Combined name + description for better display
      final combinedText = descriptionText.isNotEmpty
          ? '${item['product_name']}\n${descriptionText}'
          : item['product_name'] ?? 'N/A';
      final combinedImg = await _createTextImage(combinedText);
      combinedNameDescImages.add(combinedImg);

      // Generate lengths text
      String lengthsText = '';
      final selectedLengths = item['selected_lengths'] as List? ?? [];
      final lengthQuantities = item['length_quantities'] as Map<String, dynamic>? ?? {};

      if (selectedLengths.isNotEmpty) {
        lengthsText = selectedLengths.map((length) {
          double qty = lengthQuantities[length]?.toDouble() ?? 1.0;
          final reversedLength = length.toString().split('-').reversed.join('-');
          return 'انچ سوتر شافٹ$reversedLength (${qty.toStringAsFixed(0)})';
        }).join('\n');
      }

      final lengthImg = await _createTextImage(lengthsText);
      lengthImages.add(lengthImg);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(10),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo and company info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logo, width: 80, height: 80),
                  pw.Column(
                    children: [
                      pw.Image(nameImage, width: 170, height: 170),
                      pw.Image(addressImage, width: 200, height: 100, dpi: 2000),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        isPosMode ? 'POS Receipt' : 'Sale Invoice',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Zulfiqar Ahmad: ',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '0300-6316202',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Muhammad Irfan: ',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '0300-8167446',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(),

              // Customer Information
              pw.Image(customerDetailsImage, width: 250, dpi: 1000),
              pw.Text('Customer Number: ${customer?.contact ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 2),
                  pw.Text('Reference: $referenceNumber', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (paymentMethod == 'credit' && dueDate != null)
                pw.Text('Due Date: ${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const pw.TextStyle(fontSize: 10)),
              if (notes != null && notes.isNotEmpty)
                pw.Text('Notes: $notes', style: const pw.TextStyle(fontSize: 10)),

              pw.SizedBox(height: 10),

              pw.Table.fromTextArray(
                headers: [
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(itemNameLogo, width: 60, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(descriptionLogo, width: 80, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(weightLogo, width: 50, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(lengthLogo, width: 50, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(rateLogo, width: 50, height: 15),
                  ),
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Image(totalLogo, width: 50, height: 15),
                  ),
                ],
                data: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final quantity = isSarya
                      ? (item['weight'] ?? 0.0).toStringAsFixed(2)
                      : (item['quantity'] ?? 0).toStringAsFixed(0);

                  return [
                    pw.Image(itemNameImages[index], dpi: 1000),        // name only
                    pw.Image(descriptionImages[index], dpi: 1000),     // description only
                    pw.Text(quantity, style: const pw.TextStyle(fontSize: 10)),
                    pw.Image(lengthImages[index], dpi: 1000),
                    pw.Text((item['unit_price'] ?? 0.0).toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text((item['total'] ?? 0.0).toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 10)),
                  ];
                }).toList(),
              ),

              // Financial Summary
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(discountImage, width: 50, height: 40),
                  pw.Text(discountValue.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(filledAmountImage, width: 50, height: 30, dpi: 1000),
                  pw.Text(grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(previousAmountImage, width: 50, height: 40, dpi: 1000),
                  pw.Text(previousBalanceValue.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 15)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(totalWithPreviousImage, width: 100, height: 40, dpi: 1000),
                  pw.Text(newBalance.toStringAsFixed(2), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(paidAmountImage, width: 50, height: 30, dpi: 1000),
                  pw.Text(paidAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(remainingAmountImage, width: 50, height: 40, dpi: 1000),
                  pw.Text(remainingAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 40),
                  pw.Text('......................', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // Footer
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 20),
                  pw.Image(lineImage, width: 150, height: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Developed By Umair Arshad',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Contact: 0341-6426617',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<pw.MemoryImage> _loadImage(String path) async {
    final ByteData bytes = await rootBundle.load('asset/images/$path');
    final buffer = bytes.buffer.asUint8List();
    return pw.MemoryImage(buffer);
  }

  static Future<pw.MemoryImage> _createTextImage(String text) async {
    final String displayText = text.isEmpty ? "N/A" : text;
    const double scaleFactor = 1.5;

    // 1. Layout first to get actual dimensions
    final textStyle = const TextStyle(
      fontSize: 10 * scaleFactor,
      fontFamily: 'JameelNoori',
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: ui.TextAlign.left,
      textDirection: ui.TextDirection.rtl,
    );

    textPainter.layout();

    // 2. Use actual painted dimensions — no extra scaleFactor multiplys
    final double width = textPainter.width;
    final double height = textPainter.height;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    // 3. Canvas size matches image size exactly
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width, height),
    );

    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  // NEW: Save PDF to device and open it
  static Future<File> savePdfToDevice(Uint8List pdfData, String fileName) async {
    try {
      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a unique file name with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final fullFileName = '${safeFileName}_$timestamp.pdf';

      final filePath = '${directory.path}/$fullFileName';
      final file = File(filePath);

      // Write the PDF data to the file
      await file.writeAsBytes(pdfData);

      return file;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  // NEW: Open PDF with default PDF viewer
  static Future<void> openPdf(File pdfFile) async {
    try {
      final result = await OpenFile.open(pdfFile.path);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open PDF: ${result.message}');
      }
    } catch (e) {
      throw Exception('Failed to open PDF: $e');
    }
  }

  // NEW: Combined method to save and open PDF
  static Future<void> saveAndOpenPdf(Uint8List pdfData, String fileName) async {
    try {
      final savedFile = await savePdfToDevice(pdfData, fileName);
      await openPdf(savedFile);
    } catch (e) {
      throw Exception('Failed to save and open PDF: $e');
    }
  }

  // NEW: Save to device with custom directory (e.g., Downloads folder)
  static Future<File> savePdfToDownloads(Uint8List pdfData, String fileName) async {
    try {
      // For Android 10+, use Downloads folder
      final directory = await getDownloadsDirectory();

      if (directory == null) {
        // Fallback to documents directory
        return await savePdfToDevice(pdfData, fileName);
      }

      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      final fullFileName = '$safeFileName.pdf';

      final filePath = '${directory.path}/$fullFileName';
      final file = File(filePath);

      // Write the PDF data to the file
      await file.writeAsBytes(pdfData);

      return file;
    } catch (e) {
      throw Exception('Failed to save PDF to downloads: $e');
    }
  }

  // Keep original print method
  static Future<void> printPdf(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (format) => pdfData);
  }

  // Keep original share method
  static Future<void> sharePdf(Uint8List pdfData, String fileName) async {
    await Printing.sharePdf(bytes: pdfData, filename: fileName);
  }
}