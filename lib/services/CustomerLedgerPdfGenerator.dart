// lib/services/CustomerLedgerPdfGenerator.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../Banks/banknames.dart';

class CustomerLedgerPdfGenerator {
  static final NumberFormat _cf = NumberFormat('#,##0.00');
  static final DateFormat _df = DateFormat('dd/MM/yy');
  static final DateFormat _dtf = DateFormat('MMM dd, yyyy  hh:mm a');

  // Colors
  static const PdfColor _purple   = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor _purpleL  = PdfColor.fromInt(0xFFF5F3FF);
  static const PdfColor _purpleS  = PdfColor.fromInt(0xFFEDE9FE);
  static const PdfColor _green    = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _greenBg  = PdfColor.fromInt(0xFFECFDF5);
  static const PdfColor _red      = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor _redBg    = PdfColor.fromInt(0xFFFEF2F2);
  static const PdfColor _amber    = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor _amberBg  = PdfColor.fromInt(0xFFFFFBEB);
  static const PdfColor _indigo   = PdfColor.fromInt(0xFF6366F1);
  static const PdfColor _indigoBg = PdfColor.fromInt(0xFFEEF2FF);
  static const PdfColor _blue     = PdfColor.fromInt(0xFF3B82F6);
  static const PdfColor _blueBg   = PdfColor.fromInt(0xFFEFF6FF);
  static const PdfColor _t1       = PdfColor.fromInt(0xFF1C1C1E);
  static const PdfColor _t2       = PdfColor.fromInt(0xFF3C3C43);
  static const PdfColor _t3       = PdfColor.fromInt(0xFF8E8E93);
  static const PdfColor _border   = PdfColor.fromInt(0xFFE5E5EA);
  static const PdfColor _rowAlt   = PdfColor.fromInt(0xFFFAFAFC);
  static const PdfColor _hdrBg    = PdfColor.fromInt(0xFFF5F5F7);
  static const PdfColor _white    = PdfColor.fromInt(0xFFFFFFFF);

  // Cache for bank logos
  static final Map<String, pw.MemoryImage> _bankLogoCache = {};

  // Cache for description images to avoid re-rendering same text
  static final Map<String, pw.MemoryImage> _descriptionCache = {};

