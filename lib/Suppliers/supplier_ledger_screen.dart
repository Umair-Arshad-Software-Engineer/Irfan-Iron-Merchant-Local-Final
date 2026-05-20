// lib/screens/suppliers/supplier_ledger_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/supplier.dart';
import '../../providers/supplier_ledger_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../Banks/banknames.dart';
import '../services/supplierledgerpdf generator.dart';



class SupplierLedgerScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierLedgerScreen({super.key, required this.supplier});

  @override
  State<SupplierLedgerScreen> createState() => _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends State<SupplierLedgerScreen> {
  final ScrollController _verticalScroll = ScrollController();
  final _currencyFormat  = NumberFormat('#,##0.00');
  final _dateFormat      = DateFormat('MMM dd, yyyy');
  final _dateTimeFormat  = DateFormat('MMM dd, yyyy • hh:mm a');

  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;
  int? _expandedEntryId;

  bool _showUnclearedCheques = false;


  final Map<int, List<Map<String, dynamic>>> _receiptItemsCache   = {};
  final Map<int, bool>                       _receiptItemsLoading = {};

  static const _filterOptions = [
    {'value': 'all',              'label': 'All'},
    {'value': 'purchase_receipt', 'label': 'Receipts'},
    {'value': 'payment',          'label': 'Payments'},
    {'value': 'manual',           'label': 'Manual'},
  ];

  // Payment method meta (same as payments screen for consistency)
  static const Map<String, Map<String, dynamic>> _paymentMethodMeta = {
    'cash':   {'label': 'Cash',   'icon': Icons.payments_outlined,        'color': Color(0xFF10B981)},
    'bank':   {'label': 'Bank',   'icon': Icons.account_balance_outlined, 'color': Color(0xFF3B82F6)},
    'cheque': {'label': 'Cheque', 'icon': Icons.receipt_long_outlined,    'color': Color(0xFFF59E0B)},
    'slip':   {'label': 'Slip',   'icon': Icons.receipt_outlined,         'color': Color(0xFF8B5CF6)},
  };
  void _toggleUnclearedCheques() {
    setState(() {
      _showUnclearedCheques = !_showUnclearedCheques;
    });
    _loadLedger();
  }


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
    final provider = Provider.of<SupplierLedgerProvider>(context, listen: false);
    await provider.fetchLedger(
      context: context,
      supplierId: widget.supplier.id,
      page: 1,
      referenceType: _selectedFilter == 'all' ? null : _selectedFilter,
      fromDate: _dateRange?.start.toIso8601String().split('T').first,
      toDate: _dateRange?.end.toIso8601String().split('T').first,
      showUnclearedCheques: _showUnclearedCheques,  // Add this
      sortBy: 'transaction_date',   // add this
      sortOrder: 'asc',             // add this
    );
  }

  Future<void> _loadMore() async {
    final provider = Provider.of<SupplierLedgerProvider>(context, listen: false);
    if (!provider.hasMorePages || provider.isLoading) return;
    await provider.fetchLedger(
      context: context,
      supplierId: widget.supplier.id,
      page: provider.currentPage + 1,
      referenceType: _selectedFilter == 'all' ? null : _selectedFilter,
    );
  }

  String? _getToken() {
    try { return Provider.of<AuthProvider>(context, listen: false).user?.token; } catch (_) { return null; }
  }

  Future<void> _fetchReceiptItems(int receiptId) async {
    if (_receiptItemsCache.containsKey(receiptId)) return;
    setState(() => _receiptItemsLoading[receiptId] = true);
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.receiptByIdUrl(receiptId)),
        headers: {
          'Content-Type': 'application/json',
          if (_getToken() != null) 'Authorization': 'Bearer ${_getToken()}',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final items = (data['data']['items'] as List).map<Map<String, dynamic>>((i) => {
            'product_name': i['product']?['item_name'] ?? 'Unknown',
            'barcode':      i['product']?['barcode'],
            'quantity':     i['quantity_received'],
            'unit_cost':    double.tryParse(i['unit_cost'].toString()) ?? 0.0,
            'batch_number': i['batch_number'],
            'expiry_date':  i['expiry_date'],
          }).toList();
          if (mounted) setState(() => _receiptItemsCache[receiptId] = items);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _receiptItemsLoading[receiptId] = false);
  }

  void _toggleRow(LedgerEntry entry) {
    final expanding = _expandedEntryId != entry.id;
    setState(() => _expandedEntryId = expanding ? entry.id : null);
    if (expanding && entry.referenceType == 'purchase_receipt' && entry.referenceId != null) {
      _fetchReceiptItems(entry.referenceId!);
    }
  }

  // Helper method to get payment method label
  String _getPaymentMethodLabel(String? method) {
    if (method == null) return '—';
    return _paymentMethodMeta[method]?['label'] ?? method;
  }

  // Helper method to get payment method color
  Color _getPaymentMethodColor(String? method) {
    if (method == null) return const Color(0xFF8E8E93);
    return _paymentMethodMeta[method]?['color'] ?? const Color(0xFF8E8E93);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _buildAppBar(),
      body: Consumer<SupplierLedgerProvider>(
        builder: (context, provider, _) => Column(children: [
          _buildFiltersBar(),
          _buildSummaryCards(provider),
          Expanded(child: _buildTableSection(provider)),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEntryDialog,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.supplier.name,
            style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold, fontSize: 17)),
        const Text('Supplier Ledger',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.normal)),
      ]),
      actions: [
        // Add toggle button for uncleared cheques
        IconButton(
          icon: Icon(
            _showUnclearedCheques ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF7C3AED),
          ),
          tooltip: _showUnclearedCheques
              ? 'Hide uncleared cheques'
              : 'Show uncleared cheques (Admin)',
          onPressed: _toggleUnclearedCheques,
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF7C3AED)),
          onPressed: _generatePDF,
          tooltip: 'Export as PDF',
        ),
        IconButton(
          icon: const Icon(Icons.date_range_outlined, color: Color(0xFF7C3AED)),
          onPressed: _pickDateRange,
        ),
        if (_dateRange != null)
          IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFF8E8E93)),
            onPressed: () { setState(() => _dateRange = null); _loadLedger(); },
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE5E5EA)),
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterOptions.map((opt) {
              final selected = _selectedFilter == opt['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(opt['label']!, style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : const Color(0xFF3C3C43),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  selected: selected,
                  onSelected: (_) { setState(() => _selectedFilter = opt['value']!); _loadLedger(); },
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

  Widget _buildSummaryCards(SupplierLedgerProvider provider) {
    final s = provider.summary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        _summaryCard(label: 'Total Payable',
            value: s != null ? 'Rs ${_currencyFormat.format(s.totalCredit)}' : '—',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFEF4444), bgColor: const Color(0xFFFEF2F2)),
        const SizedBox(width: 10),
        _summaryCard(label: 'Total Paid',
            value: s != null ? 'Rs ${_currencyFormat.format(s.totalDebit)}' : '—',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF10B981), bgColor: const Color(0xFFECFDF5)),
        const SizedBox(width: 10),
        _summaryCard(label: 'Outstanding',
            value: s != null ? 'Rs ${_currencyFormat.format(s.closingBalance)}' : '—',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF7C3AED), bgColor: const Color(0xFFF5F3FF), isBold: true),
      ]),
    );
  }

  Widget _summaryCard({required String label, required String value, required IconData icon,
    required Color color, required Color bgColor, bool isBold = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isBold ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFFE5E5EA),
              width: isBold ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500],
                fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? const Color(0xFF7C3AED) : const Color(0xFF1C1C1E)),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _buildTableSection(SupplierLedgerProvider provider) {
    if (provider.isLoading && provider.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }
    if (!provider.isLoading && provider.entries.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('No transactions found', style: TextStyle(fontSize: 16, color: Colors.grey[500],
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Ledger entries will appear here', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(children: [
              _buildTableHeader(),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              Expanded(
                child: ListView.builder(
                  controller: _verticalScroll,
                  itemCount: provider.entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == provider.entries.length) {
                      return provider.isLoading
                          ? const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(
                              color: Color(0xFF7C3AED), strokeWidth: 2)))
                          : const SizedBox(height: 16);
                    }
                    final entry     = provider.entries[index];
                    final isExpanded = _expandedEntryId == entry.id;
                    return _ExpandableRow(
                      key: ValueKey(entry.id),
                      entry: entry,
                      isEven: index % 2 == 0,
                      isExpanded: isExpanded,
                      isLast: index == provider.entries.length - 1,
                      currencyFormat: _currencyFormat,
                      dateFormat: _dateFormat,
                      dateTimeFormat: _dateTimeFormat,
                      paymentMethodMeta: _paymentMethodMeta,
                      receiptItems: entry.referenceType == 'purchase_receipt' && entry.referenceId != null
                          ? _receiptItemsCache[entry.referenceId] : null,
                      isLoadingItems: entry.referenceType == 'purchase_receipt' && entry.referenceId != null
                          ? (_receiptItemsLoading[entry.referenceId] ?? false) : false,
                      onTap: () => _toggleRow(entry),
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

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF5F5F7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        _hCell('DATE', flex: 2),
        _hCell('REF #', flex: 2),
        _hCell('TYPE', flex: 1),
        _hCell('METHOD', flex: 1),
        _hCell('BANK', flex: 2),
        _hCell('DESCRIPTION', flex: 3),
        _hCell('DEBIT', flex: 2, right: true),
        _hCell('CREDIT', flex: 2, right: true),
        _hCell('BALANCE', flex: 2, right: true),
        const SizedBox(width: 24),
      ]),
    );
  }

  Widget _hCell(String text, {int flex = 1, bool right = false}) => Expanded(
    flex: flex,
    child: Text(text, textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFF8E8E93), letterSpacing: 0.5)),
  );

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(now.year - 3), lastDate: now,
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
        child: child!,
      ),
    );
    if (picked != null) { setState(() => _dateRange = picked); _loadLedger(); }
  }

  Future<void> _showAddEntryDialog() async {
    final descCtrl   = TextEditingController();
    final debitCtrl  = TextEditingController(text: '0');
    final creditCtrl = TextEditingController(text: '0');
    final refCtrl    = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Add Manual Entry', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dlgField(ctrl: descCtrl, label: 'Description *', hint: 'e.g. Opening balance'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dlgField(ctrl: creditCtrl, label: 'Credit (Payable)', hint: '0.00', num: true)),
                const SizedBox(width: 12),
                Expanded(child: _dlgField(ctrl: debitCtrl, label: 'Debit (Paid)', hint: '0.00', num: true)),
              ]),
              const SizedBox(height: 12),
              _dlgField(ctrl: refCtrl, label: 'Reference # (optional)', hint: 'e.g. CHQ-001'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(context: ctx, initialDate: selectedDate,
                      firstDate: DateTime(2020), lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
                        child: child!,
                      ));
                  if (p != null) setDlg(() => selectedDate = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E5EA))),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text('Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                        style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93)))),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Description is required'), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx);
                final provider = Provider.of<SupplierLedgerProvider>(context, listen: false);
                final result   = await provider.addManualEntry(
                  context: context, supplierId: widget.supplier.id,
                  debit: double.tryParse(debitCtrl.text) ?? 0,
                  credit: double.tryParse(creditCtrl.text) ?? 0,
                  description: descCtrl.text.trim(),
                  referenceNumber: refCtrl.text.isEmpty ? null : refCtrl.text,
                  transactionDate: selectedDate,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result['message']),
                      backgroundColor: result['success'] ? Colors.green : Colors.green));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    descCtrl.dispose(); debitCtrl.dispose(); creditCtrl.dispose(); refCtrl.dispose();
  }

  Widget _dlgField({required TextEditingController ctrl, required String label,
    required String hint, bool num = false})
  {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: const Color(0xFFF5F5F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
        ),
      ),
    ]);
  }

  Future<void> _generatePDF() async {
    final provider = Provider.of<SupplierLedgerProvider>(context, listen: false);

    if (provider.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to export'),
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
      provider.entries.map((e) => e.toJson()).toList();

      final pdfData = await SupplierLedgerPdfGenerator.generateLedgerPdf(
        supplierName: widget.supplier.name,
        supplierPhone: widget.supplier.contact ?? '',
        supplierAddress: widget.supplier.address ?? '',
        summary: provider.summary?.toJson() ?? {},
        entries: typedEntries,
        filterType: _selectedFilter,
        dateRange: _dateRange,
        receiptItemsCache: _receiptItemsCache,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        final fileName =
            'supplier_ledger_${widget.supplier.name.replaceAll(' ', '_')}_'
            '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

        // Directly open/share the PDF — no preview dialog
        await Printing.sharePdf(bytes: pdfData, filename: fileName);
      }
    } catch (e) {
      debugPrint('PDF Generation Error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}

// ─── Expandable Row ────────────────────────────────────────────────────────

class _ExpandableRow extends StatelessWidget {
  final LedgerEntry entry;
  final bool isEven, isExpanded, isLast, isLoadingItems;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat, dateTimeFormat;
  final Map<String, Map<String, dynamic>> paymentMethodMeta;
  final List<Map<String, dynamic>>? receiptItems;
  final VoidCallback onTap;

  const _ExpandableRow({
    super.key, required this.entry, required this.isEven, required this.isExpanded,
    required this.isLast, required this.currencyFormat, required this.dateFormat,
    required this.dateTimeFormat, required this.paymentMethodMeta, required this.onTap,
    this.receiptItems, this.isLoadingItems = false,
  });

  String _getPaymentMethodLabel(String? method) {
    if (method == null) return '—';
    return paymentMethodMeta[method]?['label'] ?? method;
  }

  String _getBankName() {
    if (entry.paymentMethod == null) return '—';
    if (entry.bankName != null && entry.bankName!.isNotEmpty) return entry.bankName!;
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
    final bank = _getBankByName(entry.bankName);
    final bankName = _getBankName();

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
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Fallback: just show the bank name
    return Text(
      bankName,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color typeColor; Color typeBg; IconData typeIcon; String typeLabel;
    switch (entry.referenceType) {
      case 'purchase_receipt':
        typeColor = const Color(0xFFEF4444); typeBg = const Color(0xFFFEF2F2);
        typeIcon = Icons.inventory_2_outlined; typeLabel = 'Receipt'; break;
      case 'payment':
        typeColor = const Color(0xFF10B981); typeBg = const Color(0xFFECFDF5);
        typeIcon = Icons.payments_outlined; typeLabel = 'Payment'; break;
      case 'reversal':
        typeColor = const Color(0xFFF59E0B); typeBg = const Color(0xFFFFFBEB);
        typeIcon = Icons.undo_rounded; typeLabel = 'Reversal'; break;
      default:
        typeColor = const Color(0xFF6366F1); typeBg = const Color(0xFFEEF2FF);
        typeIcon = Icons.edit_note_outlined; typeLabel = 'Manual';
    }

    final balColor = entry.balance > 0 ? const Color(0xFFEF4444)
        : entry.balance < 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93);

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
              // Date
              Expanded(flex: 2, child: Text(dateFormat.format(entry.transactionDate),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3C3C43)))),
              // Reference #
              Expanded(flex: 2, child: Text(entry.referenceNumber ?? '—',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              // Type
              Expanded(flex: 1, child: _typeBadge(typeLabel, typeColor, typeBg)),
              // Method
              Expanded(flex: 1, child: _methodBadge(_getPaymentMethodLabel(entry.paymentMethod),
                  _getPaymentMethodColor(entry.paymentMethod))),
              // Bank
              // In the main row children list, replace the bank Expanded widget:
              Expanded(
                flex: 2,
                child: _buildBankWidget(_getPaymentMethodColor(entry.paymentMethod)),
              ),
              // Description
              Expanded(flex: 3, child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(entry.description ?? '—',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1C1C1E)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
              // Debit
              Expanded(flex: 2, child: Text(
                  entry.debit > 0 ? currencyFormat.format(entry.debit) : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12,
                      fontWeight: entry.debit > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: entry.debit > 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93)))),
              // Credit
              Expanded(flex: 2, child: Text(
                  entry.credit > 0 ? currencyFormat.format(entry.credit) : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12,
                      fontWeight: entry.credit > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: entry.credit > 0 ? const Color(0xFFEF4444) : const Color(0xFF8E8E93)))),
              // Balance
              Expanded(flex: 2, child: Text(currencyFormat.format(entry.balance),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: balColor))),
              const SizedBox(width: 4),
              AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, size: 18,
                      color: isExpanded ? const Color(0xFF7C3AED) : const Color(0xFF8E8E93))),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildDetailPanel(typeColor, typeBg, typeIcon, typeLabel),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  Widget _typeBadge(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis),
  );

  Widget _methodBadge(String label, Color color) {
    if (label == '—') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis),
    );
  }

  Color _getPaymentMethodColor(String? method) {
    if (method == null) return const Color(0xFF8E8E93);
    return paymentMethodMeta[method]?['color'] ?? const Color(0xFF8E8E93);
  }

  Widget _buildDetailPanel(Color typeColor, Color typeBg, IconData typeIcon, String typeLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: typeBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Icon(typeIcon, size: 16, color: typeColor),
            const SizedBox(width: 8),
            Text('Transaction Details', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold, color: typeColor)),
            const Spacer(),
            Text('ID #${entry.id}',
                style: TextStyle(fontSize: 11, color: typeColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Date + Recorded
            Row(children: [
              Expanded(child: _detailItem(icon: Icons.calendar_today_outlined,
                  label: 'Transaction Date', value: dateTimeFormat.format(entry.transactionDate))),
              const SizedBox(width: 16),
              Expanded(child: _detailItem(icon: Icons.access_time_outlined,
                  label: 'Recorded On', value: dateTimeFormat.format(entry.createdAt))),
            ]),
            const SizedBox(height: 12),

            // Ref # + Type
            Row(children: [
              Expanded(child: _detailItem(icon: Icons.tag_outlined,
                  label: 'Reference Number', value: entry.referenceNumber ?? 'N/A')),
              const SizedBox(width: 16),
              Expanded(child: _detailItem(icon: Icons.category_outlined,
                  label: 'Transaction Type', value: typeLabel, valueColor: typeColor)),
            ]),
            const SizedBox(height: 12),

            // Description
            _detailItem(icon: Icons.notes_outlined, label: 'Description',
                value: entry.description ?? 'No description provided'),
            const SizedBox(height: 12),

            // ── Payment Method Section (only for payment entries) ────────
            if (entry.referenceType == 'payment') ...[
              _buildPaymentMethodSection(typeColor),
              const SizedBox(height: 12),
            ],

            // Amount summary bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(child: _amountCell(label: 'Debit (Paid)',
                    value: entry.debit > 0 ? currencyFormat.format(entry.debit) : '—',
                    color: const Color(0xFF10B981))),
                Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
                Expanded(child: _amountCell(label: 'Credit (Payable)',
                    value: entry.credit > 0 ? currencyFormat.format(entry.credit) : '—',
                    color: const Color(0xFFEF4444))),
                Container(width: 1, height: 36, color: const Color(0xFFE5E5EA)),
                Expanded(child: _amountCell(label: 'Running Balance',
                    value: currencyFormat.format(entry.balance),
                    color: entry.balance > 0 ? const Color(0xFFEF4444)
                        : entry.balance < 0 ? const Color(0xFF10B981) : const Color(0xFF8E8E93),
                    bold: true)),
              ]),
            ),

            // Receipt items section
            if (entry.referenceType == 'purchase_receipt') ...[
              const SizedBox(height: 14),
              _buildReceiptItemsSection(),
            ],
          ]),
        ),
      ]),
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

  // ── Payment method detail block ─────────────────────────────────────────
  Widget _buildPaymentMethodSection(Color typeColor) {
    final method     = entry.paymentMethod;
    final bankName   = entry.bankName;
    final chequeNum  = entry.chequeNumber;
    final chequeDate = entry.chequeDate;

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
        // Header
        Row(children: [
          Container(width: 3, height: 16,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(meta['icon'] as IconData, size: 15, color: color),
          const SizedBox(width: 6),
          Text('Payment Method Details', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 10),

        // Method badge + bank in a row
        Row(children: [
          // Method pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(meta['icon'] as IconData, size: 12, color: color),
              const SizedBox(width: 5),
              Text(_methodLabel(method), style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3)),
            ]),
          ),
          // In _buildPaymentMethodSection method, replace the bank display row with:
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
                    // Bank Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _getBankLogo(bankName, color, size: 28),
                    ),
                    const SizedBox(width: 8),
                    // Bank info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank',
                            style: TextStyle(
                              fontSize: 10,
                              color: color.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
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

        // In _buildPaymentMethodSection, inside the cheque-specific info section
        if (chequeNum != null && chequeNum.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoChip(
                icon: Icons.receipt_long_outlined,
                label: 'Cheque Number',
                value: chequeNum,
                color: color
            )),
            if (chequeDate != null) ...[
              const SizedBox(width: 8),
              Expanded(child: _infoChip(
                  icon: Icons.event_outlined,
                  label: 'Cheque Date',
                  value: chequeDate,
                  color: color
              )),
            ],
          ]),
          const SizedBox(height: 8),
          // Add cheque status indicator
          _infoChip(
            icon: entry.chequeCleared == true ? Icons.check_circle : Icons.pending,
            label: 'Cheque Status',
            value: entry.chequeCleared == true ? 'Cleared' : 'Pending',
            color: entry.chequeCleared == true ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
        ],
      ]),
    );
  }

  String _methodLabel(String method) {
    const labels = {'cash': 'Cash', 'bank': 'Bank Transfer', 'cheque': 'Cheque', 'slip': 'Pay Slip'};
    return labels[method] ?? method;
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
              fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  // ── Receipt items section (unchanged) ────────────────────────────────────
  Widget _buildReceiptItemsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
            color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const Text('Received Items',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
        const Spacer(),
        if (isLoadingItems)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
      ]),
      const SizedBox(height: 10),
      if (isLoadingItems && receiptItems == null)
        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(color: Color(0xFF7C3AED), strokeWidth: 2)))
      else if (receiptItems == null || receiptItems!.isEmpty)
        Container(padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center,
            child: Text('No items found', style: TextStyle(fontSize: 13, color: Colors.grey[400])))
      else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15))),
            child: const Row(children: [
              Expanded(flex: 5, child: Text('PRODUCT', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: Color(0xFF7C3AED), letterSpacing: 0.4))),
              Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED), letterSpacing: 0.4))),
              Expanded(flex: 3, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED), letterSpacing: 0.4))),
              Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED), letterSpacing: 0.4))),
            ]),
          ),
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Column(
              children: receiptItems!.asMap().entries.map((e) {
                final i = e.key; final item = e.value;
                final qty    = (item['quantity'] as num?)?.toInt() ?? 0;
                final rate   = item['unit_cost'] as double? ?? 0.0;
                final amount = qty * rate;
                final isLast = i == receiptItems!.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFC),
                      border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5)))),
                  child: Row(children: [
                    Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['product_name'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
                      if (item['batch_number'] != null)
                        Text('Batch: ${item['batch_number']}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                    ])),
                    Expanded(flex: 2, child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('$qty', textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1))))),
                    Expanded(flex: 3, child: Text(currencyFormat.format(rate),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF3C3C43)))),
                    Expanded(flex: 3, child: Text(currencyFormat.format(amount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1C1E)))),
                  ]),
                );
              }).toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2))),
            child: Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)))),
              Text(currencyFormat.format(receiptItems!.fold<double>(0,
                      (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0) * (item['unit_cost'] as double? ?? 0.0))),
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
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13,
            color: valueColor ?? const Color(0xFF1C1C1E),
            fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.w500)),
      ])),
    ]);
  }

  Widget _amountCell({required String label, required String value,
    required Color color, bool bold = false}) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
    ]);
  }
}