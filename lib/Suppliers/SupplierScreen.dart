import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_ledger_screen.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_payment_dialog.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_payments_screen.dart';
import '../components/confirmation_dialog.dart';
import '../components/supplier_form_dialog.dart';
import '../models/supplier.dart';
import '../providers/lanprovider.dart';
import '../providers/supplier_provider.dart';
import '../providers/auth_provider.dart';

// ─── Design tokens (mirrors customer screen) ──────────────────────────────────
class _C {
  static const bg         = Color(0xFFF4F5F9);
  static const surface    = Colors.white;
  static const brand      = Color(0xFF5B4FE9);
  static const brandLight = Color(0xFFEEECFD);
  static const text1      = Color(0xFF111827);
  static const text2      = Color(0xFF4B5563);
  static const text3      = Color(0xFF9CA3AF);
  static const border     = Color(0xFFE5E7EB);
  static const rowHover   = Color(0xFFF9F8FF);
  static const green      = Color(0xFF10B981);
  static const red        = Color(0xFFEF4444);
  static const orange     = Color(0xFFF59E0B);
  static const blue       = Color(0xFF3B82F6);
}

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({Key? key}) : super(key: key);

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showActiveOnly = false;
  String _currentSearch = '';
  bool _hasInitialized = false;

  // Sorting
  String _sortColumn = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_hasInitialized) return;
    final p = Provider.of<SupplierProvider>(context, listen: false);
    _hasInitialized = true;
    await p.fetchSuppliers(context: context);
    await p.fetchActiveSuppliers(context);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final p = Provider.of<SupplierProvider>(context, listen: false);
    if (p.hasMorePages && !p.isLoading) {
      await p.fetchSuppliers(
        context: context,
        page: p.currentPage + 1,
        search: _currentSearch,
        active: _showActiveOnly ? true : null,
      );
    }
  }

  Future<void> _refresh() async {
    final p = Provider.of<SupplierProvider>(context, listen: false);
    await p.fetchSuppliers(
      context: context,
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
    );
  }

  void _handleSearch(String value) {
    if (value == _currentSearch) return;
    _currentSearch = value;
    final p = Provider.of<SupplierProvider>(context, listen: false);
    p.clearSuppliers();
    p.fetchSuppliers(
      context: context,
      search: value,
      active: _showActiveOnly ? true : null,
    );
  }

  void _toggleActiveFilter() {
    setState(() => _showActiveOnly = !_showActiveOnly);
    final p = Provider.of<SupplierProvider>(context, listen: false);
    p.clearSuppliers();
    p.fetchSuppliers(
      context: context,
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
    );
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _sortSuppliers(List<Supplier> suppliers) {
    suppliers.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'name':    cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase()); break;
        case 'contact': cmp = a.contact.compareTo(b.contact); break;
        case 'address': cmp = (a.address ?? '').compareTo(b.address ?? ''); break;
        case 'status':  cmp = a.isActive.toString().compareTo(b.isActive.toString()); break;
        default:        cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isLoggedIn) {
              return Center(
                child: Text(
                  languageProvider.isEnglish
                      ? 'Please login to access suppliers'
                      : 'سپلائرز تک رسائی کے لیے لاگ ان کریں',
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                ),
              );
            }

            return Consumer<SupplierProvider>(
              builder: (context, provider, _) {
                final sorted = List<Supplier>.from(provider.suppliers);
                _sortSuppliers(sorted);

                return Scaffold(
                  backgroundColor: _C.bg,
                  body: Column(
                    children: [
                      _Header(provider: provider, languageProvider: languageProvider),
                      _SearchBar(
                        controller: _searchController,
                        currentSearch: _currentSearch,
                        showActiveOnly: _showActiveOnly,
                        onSearch: _handleSearch,
                        onToggleActive: _toggleActiveFilter,
                        onSort: _toggleSort,
                        languageProvider: languageProvider,
                      ),
                      _TableHeader(
                        sortColumn: _sortColumn,
                        sortAscending: _sortAscending,
                        onSort: _toggleSort,
                        languageProvider: languageProvider,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: _C.brand,
                          onRefresh: _refresh,
                          child: _buildBody(provider, sorted, languageProvider),
                        ),
                      ),
                    ],
                  ),
                  floatingActionButton: _AddFAB(
                    onPressed: () => _showAddSupplierDialog(languageProvider),
                    languageProvider: languageProvider,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBody(SupplierProvider provider, List<Supplier> suppliers, LanguageProvider languageProvider) {
    if (provider.isLoading && suppliers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _C.brand));
    }
    if (suppliers.isEmpty) {
      return _EmptyState(
        hasSearch: _currentSearch.isNotEmpty,
        onAdd: () => _showAddSupplierDialog(languageProvider),
        languageProvider: languageProvider,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      itemCount: suppliers.length + 1,
      itemBuilder: (context, i) {
        if (i < suppliers.length) {
          return _SupplierRow(
            supplier: suppliers[i],
            index: i,
            onTap:    () => _showSupplierDetails(suppliers[i], languageProvider),
            onEdit:   () => _showEditSupplierDialog(suppliers[i], languageProvider),
            onToggle: () => _toggleSupplierStatus(suppliers[i]),
            onDelete: () => _deleteSupplier(suppliers[i], languageProvider),
            languageProvider: languageProvider,
          );
        }
        return provider.isLoading
            ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: _C.brand)),
        )
            : const SizedBox(height: 16);
      },
    );
  }

  Future<void> _showAddSupplierDialog(LanguageProvider languageProvider) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SupplierFormDialog(languageProvider: languageProvider),
    );
    if (result?['success'] == true) {
      _showSnack(result!['message'], _C.green, languageProvider);
      _refresh();
    }
  }

  Future<void> _showEditSupplierDialog(Supplier supplier, LanguageProvider languageProvider) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SupplierFormDialog(supplier: supplier, languageProvider: languageProvider),
    );
    if (result?['success'] == true) {
      _showSnack(result!['message'], _C.green, languageProvider);
      _refresh();
    }
  }

  void _showSupplierDetails(Supplier supplier, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierDetailsSheet(
        supplier: supplier,
        onEdit: () { Navigator.pop(context); _showEditSupplierDialog(supplier, languageProvider); },
        onToggleStatus: () { Navigator.pop(context); _toggleSupplierStatus(supplier); },
        onViewLedger: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SupplierLedgerScreen(supplier: supplier, languageProvider: languageProvider),
          ));
        },
        onViewPayments: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SupplierPaymentsScreen(supplier: supplier, languageProvider: languageProvider),
          ));
        },
        onPaySupplier: () async {
          Navigator.pop(context);
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => SupplierPaymentDialog(supplier: supplier, languageProvider: languageProvider),
          );
          if (ok == true) _showSnack(
            languageProvider.isEnglish ? 'Payment recorded successfully' : 'ادائیگی کامیابی سے ریکارڈ ہوگئی',
            _C.green,
            languageProvider,
          );
        },
        languageProvider: languageProvider,
      ),
    );
  }

  Future<void> _toggleSupplierStatus(Supplier supplier) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final ok = await showConfirmationDialog(
      context,
      title: supplier.isActive
          ? (languageProvider.isEnglish ? 'Deactivate Supplier' : 'سپلائر غیر فعال کریں')
          : (languageProvider.isEnglish ? 'Activate Supplier' : 'سپلائر فعال کریں'),
      message: supplier.isActive
          ? (languageProvider.isEnglish
          ? 'Are you sure you want to deactivate ${supplier.name}?'
          : 'کیا آپ واقعی ${supplier.name} کو غیر فعال کرنا چاہتے ہیں؟')
          : (languageProvider.isEnglish
          ? 'Are you sure you want to activate ${supplier.name}?'
          : 'کیا آپ واقعی ${supplier.name} کو فعال کرنا چاہتے ہیں؟'),
      confirmText: supplier.isActive
          ? (languageProvider.isEnglish ? 'Deactivate' : 'غیر فعال کریں')
          : (languageProvider.isEnglish ? 'Activate' : 'فعال کریں'),
      confirmColor: supplier.isActive ? _C.red : _C.green,
    );
    if (ok == true) {
      final p = Provider.of<SupplierProvider>(context, listen: false);
      final result = await p.toggleSupplierStatus(supplier.id, context);
      _showSnack(result['message'], result['success'] ? _C.green : _C.red, languageProvider);
      if (result['success']) _refresh();
    }
  }

  Future<void> _deleteSupplier(Supplier supplier, LanguageProvider languageProvider) async {
    final ok = await showConfirmationDialog(
      context,
      title: languageProvider.isEnglish ? 'Delete Supplier' : 'سپلائر حذف کریں',
      message: languageProvider.isEnglish
          ? 'Are you sure you want to delete ${supplier.name}? This cannot be undone.'
          : 'کیا آپ واقعی ${supplier.name} کو حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں کیا جا سکتا۔',
      confirmText: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
      confirmColor: _C.red,
    );
    if (ok == true) {
      final p = Provider.of<SupplierProvider>(context, listen: false);
      final result = await p.deleteSupplier(supplier.id, context);
      _showSnack(result['message'], result['success'] ? _C.green : _C.red, languageProvider);
      if (result['success']) _refresh();
    }
  }

  void _showSnack(String msg, Color color, LanguageProvider languageProvider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontWeight: FontWeight.w500, fontFamily: languageProvider.fontFamily)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final SupplierProvider provider;
  final LanguageProvider languageProvider;
  const _Header({required this.provider, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final active = provider.suppliers.where((s) => s.isActive).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _C.brandLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _C.brand, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(languageProvider.isEnglish ? 'Suppliers' : 'سپلائرز',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                          color: _C.text1, letterSpacing: -0.4)),
                  Text(languageProvider.isEnglish ? 'Manage supplier relationships & contacts' : 'سپلائر تعلقات اور رابطوں کا انتظام کریں',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500], fontFamily: languageProvider.fontFamily)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(languageProvider.isEnglish ? 'Export' : 'ایکسپورٹ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.brand,
                  side: const BorderSide(color: _C.brand),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatTile(
                label: languageProvider.isEnglish ? 'Total Suppliers' : 'کل سپلائرز',
                value: provider.totalItems.toString(),
                color: _C.brand,
                languageProvider: languageProvider,
              ),
              Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 12), color: _C.border),
              _StatTile(
                label: languageProvider.isEnglish ? 'Active' : 'فعال',
                value: active.toString(),
                color: _C.green,
                languageProvider: languageProvider,
              ),
              Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 12), color: _C.border),
              _StatTile(
                label: languageProvider.isEnglish ? 'Inactive' : 'غیر فعال',
                value: (provider.totalItems - active).toString(),
                color: _C.text3,
                languageProvider: languageProvider,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final LanguageProvider languageProvider;
  const _StatTile({required this.label, required this.value, required this.color, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: _C.text3, fontWeight: FontWeight.w500, fontFamily: languageProvider.fontFamily)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.5)),
      ],
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String currentSearch;
  final bool showActiveOnly;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleActive;
  final void Function(String) onSort;
  final LanguageProvider languageProvider;

  const _SearchBar({
    required this.controller, required this.currentSearch,
    required this.showActiveOnly, required this.onSearch,
    required this.onToggleActive, required this.onSort,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: _C.surface,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                controller: controller,
                onChanged: onSearch,
                style: TextStyle(fontSize: 14, color: _C.text1, fontFamily: languageProvider.fontFamily),
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish
                      ? 'Search by name, contact or address…'
                      : 'نام، رابطہ یا پتے سے تلاش کریں…',
                  hintStyle: const TextStyle(color: _C.text3, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: _C.text3, size: 19),
                  suffixIcon: currentSearch.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close, size: 17, color: _C.text3),
                    onPressed: () { controller.clear(); onSearch(''); },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onToggleActive,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: showActiveOnly ? _C.brand : _C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: showActiveOnly ? _C.brand : _C.border),
              ),
              child: Row(
                children: [
                  Icon(
                    showActiveOnly ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 15,
                    color: showActiveOnly ? Colors.white : _C.text3,
                  ),
                  const SizedBox(width: 6),
                  Text(languageProvider.isEnglish ? 'Active only' : 'صرف فعال',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: showActiveOnly ? Colors.white : _C.text2,
                        fontFamily: languageProvider.fontFamily,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            onSelected: onSort,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            icon: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: const Icon(Icons.sort_rounded, color: _C.text2, size: 18),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'name',    child: Text(languageProvider.isEnglish ? 'Name A–Z' : 'نام A–Z')),
              PopupMenuItem(value: 'contact', child: Text(languageProvider.isEnglish ? 'Contact' : 'رابطہ')),
              PopupMenuItem(value: 'status',  child: Text(languageProvider.isEnglish ? 'Status' : 'حالت')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Table Header ─────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final String sortColumn;
  final bool sortAscending;
  final void Function(String) onSort;
  final LanguageProvider languageProvider;
  const _TableHeader({required this.sortColumn, required this.sortAscending, required this.onSort, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFD),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: const Color(0xFFDDD8FA)),
      ),
      child: Row(
        children: [
          _col(languageProvider.isEnglish ? 'Supplier' : 'سپلائر', 'name',    flex: 3),
          _col(languageProvider.isEnglish ? 'Contact' : 'رابطہ',  'contact', flex: 2),
          _col(languageProvider.isEnglish ? 'Address' : 'پتہ',  'address', flex: 4),
          _col(languageProvider.isEnglish ? 'Discount' : 'چھوٹ', '',        flex: 2),
          _col(languageProvider.isEnglish ? 'Status' : 'حالت',   'status',  flex: 2),
          const SizedBox(width: 90),
        ],
      ),
    );
  }

  Widget _col(String label, String col, {int flex = 1}) {
    final active = sortColumn == col && col.isNotEmpty;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: col.isNotEmpty ? () => onSort(col) : null,
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _C.text2, letterSpacing: 0.5,
                )),
            if (col.isNotEmpty) ...[
              const SizedBox(width: 3),
              Icon(
                active
                    ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 13,
                color: active ? _C.brand : _C.text3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Supplier Row ─────────────────────────────────────────────────────────────
class _SupplierRow extends StatefulWidget {
  final Supplier supplier;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final LanguageProvider languageProvider;

  const _SupplierRow({
    required this.supplier, required this.index,
    required this.onTap, required this.onEdit,
    required this.onToggle, required this.onDelete,
    required this.languageProvider,
  });

  @override
  State<_SupplierRow> createState() => _SupplierRowState();
}

class _SupplierRowState extends State<_SupplierRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    final isEven = widget.index % 2 == 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            color: _hovered ? _C.rowHover : (isEven ? Colors.white : const Color(0xFFFBFBFD)),
            border: Border(
              left: BorderSide(
                color: _hovered ? _C.brand : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: _C.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _C.brandLight,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: _C.brand, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.name,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _C.text1,
                          fontFamily: widget.languageProvider.fontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(s.contact,
                  style: TextStyle(fontSize: 13, color: _C.text2, fontFamily: widget.languageProvider.fontFamily),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  s.address?.isNotEmpty == true ? s.address! : '—',
                  style: TextStyle(
                    fontSize: 12,
                    color: s.address?.isNotEmpty == true ? _C.text2 : _C.text3,
                    fontFamily: widget.languageProvider.fontFamily,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: s.discountPercent > 0
                    ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.brand.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${s.discountPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _C.brand,
                    ),
                  ),
                )
                    : Text('—', style: TextStyle(fontSize: 13, color: _C.text3, fontFamily: widget.languageProvider.fontFamily)),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: s.isActive ? _C.green : _C.text3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.isActive
                          ? (widget.languageProvider.isEnglish ? 'Active' : 'فعال')
                          : (widget.languageProvider.isEnglish ? 'Inactive' : 'غیر فعال'),
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: s.isActive ? _C.green : _C.text3,
                        fontFamily: widget.languageProvider.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1 : 0.4,
                  duration: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionBtn(icon: Icons.edit_outlined,       color: _C.brand,   tooltip: widget.languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں', onTap: widget.onEdit, languageProvider: widget.languageProvider),
                      _ActionBtn(
                        icon: s.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: s.isActive ? _C.orange : _C.green,
                        tooltip: s.isActive
                            ? (widget.languageProvider.isEnglish ? 'Deactivate' : 'غیر فعال کریں')
                            : (widget.languageProvider.isEnglish ? 'Activate' : 'فعال کریں'),
                        onTap: widget.onToggle,
                        languageProvider: widget.languageProvider,
                      ),
                      _ActionBtn(icon: Icons.delete_outline,      color: _C.red,     tooltip: widget.languageProvider.isEnglish ? 'Delete' : 'حذف کریں', onTap: widget.onDelete, languageProvider: widget.languageProvider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAdd;
  final LanguageProvider languageProvider;
  const _EmptyState({required this.hasSearch, required this.onAdd, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: _C.brandLight, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.local_shipping_rounded, size: 40, color: _C.brand),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch
                ? (languageProvider.isEnglish ? 'No suppliers found' : 'کوئی سپلائر نہیں ملا')
                : (languageProvider.isEnglish ? 'No suppliers yet' : 'ابھی تک کوئی سپلائر نہیں'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _C.text1, fontFamily: languageProvider.fontFamily),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? (languageProvider.isEnglish ? 'Try a different search term' : 'مختلف تلاش کی اصطلاح آزمائیں')
                : (languageProvider.isEnglish ? 'Add your first supplier to get started' : 'شروع کرنے کے لیے اپنا پہلا سپلائر شامل کریں'),
            style: TextStyle(fontSize: 13, color: _C.text3, fontFamily: languageProvider.fontFamily),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(languageProvider.isEnglish ? 'Add Supplier' : 'سپلائر شامل کریں'),
              style: FilledButton.styleFrom(
                backgroundColor: _C.brand,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────
class _AddFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final LanguageProvider languageProvider;
  const _AddFAB({required this.onPressed, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: _C.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(languageProvider.isEnglish ? 'Add Supplier' : 'سپلائر شامل کریں', style: const TextStyle(fontWeight: FontWeight.w600)),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ─── Supplier Details Sheet ───────────────────────────────────────────────────
class SupplierDetailsSheet extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewLedger;
  final VoidCallback onViewPayments;
  final VoidCallback onPaySupplier;
  final LanguageProvider languageProvider;

  const SupplierDetailsSheet({
    Key? key,
    required this.supplier,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onViewLedger,
    required this.onViewPayments,
    required this.onPaySupplier,
    required this.languageProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasDiscount = supplier.discountPercent > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _C.brandLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_shipping_rounded, color: _C.brand, size: 19),
              ),
              const SizedBox(width: 12),
              Text(languageProvider.isEnglish ? 'Supplier Details' : 'سپلائر کی تفصیلات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text1, fontFamily: languageProvider.fontFamily)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: _C.text3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.brandLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDD8FA)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: _C.text1)),
                      const SizedBox(height: 3),
                      Text(supplier.contact,
                          style: TextStyle(fontSize: 13, color: _C.text3, fontFamily: languageProvider.fontFamily)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: supplier.isActive ? _C.green.withOpacity(0.1) : _C.text3.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: supplier.isActive ? _C.green.withOpacity(0.3) : _C.text3.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: supplier.isActive ? _C.green : _C.text3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        supplier.isActive
                            ? (languageProvider.isEnglish ? 'Active' : 'فعال')
                            : (languageProvider.isEnglish ? 'Inactive' : 'غیر فعال'),
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: supplier.isActive ? _C.green : _C.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _Info(languageProvider.isEnglish ? 'Contact' : 'رابطہ', supplier.contact, Icons.phone_rounded, languageProvider: languageProvider),
          if (supplier.address?.isNotEmpty == true)
            _Info(languageProvider.isEnglish ? 'Address' : 'پتہ', supplier.address!, Icons.location_on_rounded, languageProvider: languageProvider),
          if (hasDiscount)
            _Info(languageProvider.isEnglish ? 'Discount' : 'چھوٹ', '${supplier.discountPercent.toStringAsFixed(1)}%',
                Icons.local_offer_rounded, color: _C.brand, languageProvider: languageProvider),
          _Info(languageProvider.isEnglish ? 'Created' : 'بنایا گیا',
              '${supplier.createdAt.day}/${supplier.createdAt.month}/${supplier.createdAt.year}',
              Icons.calendar_today_rounded, languageProvider: languageProvider),

          const SizedBox(height: 22),

          Row(
            children: [
              _SheetBtn(
                icon: Icons.account_balance_wallet_rounded,
                label: languageProvider.isEnglish ? 'Ledger' : 'لیجر',
                color: _C.brand,
                onTap: onViewLedger,
                languageProvider: languageProvider,
              ),
              const SizedBox(width: 10),
              _SheetBtn(
                icon: Icons.history_rounded,
                label: languageProvider.isEnglish ? 'Payments' : 'ادائیگیاں',
                color: _C.blue,
                onTap: onViewPayments,
                languageProvider: languageProvider,
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              _SheetBtn(
                icon: Icons.payments_rounded,
                label: languageProvider.isEnglish ? 'Pay Supplier' : 'سپلائر کو ادائیگی کریں',
                color: _C.green,
                onTap: onPaySupplier,
                primary: true,
                languageProvider: languageProvider,
              ),
              const SizedBox(width: 10),
              _SheetBtn(
                icon: Icons.edit_rounded,
                label: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                color: _C.brand,
                onTap: onEdit,
                languageProvider: languageProvider,
              ),
            ],
          ),
          const SizedBox(height: 10),

          _SheetBtn(
            icon: supplier.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: supplier.isActive
                ? (languageProvider.isEnglish ? 'Deactivate Supplier' : 'سپلائر غیر فعال کریں')
                : (languageProvider.isEnglish ? 'Activate Supplier' : 'سپلائر فعال کریں'),
            color: supplier.isActive ? _C.red : _C.green,
            onTap: onToggleStatus,
            fullWidth: true,
            languageProvider: languageProvider,
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final LanguageProvider languageProvider;
  const _Info(this.label, this.value, this.icon, {this.color, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? _C.text3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: _C.text3,
                        fontWeight: FontWeight.w600, letterSpacing: 0.3, fontFamily: languageProvider.fontFamily)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: color ?? _C.text1, fontFamily: languageProvider.fontFamily)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool primary;
  final bool fullWidth;
  final LanguageProvider languageProvider;
  const _SheetBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
    this.primary = false, this.fullWidth = false,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(colors: [color, color.withOpacity(0.8)])
              : null,
          color: primary ? null : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary ? Colors.transparent : color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: primary ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : color,
                  fontFamily: languageProvider.fontFamily,
                )),
          ],
        ),
      ),
    );

    return fullWidth ? child : Expanded(child: child);
  }
}