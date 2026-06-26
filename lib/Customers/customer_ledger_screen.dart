import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/customer.dart';
import '../../providers/customer_ledger_provider.dart';
import '../../config/api_config.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../providers/lanprovider.dart';
import '../services/CustomerLedgerPdfGenerator.dart';
import '../Banks/banknames.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final Customer customer;
  final LanguageProvider languageProvider;

  const CustomerLedgerScreen({
    super.key,
    required this.customer,
    required this.languageProvider,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final _currencyFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _dateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;
  int? _expandedEntryId;
  LedgerViewType _ledgerViewType = LedgerViewType.consolidated;

  final Map<int, List<Map<String, dynamic>>> _saleItemsCache = {};
  final Map<int, bool> _saleItemsLoading = {};

  static const Map<String, Map<String, dynamic>> _paymentMethodMeta = {
    'cash': {'label': 'Cash', 'icon': Icons.payments_outlined, 'color': Color(0xFF10B981)},
    'bank': {'label': 'Bank', 'icon': Icons.account_balance_outlined, 'color': Color(0xFF3B82F6)},
    'cheque': {'label': 'Cheque', 'icon': Icons.receipt_long_outlined, 'color': Color(0xFFF59E0B)},
    'slip': {'label': 'Slip', 'icon': Icons.receipt_outlined, 'color': Color(0xFF8B5CF6)},
  };

  List<Map<String, String>> _getFilterOptions(LanguageProvider lp) => [
    {'value': 'all', 'label': lp.isEnglish ? 'All' : 'سب'},
    {'value': 'sale', 'label': lp.isEnglish ? 'Sales' : 'فروخت'},
    {'value': 'payment', 'label': lp.isEnglish ? 'Payments' : 'ادائیگیاں'},
    {'value': 'adjustment', 'label': lp.isEnglish ? 'Adjustments' : 'ایڈجسٹمنٹ'},
  ];

  @override
  void initState() {
    super.initState();
    _verticalScroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLedger());
  }

  @override
  void dispose() {
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_verticalScroll.position.pixels >= _verticalScroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadLedger() async {
    final provider = Provider.of<CustomerLedgerProvider>(context, listen: false);
    await provider.fetchCustomerLedger(
      customerId: widget.customer.id!,
      page: 1,
      limit: 50,
      transactionType: _selectedFilter == 'all' ? null : _selectedFilter,
      fromDate: _dateRange?.start.toIso8601String().split('T').first,
      toDate: _dateRange?.end.toIso8601String().split('T').first,
      sortBy: 'date',
      sortOrder: 'asc',
    );

    // Auto-fetch sale items when in itemized view
    if (_ledgerViewType == LedgerViewType.itemized) {
      _prefetchAllSaleItems(provider.entries);
    }
  }

  Future<void> _loadMore() async {
    final provider = Provider.of<CustomerLedgerProvider>(context, listen: false);
    if (!provider.hasMorePages || provider.isLoading) return;
    await provider.fetchCustomerLedger(
      customerId: widget.customer.id!,
      page: provider.currentPage + 1,
      limit: 50,
      transactionType: _selectedFilter == 'all' ? null : _selectedFilter,
      sortBy: 'created_at',
      sortOrder: 'asc',
    );

    // Also prefetch for newly loaded entries in itemized view
    if (_ledgerViewType == LedgerViewType.itemized) {
      _prefetchAllSaleItems(provider.entries);
    }
  }

  /// Prefetch all sale items that aren't cached yet
  void _prefetchAllSaleItems(List<dynamic> entries) {
    for (final entry in entries) {
      if (entry['transaction_type'] == 'sale' && entry['reference_id'] != null) {
        final refId = entry['reference_id'] as int;
        if (!_saleItemsCache.containsKey(refId) && !(_saleItemsLoading[refId] ?? false)) {
          _fetchSaleItems(refId);
        }
      }
    }
  }

  List<String> _parseDynamicList(dynamic val) {
    if (val is String) {
      try {
        return List<String>.from(jsonDecode(val));
      } catch (_) {
        return [];
      }
    }
    if (val is List) return val.cast<String>();
    return [];
  }

  Map<String, int> _parseLengthQuantities(dynamic val) {
    if (val == null) return {};

    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) {
          return Map<String, int>.from(decoded.map((k, v) => MapEntry(k.toString(), _toInt(v))));
        }
      } catch (_) {}
      return {};
    }

    if (val is Map) {
      return Map<String, int>.from(val.map((k, v) => MapEntry(k.toString(), _toInt(v))));
    }

    return {};
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  Future<void> _fetchSaleItems(int saleId) async {
    if (_saleItemsCache.containsKey(saleId)) return;
    if (mounted) setState(() => _saleItemsLoading[saleId] = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sales/$saleId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final items = (data['data']['items'] as List).map<Map<String, dynamic>>((i) => {
            'product_name': i['product']?['item_name'] ?? 'Unknown',
            'barcode': i['product']?['barcode'],
            'quantity': i['quantity'],
            'unit_price': double.tryParse(i['unit_price'].toString()) ?? 0.0,
            'total_price': double.tryParse(i['total_price'].toString()) ?? 0.0,
            'selected_lengths': _parseDynamicList(i['selected_lengths']),
            'length_quantities': _parseLengthQuantities(i['length_quantities']),
            'weight': double.tryParse(i['weight']?.toString() ?? '0') ?? 0.0,
          }).toList();
          if (mounted) setState(() => _saleItemsCache[saleId] = items);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _saleItemsLoading[saleId] = false);
  }

  void _toggleRow(dynamic entry) {
    final expanding = _expandedEntryId != entry['id'];
    setState(() => _expandedEntryId = expanding ? entry['id'] : null);
    if (expanding && entry['transaction_type'] == 'sale' && entry['reference_id'] != null) {
      _fetchSaleItems(entry['reference_id']);
    }
  }

  String _getPaymentMethodLabel(String? method, LanguageProvider lp) {
    if (method == null) return '—';
    return _paymentMethodMeta[method]?['label'] ?? method;
  }

  Color _getPaymentMethodColor(String? method) {
    if (method == null) return const Color(0xFF8E8E93);
    return _paymentMethodMeta[method]?['color'] ?? const Color(0xFF8E8E93);
  }

  // ─── Type Helper Methods ──────────────────────────────────────────────────
  Color _getTypeColor(String type) {
    switch (type) {
      case 'sale': return const Color(0xFFEF4444);
      case 'payment': return const Color(0xFF10B981);
      case 'adjustment': return const Color(0xFF6366F1);
      default: return const Color(0xFFF59E0B);
    }
  }

  Color _getTypeBg(String type) {
    switch (type) {
      case 'sale': return const Color(0xFFFEF2F2);
      case 'payment': return const Color(0xFFECFDF5);
      case 'adjustment': return const Color(0xFFEEF2FF);
      default: return const Color(0xFFFFFBEB);
    }
  }

  String _getTypeLabel(String type, LanguageProvider lp) {
    switch (type) {
      case 'sale': return lp.isEnglish ? 'Sale' : 'فروخت';
      case 'payment': return lp.isEnglish ? 'Payment' : 'ادائیگی';
      case 'adjustment': return lp.isEnglish ? 'Adjustment' : 'ایڈجسٹمنٹ';
      default: return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  Map<String, dynamic> _extractLengthDataForItem(Map<String, dynamic> item) {
    String display = '';
    bool hasLengths = false;

    if (item['selected_lengths'] != null && item['selected_lengths'] is List) {
      final selectedLengths = List<String>.from(item['selected_lengths']);
      final lengthQuantities = item['length_quantities'] as Map<String, dynamic>? ?? {};

      List<String> parts = [];
      for (var length in selectedLengths) {
        int qty = 1;
        if (lengthQuantities.containsKey(length)) {
          final qtyValue = lengthQuantities[length];
          if (qtyValue != null) {
            if (qtyValue is int) {
              qty = qtyValue;
            } else if (qtyValue is double) {
              qty = qtyValue.toInt();
            } else if (qtyValue is String) {
              qty = int.tryParse(qtyValue) ?? 1;
            } else {
              qty = (qtyValue as num?)?.toInt() ?? 1;
            }
          }
        }
        if (qty > 1) {
          parts.add('$length×$qty');
        } else {
          parts.add(length);
        }
      }
      if (parts.isNotEmpty) {
        display = parts.join(', ');
        hasLengths = true;
      }
    }

    return {
      'display': display,
      'hasLengths': hasLengths,
    };
  }

  /// Total pieces from length_quantities
  int _getTotalPiecesFromItem(Map<String, dynamic> item) {
    if (item['selected_lengths'] == null || item['selected_lengths'] is! List) return 0;
    final selectedLengths = List<String>.from(item['selected_lengths']);
    final lengthQuantities = item['length_quantities'] as Map<String, dynamic>? ?? {};
    return selectedLengths.fold<int>(0, (sum, length) {
      final qtyValue = lengthQuantities[length];
      int qty = 1;
      if (qtyValue is int) qty = qtyValue;
      else if (qtyValue is double) qty = qtyValue.toInt();
      else if (qtyValue is String) qty = int.tryParse(qtyValue) ?? 1;
      return sum + qty;
    });
  }

  Future<void> _generatePdf(LanguageProvider lp, PdfType pdfType) async {
    final provider = Provider.of<CustomerLedgerProvider>(context, listen: false);

    if (provider.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lp.isEnglish ? 'No transactions to export' : 'ایکسپورٹ کرنے کے لیے کوئی لین دین نہیں'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      ),
    );

    try {
      final List<Map<String, dynamic>> typedEntries =
      provider.entries.map((e) => Map<String, dynamic>.from(e)).toList();

      final pdfData = await CustomerLedgerPdfGenerator.generateLedgerPdf(
        customerName: widget.customer.name,
        customerPhone: widget.customer.contact ?? '',
        customerAddress: widget.customer.address ?? '',
        summary: provider.summary ?? {},
        entries: typedEntries,
        filterType: _selectedFilter,
        dateRange: _dateRange,
        saleItemsCache: _saleItemsCache,
        languageProvider: lp,
        pdfType: pdfType,
        ledgerViewType: _ledgerViewType,
      );

      if (mounted) {
        Navigator.pop(context);

        final typeLabel = pdfType == PdfType.summary ? 'summary' : 'detailed';
        final viewLabel = _ledgerViewType == LedgerViewType.consolidated ? 'consolidated' : 'itemized';
        final fileName =
            'customer_ledger_${typeLabel}_${viewLabel}_${widget.customer.name.replaceAll(' ', '_')}_'
            '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        await Printing.sharePdf(bytes: pdfData, filename: fileName);
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lp.isEnglish ? 'Error generating PDF' : 'PDF بنانے میں خرابی'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPdfOptions(LanguageProvider lp) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lp.isEnglish ? 'Export PDF' : 'پی ڈی ایف ایکسپورٹ کریں',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lp.isEnglish ? 'Select PDF format:' : 'پی ڈی ایف فارمیٹ منتخب کریں:',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.summarize, color: Color(0xFF7C3AED)),
                ),
                title: Text(
                  lp.isEnglish ? 'Summary View' : 'خلاصہ ویو',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                subtitle: Text(
                  lp.isEnglish
                      ? 'Shows only invoice-wise entries without items'
                      : 'صرف انوائس کے مطابق اندراجات دکھاتا ہے، اشیاء کے بغیر',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _generatePdf(lp, PdfType.summary);
                },
              ),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: Color(0xFF7C3AED)),
                ),
                title: Text(
                  lp.isEnglish ? 'Detailed View' : 'تفصیلی ویو',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                subtitle: Text(
                  lp.isEnglish
                      ? 'Shows full invoice items expanded'
                      : 'مکمل انوائس اشیاء دکھاتا ہے',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _generatePdf(lp, PdfType.detailed);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final filterOptions = _getFilterOptions(languageProvider);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: _buildAppBar(languageProvider),
          body: Consumer<CustomerLedgerProvider>(
            builder: (context, provider, _) => Column(children: [
              _buildFiltersBar(languageProvider, filterOptions),
              _buildSummaryCards(provider, languageProvider),
              Expanded(child: _buildTableSection(provider, languageProvider)),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEntryDialog(languageProvider),
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(languageProvider.isEnglish ? 'Add Adjustment' : 'ایڈجسٹمنٹ شامل کریں'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(LanguageProvider lp) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.customer.name,
            style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold, fontSize: 17)),
        Text(_ledgerViewType == LedgerViewType.consolidated
            ? (lp.isEnglish ? 'Consolidated Ledger' : 'مجموعی لیجر')
            : (lp.isEnglish ? 'Itemized Ledger' : 'تفصیلی لیجر'),
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.normal)),
      ]),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          child: SegmentedButton<LedgerViewType>(
            segments: [
              ButtonSegment<LedgerViewType>(
                value: LedgerViewType.consolidated,
                label: Text(lp.isEnglish ? 'Consolidated' : 'مجموعی'),
                icon: const Icon(Icons.table_rows, size: 16),
              ),
              ButtonSegment<LedgerViewType>(
                value: LedgerViewType.itemized,
                label: Text(lp.isEnglish ? 'Itemized' : 'تفصیلی'),
                icon: const Icon(Icons.receipt_long, size: 16),
              ),
            ],
            selected: {_ledgerViewType},
            onSelectionChanged: (Set<LedgerViewType> newSelection) {
              final newType = newSelection.first;
              setState(() => _ledgerViewType = newType);
              // Auto-prefetch when switching to itemized
              if (newType == LedgerViewType.itemized) {
                final provider = Provider.of<CustomerLedgerProvider>(context, listen: false);
                _prefetchAllSaleItems(provider.entries);
              }
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF7C3AED);
                  }
                  return Colors.transparent;
                },
              ),
              foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFF3C3C43);
                },
              ),
              side: MaterialStateProperty.resolveWith<BorderSide?>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return const BorderSide(color: Color(0xFF7C3AED), width: 1);
                  }
                  return const BorderSide(color: Color(0xFFE5E5EA), width: 1);
                },
              ),
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              textStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF7C3AED)),
          onPressed: () => _showPdfOptions(lp),
          tooltip: lp.isEnglish ? 'Export to PDF' : 'PDF ایکسپورٹ کریں',
        ),
        IconButton(
          icon: const Icon(Icons.date_range_outlined, color: Color(0xFF7C3AED)),
          onPressed: _pickDateRange,
          tooltip: lp.isEnglish ? 'Select date range' : 'تاریخ کی حد منتخب کریں',
        ),
        if (_dateRange != null)
          IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFF8E8E93)),
            onPressed: () {
              setState(() => _dateRange = null);
              _loadLedger();
            },
            tooltip: lp.isEnglish ? 'Clear filter' : 'فلٹر صاف کریں',
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE5E5EA)),
      ),
    );
  }

  // ─── Filters Bar ────────────────────────────────────────────────────────────
  Widget _buildFiltersBar(LanguageProvider lp, List<Map<String, String>> filterOptions) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filterOptions.map((opt) {
              final selected = _selectedFilter == opt['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(opt['label']!,
                      style: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.white : const Color(0xFF3C3C43),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontFamily: lp.fontFamily)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedFilter = opt['value']!);
                    _loadLedger();
                  },
                  backgroundColor: const Color(0xFFF5F5F7),
                  selectedColor: const Color(0xFF7C3AED),
                  checkmarkColor: Colors.white,
                  side: BorderSide(color: selected ? const Color(0xFF7C3AED) : const Color(0xFFE5E5EA)),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        if (_dateRange != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.date_range, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text('${_dateFormat.format(_dateRange!.start)} – ${_dateFormat.format(_dateRange!.end)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ─── Summary Cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards(CustomerLedgerProvider provider, LanguageProvider lp) {
    final s = provider.summary;

    double totalDebit = 0;
    double totalCredit = 0;
    double currentBalance = 0;

    if (provider.entries.isNotEmpty) {
      for (var entry in provider.entries) {
        totalDebit += double.tryParse(entry['debit'].toString()) ?? 0;
        totalCredit += double.tryParse(entry['credit'].toString()) ?? 0;
      }
      currentBalance = double.tryParse(provider.entries.last['balance'].toString()) ?? 0;
    } else {
      totalDebit = s != null ? (double.tryParse(s['total_debit'].toString()) ?? 0) : 0;
      totalCredit = s != null ? (double.tryParse(s['total_credit'].toString()) ?? 0) : 0;
      currentBalance = s != null ? (double.tryParse(s['closing_balance'].toString()) ?? 0) : 0;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        _summaryCard(
            label: lp.isEnglish ? 'Total Sales' : 'کل فروخت',
            value: 'Rs ${_currencyFormat.format(totalDebit)}',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            lp: lp),
        const SizedBox(width: 10),
        _summaryCard(
            label: lp.isEnglish ? 'Total Payments' : 'کل ادائیگیاں',
            value: 'Rs ${_currencyFormat.format(totalCredit)}',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
            lp: lp),
        const SizedBox(width: 10),
        _summaryCard(
            label: lp.isEnglish ? 'Outstanding' : 'بقایا',
            value: 'Rs ${_currencyFormat.format(currentBalance)}',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            isBold: true,
            lp: lp),
      ]),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isBold = false,
    required LanguageProvider lp,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isBold ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFFE5E5EA),
              width: isBold ? 1.5 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500,
                        fontFamily: lp.fontFamily),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: isBold ? const Color(0xFF7C3AED) : const Color(0xFF1C1C1E),
                  fontFamily: lp.fontFamily),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ─── Table Section ──────────────────────────────────────────────────────────
  Widget _buildTableSection(CustomerLedgerProvider provider, LanguageProvider lp) {
    if (provider.isLoading && provider.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }
    if (!provider.isLoading && provider.entries.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(lp.isEnglish ? 'No transactions found' : 'کوئی لین دین نہیں ملا',
                style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500,
                    fontFamily: lp.fontFamily)),
            const SizedBox(height: 6),
            Text(lp.isEnglish ? 'Ledger entries will appear here' : 'لیجر اندراجات یہاں ظاہر ہوں گے',
                style: TextStyle(fontSize: 13, color: Colors.grey[400], fontFamily: lp.fontFamily)),
          ]));
    }

    return RefreshIndicator(
      onRefresh: _loadLedger,
      color: const Color(0xFF7C3AED),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                // Fixed Header - Now scrolls with the body using the same controller
                Container(
                  color: const Color(0xFFF5F5F7),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalScroll,
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: _buildTableHeaders(lp),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E5EA)),
                // Scrollable body with horizontal scroll sync
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalScroll,
                    scrollDirection: Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          // Build all rows as a single column
                          ...provider.entries.asMap().entries.map((entry) {
                            final index = entry.key;
                            final entryData = entry.value;
                            if (_ledgerViewType == LedgerViewType.itemized) {
                              return _buildItemizedRow(
                                entry: entryData,
                                index: index,
                                isEven: index % 2 == 0,
                                isLast: index == provider.entries.length - 1,
                                languageProvider: lp,
                              );
                            }
                            final isExpanded = _expandedEntryId == entryData['id'];
                            return _ExpandableRow(
                              key: ValueKey(entryData['id']),
                              entry: entryData,
                              isEven: index % 2 == 0,
                              isExpanded: isExpanded,
                              isLast: index == provider.entries.length - 1,
                              currencyFormat: _currencyFormat,
                              dateFormat: _dateFormat,
                              dateTimeFormat: _dateTimeFormat,
                              paymentMethodMeta: _paymentMethodMeta,
                              saleItems: entryData['transaction_type'] == 'sale' && entryData['reference_id'] != null
                                  ? _saleItemsCache[entryData['reference_id']]
                                  : null,
                              isLoadingItems: entryData['transaction_type'] == 'sale' && entryData['reference_id'] != null
                                  ? (_saleItemsLoading[entryData['reference_id']] ?? false)
                                  : false,
                              onTap: () => _toggleRow(entryData),
                              languageProvider: lp,
                              horizontalScrollController: _horizontalScroll,
                            );
                          }),
                          // Loading indicator at bottom
                          if (provider.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF7C3AED),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// ─── Column widths (wider for full data display) ────────────────────────────────
  static const double _iDate   = 100;
  static const double _iRef    = 120;
  static const double _iProd   = 200;
  static const double _iType   = 80;
  static const double _iQty    = 60;
  static const double _iWgt    = 80;
  static const double _iRate   = 100;
  static const double _iTotal  = 110;
  static const double _iMeth   = 100;
  static const double _iDebit  = 110;
  static const double _iCred   = 110;
  static const double _iBal    = 110;

  Widget _buildTableHeaders(LanguageProvider lp) {
    if (_ledgerViewType == LedgerViewType.itemized) {
      return IntrinsicWidth(
        child: Row(
          children: [
            _hCell(lp.isEnglish ? 'Date' : 'تاریخ', width: 100),
            _hCell(lp.isEnglish ? 'Ref #' : 'حوالہ', width: 120),
            _hCell(lp.isEnglish ? 'Product' : 'پروڈکٹ', width: 200),
            _hCell(lp.isEnglish ? 'Type' : 'قسم', width: 80),
            _hCell(lp.isEnglish ? 'Qty' : 'مقدار', width: 60, right: true),
            _hCell(lp.isEnglish ? 'Weight' : 'وزن', width: 80, right: true),
            _hCell(lp.isEnglish ? 'Rate' : 'ریٹ', width: 100, right: true),
            _hCell(lp.isEnglish ? 'Total' : 'کل', width: 110, right: true),
            _hCell(lp.isEnglish ? 'Method' : 'طریقہ', width: 100),
            _hCell(lp.isEnglish ? 'Debit' : 'ڈیبٹ', width: 110, right: true),
            _hCell(lp.isEnglish ? 'Credit' : 'کریڈٹ', width: 110, right: true),
            _hCell(lp.isEnglish ? 'Balance' : 'بیلنس', width: 110, right: true),
            const SizedBox(width: 8),
          ],
        ),
      );
    }
    // Consolidated headers
    return IntrinsicWidth(
      child: Row(
        children: [
          _hCell(lp.isEnglish ? 'Date' : 'تاریخ', width: 110),
          _hCell(lp.isEnglish ? 'Ref #' : 'حوالہ', width: 120),
          _hCell(lp.isEnglish ? 'Type' : 'قسم', width: 90),
          _hCell(lp.isEnglish ? 'Method' : 'طریقہ', width: 110),
          _hCell(lp.isEnglish ? 'Bank' : 'بینک', width: 140),
          _hCell(lp.isEnglish ? 'Description' : 'تفصیل', width: 250),
          _hCell(lp.isEnglish ? 'Debit' : 'ڈیبٹ', width: 110, right: true),
          _hCell(lp.isEnglish ? 'Credit' : 'کریڈٹ', width: 110, right: true),
          _hCell(lp.isEnglish ? 'Balance' : 'بیلنس', width: 110, right: true),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _hCell(String text, {double width = 60, bool right = false}) => SizedBox(
    width: width,
    child: Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.3)),
  );

  // ─── Itemized Row Builder ──────────────────────────────────────────────────
  Widget _buildItemizedRow({
    required Map<String, dynamic> entry,
    required int index,
    required bool isEven,
    required bool isLast,
    required LanguageProvider languageProvider,
  }) {
    final isSale = entry['transaction_type'] == 'sale';
    final referenceId = entry['reference_id'] as int?;
    final saleItems = referenceId != null ? _saleItemsCache[referenceId] : null;
    final isLoading = referenceId != null ? (_saleItemsLoading[referenceId] ?? false) : false;

    // Trigger fetch if not cached and not loading
    if (isSale && referenceId != null && saleItems == null && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchSaleItems(referenceId);
      });
    }

    // Loading state — show skeleton row
    if (isSale && referenceId != null && isLoading && saleItems == null) {
      return _buildItemizedLoadingRow(entry: entry, isEven: isEven, isLast: isLast, lp: languageProvider);
    }

    // Non-sale or sale without items yet
    if (!isSale || saleItems == null || saleItems.isEmpty) {
      return _buildItemizedSingleRow(
        entry: entry,
        isEven: isEven,
        isLast: isLast,
        lp: languageProvider,
        isSale: isSale,
      );
    }

    // Sale with items — show header + item rows
    final List<Widget> rows = [];
    rows.add(_buildItemizedSaleHeader(
      entry: entry,
      isEven: isEven,
      isLast: false,
      lp: languageProvider,
      itemCount: saleItems.length,
    ));
    for (int i = 0; i < saleItems.length; i++) {
      rows.add(_buildItemizedItemRow(
        item: saleItems[i],
        isEven: isEven,
        isLast: isLast && i == saleItems.length - 1,
        lp: languageProvider,
        itemIndex: i,
      ));
    }
    return Column(children: rows);
  }

  /// Skeleton row shown while items are loading
  Widget _buildItemizedLoadingRow({
    required Map<String, dynamic> entry,
    required bool isEven,
    required bool isLast,
    required LanguageProvider lp,
  }) {
    DateTime? txDate;
    try { txDate = DateTime.parse(entry['date']); } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFAFC),
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          _buildDataCell(txDate != null ? _dateFormat.format(txDate) : '—', width: _iDate, fontSize: 11),
          _buildDataCell(entry['reference_number'] ?? '—', width: _iRef, fontSize: 11,
              color: const Color(0xFF7C3AED), bold: true),
          SizedBox(
            width: _iProd,
            child: Row(children: [
              const SizedBox(width: 4),
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 6),
              Text(lp.isEnglish ? 'Loading…' : 'لوڈ ہو رہا ہے',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
            ]),
          ),
          const SizedBox(width: _iType + _iQty + _iWgt + _iRate + _iTotal + _iMeth + _iDebit + _iCred + _iBal + 8),
        ]),
      ),
    );
  }

  Widget _buildItemizedSaleHeader({
    required Map<String, dynamic> entry,
    required bool isEven,
    required bool isLast,
    required LanguageProvider lp,
    required int itemCount,
  }) {
    final debitValue = double.tryParse(entry['debit'].toString()) ?? 0.0;
    final creditValue = double.tryParse(entry['credit'].toString()) ?? 0.0;
    final balanceValue = double.tryParse(entry['balance'].toString()) ?? 0.0;
    final paymentMethod = entry['payment_method']?.toString();
    final refNum = entry['reference_number'] ?? '—';

    final balColor = balanceValue > 0
        ? const Color(0xFFEF4444)
        : balanceValue < 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93);

    final typeColor = _getTypeColor('sale');
    final typeBg = _getTypeBg('sale');
    final typeLabel = _getTypeLabel('sale', lp);
    final methodColor = _getPaymentMethodColor(paymentMethod);

    DateTime? txDate;
    try { txDate = DateTime.parse(entry['date']); } catch (_) {}

    final displayText =
        '${lp.isEnglish ? 'Sale' : 'فروخت'} ($itemCount ${lp.isEnglish ? 'items' : 'اشیاء'})';

    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFDF8FF) : const Color(0xFFF9F4FF),
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE0D4FB))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _buildDataCell(txDate != null ? _dateFormat.format(txDate) : '—',
              width: _iDate, fontSize: 11),
          _buildDataCell(refNum,
              width: _iRef, fontSize: 11, color: const Color(0xFF7C3AED), bold: true),
          SizedBox(
            width: _iProd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
                ),
                child: Text(displayText,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          _buildTypeBadge(typeLabel, typeColor, typeBg, width: _iType),
          _buildDataCell('', width: _iQty, fontSize: 11, align: TextAlign.right),
          _buildDataCell('', width: _iWgt, fontSize: 11, align: TextAlign.right),
          _buildDataCell('', width: _iRate, fontSize: 11, align: TextAlign.right),
          _buildDataCell('', width: _iTotal, fontSize: 11, align: TextAlign.right),
          _buildMethodBadge(_getPaymentMethodLabel(paymentMethod, lp), methodColor, width: _iMeth),
          _buildDataCell(
            debitValue > 0 ? 'Rs ${_currencyFormat.format(debitValue)}' : '—',
            width: _iDebit, fontSize: 11, align: TextAlign.right,
            color: debitValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF8E8E93),
            bold: debitValue > 0,
          ),
          _buildDataCell(
            creditValue > 0 ? 'Rs ${_currencyFormat.format(creditValue)}' : '—',
            width: _iCred, fontSize: 11, align: TextAlign.right,
            color: creditValue > 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93),
            bold: creditValue > 0,
          ),
          _buildDataCell(
            'Rs ${_currencyFormat.format(balanceValue)}',
            width: _iBal, fontSize: 11, align: TextAlign.right,
            color: balColor, bold: true,
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _buildItemizedSingleRow({
    required Map<String, dynamic> entry,
    required bool isEven,
    required bool isLast,
    required LanguageProvider lp,
    required bool isSale,
  }) {
    final debitValue = double.tryParse(entry['debit'].toString()) ?? 0.0;
    final creditValue = double.tryParse(entry['credit'].toString()) ?? 0.0;
    final balanceValue = double.tryParse(entry['balance'].toString()) ?? 0.0;
    final transactionType = entry['transaction_type'].toString();
    final paymentMethod = entry['payment_method']?.toString();
    final refNum = entry['reference_number'] ?? '—';

    final balColor = balanceValue > 0
        ? const Color(0xFFEF4444)
        : balanceValue < 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93);

    final typeColor = _getTypeColor(transactionType);
    final typeBg = _getTypeBg(transactionType);
    final typeLabel = _getTypeLabel(transactionType, lp);
    final methodColor = _getPaymentMethodColor(paymentMethod);

    DateTime? txDate;
    try { txDate = DateTime.parse(entry['date']); } catch (_) {}

    final displayText = entry['description'] ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFAFC),
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _buildDataCell(txDate != null ? _dateFormat.format(txDate) : '—',
              width: _iDate, fontSize: 11),
          _buildDataCell(refNum,
              width: _iRef, fontSize: 11, color: const Color(0xFF7C3AED), bold: true),
          _buildDataCell(displayText,
              width: _iProd, fontSize: 11),
          _buildTypeBadge(typeLabel, typeColor, typeBg, width: _iType),
          _buildDataCell('—', width: _iQty, fontSize: 11, align: TextAlign.right, color: const Color(0xFF8E8E93)),
          _buildDataCell('—', width: _iWgt, fontSize: 11, align: TextAlign.right, color: const Color(0xFF8E8E93)),
          _buildDataCell('—', width: _iRate, fontSize: 11, align: TextAlign.right, color: const Color(0xFF8E8E93)),
          _buildDataCell('—', width: _iTotal, fontSize: 11, align: TextAlign.right, color: const Color(0xFF8E8E93)),
          _buildMethodBadge(_getPaymentMethodLabel(paymentMethod, lp), methodColor, width: _iMeth),
          _buildDataCell(
            debitValue > 0 ? 'Rs ${_currencyFormat.format(debitValue)}' : '—',
            width: _iDebit, fontSize: 11, align: TextAlign.right,
            color: debitValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF8E8E93),
            bold: debitValue > 0,
          ),
          _buildDataCell(
            creditValue > 0 ? 'Rs ${_currencyFormat.format(creditValue)}' : '—',
            width: _iCred, fontSize: 11, align: TextAlign.right,
            color: creditValue > 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93),
            bold: creditValue > 0,
          ),
          _buildDataCell(
            'Rs ${_currencyFormat.format(balanceValue)}',
            width: _iBal, fontSize: 11, align: TextAlign.right,
            color: balColor, bold: true,
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _buildItemizedItemRow({
    required Map<String, dynamic> item,
    required bool isEven,
    required bool isLast,
    required LanguageProvider lp,
    required int itemIndex,
  }) {
    final productName = item['product_name'] as String? ?? 'Unknown';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
    final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;

    final isSarya = weight > 0 && quantity == 0;
    final lengthData = _extractLengthDataForItem(item);
    final hasLengths = lengthData['hasLengths'] as bool;
    final lengthsDisplay = lengthData['display'] as String;
    final totalPieces = hasLengths ? _getTotalPiecesFromItem(item) : 0;

    final String qtyDisplay = isSarya
        ? '—'
        : hasLengths
        ? (totalPieces > 0 ? '$totalPieces' : '$quantity')
        : '$quantity';

    final String weightDisplay = weight > 0 ? '${weight.toStringAsFixed(2)} kg' : '—';

    final Color itemBg = itemIndex % 2 == 0
        ? const Color(0xFFF5F3FF)
        : const Color(0xFFEDE9FE);

    return Container(
      decoration: BoxDecoration(
        color: itemBg,
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          _buildDataCell('', width: _iDate, fontSize: 11),
          _buildDataCell('', width: _iRef, fontSize: 11),
          SizedBox(
            width: _iProd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Container(
                  width: 3, height: 28,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(productName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
                    if (hasLengths)
                      Text(lengthsDisplay,
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF3B82F6), fontStyle: FontStyle.italic)),
                    if (isSarya)
                      Text('${lp.isEnglish ? 'Sarya' : 'سریا'} • ${weight.toStringAsFixed(2)} kg',
                          style: const TextStyle(fontSize: 9, color: Color(0xFF1D4ED8))),
                  ]),
                ),
              ]),
            ),
          ),
          _buildTypeBadge(lp.isEnglish ? 'ITEM' : 'آئٹم', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), width: _iType),
          _buildDataCell(qtyDisplay,
              width: _iQty, fontSize: 11, align: TextAlign.right,
              color: const Color(0xFF6366F1), bold: true),
          _buildDataCell(weightDisplay,
              width: _iWgt, fontSize: 10, align: TextAlign.right,
              color: isSarya ? const Color(0xFF1D4ED8) : const Color(0xFF8E8E93)),
          _buildDataCell('Rs ${_currencyFormat.format(unitPrice)}',
              width: _iRate, fontSize: 11, align: TextAlign.right,
              color: const Color(0xFF3C3C43)),
          _buildDataCell('Rs ${_currencyFormat.format(totalPrice)}',
              width: _iTotal, fontSize: 11, align: TextAlign.right,
              color: const Color(0xFF10B981), bold: true),
          _buildDataCell('', width: _iMeth, fontSize: 11),
          _buildDataCell('', width: _iDebit, fontSize: 11),
          _buildDataCell('', width: _iCred, fontSize: 11),
          _buildDataCell('', width: _iBal, fontSize: 11),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _buildDataCell(String text, {
    double width = 60,
    double fontSize = 12,
    TextAlign align = TextAlign.left,
    Color color = const Color(0xFF1C1C1E),
    bool bold = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: color,
            fontFamily: widget.languageProvider.fontFamily,
          ),
          // Removed maxLines and overflow - show full text
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String label, Color color, Color bg, {double width = 60}) {
    return SizedBox(
      width: width,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
            fontFamily: widget.languageProvider.fontFamily,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMethodBadge(String label, Color color, {double width = 60}) {
    if (label == '—') {
      return SizedBox(
        width: width,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500, fontFamily: widget.languageProvider.fontFamily),
              overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return SizedBox(
      width: width,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600,
                fontFamily: widget.languageProvider.fontFamily),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  // ─── Date Picker ────────────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context)
            .copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadLedger();
    }
  }

  // ─── Add Adjustment Dialog ──────────────────────────────────────────────────
  Future<void> _showAddEntryDialog(LanguageProvider lp) async {
    final descCtrl  = TextEditingController();
    final debitCtrl = TextEditingController(text: '0');
    final creditCtrl = TextEditingController(text: '0');
    final refCtrl   = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text(lp.isEnglish ? 'Add Manual Adjustment' : 'دستی ایڈجسٹمنٹ شامل کریں',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dlgField(ctrl: descCtrl,
                  label: lp.isEnglish ? 'Description *' : 'تفصیل *',
                  hint: lp.isEnglish ? 'e.g. Opening balance adjustment' : 'مثال: ابتدائی بیلنس ایڈجسٹمنٹ',
                  lp: lp),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _dlgField(ctrl: debitCtrl,
                        label: lp.isEnglish ? 'Debit (Customer Owes)' : 'ڈیبٹ (کسٹمر کا قرض)',
                        hint: '0.00', num: true, lp: lp)),
                const SizedBox(width: 12),
                Expanded(
                    child: _dlgField(ctrl: creditCtrl,
                        label: lp.isEnglish ? 'Credit (Payment)' : 'کریڈٹ (ادائیگی)',
                        hint: '0.00', num: true, lp: lp)),
              ]),
              const SizedBox(height: 12),
              _dlgField(ctrl: refCtrl,
                  label: lp.isEnglish ? 'Reference # (optional)' : 'حوالہ نمبر (اختیاری)',
                  hint: lp.isEnglish ? 'e.g. ADJ-001' : 'مثال: ADJ-001', lp: lp),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
                        child: child!,
                      ));
                  if (p != null) setDlg(() => selectedDate = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E5EA))),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text('${lp.isEnglish ? 'Date' : 'تاریخ'}: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                        style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں',
                    style: const TextStyle(color: Color(0xFF8E8E93)))),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lp.isEnglish ? 'Description is required' : 'تفصیل ضروری ہے'),
                      backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx);
                final provider = Provider.of<CustomerLedgerProvider>(context, listen: false);
                final result = await provider.addAdjustment(
                  customerId: widget.customer.id!,
                  description: descCtrl.text.trim(),
                  debit: double.tryParse(debitCtrl.text) ?? 0,
                  credit: double.tryParse(creditCtrl.text) ?? 0,
                  date: selectedDate,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result['message']),
                      backgroundColor: result['success'] ? Colors.green : Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(lp.isEnglish ? 'Save' : 'محفوظ کریں',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    descCtrl.dispose();
    debitCtrl.dispose();
    creditCtrl.dispose();
    refCtrl.dispose();
  }

  Widget _dlgField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    bool num = false,
    required LanguageProvider lp,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(fontSize: 14, fontFamily: lp.fontFamily),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
        ),
      ),
    ]);
  }
}

