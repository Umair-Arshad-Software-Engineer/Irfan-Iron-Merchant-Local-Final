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

  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
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

  // Responsive state
  bool _isMobile = true;
  bool _isTablet = false;

  // Sorting
  String _sortColumn = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeData();
      _updateResponsiveState();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateResponsiveState() {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _isMobile = width < _C.mobileBreakpoint;
      _isTablet = width >= _C.mobileBreakpoint && width < _C.tabletBreakpoint;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResponsiveState();
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
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWeb = constraints.maxWidth >= _C.tabletBreakpoint;
                      return RefreshIndicator(
                        color: _C.brand,
                        onRefresh: _refresh,
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _Header(
                                    provider: provider,
                                    languageProvider: languageProvider,
                                    isMobile: _isMobile,
                                    isWeb: isWeb,
                                  ),
                                  _SearchBar(
                                    controller: _searchController,
                                    currentSearch: _currentSearch,
                                    showActiveOnly: _showActiveOnly,
                                    onSearch: _handleSearch,
                                    onToggleActive: _toggleActiveFilter,
                                    onSort: _toggleSort,
                                    languageProvider: languageProvider,
                                    isMobile: _isMobile,
                                    isWeb: isWeb,
                                  ),
                                  if (!_isMobile)
                                    _TableHeader(
                                      sortColumn: _sortColumn,
                                      sortAscending: _sortAscending,
                                      onSort: _toggleSort,
                                      languageProvider: languageProvider,
                                      isWeb: isWeb,
                                    ),
                                ],
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _buildBodyWithSliver(provider, sorted, languageProvider, isWeb),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: _isMobile ? 80.0 : 32.0),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  floatingActionButton: _AddFAB(
                    onPressed: () => _showAddSupplierDialog(languageProvider),
                    languageProvider: languageProvider,
                    isMobile: _isMobile,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBodyWithSliver(SupplierProvider provider, List<Supplier> suppliers, LanguageProvider languageProvider, bool isWeb) {
    if (provider.isLoading && suppliers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              const CircularProgressIndicator(color: _C.brand),
              const SizedBox(height: 16),
              Text(
                languageProvider.isEnglish ? 'Loading suppliers...' : 'سپلائرز لوڈ ہو رہے ہیں...',
                style: TextStyle(
                  color: _C.text3,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (suppliers.isEmpty) {
      return _EmptyState(
        hasSearch: _currentSearch.isNotEmpty,
        onAdd: () => _showAddSupplierDialog(languageProvider),
        languageProvider: languageProvider,
        isWeb: isWeb,
      );
    }

    final padding = isWeb
        ? EdgeInsets.symmetric(horizontal: _getWebPadding(), vertical: 8.0)
        : const EdgeInsets.fromLTRB(16, 8, 16, 16);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      controller: _scrollController,
      padding: padding,
      itemCount: suppliers.length + 1,
      itemBuilder: (context, i) {
        if (i < suppliers.length) {
          return _SupplierRow(
            supplier: suppliers[i],
            index: i,
            isMobile: _isMobile,
            isWeb: isWeb,
            onTap: () => _showSupplierDetails(suppliers[i], languageProvider),
            onEdit: () => _showEditSupplierDialog(suppliers[i], languageProvider),
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

  double _getWebPadding() {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 48;
    if (width > 1200) return 32;
    return 24;
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
    final isWeb = MediaQuery.of(context).size.width >= _C.tabletBreakpoint;

    if (isWeb) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: SupplierDetailsSheet(
              supplier: supplier,
              isWeb: true,
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
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SupplierDetailsSheet(
          supplier: supplier,
          isWeb: false,
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
  final bool isMobile;
  final bool isWeb;

  const _Header({
    required this.provider,
    required this.languageProvider,
    required this.isMobile,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final active = provider.suppliers.where((s) => s.isActive).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16.0 : 28.0,
        isMobile ? 16.0 : 28.0,
        isMobile ? 16.0 : 28.0,
        isMobile ? 12.0 : 20.0,
      ),
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
                width: isMobile ? 36.0 : 44.0,
                height: isMobile ? 36.0 : 44.0,
                decoration: BoxDecoration(
                  color: _C.brandLight,
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
                child: Icon(Icons.local_shipping_rounded, color: _C.brand, size: isMobile ? 18 : 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.isEnglish ? 'Suppliers' : 'سپلائرز',
                    style: TextStyle(
                      fontSize: isMobile ? 18.0 : 22.0,
                      fontWeight: FontWeight.w700,
                      color: _C.text1,
                      letterSpacing: -0.4,
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                  if (!isMobile)
                    Text(
                      languageProvider.isEnglish ? 'Manage supplier relationships & contacts' : 'سپلائر تعلقات اور رابطوں کا انتظام کریں',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.grey.shade500,
                        fontFamily: languageProvider.fontFamily,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (!isMobile)
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
          SizedBox(height: isMobile ? 12.0 : 20.0),
          _buildStatsRow(active, context),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int active, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    if (isWide) {
      return Row(
        children: [
          _StatTile(
            label: languageProvider.isEnglish ? 'Total Suppliers' : 'کل سپلائرز',
            value: provider.totalItems.toString(),
            color: _C.brand,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
          _divider(),
          _StatTile(
            label: languageProvider.isEnglish ? 'Active' : 'فعال',
            value: active.toString(),
            color: _C.green,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
          _divider(),
          _StatTile(
            label: languageProvider.isEnglish ? 'Inactive' : 'غیر فعال',
            value: (provider.totalItems - active).toString(),
            color: _C.text3,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
        ],
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatTile(
            label: languageProvider.isEnglish ? 'Total Suppliers' : 'کل سپلائرز',
            value: provider.totalItems.toString(),
            color: _C.brand,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
          _StatTile(
            label: languageProvider.isEnglish ? 'Active' : 'فعال',
            value: active.toString(),
            color: _C.green,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
          _StatTile(
            label: languageProvider.isEnglish ? 'Inactive' : 'غیر فعال',
            value: (provider.totalItems - active).toString(),
            color: _C.text3,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
        ],
      );
    }
  }

  Widget _divider() => Container(
    width: 1.0,
    height: 36.0,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: _C.border,
  );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.languageProvider,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4.0 : 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10.0 : 11.0,
              color: _C.text3,
              fontWeight: FontWeight.w500,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16.0 : 20.0,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ],
      ),
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
  final bool isMobile;
  final bool isWeb;

  const _SearchBar({
    required this.controller,
    required this.currentSearch,
    required this.showActiveOnly,
    required this.onSearch,
    required this.onToggleActive,
    required this.onSort,
    required this.languageProvider,
    required this.isMobile,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 24.0,
        vertical: isMobile ? 8.0 : 14.0,
      ),
      color: _C.surface,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: isMobile ? 40.0 : 44.0,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                controller: controller,
                onChanged: onSearch,
                style: TextStyle(
                  fontSize: isMobile ? 13.0 : 14.0,
                  color: _C.text1,
                  fontFamily: languageProvider.fontFamily,
                ),
                decoration: InputDecoration(
                  hintText: isMobile
                      ? (languageProvider.isEnglish ? 'Search…' : 'تلاش کریں…')
                      : (languageProvider.isEnglish
                      ? 'Search by name, contact or address…'
                      : 'نام، رابطہ یا پتے سے تلاش کریں…'),
                  hintStyle: const TextStyle(color: _C.text3, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: _C.text3, size: isMobile ? 17 : 19),
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
          if (!isMobile || isWeb)
            _FilterPill(
              label: languageProvider.isEnglish ? 'Active only' : 'صرف فعال',
              selected: showActiveOnly,
              onTap: onToggleActive,
              languageProvider: languageProvider,
              isMobile: isMobile,
            ),
          if (!isMobile)
            const SizedBox(width: 10),
          if (!isMobile)
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

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.languageProvider,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10.0 : 14.0,
          vertical: isMobile ? 7.0 : 9.0,
        ),
        decoration: BoxDecoration(
          color: selected ? _C.brand : _C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _C.brand : _C.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: isMobile ? 13 : 15,
              color: selected ? Colors.white : _C.text3,
            ),
            const SizedBox(width: 6),
            if (!isMobile)
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : _C.text2,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
          ],
        ),
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
  final bool isWeb;

  const _TableHeader({
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.languageProvider,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isWeb ? _getWebPadding(screenWidth) : 16.0,
        12.0,
        isWeb ? _getWebPadding(screenWidth) : 16.0,
        0.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFD),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: const Color(0xFFDDD8FA)),
      ),
      child: Row(
        children: [
          _col(languageProvider.isEnglish ? 'Supplier' : 'سپلائر', 'name',    flex: isWide ? 3 : 2),
          _col(languageProvider.isEnglish ? 'Contact' : 'رابطہ',  'contact', flex: isWide ? 2 : 1),
          if (isWide)
            _col(languageProvider.isEnglish ? 'Address' : 'پتہ',  'address', flex: 4),
          _col(languageProvider.isEnglish ? 'Discount' : 'چھوٹ', '',        flex: isWide ? 2 : 1),
          _col(languageProvider.isEnglish ? 'Status' : 'حالت',   'status',  flex: isWide ? 2 : 1),
          SizedBox(width: isWide ? 90.0 : 60.0),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.text2,
                  letterSpacing: 0.5,
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

  double _getWebPadding(double screenWidth) {
    if (screenWidth > 1400) return 48;
    if (screenWidth > 1200) return 32;
    return 24;
  }
}

// ─── Supplier Row ─────────────────────────────────────────────────────────────
class _SupplierRow extends StatefulWidget {
  final Supplier supplier;
  final int index;
  final bool isMobile;
  final bool isWeb;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final LanguageProvider languageProvider;

  const _SupplierRow({
    required this.supplier,
    required this.index,
    required this.isMobile,
    required this.isWeb,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.symmetric(
            horizontal: widget.isWeb ? _getWebPadding(screenWidth) : 0.0,
          ),
          decoration: BoxDecoration(
            color: _hovered ? _C.rowHover : (isEven ? Colors.white : const Color(0xFFFBFBFD)),
            border: Border(
              left: BorderSide(
                color: _hovered ? _C.brand : Colors.transparent,
                width: 3.0,
              ),
              bottom: const BorderSide(color: _C.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: widget.isMobile
              ? _buildMobileRow(s)
              : _buildDesktopRow(s, isWide, screenWidth),
        ),
      ),
    );
  }

  Widget _buildMobileRow(Supplier s) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: _C.brandLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _C.brand, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.text1,
                        fontFamily: widget.languageProvider.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(s.contact,
                      style: TextStyle(
                        fontSize: 11,
                        color: _C.text3,
                        fontFamily: widget.languageProvider.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusDot(
          active: s.isActive,
          languageProvider: widget.languageProvider,
          isMobile: true,
        ),
      ],
    );
  }

  Widget _buildDesktopRow(Supplier s, bool isWide, double screenWidth) {
    return Row(
      children: [
        Expanded(
          flex: isWide ? 3 : 2,
          child: Row(
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: _C.brandLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _C.brand, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.text1,
                        fontFamily: widget.languageProvider.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.address != null && s.address!.isNotEmpty)
                      Text(s.address!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _C.text3,
                          fontFamily: widget.languageProvider.fontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: isWide ? 2 : 1,
          child: Text(s.contact,
            style: TextStyle(
              fontSize: 13,
              color: _C.text2,
              fontFamily: widget.languageProvider.fontFamily,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isWide)
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
          flex: isWide ? 2 : 1,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.brand,
              ),
            ),
          )
              : Text('—', style: TextStyle(fontSize: 13, color: _C.text3, fontFamily: widget.languageProvider.fontFamily)),
        ),
        Expanded(
          flex: isWide ? 2 : 1,
          child: _StatusDot(
            active: s.isActive,
            languageProvider: widget.languageProvider,
            isMobile: false,
          ),
        ),
        SizedBox(
          width: isWide ? 90.0 : 60.0,
          child: AnimatedOpacity(
            opacity: _hovered ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 120),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  color: _C.brand,
                  tooltip: widget.languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                  onTap: widget.onEdit,
                  languageProvider: widget.languageProvider,
                ),
                _ActionBtn(
                  icon: s.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: s.isActive ? _C.orange : _C.green,
                  tooltip: s.isActive
                      ? (widget.languageProvider.isEnglish ? 'Deactivate' : 'غیر فعال کریں')
                      : (widget.languageProvider.isEnglish ? 'Activate' : 'فعال کریں'),
                  onTap: widget.onToggle,
                  languageProvider: widget.languageProvider,
                ),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  color: _C.red,
                  tooltip: widget.languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                  onTap: widget.onDelete,
                  languageProvider: widget.languageProvider,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _getWebPadding(double screenWidth) {
    if (screenWidth > 1400) return 48;
    if (screenWidth > 1200) return 32;
    return 24;
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _StatusDot({
    required this.active,
    required this.languageProvider,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = active
        ? (languageProvider.isEnglish ? 'Active' : 'فعال')
        : (languageProvider.isEnglish ? 'Inactive' : 'غیر فعال');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMobile ? 6.0 : 7.0,
          height: isMobile ? 6.0 : 7.0,
          decoration: BoxDecoration(
            color: active ? _C.green : _C.text3,
            shape: BoxShape.circle,
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: active ? _C.green : _C.text3,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    required this.languageProvider,
  });

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
  final bool isWeb;

  const _EmptyState({
    required this.hasSearch,
    required this.onAdd,
    required this.languageProvider,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 48.0 : 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isWeb ? 100.0 : 80.0,
              height: isWeb ? 100.0 : 80.0,
              decoration: BoxDecoration(
                color: _C.brandLight,
                borderRadius: BorderRadius.circular(isWeb ? 24 : 20),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                size: isWeb ? 50 : 40,
                color: _C.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch
                  ? (languageProvider.isEnglish ? 'No suppliers found' : 'کوئی سپلائر نہیں ملا')
                  : (languageProvider.isEnglish ? 'No suppliers yet' : 'ابھی تک کوئی سپلائر نہیں'),
              style: TextStyle(
                fontSize: isWeb ? 20.0 : 17.0,
                fontWeight: FontWeight.w600,
                color: _C.text1,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? (languageProvider.isEnglish ? 'Try a different search term' : 'مختلف تلاش کی اصطلاح آزمائیں')
                  : (languageProvider.isEnglish ? 'Add your first supplier to get started' : 'شروع کرنے کے لیے اپنا پہلا سپلائر شامل کریں'),
              style: TextStyle(
                fontSize: isWeb ? 14.0 : 13.0,
                color: _C.text3,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: Icon(Icons.add_rounded, size: isWeb ? 19 : 17),
                label: Text(
                  languageProvider.isEnglish ? 'Add Supplier' : 'سپلائر شامل کریں',
                  style: TextStyle(fontSize: isWeb ? 15.0 : 13.0),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.brand,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 28.0 : 20.0,
                    vertical: isWeb ? 14.0 : 12.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────
class _AddFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _AddFAB({
    required this.onPressed,
    required this.languageProvider,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMobile) {
      return FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: _C.brand,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 24),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
    }
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: _C.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(
        languageProvider.isEnglish ? 'Add Supplier' : 'سپلائر شامل کریں',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ─── Supplier Details Sheet ───────────────────────────────────────────────────
class SupplierDetailsSheet extends StatelessWidget {
  final Supplier supplier;
  final bool isWeb;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewLedger;
  final VoidCallback onViewPayments;
  final VoidCallback onPaySupplier;
  final LanguageProvider languageProvider;

  const SupplierDetailsSheet({
    Key? key,
    required this.supplier,
    required this.isWeb,
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
    final padding = isWeb ? 32.0 : 24.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isWeb
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        padding,
        isWeb ? 24.0 : 20.0,
        padding,
        isWeb ? 24.0 : MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWeb)
            Center(
              child: Container(
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (!isWeb) const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _C.brandLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _C.brand, size: 19),
              ),
              const SizedBox(width: 12),
              Text(
                languageProvider.isEnglish ? 'Supplier Details' : 'سپلائر کی تفصیلات',
                style: TextStyle(
                  fontSize: isWeb ? 18.0 : 16.0,
                  fontWeight: FontWeight.w700,
                  color: _C.text1,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
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
                          style: TextStyle(
                            fontSize: isWeb ? 19.0 : 17.0,
                            fontWeight: FontWeight.w700,
                            color: _C.text1,
                            fontFamily: languageProvider.fontFamily,
                          )),
                      const SizedBox(height: 3),
                      Text(supplier.contact,
                          style: TextStyle(
                            fontSize: isWeb ? 14.0 : 13.0,
                            color: _C.text3,
                            fontFamily: languageProvider.fontFamily,
                          )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: supplier.isActive ? _C.green.withOpacity(0.1) : _C.text3.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: supplier.isActive ? _C.green.withOpacity(0.3) : _C.text3.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6.0,
                        height: 6.0,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: supplier.isActive ? _C.green : _C.text3,
                          fontFamily: languageProvider.fontFamily,
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

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SheetBtn(
                icon: Icons.account_balance_wallet_rounded,
                label: languageProvider.isEnglish ? 'Ledger' : 'لیجر',
                color: _C.brand,
                onTap: onViewLedger,
                languageProvider: languageProvider,
                isWeb: isWeb,
              ),
              _SheetBtn(
                icon: Icons.history_rounded,
                label: languageProvider.isEnglish ? 'Payments' : 'ادائیگیاں',
                color: _C.blue,
                onTap: onViewPayments,
                languageProvider: languageProvider,
                isWeb: isWeb,
              ),
              _SheetBtn(
                icon: Icons.payments_rounded,
                label: languageProvider.isEnglish ? 'Pay Supplier' : 'سپلائر کو ادائیگی کریں',
                color: _C.green,
                onTap: onPaySupplier,
                primary: true,
                languageProvider: languageProvider,
                isWeb: isWeb,
              ),
              _SheetBtn(
                icon: Icons.edit_rounded,
                label: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                color: _C.brand,
                onTap: onEdit,
                languageProvider: languageProvider,
                isWeb: isWeb,
              ),
              _SheetBtn(
                icon: supplier.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: supplier.isActive
                    ? (languageProvider.isEnglish ? 'Deactivate' : 'غیر فعال کریں')
                    : (languageProvider.isEnglish ? 'Activate' : 'فعال کریں'),
                color: supplier.isActive ? _C.red : _C.green,
                onTap: onToggleStatus,
                languageProvider: languageProvider,
                isWeb: isWeb,
              ),
            ],
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

  const _Info(
      this.label,
      this.value,
      this.icon, {
        this.color,
        required this.languageProvider,
      });

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
                    style: TextStyle(
                      fontSize: 10,
                      color: _C.text3,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      fontFamily: languageProvider.fontFamily,
                    )),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color ?? _C.text1,
                      fontFamily: languageProvider.fontFamily,
                    )),
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
  final LanguageProvider languageProvider;
  final bool isWeb;

  const _SheetBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.primary = false,
    required this.languageProvider,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isWeb ? 160.0 : double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary ? Colors.white : color,
                    fontFamily: languageProvider.fontFamily,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}