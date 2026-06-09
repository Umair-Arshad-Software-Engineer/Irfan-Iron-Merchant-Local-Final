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
import '../providers/lanprovider.dart';

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
    const double sc = 3.0;

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

  static String _getDescriptionText(Map<String, dynamic> entry, LanguageProvider lp) {
    final type = (entry['transaction_type'] as String?) ?? 'adjustment';
    final rawDesc = (entry['description'] as String?) ?? '';

    if (type == 'sale') {
      return lp.isEnglish ? 'SALE' : 'فروخت';
    }

    return rawDesc;
  }

  static Future<pw.MemoryImage> _getDescriptionImage(Map<String, dynamic> entry, LanguageProvider lp) async {
    final descriptionText = _getDescriptionText(entry, lp);

    if (descriptionText.isEmpty) {
      return await _img(' ', fs: 5.5, maxW: 180, maxLines: 2);
    }

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
    required LanguageProvider languageProvider,
  }) async {
    _descriptionCache.clear();

    final Map<int, pw.MemoryImage> descriptionImages = {};
    for (int i = 0; i < entries.length; i++) {
      descriptionImages[i] = await _getDescriptionImage(entries[i], languageProvider);
    }

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
        nameImg, metaImg, filterType, dateRange, summary, entries.length, ctx, languageProvider,
      ),
      footer: (ctx) => _pageFooter(ctx, languageProvider),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        _table(entries, summary, saleItemsCache ?? {}, descriptionImages, languageProvider),
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
      LanguageProvider lp,
      ) {
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
                    lp.isEnglish ? 'CUSTOMER LEDGER STATEMENT' : 'کسٹمر لیجر سٹیٹمنٹ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
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
                      _filterLabel(filterType, lp),
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
                    lp.isEnglish
                        ? 'Generated: ${_dtf.format(DateTime.now())}'
                        : 'تیار کردہ: ${_dtf.format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 6,
                      color: PdfColor.fromInt(0xFFDDD6FE),
                    ),
                  ),
                  pw.Text(
                    '${lp.isEnglish ? 'Page' : 'صفحہ'} ${ctx.pageNumber}',
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

        pw.Row(children: [
          _sCard(
            lp.isEnglish ? 'TOTAL SALES' : 'کل فروخت',
            'Rs ${_cf.format(totalDebit)}',
            _red, _redBg,
            lp,
          ),
          pw.SizedBox(width: 5),
          _sCard(
            lp.isEnglish ? 'TOTAL PAYMENTS' : 'کل ادائیگیاں',
            'Rs ${_cf.format(totalCredit)}',
            _green, _greenBg,
            lp,
          ),
          pw.SizedBox(width: 5),
          _sCard(
            lp.isEnglish ? 'OUTSTANDING' : 'بقایا',
            'Rs ${_cf.format(closingBalance)}',
            _purple, _purpleL,
            lp,
            bold: true,
          ),
          pw.SizedBox(width: 5),
          _sCard(
            lp.isEnglish ? 'ENTRIES' : 'اندراجات',
            '$entryCount',
            _t2, _hdrBg,
            lp,
          ),
        ]),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _sCard(
      String lbl,
      String val,
      PdfColor col,
      PdfColor bg,
      LanguageProvider lp, {
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

  static pw.Widget _pageFooter(pw.Context ctx, LanguageProvider lp) {
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
            lp.isEnglish
                ? 'Computer-generated - not valid without authorisation.'
                : 'کمپیوٹر سے تیار کردہ - اجازت کے بغیر درست نہیں۔',
            style: pw.TextStyle(
              fontSize: 5.5,
              color: _t3,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Text(
            '${lp.isEnglish ? 'Page' : 'صفحہ'} ${ctx.pageNumber} ${lp.isEnglish ? 'of' : 'of'} ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 5.5, color: _t3),
          ),
        ],
      ),
    );
  }

  static pw.Widget _table(
      List<Map<String, dynamic>> entries,
      Map<String, dynamic> summary,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
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
          _tHeader(lp),
          ...entries.asMap().entries.expand(
                (en) => _tRow(en.value, en.key, cache, descriptionImages, lp),
          ),
          _tTotal(totDebit, totCredit, closing, lp),
        ]),
      ),
    );
  }

  static pw.Widget _tHeader(LanguageProvider lp) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    color: _hdrBg,
    child: pw.Row(children: [
      _hc(lp.isEnglish ? 'DATE' : 'تاریخ',        11),
      _hc(lp.isEnglish ? 'REF #' : 'حوالہ نمبر',  10),
      _hc(lp.isEnglish ? 'TYPE' : 'قسم',          9),
      _hc(lp.isEnglish ? 'METHOD' : 'طریقہ',      8),
      _hc(lp.isEnglish ? 'BANK' : 'بینک',        13),
      _hc(lp.isEnglish ? 'DESCRIPTION' : 'تفصیل', 23),
      _hc(lp.isEnglish ? 'DEBIT' : 'ڈیبٹ',       12, r: true),
      _hc(lp.isEnglish ? 'CREDIT' : 'کریڈٹ',     12, r: true),
      _hc(lp.isEnglish ? 'BALANCE' : 'بیلنس',    12, r: true),
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

  static List<pw.Widget> _tRow(
      Map<String, dynamic> e,
      int idx,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      ) {
    final widgets = <pw.Widget>[];

    final debit   = _d(e['debit']);
    final credit  = _d(e['credit']);
    final balance = _d(e['balance']);
    final type    = (e['transaction_type'] as String?) ?? 'adjustment';
    final method  = e['payment_method'] as String?;
    final bank    = e['bank_name'] as String?;
    final refNum  = e['reference_number'] as String?;

    final ts     = _typeStyle(type, lp);
    final ms     = _methodStyle(method, lp);
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
          pw.Expanded(
            flex: 11,
            child: pw.Text(
              txDate != null ? _df.format(txDate) : '',
              style: pw.TextStyle(fontSize: 6.5, color: _t2),
            ),
          ),
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
          pw.Expanded(
            flex: 9,
            child: _badge(
              ts['label'] as String,
              ts['color'] as PdfColor,
              ts['bg'] as PdfColor,
            ),
          ),
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
          pw.Expanded(
            flex: 13,
            child: bank != null && bank.isNotEmpty
                ? _buildBankCell(bank)
                : pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 23,
            child: pw.Image(descriptionImages[idx]!, height: 20),
          ),
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

    if (type == 'sale' && e['reference_id'] != null) {
      final items = cache[e['reference_id'] as int];
      if (items != null && items.isNotEmpty) widgets.add(_saleSub(items, lp));
    }

    if (type == 'payment' && method == 'cheque') {
      final cn = e['cheque_number'] as String?;
      final cd = e['cheque_date'] as String?;
      final cl = e['cheque_cleared'] as bool? ?? false;
      if (cn != null) widgets.add(_chequeSub(cn, cd, cl, lp));
    }

    return widgets;
  }

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

  static pw.Widget _saleSub(List<Map<String, dynamic>> items, LanguageProvider lp) =>
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
              lp.isEnglish ? 'Sold Items' : 'فروخت شدہ اشیاء',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: _purple,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: _purpleS,
              child: pw.Row(children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    lp.isEnglish ? 'PRODUCT' : 'پروڈکٹ',
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
                    lp.isEnglish ? 'QTY' : 'مقدار',
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
                    lp.isEnglish ? 'PRICE' : 'قیمت',
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
                    lp.isEnglish ? 'TOTAL' : 'کل',
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
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              color: _purpleS,
              child: pw.Row(children: [
                pw.Expanded(
                  child: pw.Text(
                    lp.isEnglish ? 'Total' : 'کل',
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

  static pw.Widget _chequeSub(String num, String? date, bool cleared, LanguageProvider lp) {
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
          '${lp.isEnglish ? 'Cheque #' : 'چیک نمبر'}$num',
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
            color: col,
          ),
        ),
        if (date != null) ...[
          pw.SizedBox(width: 10),
          pw.Text(
            '${lp.isEnglish ? 'Date' : 'تاریخ'}: $date',
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
            cleared
                ? (lp.isEnglish ? 'CLEARED' : 'کلیئر شدہ')
                : (lp.isEnglish ? 'PENDING' : 'زیر التواء'),
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

  static pw.Widget _tTotal(double debit, double credit, double closing, LanguageProvider lp) {
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
            lp.isEnglish ? 'TOTAL' : 'کل',
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

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;

  static Map<String, dynamic> _typeStyle(String type, LanguageProvider lp) {
    switch (type) {
      case 'sale':
        return {'label': lp.isEnglish ? 'SALE' : 'فروخت', 'color': _red,    'bg': _redBg};
      case 'payment':
        return {'label': lp.isEnglish ? 'PAYMENT' : 'ادائیگی', 'color': _green,  'bg': _greenBg};
      case 'adjustment':
        return {'label': lp.isEnglish ? 'ADJUSTMENT' : 'ایڈجسٹمنٹ', 'color': _amber,  'bg': _amberBg};
      default:
        return {'label': lp.isEnglish ? 'MANUAL' : 'دستی', 'color': _indigo, 'bg': _indigoBg};
    }
  }

  static Map<String, dynamic> _methodStyle(String? method, LanguageProvider lp) {
    switch (method) {
      case 'cash':   return {'label': lp.isEnglish ? 'CASH' : 'نقد',   'color': _green,  'bg': _greenBg};
      case 'bank':   return {'label': lp.isEnglish ? 'BANK' : 'بینک',   'color': _blue,   'bg': _blueBg};
      case 'cheque': return {'label': lp.isEnglish ? 'CHEQUE' : 'چیک', 'color': _amber,  'bg': _amberBg};
      case 'slip':   return {'label': lp.isEnglish ? 'SLIP' : 'سلیپ',   'color': _purple, 'bg': _purpleL};
      default:       return {'label': '',       'color': _t3,     'bg': _hdrBg};
    }
  }

  static String _filterLabel(String f, LanguageProvider lp) {
    switch (f) {
      case 'sale':
        return lp.isEnglish ? 'SALES ONLY' : 'صرف فروخت';
      case 'payment':
        return lp.isEnglish ? 'PAYMENTS ONLY' : 'صرف ادائیگیاں';
      case 'adjustment':
        return lp.isEnglish ? 'ADJUSTMENTS ONLY' : 'صرف ایڈجسٹمنٹ';
      default:
        return lp.isEnglish ? 'ALL TRANSACTIONS' : 'تمام لین دین';
    }
  }
}