// ─── Expandable Row (Consolidated View) — UNCHANGED ──────────────────────────
class _ExpandableRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isEven, isExpanded, isLast, isLoadingItems;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat, dateTimeFormat;
  final Map<String, Map<String, dynamic>> paymentMethodMeta;
  final List<Map<String, dynamic>>? saleItems;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;
  final ScrollController horizontalScrollController;

  const _ExpandableRow({
    super.key,
    required this.entry,
    required this.isEven,
    required this.isExpanded,
    required this.isLast,
    required this.currencyFormat,
    required this.dateFormat,
    required this.dateTimeFormat,
    required this.paymentMethodMeta,
    required this.onTap,
    required this.languageProvider,
    required this.horizontalScrollController,
    this.saleItems,
    this.isLoadingItems = false,
  });

  List<String> _parseDynamicList(dynamic val) {
    if (val is String) {
      try { return List<String>.from(jsonDecode(val)); } catch (_) { return []; }
    }
    if (val is List) return val.cast<String>();
    return [];
  }

  Map<String, int> _parseLengthQuantities(dynamic val) {
    if (val == null) return {};
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) {
          return Map<String, int>.from(decoded.map((k, v) => MapEntry(k.toString(), _toInt(v))));
        }
      } catch (_) {}
      return {};
    }
    if (val is Map) {
      return Map<String, int>.from(val.map((k, v) => MapEntry(k.toString(), _toInt(v))));
    }
    return {};
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  String _safeLengthLabel(String length, int qty) {
    const fsi = '\u2068';
    const pdi = '\u2069';
    return '$fsi$length$pdi × $qty';
  }

  String _getPaymentMethodLabel(String? method) {
    if (method == null) return '—';
    return paymentMethodMeta[method]?['label'] ?? method;
  }

  Color _getPaymentMethodColor(String? method) {
    if (method == null) return const Color(0xFF8E8E93);
    return paymentMethodMeta[method]?['color'] ?? const Color(0xFF8E8E93);
  }

  String _getBankName() {
    if (entry['payment_method'] == null) return '—';
    final bankName = entry['bank_name']?.toString();
    if (bankName != null && bankName.isNotEmpty) return bankName;
    return '—';
  }

  Bank? _getBankByName(String? bankName) {
    if (bankName == null || bankName.isEmpty) return null;
    try {
      return pakistaniBanks.firstWhere(
            (bank) => bank.name.toLowerCase() == bankName.toLowerCase(),
        orElse: () => pakistaniBanks.firstWhere(
              (bank) => bankName.toLowerCase().contains(bank.name.toLowerCase()),
          orElse: () => Bank(name: bankName, iconPath: ''),
        ),
      );
    } catch (_) { return null; }
  }

  Widget _buildBankWidget(Color color) {
    final bankName = _getBankName();
    final bank = _getBankByName(bankName);

    if (bank != null && bank.iconPath.isNotEmpty && bankName != '—') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(bank.iconPath, width: 20, height: 20, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.account_balance, size: 16, color: color)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(bankName,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500,
                      fontFamily: languageProvider.fontFamily),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }
    return Text(bankName,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500,
            fontFamily: languageProvider.fontFamily),
        overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    final debitValue = double.tryParse(entry['debit'].toString()) ?? 0.0;
    final creditValue = double.tryParse(entry['credit'].toString()) ?? 0.0;
    final balanceValue = double.tryParse(entry['balance'].toString()) ?? 0.0;
    final transactionType = entry['transaction_type'].toString();
    final paymentMethod = entry['payment_method']?.toString();

    Color typeColor; Color typeBg; IconData typeIcon; String typeLabel;
    switch (transactionType) {
      case 'sale':
        typeColor = const Color(0xFFEF4444); typeBg = const Color(0xFFFEF2F2);
        typeIcon = Icons.shopping_cart_outlined; typeLabel = languageProvider.isEnglish ? 'Sale' : 'فروخت';
        break;
      case 'payment':
        typeColor = const Color(0xFF10B981); typeBg = const Color(0xFFECFDF5);
        typeIcon = Icons.payments_outlined; typeLabel = languageProvider.isEnglish ? 'Payment' : 'ادائیگی';
        break;
      case 'adjustment':
        typeColor = const Color(0xFF6366F1); typeBg = const Color(0xFFEEF2FF);
        typeIcon = Icons.edit_note_outlined; typeLabel = languageProvider.isEnglish ? 'Adjustment' : 'ایڈجسٹمنٹ';
        break;
      default:
        typeColor = const Color(0xFFF59E0B); typeBg = const Color(0xFFFFFBEB);
        typeIcon = Icons.info_outline; typeLabel = transactionType.replaceAll('_', ' ').toUpperCase();
    }

    final balColor = balanceValue > 0
        ? const Color(0xFFEF4444)
        : balanceValue < 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isExpanded ? const Color(0xFFF5F3FF) : isEven ? Colors.white : const Color(0xFFFAFAFC),
        border: isLast && !isExpanded ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _buildDataCell(dateFormat.format(DateTime.parse(entry['date'])), width: 90, fontSize: 11),
                _buildDataCell(entry['reference_number'] ?? '—', width: 80, fontSize: 11,
                    color: const Color(0xFF7C3AED), bold: true),
                _buildTypeBadge(typeLabel, typeColor, typeBg, width: 75),
                _buildMethodBadge(_getPaymentMethodLabel(paymentMethod),
                    _getPaymentMethodColor(paymentMethod), width: 80),
                SizedBox(width: 90, child: _buildBankWidget(_getPaymentMethodColor(paymentMethod))),
                _buildDataCell(entry['description'] ?? '—', width: 120, fontSize: 11, maxLines: 1),
                _buildDataCell(debitValue > 0 ? 'Rs ${currencyFormat.format(debitValue)}' : '—',
                    width: 85, fontSize: 11, align: TextAlign.right,
                    color: debitValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF8E8E93),
                    bold: debitValue > 0),
                _buildDataCell(creditValue > 0 ? 'Rs ${currencyFormat.format(creditValue)}' : '—',
                    width: 85, fontSize: 11, align: TextAlign.right,
                    color: creditValue > 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93),
                    bold: creditValue > 0),
                _buildDataCell('Rs ${currencyFormat.format(balanceValue)}',
                    width: 90, fontSize: 11, align: TextAlign.right, color: balColor, bold: true),
                const SizedBox(width: 8),
                AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, size: 18,
                        color: isExpanded ? const Color(0xFF7C3AED) : const Color(0xFF8E8E93))),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildDetailPanel(
              typeColor, typeBg, typeIcon, typeLabel, debitValue, creditValue, balanceValue),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  Widget _buildDataCell(String text, {
    double width = 60, double fontSize = 12,
    TextAlign align = TextAlign.left, Color color = const Color(0xFF1C1C1E),
    bool bold = false, int maxLines = 2,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text, textAlign: align,
            style: TextStyle(fontSize: fontSize,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color, fontFamily: languageProvider.fontFamily),
            maxLines: maxLines, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildTypeBadge(String label, Color color, Color bg, {double width = 60}) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600,
                fontFamily: languageProvider.fontFamily),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildMethodBadge(String label, Color color, {double width = 60}) {
    if (label == '—') {
      return SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(6)),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500,
                  fontFamily: languageProvider.fontFamily),
              overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600,
                fontFamily: languageProvider.fontFamily),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _getBankLogo(String bankName, Color color, {double size = 24}) {
    final bank = _getBankByName(bankName);
    if (bank != null && bank.iconPath.isNotEmpty) {
      return Image.asset(bank.iconPath, width: size, height: size, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: size, height: size,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.account_balance, size: size * 0.6, color: color),
          ));
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.account_balance, size: size * 0.6, color: color),
    );
  }

  String _methodLabel(String method) {
    if (languageProvider.isEnglish) {
      const labels = {'cash': 'Cash', 'bank': 'Bank Transfer', 'cheque': 'Cheque', 'slip': 'Pay Slip'};
      return labels[method] ?? method;
    } else {
      const labels = {'cash': 'نقد', 'bank': 'بینک ٹرانسفر', 'cheque': 'چیک', 'slip': 'پے سلیپ'};
      return labels[method] ?? method;
    }
  }

  Widget _infoChip({required IconData icon, required String label,
    required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 13, color: color.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _buildPaymentMethodSection(Color typeColor) {
    final method    = entry['payment_method']?.toString();
    final bankName  = entry['bank_name']?.toString();
    final chequeNum = entry['cheque_number']?.toString();
    final chequeDate = entry['cheque_date']?.toString();

    if (method == null) return const SizedBox.shrink();

    final meta  = paymentMethodMeta[method] ?? paymentMethodMeta['cash']!;
    final color = meta['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 16,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(meta['icon'] as IconData, size: 15, color: color),
          const SizedBox(width: 6),
          Text(languageProvider.isEnglish ? 'Payment Method Details' : 'ادائیگی کے طریقے کی تفصیلات',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color,
                  fontFamily: languageProvider.fontFamily)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(meta['icon'] as IconData, size: 12, color: color),
              const SizedBox(width: 5),
              Text(_methodLabel(method), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: color, letterSpacing: 0.3, fontFamily: languageProvider.fontFamily)),
            ]),
          ),
          if (bankName != null && bankName.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2))),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(6),
                      child: _getBankLogo(bankName, color, size: 24)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(languageProvider.isEnglish ? 'Bank' : 'بینک',
                        style: TextStyle(fontSize: 10, color: color.withOpacity(0.7),
                            fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily)),
                    Text(bankName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ),
            ),
          ],
        ]),
        if (chequeNum != null && chequeNum.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoChip(icon: Icons.receipt_long_outlined,
                label: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
                value: chequeNum, color: color)),
            if (chequeDate != null) ...[
              const SizedBox(width: 8),
              Expanded(child: _infoChip(icon: Icons.event_outlined,
                  label: languageProvider.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ',
                  value: chequeDate, color: color)),
            ],
          ]),
          const SizedBox(height: 8),
          _infoChip(
            icon: entry['cheque_cleared'] == true ? Icons.check_circle : Icons.pending,
            label: languageProvider.isEnglish ? 'Cheque Status' : 'چیک کی حالت',
            value: entry['cheque_cleared'] == true
                ? (languageProvider.isEnglish ? 'Cleared' : 'کلیئر شدہ')
                : (languageProvider.isEnglish ? 'Pending' : 'زیر التواء'),
            color: entry['cheque_cleared'] == true ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
        ],
      ]),
    );
  }

  Widget _buildDetailPanel(Color typeColor, Color typeBg, IconData typeIcon, String typeLabel,
      double debitValue, double creditValue, double balanceValue) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: typeBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Icon(typeIcon, size: 16, color: typeColor),
            const SizedBox(width: 8),
            Text(languageProvider.isEnglish ? 'Transaction Details' : 'لین دین کی تفصیلات',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: typeColor,
                    fontFamily: languageProvider.fontFamily)),
            const Spacer(),
            Text('ID #${entry['id']}',
                style: TextStyle(fontSize: 11, color: typeColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500, fontFamily: languageProvider.fontFamily)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _detailItem(icon: Icons.calendar_today_outlined,
                  label: languageProvider.isEnglish ? 'Transaction Date' : 'لین دین کی تاریخ',
                  value: dateTimeFormat.format(DateTime.parse(entry['date'])))),
              const SizedBox(width: 16),
              Expanded(child: _detailItem(icon: Icons.access_time_outlined,
                  label: languageProvider.isEnglish ? 'Recorded On' : 'ریکارڈ شدہ',
                  value: dateTimeFormat.format(DateTime.parse(entry['created_at'])))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _detailItem(icon: Icons.tag_outlined,
                  label: languageProvider.isEnglish ? 'Reference Number' : 'حوالہ نمبر',
                  value: entry['reference_number'] ?? 'N/A')),
              const SizedBox(width: 16),
              Expanded(child: _detailItem(icon: Icons.category_outlined,
                  label: languageProvider.isEnglish ? 'Transaction Type' : 'لین دین کی قسم',
                  value: typeLabel, valueColor: typeColor)),
            ]),
            const SizedBox(height: 12),
            _detailItem(icon: Icons.notes_outlined,
                label: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                value: entry['description'] ?? (languageProvider.isEnglish
                    ? 'No description provided' : 'کوئی تفصیل فراہم نہیں کی گئی')),
            const SizedBox(height: 12),
            if (entry['transaction_type'] == 'payment') ...[
              _buildPaymentMethodSection(typeColor),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(child: _amountCell(
                    label: languageProvider.isEnglish ? 'Debit (Owes)' : 'ڈیبٹ (قرض)',
                    value: debitValue > 0 ? 'Rs ${currencyFormat.format(debitValue)}' : '—',
                    color: const Color(0xFFEF4444))),
                Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
                Expanded(child: _amountCell(
                    label: languageProvider.isEnglish ? 'Credit (Paid)' : 'کریڈٹ (ادا شدہ)',
                    value: creditValue > 0 ? 'Rs ${currencyFormat.format(creditValue)}' : '—',
                    color: const Color(0xFF10B981))),
                Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
                Expanded(child: _amountCell(
                    label: languageProvider.isEnglish ? 'Running Balance' : 'چلتا بیلنس',
                    value: 'Rs ${currencyFormat.format(balanceValue)}',
                    color: balanceValue > 0 ? const Color(0xFFEF4444)
                        : balanceValue < 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93),
                    bold: true)),
              ]),
            ),
            if (entry['transaction_type'] == 'sale') ...[
              const SizedBox(height: 14),
              _buildSaleItemsSection(),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildLengthChips(Map<String, dynamic> item) {
    final lengths    = _parseDynamicList(item['selected_lengths']);
    final quantities = _parseLengthQuantities(item['length_quantities']);
    if (lengths.isEmpty) return const SizedBox.shrink();

    final totalPieces = lengths.fold<int>(0, (sum, l) => sum + (quantities[l] ?? 1));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(languageProvider.isEnglish ? 'Length Breakdown' : 'لمبائی کی تفصیل',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
            if (totalPieces > 0)
              Text(languageProvider.isEnglish ? '$totalPieces pcs' : '$totalPieces ٹکڑے',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[700])),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: lengths.map((length) {
              final qty = quantities[length] ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(_safeLengthLabel(length, qty),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
              );
            }).toList(),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildSaleItemsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(languageProvider.isEnglish ? 'Sale Items' : 'فروخت کی اشیاء',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
        const Spacer(),
        if (isLoadingItems)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
      ]),
      const SizedBox(height: 10),
      if (isLoadingItems && saleItems == null)
        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2)))
      else if (saleItems == null || saleItems!.isEmpty)
        Container(padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center,
            child: Text(languageProvider.isEnglish ? 'No items found' : 'کوئی اشیاء نہیں ملی',
                style: TextStyle(fontSize: 13, color: Colors.grey[400],
                    fontFamily: languageProvider.fontFamily)))
      else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15))),
            child: Row(children: [
              Expanded(flex: 5, child: Text(languageProvider.isEnglish ? 'PRODUCT' : 'پروڈکٹ',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED), letterSpacing: 0.4))),
              Expanded(flex: 2, child: Text(languageProvider.isEnglish ? 'QTY' : 'مقدار',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED), letterSpacing: 0.4))),
              Expanded(flex: 3, child: Text(languageProvider.isEnglish ? 'PRICE' : 'قیمت',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED), letterSpacing: 0.4))),
              Expanded(flex: 3, child: Text(languageProvider.isEnglish ? 'TOTAL' : 'کل',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED), letterSpacing: 0.4))),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Column(
              children: saleItems!.asMap().entries.map((e) {
                final i    = e.key;
                final item = e.value;
                final qty   = (item['quantity'] as num?)?.toInt() ?? 0;
                final price = item['unit_price'] as double? ?? 0.0;
                final total = item['total_price'] as double? ?? (qty * price);
                final isLast = i == saleItems!.length - 1;

                final lengths    = _parseDynamicList(item['selected_lengths']);
                final hasLengths = lengths.isNotEmpty;
                final quantities = _parseLengthQuantities(item['length_quantities']);
                final totalPieces = hasLengths
                    ? lengths.fold<int>(0, (sum, l) => sum + (quantities[l] ?? 1))
                    : 0;
                final weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0.0;

                return Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFC),
                        border: isLast && !hasLengths
                            ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5)))),
                    child: Row(children: [
                      Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['product_name'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
                        if (item['barcode'] != null)
                          Text('${languageProvider.isEnglish ? 'Barcode' : 'بارکوڈ'}: ${item['barcode']}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                        if (hasLengths && item['selected_lengths_display'] != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.straighten, size: 11, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Expanded(child: Directionality(textDirection: TextDirection.ltr,
                                child: Text(item['selected_lengths_display']!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED),
                                        fontStyle: FontStyle.italic),
                                    maxLines: 2, overflow: TextOverflow.ellipsis))),
                          ]),
                        ],
                        if (hasLengths && totalPieces > 0) ...[
                          const SizedBox(height: 2),
                          Text(languageProvider.isEnglish ? '$totalPieces pcs total' : 'کل $totalPieces ٹکڑے',
                              style: TextStyle(fontSize: 11, color: Colors.teal[700], fontWeight: FontWeight.w500)),
                        ],
                        if (weight > 0 && !hasLengths)
                          Text('${languageProvider.isEnglish ? 'Weight' : 'وزن'}: ${weight.toStringAsFixed(2)} Kg',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8))),
                      ])),
                      Expanded(flex: 2, child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                          child: Text('$qty', textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))))),
                      Expanded(flex: 3, child: Text('Rs ${currencyFormat.format(price)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF3C3C43)))),
                      Expanded(flex: 3, child: Text('Rs ${currencyFormat.format(total)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)))),
                    ]),
                  ),
                  if (hasLengths)
                    Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _buildLengthChips(item)),
                ]);
              }).toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2))),
            child: Row(children: [
              const Expanded(child: Text('Total',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)))),
              Text('Rs ${currencyFormat.format(saleItems!.fold<double>(0, (s, item) => s + (item['total_price'] as double? ?? 0.0)))}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
            ]),
          ),
        ],
    ]);
  }

  Widget _detailItem({required IconData icon, required String label,
    required String value, Color? valueColor}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: const Color(0xFF8E8E93)),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: const Color(0xFF8E8E93),
            fontWeight: FontWeight.w500, fontFamily: languageProvider.fontFamily)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13,
            color: valueColor ?? const Color(0xFF1C1C1E),
            fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.w500,
            fontFamily: languageProvider.fontFamily)),
      ])),
    ]);
  }

  Widget _amountCell({required String label, required String value,
    required Color color, bool bold = false}) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: const Color(0xFF8E8E93),
          fontWeight: FontWeight.w500, fontFamily: languageProvider.fontFamily)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color,
          fontFamily: languageProvider.fontFamily)),
    ]);
  }
}