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

// Update the CustomerLedgerScreen class definition at the top of the file:

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
  final _currencyFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _dateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;
  int? _expandedEntryId;

  final Map<int, List<Map<String, dynamic>>> _saleItemsCache = {};
  final Map<int, bool> _saleItemsLoading = {};

  // Payment method meta (same as supplier ledger for consistency)
  static const Map<String, Map<String, dynamic>> _paymentMethodMeta = {
    'cash': {'label': 'Cash', 'icon': Icons.payments_outlined, 'color': Color(0xFF10B981)},
    'bank': {'label': 'Bank', 'icon': Icons.account_balance_outlined, 'color': Color(0xFF3B82F6)},
    'cheque': {'label': 'Cheque', 'icon': Icons.receipt_long_outlined, 'color': Color(0xFFF59E0B)},
    'slip': {'label': 'Slip', 'icon': Icons.receipt_outlined, 'color': Color(0xFF8B5CF6)},
  };

  // Filter options with bilingual labels
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
    setState(() => _saleItemsLoading[saleId] = true);
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

  Future<void> _generatePdf(LanguageProvider lp) async {
    final provider = Provider.of<CustomerLedgerProvider>(context, listen: false);

    if (provider.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lp.isEnglish ? 'No transactions to export' : 'ایکسپورٹ کرنے کے لیے کوئی لین دین نہیں'), backgroundColor: Colors.orange),
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
      );

      if (mounted) {
        Navigator.pop(context);
        final fileName =
            'customer_ledger_${widget.customer.name.replaceAll(' ', '_')}_'
            '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
        await Printing.sharePdf(bytes: pdfData, filename: fileName);
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lp.isEnglish ? 'Error generating PDF' : 'PDF بنانے میں خرابی'}: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        Text(lp.isEnglish ? 'Customer Ledger' : 'کسٹمر لیجر',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.normal)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF7C3AED)),
          onPressed: () => _generatePdf(lp),
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
            child: Column(children: [
              _buildTableHeader(lp),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              Expanded(
                child: ListView.builder(
                  controller: _verticalScroll,
                  itemCount: provider.entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == provider.entries.length) {
                      return provider.isLoading
                          ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF7C3AED), strokeWidth: 2)))
                          : const SizedBox(height: 16);
                    }
                    final entry = provider.entries[index];
                    final isExpanded = _expandedEntryId == entry['id'];
                    return _ExpandableRow(
                      key: ValueKey(entry['id']),
                      entry: entry,
                      isEven: index % 2 == 0,
                      isExpanded: isExpanded,
                      isLast: index == provider.entries.length - 1,
                      currencyFormat: _currencyFormat,
                      dateFormat: _dateFormat,
                      dateTimeFormat: _dateTimeFormat,
                      paymentMethodMeta: _paymentMethodMeta,
                      saleItems: entry['transaction_type'] == 'sale' && entry['reference_id'] != null
                          ? _saleItemsCache[entry['reference_id']]
                          : null,
                      isLoadingItems: entry['transaction_type'] == 'sale' && entry['reference_id'] != null
                          ? (_saleItemsLoading[entry['reference_id']] ?? false)
                          : false,
                      onTap: () => _toggleRow(entry),
                      languageProvider: lp,
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(LanguageProvider lp) {
    return Container(
      color: const Color(0xFFF5F5F7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        _hCell(lp.isEnglish ? 'DATE' : 'تاریخ', flex: 2),
        _hCell(lp.isEnglish ? 'REF #' : 'حوالہ نمبر', flex: 2),
        _hCell(lp.isEnglish ? 'TYPE' : 'قسم', flex: 1),
        _hCell(lp.isEnglish ? 'METHOD' : 'طریقہ', flex: 1),
        _hCell(lp.isEnglish ? 'BANK' : 'بینک', flex: 2),
        _hCell(lp.isEnglish ? 'DESCRIPTION' : 'تفصیل', flex: 3),
        _hCell(lp.isEnglish ? 'DEBIT' : 'ڈیبٹ', flex: 2, right: true),
        _hCell(lp.isEnglish ? 'CREDIT' : 'کریڈٹ', flex: 2, right: true),
        _hCell(lp.isEnglish ? 'BALANCE' : 'بیلنس', flex: 2, right: true),
        const SizedBox(width: 24),
      ]),
    );
  }

  Widget _hCell(String text, {int flex = 1, bool right = false}) => Expanded(
    flex: flex,
    child: Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.5)),
  );

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

  Future<void> _showAddEntryDialog(LanguageProvider lp) async {
    final descCtrl = TextEditingController();
    final debitCtrl = TextEditingController(text: '0');
    final creditCtrl = TextEditingController(text: '0');
    final refCtrl = TextEditingController();
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
              _dlgField(
                  ctrl: descCtrl,
                  label: lp.isEnglish ? 'Description *' : 'تفصیل *',
                  hint: lp.isEnglish ? 'e.g. Opening balance adjustment' : 'مثال: ابتدائی بیلنس ایڈجسٹمنٹ',
                  lp: lp),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _dlgField(
                        ctrl: debitCtrl,
                        label: lp.isEnglish ? 'Debit (Customer Owes)' : 'ڈیبٹ (کسٹمر کا قرض)',
                        hint: '0.00',
                        num: true,
                        lp: lp)),
                const SizedBox(width: 12),
                Expanded(
                    child: _dlgField(
                        ctrl: creditCtrl,
                        label: lp.isEnglish ? 'Credit (Payment)' : 'کریڈٹ (ادائیگی)',
                        hint: '0.00',
                        num: true,
                        lp: lp)),
              ]),
              const SizedBox(height: 12),
              _dlgField(ctrl: refCtrl,
                  label: lp.isEnglish ? 'Reference # (optional)' : 'حوالہ نمبر (اختیاری)',
                  hint: lp.isEnglish ? 'e.g. ADJ-001' : 'مثال: ADJ-001',
                  lp: lp),
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
                            colorScheme:
                            const ColorScheme.light(primary: Color(0xFF7C3AED))),
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
          style: TextStyle(fontSize: 12, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
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

// ─── Expandable Row (Updated to match supplier ledger design) ────────────────────────────────────────────────────────

class _ExpandableRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isEven, isExpanded, isLast, isLoadingItems;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat, dateTimeFormat;
  final Map<String, Map<String, dynamic>> paymentMethodMeta;
  final List<Map<String, dynamic>>? saleItems;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

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
    this.saleItems,
    this.isLoadingItems = false,
  });

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
    } catch (_) {
      return null;
    }
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
              child: Image.asset(
                bank.iconPath,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.account_balance,
                  size: 20,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                bankName,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontFamily: languageProvider.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      bankName,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
        fontFamily: languageProvider.fontFamily,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final debitValue = double.tryParse(entry['debit'].toString()) ?? 0.0;
    final creditValue = double.tryParse(entry['credit'].toString()) ?? 0.0;
    final balanceValue = double.tryParse(entry['balance'].toString()) ?? 0.0;
    final transactionType = entry['transaction_type'].toString();
    final paymentMethod = entry['payment_method']?.toString();

    Color typeColor;
    Color typeBg;
    IconData typeIcon;
    String typeLabel;

    switch (transactionType) {
      case 'sale':
        typeColor = const Color(0xFFEF4444);
        typeBg = const Color(0xFFFEF2F2);
        typeIcon = Icons.shopping_cart_outlined;
        typeLabel = languageProvider.isEnglish ? 'Sale' : 'فروخت';
        break;
      case 'payment':
        typeColor = const Color(0xFF10B981);
        typeBg = const Color(0xFFECFDF5);
        typeIcon = Icons.payments_outlined;
        typeLabel = languageProvider.isEnglish ? 'Payment' : 'ادائیگی';
        break;
      case 'adjustment':
        typeColor = const Color(0xFF6366F1);
        typeBg = const Color(0xFFEEF2FF);
        typeIcon = Icons.edit_note_outlined;
        typeLabel = languageProvider.isEnglish ? 'Adjustment' : 'ایڈجسٹمنٹ';
        break;
      default:
        typeColor = const Color(0xFFF59E0B);
        typeBg = const Color(0xFFFFFBEB);
        typeIcon = Icons.info_outline;
        typeLabel = transactionType.replaceAll('_', ' ').toUpperCase();
    }

    final balColor = balanceValue > 0
        ? const Color(0xFFEF4444)
        : balanceValue < 0
        ? const Color(0xFF10B981)
        : const Color(0xFF8E8E93);

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(flex: 2, child: Text(dateFormat.format(DateTime.parse(entry['date'])),
                  style: TextStyle(fontSize: 12, color: Color(0xFF3C3C43), fontFamily: languageProvider.fontFamily))),
              Expanded(flex: 2, child: Text(entry['reference_number'] ?? '—',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
              Expanded(flex: 1, child: _typeBadge(typeLabel, typeColor, typeBg)),
              Expanded(flex: 1, child: _methodBadge(_getPaymentMethodLabel(paymentMethod),
                  _getPaymentMethodColor(paymentMethod))),
              Expanded(flex: 2, child: _buildBankWidget(_getPaymentMethodColor(paymentMethod))),
              Expanded(flex: 3, child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(entry['description'] ?? '—',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1C1C1E), fontFamily: languageProvider.fontFamily),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              )),
              Expanded(flex: 2, child: Text(debitValue > 0 ? 'Rs ${currencyFormat.format(debitValue)}' : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: debitValue > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: debitValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF8E8E93),
                      fontFamily: languageProvider.fontFamily))),
              Expanded(flex: 2, child: Text(creditValue > 0 ? 'Rs ${currencyFormat.format(creditValue)}' : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: creditValue > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: creditValue > 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93),
                      fontFamily: languageProvider.fontFamily))),
              Expanded(flex: 2, child: Text('Rs ${currencyFormat.format(balanceValue)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: balColor,
                      fontFamily: languageProvider.fontFamily))),
              const SizedBox(width: 4),
              AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 18,
                      color: isExpanded ? const Color(0xFF7C3AED) : const Color(0xFF8E8E93))),
            ]),
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

  Widget _typeBadge(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600,
            fontFamily: languageProvider.fontFamily),
        overflow: TextOverflow.ellipsis),
  );

  Widget _methodBadge(String label, Color color) {
    if (label == '—') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500,
                fontFamily: languageProvider.fontFamily),
            overflow: TextOverflow.ellipsis),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600,
              fontFamily: languageProvider.fontFamily),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _getBankLogo(String bankName, Color color, {double size = 28}) {
    final bank = _getBankByName(bankName);
    if (bank != null && bank.iconPath.isNotEmpty) {
      return Image.asset(
        bank.iconPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.account_balance,
            size: size * 0.6,
            color: color,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.account_balance,
        size: size * 0.6,
        color: color,
      ),
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
    final method = entry['payment_method']?.toString();
    final bankName = entry['bank_name']?.toString();
    final chequeNum = entry['cheque_number']?.toString();
    final chequeDate = entry['cheque_date']?.toString();

    if (method == null) return const SizedBox.shrink();

    final meta = paymentMethodMeta[method] ?? paymentMethodMeta['cash']!;
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
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(meta['icon'] as IconData, size: 12, color: color),
              const SizedBox(width: 5),
              Text(_methodLabel(method), style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3,
                  fontFamily: languageProvider.fontFamily)),
            ]),
          ),
          if (bankName != null && bankName.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _getBankLogo(bankName, color, size: 28),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.isEnglish ? 'Bank' : 'بینک',
                            style: TextStyle(
                              fontSize: 10,
                              color: color.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              fontFamily: languageProvider.fontFamily,
                            ),
                          ),
                          Text(
                            bankName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ]),

        if (chequeNum != null && chequeNum.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoChip(
                icon: Icons.receipt_long_outlined,
                label: languageProvider.isEnglish ? 'Cheque Number' : 'چیک نمبر',
                value: chequeNum,
                color: color
            )),
            if (chequeDate != null) ...[
              const SizedBox(width: 8),
              Expanded(child: _infoChip(
                  icon: Icons.event_outlined,
                  label: languageProvider.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ',
                  value: chequeDate,
                  color: color
              )),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: typeBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Icon(typeIcon, size: 16, color: typeColor),
            const SizedBox(width: 8),
            Text(languageProvider.isEnglish ? 'Transaction Details' : 'لین دین کی تفصیلات',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: typeColor,
                    fontFamily: languageProvider.fontFamily)),
            const Spacer(),
            Text('ID #${entry['id']}',
                style: TextStyle(
                    fontSize: 11,
                    color: typeColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontFamily: languageProvider.fontFamily)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: _detailItem(
                      icon: Icons.calendar_today_outlined,
                      label: languageProvider.isEnglish ? 'Transaction Date' : 'لین دین کی تاریخ',
                      value: dateTimeFormat.format(DateTime.parse(entry['date'])))),
              const SizedBox(width: 16),
              Expanded(
                  child: _detailItem(
                      icon: Icons.access_time_outlined,
                      label: languageProvider.isEnglish ? 'Recorded On' : 'ریکارڈ شدہ',
                      value: dateTimeFormat.format(DateTime.parse(entry['created_at'])))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _detailItem(
                      icon: Icons.tag_outlined,
                      label: languageProvider.isEnglish ? 'Reference Number' : 'حوالہ نمبر',
                      value: entry['reference_number'] ?? 'N/A')),
              const SizedBox(width: 16),
              Expanded(
                  child: _detailItem(
                      icon: Icons.category_outlined,
                      label: languageProvider.isEnglish ? 'Transaction Type' : 'لین دین کی قسم',
                      value: typeLabel,
                      valueColor: typeColor)),
            ]),
            const SizedBox(height: 12),
            _detailItem(
                icon: Icons.notes_outlined,
                label: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                value: entry['description'] ?? (languageProvider.isEnglish ? 'No description provided' : 'کوئی تفصیل فراہم نہیں کی گئی')),
            const SizedBox(height: 12),

            if (entry['transaction_type'] == 'payment') ...[
              _buildPaymentMethodSection(typeColor),
              const SizedBox(height: 12),
            ],

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(
                    child: _amountCell(
                        label: languageProvider.isEnglish ? 'Debit (Owes)' : 'ڈیبٹ (قرض)',
                        value: debitValue > 0 ? 'Rs ${currencyFormat.format(debitValue)}' : '—',
                        color: const Color(0xFFEF4444))),
                Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
                Expanded(
                    child: _amountCell(
                        label: languageProvider.isEnglish ? 'Credit (Paid)' : 'کریڈٹ (ادا شدہ)',
                        value: creditValue > 0 ? 'Rs ${currencyFormat.format(creditValue)}' : '—',
                        color: const Color(0xFF10B981))),
                Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
                Expanded(
                    child: _amountCell(
                        label: languageProvider.isEnglish ? 'Running Balance' : 'چلتا بیلنس',
                        value: 'Rs ${currencyFormat.format(balanceValue)}',
                        color: balanceValue > 0
                            ? const Color(0xFFEF4444)
                            : balanceValue < 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF8E8E93),
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
    final lengths = _parseDynamicList(item['selected_lengths']);
    final quantities = _parseLengthQuantities(item['length_quantities']);

    if (lengths.isEmpty) return const SizedBox.shrink();

    final totalPieces = lengths.fold<int>(0, (sum, length) {
      return sum + (quantities[length] ?? 1);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageProvider.isEnglish ? 'Length Breakdown' : 'لمبائی کی تفصیل',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  if (totalPieces > 0)
                    Text(
                      languageProvider.isEnglish ? '$totalPieces pcs' : '$totalPieces ٹکڑے',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: lengths.map((length) {
                  final qty = quantities[length] ?? 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      _safeLengthLabel(length, qty),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaleItemsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
                color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(languageProvider.isEnglish ? 'Sale Items' : 'فروخت کی اشیاء',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
        const Spacer(),
        if (isLoadingItems)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
      ]),
      const SizedBox(height: 10),
      if (isLoadingItems && saleItems == null)
        const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2)))
      else if (saleItems == null || saleItems!.isEmpty)
        Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(languageProvider.isEnglish ? 'No items found' : 'کوئی اشیاء نہیں ملی',
                style: TextStyle(fontSize: 13, color: Colors.grey[400], fontFamily: languageProvider.fontFamily)))
      else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15))),
            child: Row(children: [
              Expanded(
                  flex: 5,
                  child: Text(languageProvider.isEnglish ? 'PRODUCT' : 'پروڈکٹ',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.4))),
              Expanded(
                  flex: 2,
                  child: Text(languageProvider.isEnglish ? 'QTY' : 'مقدار',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.4))),
              Expanded(
                  flex: 3,
                  child: Text(languageProvider.isEnglish ? 'PRICE' : 'قیمت',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.4))),
              Expanded(
                  flex: 3,
                  child: Text(languageProvider.isEnglish ? 'TOTAL' : 'کل',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.4))),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Column(
              children: saleItems!.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                final price = item['unit_price'] as double? ?? 0.0;
                final total = item['total_price'] as double? ?? (qty * price);
                final isLast = i == saleItems!.length - 1;

                final lengths = _parseDynamicList(item['selected_lengths']);
                final hasLengths = lengths.isNotEmpty;

                final weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0.0;

                final quantities = _parseLengthQuantities(item['length_quantities']);
                final totalPieces = hasLengths
                    ? lengths.fold<int>(0, (sum, length) => sum + (quantities[length] ?? 1))
                    : 0;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFC),
                          border: isLast && !hasLengths
                              ? null
                              : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5)))),
                      child: Row(children: [
                        Expanded(
                            flex: 5,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item['product_name'] as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1C1C1E)),
                                  overflow: TextOverflow.ellipsis),
                              if (item['barcode'] != null)
                                Text('${languageProvider.isEnglish ? 'Barcode' : 'بارکوڈ'}: ${item['barcode']}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                              if (hasLengths && item['selected_lengths_display'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 11, color: Color(0xFF7C3AED)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          item['selected_lengths_display']!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF7C3AED),
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (hasLengths && totalPieces > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  languageProvider.isEnglish ? '$totalPieces pcs total' : 'کل $totalPieces ٹکڑے',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.teal[700],
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                              if (weight > 0 && !hasLengths)
                                Text('${languageProvider.isEnglish ? 'Weight' : 'وزن'}: ${weight.toStringAsFixed(2)} Kg',
                                    style: const TextStyle(
                                        fontSize: 10, color: Color(0xFF1D4ED8))),
                            ])),
                        Expanded(
                            flex: 2,
                            child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text('$qty',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6366F1))))),
                        Expanded(
                            flex: 3,
                            child: Text('Rs ${currencyFormat.format(price)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF3C3C43)))),
                        Expanded(
                            flex: 3,
                            child: Text('Rs ${currencyFormat.format(total)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1C1E)))),
                      ]),
                    ),
                    if (hasLengths)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: _buildLengthChips(item),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2))),
            child: Row(children: [
              const Expanded(
                  child: Text('Total',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E)))),
              Text(
                  'Rs ${currencyFormat.format(saleItems!.fold<double>(0, (sum, item) => sum + (item['total_price'] as double? ?? 0.0)))}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED))),
            ]),
          ),
        ],
    ]);
  }

  Widget _detailItem(
      {required IconData icon,
        required String label,
        required String value,
        Color? valueColor}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: const Color(0xFF8E8E93)),
      const SizedBox(width: 6),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500,
                    fontFamily: languageProvider.fontFamily)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? const Color(0xFF1C1C1E),
                    fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: languageProvider.fontFamily)),
          ])),
    ]);
  }

  Widget _amountCell(
      {required String label, required String value, required Color color, bool bold = false}) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 10, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500,
              fontFamily: languageProvider.fontFamily)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
              fontFamily: languageProvider.fontFamily)),
    ]);
  }
}