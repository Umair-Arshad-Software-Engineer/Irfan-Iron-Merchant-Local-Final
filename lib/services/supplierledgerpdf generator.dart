import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../Banks/banknames.dart';
import '../providers/lanprovider.dart';

// ─── Ledger View Type Enum ──────────────────────────────────────────────────
enum LedgerViewType {
  consolidated,
  itemized,
}

// ─── PDF Type Enum ──────────────────────────────────────────────────────────
enum PdfType {
  summary,
  detailed,
}

class SupplierLedgerPdfGenerator {
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
  static const PdfColor _itemBg   = PdfColor.fromInt(0xFFF0F7FF);

  static final Map<String, pw.MemoryImage> _bankLogoCache = {};
  static final Map<String, pw.MemoryImage> _textImageCache = {};

  // ─── Helper to convert Flutter FontWeight to ui.FontWeight ──────────────
  static ui.FontWeight _toUiFontWeight(FontWeight weight) {
    if (weight == FontWeight.w100) return ui.FontWeight.w100;
    if (weight == FontWeight.w200) return ui.FontWeight.w200;
    if (weight == FontWeight.w300) return ui.FontWeight.w300;
    if (weight == FontWeight.w400) return ui.FontWeight.w400;
    if (weight == FontWeight.w500) return ui.FontWeight.w500;
    if (weight == FontWeight.w600) return ui.FontWeight.w600;
    if (weight == FontWeight.w700) return ui.FontWeight.w700;
    if (weight == FontWeight.w800) return ui.FontWeight.w800;
    if (weight == FontWeight.w900) return ui.FontWeight.w900;
    return ui.FontWeight.normal;
  }