  // ── Raster helper: Used for Urdu/RTL text in header AND description field ──
  static Future<pw.MemoryImage> _img(
      String text, {
        double fs = 10,
        Color color = Colors.black,
        FontWeight weight = FontWeight.normal,
        bool rtl = false,
        double maxW = 260,
        int maxLines = 2,
      }) async {
    final txt = text.isEmpty ? ' ' : text;
    const double sc = 3.0; // scale factor

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, maxW * sc, (fs * maxLines + 10) * sc));
    final tp = TextPainter(
      text: TextSpan(
        text: txt,
        style: TextStyle(
          fontSize: fs * sc,
          color: color,
          fontWeight: weight,
        ),
      ),
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxW * sc);
    tp.paint(canvas, Offset.zero);

    final pic = rec.endRecording();
    final w = tp.width.clamp(1, maxW * sc).toInt();
    final h = tp.height.clamp(1, (fs * maxLines + 10) * sc).toInt();
    final image = await pic.toImage(w, h);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return pw.MemoryImage(bd!.buffer.asUint8List());
  }

  // Helper to get description text based on transaction type
  static String _getDescriptionText(Map<String, dynamic> entry) {
    final type = (entry['transaction_type'] as String?) ?? 'adjustment';
    final rawDesc = (entry['description'] as String?) ?? '';

    // For sale, show "SALE" instead of the actual description
    if (type == 'sale') {
      return 'SALE';
    }

    // For other types, return the actual description
    return rawDesc;
  }

  // Helper to get or create description image with caching
  static Future<pw.MemoryImage> _getDescriptionImage(Map<String, dynamic> entry) async {
    final descriptionText = _getDescriptionText(entry);

    if (descriptionText.isEmpty) {
      return await _img(' ', fs: 5.5, maxW: 180, maxLines: 2);
    }

    // Create cache key
    final cacheKey = descriptionText.substring(0, math.min(descriptionText.length, 100));

    if (_descriptionCache.containsKey(cacheKey)) {
      return _descriptionCache[cacheKey]!;
    }

    final image = await _img(
      descriptionText,
      fs: 5.5,
      color: const Color(0xFF1C1C1E),
      weight: FontWeight.normal,
      rtl: false,
      maxW: 180,
      maxLines: 2,
    );

    _descriptionCache[cacheKey] = image;
    return image;
  }

  // Load bank logo from assets with caching
  static Future<pw.MemoryImage?> _loadBankLogo(String bankName) async {
    if (_bankLogoCache.containsKey(bankName)) return _bankLogoCache[bankName];
    try {
      final bank = _getBankByName(bankName);
      if (bank != null && bank.iconPath.isNotEmpty) {
        final data = await rootBundle.load(bank.iconPath);
        final image = pw.MemoryImage(data.buffer.asUint8List());
        _bankLogoCache[bankName] = image;
        return image;
      }
    } catch (e) {
      debugPrint('Error loading bank logo: $e');
    }
    return null;
  }

  static Bank? _getBankByName(String? bankName) {
    if (bankName == null || bankName.isEmpty) return null;
    try {
      return pakistaniBanks.firstWhere(
            (b) => b.name.toLowerCase() == bankName.toLowerCase(),
        orElse: () => pakistaniBanks.firstWhere(
              (b) => bankName.toLowerCase().contains(b.name.toLowerCase()),
          orElse: () => Bank(name: bankName, iconPath: ''),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Main entry point ───────────────────────────────────────────────────────
  static Future<Uint8List> generateLedgerPdf({
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> entries,
    required String filterType,
    DateTimeRange? dateRange,
    Map<int, List<Map<String, dynamic>>>? saleItemsCache,
  }) async {
    // Clear description cache at start of generation
    _descriptionCache.clear();

    // Pre-render all description images
    final Map<int, pw.MemoryImage> descriptionImages = {};
    for (int i = 0; i < entries.length; i++) {
      descriptionImages[i] = await _getDescriptionImage(entries[i]);
    }

    // Raster the Urdu customer name (RTL) and meta line for the header
    final nameImg = await _img(
      customerName,
      fs: 13,
      weight: FontWeight.bold,
      color: const Color(0xFFFFFFFF),
      rtl: true,
      maxW: 300,
    );

    final meta = [customerPhone, customerAddress]
        .where((s) => s.isNotEmpty)
        .join('  •  ');
    final metaImg = await _img(
      meta,
      fs: 7.5,
      color: const Color(0xFFDDD6FE),
      maxW: 380,
    );

    // Pre-load bank logos
    final uniqueBankNames = <String>{};
    for (final e in entries) {
      final b = e['bank_name'] as String?;
      if (b != null && b.isNotEmpty) uniqueBankNames.add(b);
    }
    for (final b in uniqueBankNames) {
      await _loadBankLogo(b);
    }

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      header: (ctx) => _pageHeader(
        nameImg, metaImg, filterType, dateRange, summary, entries.length, ctx,
      ),
      footer: (ctx) => _pageFooter(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        _table(entries, summary, saleItemsCache ?? {}, descriptionImages),
      ],
    ));
    return pdf.save();
  }

  // ── Page header ────────────────────────────────────────────────────────────
  static pw.Widget _pageHeader(
      pw.MemoryImage nameImg,
      pw.MemoryImage metaImg,
      String filterType,
      DateTimeRange? dateRange,
      Map<String, dynamic> summary,
      int entryCount,
      pw.Context ctx,
      ) {
    // Calculate totals
    double totalDebit = 0;
    double totalCredit = 0;
    double closingBalance = 0;

    if (summary.isNotEmpty) {
      totalDebit = _d(summary['total_debit']);
      totalCredit = _d(summary['total_credit']);
      closingBalance = _d(summary['closing_balance']);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Purple banner ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: _purple,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CUSTOMER LEDGER STATEMENT',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  // Raster image for Urdu name (RTL script requires raster)
                  pw.Image(nameImg, height: 15),
                  pw.SizedBox(height: 2),
                  pw.Image(metaImg, height: 10),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: _white,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      _filterLabel(filterType),
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        color: _purple,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  if (dateRange != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${_df.format(dateRange.start)} – ${_df.format(dateRange.end)}',
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColor.fromInt(0xFFDDD6FE),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: ${_dtf.format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 6,
                      color: PdfColor.fromInt(0xFFDDD6FE),
                    ),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber}',
                    style: pw.TextStyle(
                      fontSize: 6,
                      color: PdfColor.fromInt(0xFFDDD6FE),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),

        // ── Summary cards ──
        pw.Row(children: [
          _sCard('TOTAL SALES',   'Rs ${_cf.format(totalDebit)}',   _red,    _redBg),
          pw.SizedBox(width: 5),
          _sCard('TOTAL PAYMENTS', 'Rs ${_cf.format(totalCredit)}',  _green,  _greenBg),
          pw.SizedBox(width: 5),
          _sCard('OUTSTANDING',    'Rs ${_cf.format(closingBalance)}', _purple, _purpleL, bold: true),
          pw.SizedBox(width: 5),
          _sCard('ENTRIES',        '$entryCount',                    _t2,     _hdrBg),
        ]),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _sCard(
      String lbl,
      String val,
      PdfColor col,
      PdfColor bg, {
        bool bold = false,
      }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(
            color: bold ? _purple : _border,
            width: bold ? 1.5 : 0.8,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                color: bg,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                lbl,
                style: pw.TextStyle(
                  fontSize: 6,
                  color: col,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              val,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: bold ? _purple : _t1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page footer ────────────────────────────────────────────────────────────
  static pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Computer-generated - not valid without authorisation.',
            style: pw.TextStyle(
              fontSize: 5.5,
              color: _t3,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 5.5, color: _t3),
          ),
        ],
      ),
    );
  }

  // ── Full table ─────────────────────────────────────────────────────────────
  static pw.Widget _table(
      List<Map<String, dynamic>> entries,
      Map<String, dynamic> summary,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      ) {
    double totDebit = 0, totCredit = 0;
    for (final e in entries) {
      totDebit += _d(e['debit']);
      totCredit += _d(e['credit']);
    }
    final closing = entries.isNotEmpty
        ? _d(entries.last['balance'])
        : _d(summary['closing_balance']);

    return pw.ClipRRect(
      horizontalRadius: 6,
      verticalRadius: 6,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(children: [
          _tHeader(),
          ...entries.asMap().entries.expand(
                (en) => _tRow(en.value, en.key, cache, descriptionImages),
          ),
          _tTotal(totDebit, totCredit, closing),
        ]),
      ),
    );
  }

  // ── Table header ───────────────────────────────────────────────────────────
  static pw.Widget _tHeader() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    color: _hdrBg,
    child: pw.Row(children: [
      _hc('DATE',        11),
      _hc('REF #',       10),
      _hc('TYPE',         9),
      _hc('METHOD',       8),
      _hc('BANK',        13),
      _hc('DESCRIPTION', 23),
      _hc('DEBIT',       12, r: true),
      _hc('CREDIT',      12, r: true),
      _hc('BALANCE',     12, r: true),
    ]),
  );

  static pw.Widget _hc(String t, int flex, {bool r = false}) => pw.Expanded(
    flex: flex,
    child: pw.Text(
      t,
      textAlign: r ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 6,
        fontWeight: pw.FontWeight.bold,
        color: _t3,
        letterSpacing: 0.4,
      ),
    ),
  );

  // ── Table row (returns 1–3 widgets: main row + optional sub-rows) ──────────
  static List<pw.Widget> _tRow(
      Map<String, dynamic> e,
      int idx,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      ) {
    final widgets = <pw.Widget>[];

    final debit   = _d(e['debit']);
    final credit  = _d(e['credit']);
    final balance = _d(e['balance']);
    final type    = (e['transaction_type'] as String?) ?? 'adjustment';
    final method  = e['payment_method'] as String?;
    final bank    = e['bank_name'] as String?;
    final refNum  = e['reference_number'] as String?;

    final ts     = _typeStyle(type);
    final ms     = _methodStyle(method);
    final balCol = balance > 0 ? _red : balance < 0 ? _green : _t3;
    final bg     = idx.isEven ? _white : _rowAlt;

    DateTime? txDate;
    try {
      txDate = DateTime.parse(e['date'] as String);
    } catch (_) {}

    widgets.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: bg,
        border: const pw.Border(
          bottom: pw.BorderSide(color: _border, width: 0.4),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // DATE
          pw.Expanded(
            flex: 11,
            child: pw.Text(
              txDate != null ? _df.format(txDate) : '',
              style: pw.TextStyle(fontSize: 6.5, color: _t2),
            ),
          ),
          // REF #
          pw.Expanded(
            flex: 10,
            child: pw.Text(
              refNum ?? '',
              style: pw.TextStyle(
                fontSize: 6.5,
                color: _purple,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          // TYPE badge
          pw.Expanded(
            flex: 9,
            child: _badge(
              ts['label'] as String,
              ts['color'] as PdfColor,
              ts['bg'] as PdfColor,
            ),
          ),
          // METHOD badge
          pw.Expanded(
            flex: 8,
            child: method != null
                ? _badge(
              ms['label'] as String,
              ms['color'] as PdfColor,
              ms['bg'] as PdfColor,
            )
                : pw.SizedBox(),
          ),
          // BANK with logo
          pw.Expanded(
            flex: 13,
            child: bank != null && bank.isNotEmpty
                ? _buildBankCell(bank)
                : pw.SizedBox(),
          ),
          // DESCRIPTION — Using pre-rendered raster image
          pw.Expanded(
            flex: 23,
            child: pw.Image(descriptionImages[idx]!, height: 20),
          ),
          // DEBIT (Sales)
          pw.Expanded(
            flex: 12,
            child: pw.Text(
              debit > 0 ? _cf.format(debit) : '',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: debit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: debit > 0 ? _red : _t3,
              ),
            ),
          ),
          // CREDIT (Payments)
          pw.Expanded(
            flex: 12,
            child: pw.Text(
              credit > 0 ? _cf.format(credit) : '',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: credit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: credit > 0 ? _green : _t3,
              ),
            ),
          ),
          // BALANCE
          pw.Expanded(
            flex: 12,
            child: pw.Text(
              _cf.format(balance),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: balCol,
              ),
            ),
          ),
        ],
      ),
    ));

    // Sale items sub-row
    if (type == 'sale' && e['reference_id'] != null) {
      final items = cache[e['reference_id'] as int];
      if (items != null && items.isNotEmpty) widgets.add(_saleSub(items));
    }

    // Cheque sub-row
    if (type == 'payment' && method == 'cheque') {
      final cn = e['cheque_number'] as String?;
      final cd = e['cheque_date'] as String?;
      final cl = e['cheque_cleared'] as bool? ?? false;
      if (cn != null) widgets.add(_chequeSub(cn, cd, cl));
    }

    return widgets;
  }

  // ── Bank cell with logo ────────────────────────────────────────────────────
  static pw.Widget _buildBankCell(String bankName) {
    final logo = _bankLogoCache[bankName];
    if (logo != null) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Image(logo, height: 12, width: 12, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 3),
          pw.Expanded(
            child: pw.Text(
              bankName,
              style: pw.TextStyle(
                fontSize: 6.5,
                color: _t2,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      );
    }
    return pw.Text(
      bankName,
      style: pw.TextStyle(
        fontSize: 6.5,
        color: _t2,
        fontWeight: pw.FontWeight.bold,
      ),
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
    );
  }

  // ── Badge widget ───────────────────────────────────────────────────────────
  static pw.Widget _badge(String label, PdfColor col, PdfColor bg) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 5.5,
            fontWeight: pw.FontWeight.bold,
            color: col,
          ),
        ),
      );

  // ── Sale items sub-row (similar to receipt sub-row in supplier) ────────────
  static pw.Widget _saleSub(List<Map<String, dynamic>> items) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(left: 18, right: 6, bottom: 4),
        padding: const pw.EdgeInsets.all(5),
        decoration: pw.BoxDecoration(
          color: _purpleL,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _purpleS, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Sold Items',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: _purple,
              ),
            ),
            pw.SizedBox(height: 3),
            // Sub-table header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: _purpleS,
              child: pw.Row(children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    'PRODUCT',
                    style: pw.TextStyle(
                      fontSize: 5,
                      fontWeight: pw.FontWeight.bold,
                      color: _purple,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'QTY',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 5,
                      fontWeight: pw.FontWeight.bold,
                      color: _purple,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'PRICE',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 5,
                      fontWeight: pw.FontWeight.bold,
                      color: _purple,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'TOTAL',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 5,
                      fontWeight: pw.FontWeight.bold,
                      color: _purple,
                    ),
                  ),
                ),
              ]),
            ),
            // Sub-table rows
            ...items.asMap().entries.map((en) {
              final qty  = (en.value['quantity'] as num?)?.toInt() ?? 0;
              final price = (en.value['unit_price'] as num?)?.toDouble() ?? 0.0;
              final total = (en.value['total_price'] as num?)?.toDouble() ?? (qty * price);

              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: en.key.isEven ? _white : _rowAlt,
                child: pw.Row(children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      en.value['product_name'] as String? ?? '',
                      style: pw.TextStyle(fontSize: 5.5, color: _t1),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '$qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _indigo,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _cf.format(price),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 5.5, color: _t2),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _cf.format(total),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _t1,
                      ),
                    ),
                  ),
                ]),
              );
            }),
            // Sub-table total row
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              color: _purpleS,
              child: pw.Row(children: [
                pw.Expanded(
                  child: pw.Text(
                    'Total',
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: _t1,
                    ),
                  ),
                ),
                pw.Text(
                  _cf.format(items.fold<double>(
                    0,
                        (s, i) => s + (
                        ((i['quantity'] as num?)?.toInt() ?? 0) *
                            ((i['unit_price'] as num?)?.toDouble() ?? 0.0)
                    ),
                  )),
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: _purple,
                  ),
                ),
              ]),
            ),
          ],
        ),
      );

  // ── Cheque sub-row ─────────────────────────────────────────────────────────
  static pw.Widget _chequeSub(String num, String? date, bool cleared) {
    final col = cleared ? _green : _amber;
    final bg  = cleared ? _greenBg : _amberBg;
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 18, right: 6, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: col, width: 0.6),
      ),
      child: pw.Row(children: [
        pw.Text(
          'Cheque #$num',
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
            color: col,
          ),
        ),
        if (date != null) ...[
          pw.SizedBox(width: 10),
          pw.Text(
            'Date: $date',
            style: pw.TextStyle(fontSize: 6.5, color: col),
          ),
        ],
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            color: col,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            cleared ? 'CLEARED' : 'PENDING',
            style: pw.TextStyle(
              fontSize: 5.5,
              fontWeight: pw.FontWeight.bold,
              color: _white,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Totals footer row ──────────────────────────────────────────────────────
  static pw.Widget _tTotal(double debit, double credit, double closing) {
    final balCol = closing > 0 ? _red : closing < 0 ? _green : _t1;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: const pw.BoxDecoration(
        color: _purpleL,
        border: pw.Border(
          top: pw.BorderSide(color: _purple, width: 1.2),
        ),
      ),
      child: pw.Row(children: [
        pw.Expanded(flex: 11, child: pw.SizedBox()),
        pw.Expanded(flex: 10, child: pw.SizedBox()),
        pw.Expanded(flex: 9,  child: pw.SizedBox()),
        pw.Expanded(flex: 8,  child: pw.SizedBox()),
        pw.Expanded(flex: 13, child: pw.SizedBox()),
        pw.Expanded(
          flex: 23,
          child: pw.Text(
            'TOTAL',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _purple,
              letterSpacing: 0.5,
            ),
          ),
        ),
        pw.Expanded(
          flex: 12,
          child: pw.Text(
            _cf.format(debit),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _red,
            ),
          ),
        ),
        pw.Expanded(
          flex: 12,
          child: pw.Text(
            _cf.format(credit),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _green,
            ),
          ),
        ),
        pw.Expanded(
          flex: 12,
          child: pw.Text(
            _cf.format(closing),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: balCol,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;

  static Map<String, dynamic> _typeStyle(String type) {
    switch (type) {
      case 'sale':
        return {'label': 'SALE',      'color': _red,    'bg': _redBg};
      case 'payment':
        return {'label': 'PAYMENT',   'color': _green,  'bg': _greenBg};
      case 'adjustment':
        return {'label': 'ADJUSTMENT','color': _amber,  'bg': _amberBg};
      default:
        return {'label': 'MANUAL',    'color': _indigo, 'bg': _indigoBg};
    }
  }

  static Map<String, dynamic> _methodStyle(String? method) {
    switch (method) {
      case 'cash':   return {'label': 'CASH',   'color': _green,  'bg': _greenBg};
      case 'bank':   return {'label': 'BANK',   'color': _blue,   'bg': _blueBg};
      case 'cheque': return {'label': 'CHEQUE', 'color': _amber,  'bg': _amberBg};
      case 'slip':   return {'label': 'SLIP',   'color': _purple, 'bg': _purpleL};
      default:       return {'label': '',       'color': _t3,     'bg': _hdrBg};
    }
  }

  static String _filterLabel(String f) {
    switch (f) {
      case 'sale':     return 'SALES ONLY';
      case 'payment':  return 'PAYMENTS ONLY';
      case 'adjustment': return 'ADJUSTMENTS ONLY';
      default:         return 'ALL TRANSACTIONS';
    }
  }
}