  // ─── Create Urdu text as image ──────────────────────────────────────────────
  static Future<pw.MemoryImage> _createUrduTextImage(
      String text, {
        double fontSize = 12,
        Color color = Colors.black,
        FontWeight weight = FontWeight.normal,
        bool rtl = true,
        double maxWidth = 300,
        int maxLines = 2,
        Color? backgroundColor,
      }) async {
    final String displayText = text.isEmpty ? ' ' : text;
    final cacheKey = '$text|$fontSize|${color.value}|$weight|$rtl|$maxWidth|$maxLines';

    if (_textImageCache.containsKey(cacheKey)) {
      return _textImageCache[cacheKey]!;
    }

    const double scaleFactor = 2.5;
    final double scaledFontSize = fontSize * scaleFactor;
    final double scaledMaxWidth = maxWidth * scaleFactor;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, scaledMaxWidth, (fontSize * maxLines + 12) * scaleFactor),
    );

    final ui.TextStyle textStyle = ui.TextStyle(
      fontSize: scaledFontSize,
      fontFamily: 'JameelNoori',
      color: color,
      fontWeight: _toUiFontWeight(weight),
    );

    final ui.TextPainter textPainter = ui.TextPainter(
      text: ui.TextSpan(text: displayText, style: textStyle),
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      maxLines: maxLines,
    );

    textPainter.layout(maxWidth: scaledMaxWidth);

    final width = textPainter.width + 16;
    final height = textPainter.height + 12;

    final finalRecorder = ui.PictureRecorder();
    final finalCanvas = Canvas(
      finalRecorder,
      Rect.fromLTWH(0, 0, width, height),
    );

    if (backgroundColor != null) {
      finalCanvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = backgroundColor,
      );
    } else {
      finalCanvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0x00FFFFFF),
      );
    }

    final offset = rtl
        ? Offset(width - textPainter.width - 8, 6)
        : Offset(8, 6);
    textPainter.paint(finalCanvas, offset);

    final picture = finalRecorder.endRecording();
    final img = await picture.toImage(width.ceil(), height.ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final memoryImage = pw.MemoryImage(byteData!.buffer.asUint8List());
    _textImageCache[cacheKey] = memoryImage;
    return memoryImage;
  }

  // ─── Create description text image ──────────────────────────────────────────
  static Future<pw.MemoryImage> _createDescriptionTextImage(String text, {bool rtl = false}) async {
    return await _createUrduTextImage(
      text,
      fontSize: 9,
      color: const Color(0xFF1C1C1E),
      weight: FontWeight.normal,
      rtl: rtl,
      maxWidth: 200,
      maxLines: 2,
    );
  }

  // ─── Create badge text image ──────────────────────────────────────────────
  static Future<pw.MemoryImage> _createBadgeTextImage(
      String text, {
        Color color = const Color(0xFF7C3AED),
        Color bgColor = const Color(0xFFF5F3FF),
        bool rtl = true,
      }) async {
    return await _createUrduTextImage(
      text,
      fontSize: 7,
      color: color,
      weight: FontWeight.bold,
      rtl: rtl,
      maxWidth: 80,
      maxLines: 1,
      backgroundColor: bgColor,
    );
  }

  static Future<pw.MemoryImage> _getDescriptionImage(Map<String, dynamic> entry, LanguageProvider lp) async {
    final type = (entry['reference_type'] as String?) ?? 'manual';
    String descriptionText = '';

    if (type == 'purchase_receipt') {
      descriptionText = lp.isEnglish ? 'RECEIPT' : 'رسید';
    } else {
      descriptionText = (entry['description'] as String?) ?? '';
    }

    if (descriptionText.isEmpty) {
      return await _createUrduTextImage(' ', fontSize: 6, maxWidth: 100, maxLines: 1);
    }

    return await _createDescriptionTextImage(descriptionText, rtl: !lp.isEnglish);
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

  // ─── Main Entry Point ───────────────────────────────────────────────────────
  static Future<Uint8List> generateLedgerPdf({
    required String supplierName,
    required String supplierPhone,
    required String supplierAddress,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> entries,
    required String filterType,
    DateTimeRange? dateRange,
    Map<int, List<Map<String, dynamic>>>? receiptItemsCache,
    required LanguageProvider languageProvider,
    required PdfType pdfType,
    required LedgerViewType ledgerViewType,
  }) async {
    _textImageCache.clear();
    _bankLogoCache.clear();

    // Generate text images
    final nameImg = await _createUrduTextImage(
      supplierName,
      fontSize: 14,
      color: const Color(0xFFFFFFFF),
      weight: FontWeight.bold,
      rtl: true,
      maxWidth: 300,
      maxLines: 1,
    );

    final metaText = [supplierPhone, supplierAddress]
        .where((s) => s.isNotEmpty)
        .join('  •  ');
    final metaImg = await _createUrduTextImage(
      metaText,
      fontSize: 8,
      color: const Color(0xFFDDD6FE),
      weight: FontWeight.normal,
      rtl: true,
      maxWidth: 380,
      maxLines: 2,
    );

    // Pre-generate all description images
    final Map<int, pw.MemoryImage> descriptionImages = {};
    for (int i = 0; i < entries.length; i++) {
      descriptionImages[i] = await _getDescriptionImage(entries[i], languageProvider);
    }

    // Load bank logos
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
        nameImg, metaImg, filterType, dateRange, summary, entries.length, ctx, languageProvider, pdfType,
      ),
      footer: (ctx) => _pageFooter(ctx, languageProvider),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        ledgerViewType == LedgerViewType.itemized
            ? _itemizedTable(entries, summary, receiptItemsCache ?? {}, descriptionImages, languageProvider, pdfType)
            : _consolidatedTable(entries, summary, receiptItemsCache ?? {}, descriptionImages, languageProvider, pdfType),
      ],
    ));
    return pdf.save();
  }

  // ─── Page Header ────────────────────────────────────────────────────────────
  static pw.Widget _pageHeader(
      pw.MemoryImage nameImg,
      pw.MemoryImage metaImg,
      String filterType,
      DateTimeRange? dateRange,
      Map<String, dynamic> summary,
      int entryCount,
      pw.Context ctx,
      LanguageProvider lp,
      PdfType pdfType,
      ) {
    double totalDebit = _d(summary['total_debit']);
    double totalCredit = _d(summary['total_credit']);
    double closingBalance = _d(summary['closing_balance']);

    final title = pdfType == PdfType.summary
        ? (lp.isEnglish ? 'LEDGER SUMMARY' : 'لیجر خلاصہ')
        : (lp.isEnglish ? 'DETAILED LEDGER' : 'تفصیلی لیجر');

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
                    title,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Image(nameImg, height: 18),
                  pw.SizedBox(height: 2),
                  pw.Image(metaImg, height: 12),
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
            lp.isEnglish ? 'TOTAL PAYABLE' : 'کل قابل ادائیگی',
            'Rs ${_cf.format(totalCredit)}',
            _red, _redBg,
            lp,
          ),
          pw.SizedBox(width: 5),
          _sCard(
            lp.isEnglish ? 'TOTAL PAID' : 'کل ادا شدہ',
            'Rs ${_cf.format(totalDebit)}',
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

  // ─── Consolidated Table ──────────────────────────────────────────────────────
  static pw.Widget _consolidatedTable(
      List<Map<String, dynamic>> entries,
      Map<String, dynamic> summary,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      PdfType pdfType,
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
          _consolidatedHeader(lp, pdfType),
          ...entries.asMap().entries.expand(
                (en) => _consolidatedRow(en.value, en.key, cache, descriptionImages, lp, pdfType),
          ),
          _consolidatedTotal(totDebit, totCredit, closing, lp),
        ]),
      ),
    );
  }

  static pw.Widget _consolidatedHeader(LanguageProvider lp, PdfType pdfType) {
    if (pdfType == PdfType.detailed) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: _hdrBg,
        child: pw.Row(children: [
          _hc(lp.isEnglish ? 'DATE' : 'تاریخ',        8),
          _hc(lp.isEnglish ? 'REF #' : 'حوالہ نمبر',  8),
          _hc(lp.isEnglish ? 'ITEM NAME' : 'آئٹم نام', 12),
          _hc(lp.isEnglish ? 'TYPE' : 'قسم',          6),
          _hc(lp.isEnglish ? 'QTY' : 'مقدار',         5),
          _hc(lp.isEnglish ? 'RATE' : 'ریٹ',          6),
          _hc(lp.isEnglish ? 'METHOD' : 'طریقہ',      6),
          _hc(lp.isEnglish ? 'BANK' : 'بینک',         8),
          _hc(lp.isEnglish ? 'DEBIT' : 'ڈیبٹ',        7, r: true),
          _hc(lp.isEnglish ? 'CREDIT' : 'کریڈٹ',      7, r: true),
          _hc(lp.isEnglish ? 'BALANCE' : 'بیلنس',     7, r: true),
        ]),
      );
    }

    return pw.Container(
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
  }

  static List<pw.Widget> _consolidatedRow(
      Map<String, dynamic> e,
      int idx,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      PdfType pdfType,
      ) {
    final widgets = <pw.Widget>[];

    final debit   = _d(e['debit']);
    final credit  = _d(e['credit']);
    final balance = _d(e['balance']);
    final type    = (e['reference_type'] as String?) ?? 'manual';
    final method  = e['payment_method'] as String?;
    final bank    = e['bank_name'] as String?;
    final refNum  = e['reference_number'] as String?;

    final ts     = _typeStyle(type, lp);
    final ms     = _methodStyle(method, lp);
    final balCol = balance > 0 ? _red : balance < 0 ? _green : _t3;
    final bg     = idx.isEven ? _white : _rowAlt;

    DateTime? txDate;
    try {
      txDate = DateTime.parse(e['transaction_date'] as String);
    } catch (_) {}

    if (pdfType == PdfType.detailed && type == 'purchase_receipt' && e['reference_id'] != null) {
      final items = cache[e['reference_id'] as int];
      if (items != null && items.isNotEmpty) {
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
                flex: 8,
                child: pw.Text(
                  txDate != null ? _df.format(txDate) : '',
                  style: pw.TextStyle(fontSize: 6.5, color: _t2),
                ),
              ),
              pw.Expanded(
                flex: 8,
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
                flex: 12,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: _purpleL,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          _getReceiptDescription(items, lp),
                          style: pw.TextStyle(
                            fontSize: 6.5,
                            color: _purple,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                flex: 6,
                child: _badge(
                  ts['label'] as String,
                  ts['color'] as PdfColor,
                  ts['bg'] as PdfColor,
                ),
              ),
              pw.Expanded(
                flex: 5,
                child: pw.Text(
                  _getTotalQuantity(items).toString(),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _indigo,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 6,
                child: pw.Text(
                  'Rs ${_getAverageRate(items).toStringAsFixed(2)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    color: _t2,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 6,
                child: method != null
                    ? _badge(
                  ms['label'] as String,
                  ms['color'] as PdfColor,
                  ms['bg'] as PdfColor,
                )
                    : pw.SizedBox(),
              ),
              pw.Expanded(
                flex: 8,
                child: bank != null && bank.isNotEmpty
                    ? _buildBankCell(bank)
                    : pw.SizedBox(),
              ),
              pw.Expanded(
                flex: 7,
                child: pw.Text(
                  debit > 0 ? _cf.format(debit) : '',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: debit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: debit > 0 ? _green : _t3,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 7,
                child: pw.Text(
                  credit > 0 ? _cf.format(credit) : '',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: credit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: credit > 0 ? _red : _t3,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 7,
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

        for (var item in items) {
          widgets.add(_consolidatedItemRow(item, lp, idx));
        }
      } else {
        widgets.add(_consolidatedRegularRow(e, idx, descriptionImages, lp, pdfType, txDate, refNum, ts, ms, method, bank, debit, credit, balance, balCol, bg));
      }
    } else {
      widgets.add(_consolidatedRegularRow(e, idx, descriptionImages, lp, pdfType, txDate, refNum, ts, ms, method, bank, debit, credit, balance, balCol, bg));
    }

    if (type == 'payment' && method == 'cheque') {
      final cn = e['cheque_number'] as String?;
      final cd = e['cheque_date'] as String?;
      final cl = e['cheque_cleared'] as bool? ?? false;
      if (cn != null) widgets.add(_chequeSub(cn, cd, cl, lp));
    }

    return widgets;
  }

  static pw.Widget _consolidatedRegularRow(
      Map<String, dynamic> e,
      int idx,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      PdfType pdfType,
      DateTime? txDate,
      String? refNum,
      Map<String, dynamic> ts,
      Map<String, dynamic> ms,
      String? method,
      String? bank,
      double debit,
      double credit,
      double balance,
      PdfColor balCol,
      PdfColor bg,
      ) {
    if (pdfType == PdfType.detailed) {
      return pw.Container(
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
              flex: 8,
              child: pw.Text(
                txDate != null ? _df.format(txDate) : '',
                style: pw.TextStyle(fontSize: 6.5, color: _t2),
              ),
            ),
            pw.Expanded(
              flex: 8,
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
              flex: 12,
              child: pw.Image(descriptionImages[idx]!, height: 20),
            ),
            pw.Expanded(
              flex: 6,
              child: _badge(
                ts['label'] as String,
                ts['color'] as PdfColor,
                ts['bg'] as PdfColor,
              ),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.SizedBox(),
            ),
            pw.Expanded(
              flex: 6,
              child: pw.SizedBox(),
            ),
            pw.Expanded(
              flex: 6,
              child: method != null
                  ? _badge(
                ms['label'] as String,
                ms['color'] as PdfColor,
                ms['bg'] as PdfColor,
              )
                  : pw.SizedBox(),
            ),
            pw.Expanded(
              flex: 8,
              child: bank != null && bank.isNotEmpty
                  ? _buildBankCell(bank)
                  : pw.SizedBox(),
            ),
            pw.Expanded(
              flex: 7,
              child: pw.Text(
                debit > 0 ? _cf.format(debit) : '',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: debit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: debit > 0 ? _green : _t3,
                ),
              ),
            ),
            pw.Expanded(
              flex: 7,
              child: pw.Text(
                credit > 0 ? _cf.format(credit) : '',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: credit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: credit > 0 ? _red : _t3,
                ),
              ),
            ),
            pw.Expanded(
              flex: 7,
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
      );
    } else {
      return pw.Container(
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
                  color: debit > 0 ? _green : _t3,
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
                  color: credit > 0 ? _red : _t3,
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
      );
    }
  }

  static pw.Widget _consolidatedItemRow(Map<String, dynamic> item, LanguageProvider lp, int parentIdx) {
    final qty   = (item['quantity'] as num?)?.toInt() ?? 0;
    final rate  = (item['unit_cost'] as num?)?.toDouble() ?? 0.0;
    final total = qty * rate;

    final productName = (item['product_name'] as String?) ?? 'Unknown';
    final barcode = item['barcode'] as String?;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _itemBg,
        border: const pw.Border(
          bottom: pw.BorderSide(color: _border, width: 0.3),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 12,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  productName,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _t1,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                if (barcode != null)
                  pw.Text(
                    '($barcode)',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      color: _t3,
                    ),
                  ),
                if (item['batch_number'] != null)
                  pw.Text(
                    '${lp.isEnglish ? 'Batch' : 'بیچ'}: ${item['batch_number']}',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      color: _blue,
                    ),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: _badge(
              lp.isEnglish ? 'ITEM' : 'آئٹم',
              _blue,
              _blueBg,
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              '$qty',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: _indigo,
              ),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Text(
              'Rs ${rate.toStringAsFixed(2)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                color: _t2,
              ),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.Text(
              'Rs ${total.toStringAsFixed(2)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.SizedBox(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _consolidatedTotal(double debit, double credit, double closing, LanguageProvider lp) {
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
        pw.Expanded(flex: 8, child: pw.SizedBox()),
        pw.Expanded(flex: 8, child: pw.SizedBox()),
        pw.Expanded(flex: 12, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.SizedBox()),
        pw.Expanded(flex: 5, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.SizedBox()),
        pw.Expanded(flex: 8, child: pw.SizedBox()),
        pw.Expanded(
          flex: 7,
          child: pw.Text(
            _cf.format(debit),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _green,
            ),
          ),
        ),
        pw.Expanded(
          flex: 7,
          child: pw.Text(
            _cf.format(credit),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _red,
            ),
          ),
        ),
        pw.Expanded(
          flex: 7,
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

  // ─── Itemized Table ──────────────────────────────────────────────────────────
  static pw.Widget _itemizedTable(
      List<Map<String, dynamic>> entries,
      Map<String, dynamic> summary,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      PdfType pdfType,
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
          _itemizedHeader(lp),
          ...entries.asMap().entries.expand(
                (en) => _itemizedRows(en.value, en.key, cache, descriptionImages, lp),
          ),
          _itemizedTotal(totDebit, totCredit, closing, lp),
        ]),
      ),
    );
  }

  static pw.Widget _itemizedHeader(LanguageProvider lp) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: _hdrBg,
      child: pw.Row(children: [
        _hc(lp.isEnglish ? 'DATE' : 'تاریخ', 8),
        _hc(lp.isEnglish ? 'REF #' : 'حوالہ', 7),
        _hc(lp.isEnglish ? 'PRODUCT' : 'پروڈکٹ', 12),
        _hc(lp.isEnglish ? 'TYPE' : 'قسم', 6),
        _hc(lp.isEnglish ? 'QTY' : 'مقدار', 5),
        _hc(lp.isEnglish ? 'RATE' : 'ریٹ', 7, r: true),
        _hc(lp.isEnglish ? 'TOTAL' : 'کل', 8, r: true),
        _hc(lp.isEnglish ? 'METHOD' : 'طریقہ', 7),
        _hc(lp.isEnglish ? 'DEBIT' : 'ڈیبٹ', 8, r: true),
        _hc(lp.isEnglish ? 'CREDIT' : 'کریڈٹ', 8, r: true),
        _hc(lp.isEnglish ? 'BALANCE' : 'بیلنس', 8, r: true),
      ]),
    );
  }

  static Iterable<pw.Widget> _itemizedRows(
      Map<String, dynamic> entry,
      int idx,
      Map<int, List<Map<String, dynamic>>> cache,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      ) sync* {
    final type = (entry['reference_type'] as String?) ?? 'manual';
    final isReceipt = type == 'purchase_receipt';
    final referenceId = entry['reference_id'] as int?;
    final items = referenceId != null ? cache[referenceId] : null;

    if (isReceipt && items != null && items.isNotEmpty) {
      yield _itemizedReceiptHeader(entry, items, idx, lp);
      for (var item in items) {
        yield _itemizedItemRow(item, lp);
      }
    } else {
      yield _itemizedRegularRow(entry, idx, descriptionImages, lp);
    }
  }

  static pw.Widget _itemizedReceiptHeader(
      Map<String, dynamic> entry,
      List<Map<String, dynamic>> items,
      int idx,
      LanguageProvider lp,
      ) {
    final debit   = _d(entry['debit']);
    final credit  = _d(entry['credit']);
    final balance = _d(entry['balance']);
    final method  = entry['payment_method'] as String?;
    final refNum  = entry['reference_number'] as String?;
    final ts = _typeStyle('purchase_receipt', lp);
    final ms = _methodStyle(method, lp);
    final balCol = balance > 0 ? _red : balance < 0 ? _green : _t3;
    final bg = idx.isEven ? _white : _rowAlt;

    DateTime? txDate;
    try {
      txDate = DateTime.parse(entry['transaction_date'] as String);
    } catch (_) {}

    return pw.Container(
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
            flex: 8,
            child: pw.Text(
              txDate != null ? _df.format(txDate) : '',
              style: pw.TextStyle(fontSize: 6.5, color: _t2),
            ),
          ),
          pw.Expanded(
            flex: 7,
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
            flex: 12,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                color: _purpleL,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${lp.isEnglish ? 'Receipt' : 'رسید'} (${items.length} ${lp.isEnglish ? 'items' : 'اشیاء'})',
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        color: _purple,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: _badge(
              ts['label'] as String,
              ts['color'] as PdfColor,
              ts['bg'] as PdfColor,
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: method != null
                ? _badge(
              ms['label'] as String,
              ms['color'] as PdfColor,
              ms['bg'] as PdfColor,
            )
                : pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.Text(
              debit > 0 ? _cf.format(debit) : '',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: debit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: debit > 0 ? _green : _t3,
              ),
            ),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.Text(
              credit > 0 ? _cf.format(credit) : '',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: credit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: credit > 0 ? _red : _t3,
              ),
            ),
          ),
          pw.Expanded(
            flex: 8,
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
    );
  }

  static pw.Widget _itemizedItemRow(Map<String, dynamic> item, LanguageProvider lp) {
    final productName = (item['product_name'] as String?) ?? 'Unknown';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final rate = (item['unit_cost'] as num?)?.toDouble() ?? 0.0;
    final total = quantity * rate;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _itemBg,
        border: const pw.Border(
          bottom: pw.BorderSide(color: _border, width: 0.3),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 12,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  productName,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _t1,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                if (item['batch_number'] != null)
                  pw.Text(
                    '${lp.isEnglish ? 'Batch' : 'بیچ'}: ${item['batch_number']}',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      color: _blue,
                    ),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: _badge(
              lp.isEnglish ? 'ITEM' : 'آئٹم',
              _blue,
              _blueBg,
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              '$quantity',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: _indigo,
              ),
            ),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.Text(
              'Rs ${rate.toStringAsFixed(2)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                color: _t2,
              ),
            ),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.Text(
              'Rs ${total.toStringAsFixed(2)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemizedRegularRow(
      Map<String, dynamic> entry,
      int idx,
      Map<int, pw.MemoryImage> descriptionImages,
      LanguageProvider lp,
      ) {
    final debit   = _d(entry['debit']);
    final credit  = _d(entry['credit']);
    final balance = _d(entry['balance']);
    final type    = (entry['reference_type'] as String?) ?? 'manual';
    final method  = entry['payment_method'] as String?;
    final refNum  = entry['reference_number'] as String?;

    final ts = _typeStyle(type, lp);
    final ms = _methodStyle(method, lp);
    final balCol = balance > 0 ? _red : balance < 0 ? _green : _t3;
    final bg = idx.isEven ? _white : _rowAlt;

    DateTime? txDate;
    try {
      txDate = DateTime.parse(entry['transaction_date'] as String);
    } catch (_) {}

    final displayText = type == 'purchase_receipt'
        ? (lp.isEnglish ? 'Receipt' : 'رسید')
        : (entry['description'] as String? ?? '—');

    return pw.Container(
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
            flex: 8,
            child: pw.Text(
              txDate != null ? _df.format(txDate) : '',
              style: pw.TextStyle(fontSize: 6.5, color: _t2),
            ),
          ),
          pw.Expanded(
            flex: 7,
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
            flex: 12,
            child: pw.Image(descriptionImages[idx]!, height: 20),
          ),
          pw.Expanded(
            flex: 6,
            child: _badge(
              ts['label'] as String,
              ts['color'] as PdfColor,
              ts['bg'] as PdfColor,
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 7,
            child: method != null
                ? _badge(
              ms['label'] as String,
              ms['color'] as PdfColor,
              ms['bg'] as PdfColor,
            )
                : pw.SizedBox(),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.Text(
              debit > 0 ? _cf.format(debit) : '',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: debit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: debit > 0 ? _green : _t3,
              ),
            ),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.Text(
              credit > 0 ? _cf.format(credit) : '',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: credit > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: credit > 0 ? _red : _t3,
              ),
            ),
          ),
          pw.Expanded(
            flex: 8,
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
    );
  }

  static pw.Widget _itemizedTotal(double debit, double credit, double closing, LanguageProvider lp) {
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
        pw.Expanded(flex: 8, child: pw.SizedBox()),
        pw.Expanded(flex: 7, child: pw.SizedBox()),
        pw.Expanded(flex: 12, child: pw.SizedBox()),
        pw.Expanded(flex: 6, child: pw.SizedBox()),
        pw.Expanded(flex: 5, child: pw.SizedBox()),
        pw.Expanded(flex: 7, child: pw.SizedBox()),
        pw.Expanded(flex: 8, child: pw.SizedBox()),
        pw.Expanded(flex: 7, child: pw.SizedBox()),
        pw.Expanded(
          flex: 8,
          child: pw.Text(
            _cf.format(debit),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _green,
            ),
          ),
        ),
        pw.Expanded(
          flex: 8,
          child: pw.Text(
            _cf.format(credit),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _red,
            ),
          ),
        ),
        pw.Expanded(
          flex: 8,
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

  // ─── Helper Widgets ──────────────────────────────────────────────────────────
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

  static String _getReceiptDescription(List<Map<String, dynamic>> items, LanguageProvider lp) {
    if (items.isEmpty) return '';
    final firstName = items.first['product_name'] as String? ?? 'Item';
    if (items.length == 1) return firstName;
    return '$firstName + ${items.length - 1} more';
  }

  static int _getTotalQuantity(List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      total += (item['quantity'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  static double _getAverageRate(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 0.0;
    double total = 0.0;
    int count = 0;
    for (var item in items) {
      final rate = (item['unit_cost'] ?? 0.0).toDouble();
      if (rate > 0) {
        total += rate;
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  static Map<String, dynamic> _typeStyle(String type, LanguageProvider lp) {
    switch (type) {
      case 'purchase_receipt':
        return {'label': lp.isEnglish ? 'RECEIPT' : 'رسید', 'color': _red,    'bg': _redBg};
      case 'payment':
        return {'label': lp.isEnglish ? 'PAYMENT' : 'ادائیگی', 'color': _green,  'bg': _greenBg};
      case 'reversal':
        return {'label': lp.isEnglish ? 'REVERSAL' : 'واپسی', 'color': _amber,  'bg': _amberBg};
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
      case 'purchase_receipt':
        return lp.isEnglish ? 'RECEIPTS ONLY' : 'صرف رسیدیں';
      case 'payment':
        return lp.isEnglish ? 'PAYMENTS ONLY' : 'صرف ادائیگیاں';
      case 'manual':
        return lp.isEnglish ? 'MANUAL ENTRIES' : 'دستی اندراجات';
      default:
        return lp.isEnglish ? 'ALL TRANSACTIONS' : 'تمام لین دین';
    }
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;
}