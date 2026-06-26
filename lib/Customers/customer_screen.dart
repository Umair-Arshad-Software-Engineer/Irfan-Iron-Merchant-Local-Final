import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../components/confirmation_dialog.dart';
import '../components/customer_form_dialog.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../components/custom_button.dart';
import '../providers/lanprovider.dart';
import 'customer_adjustment_dialog.dart';
import 'customer_balance_report_screen.dart';
import 'customer_invoice_payment_screen.dart';
import 'customer_ledger_screen.dart';
import 'customer_payments_screen.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
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

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({Key? key}) : super(key: key);

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showActiveOnly = false;
  String _currentSearch = '';
  String _selectedType = 'all';
  bool _hasInitialized = false;
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // Responsive state
  bool _isMobile = true;
  bool _isTablet = false;

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
    final p = Provider.of<CustomerProvider>(context, listen: false);
    _hasInitialized = true;
    await p.fetchCustomers();
    await p.fetchActiveCustomers();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreCustomers();
    }
  }

  Future<void> _loadMoreCustomers() async {
    final p = Provider.of<CustomerProvider>(context, listen: false);
    if (p.hasMorePages && !p.isLoading) {
      await p.fetchCustomers(
        page: p.currentPage + 1,
        search: _currentSearch,
        active: _showActiveOnly ? true : null,
        customerType: _selectedType != 'all' ? _selectedType : null,
      );
    }
  }

  Future<void> _refreshCustomers() async {
    final p = Provider.of<CustomerProvider>(context, listen: false);
    await p.fetchCustomers(
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
      customerType: _selectedType != 'all' ? _selectedType : null,
    );
  }

  void _handleSearch(String value) {
    if (value == _currentSearch) return;
    _currentSearch = value;
    final p = Provider.of<CustomerProvider>(context, listen: false);
    p.clearCustomers();
    p.fetchCustomers(
      search: value,
      active: _showActiveOnly ? true : null,
      customerType: _selectedType != 'all' ? _selectedType : null,
    );
  }

  void _toggleActiveFilter() {
    setState(() => _showActiveOnly = !_showActiveOnly);
    final p = Provider.of<CustomerProvider>(context, listen: false);
    p.clearCustomers();
    p.fetchCustomers(
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
      customerType: _selectedType != 'all' ? _selectedType : null,
    );
  }

  void _handleTypeFilter(String type) {
    setState(() => _selectedType = type);
    final p = Provider.of<CustomerProvider>(context, listen: false);
    p.clearCustomers();
    p.fetchCustomers(
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
      customerType: type != 'all' ? type : null,
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

  void _sortCustomers(List<Customer> customers) {
    customers.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'name':    cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase()); break;
        case 'contact': cmp = a.contact.compareTo(b.contact); break;
        case 'email':   cmp = (a.email ?? '').compareTo(b.email ?? ''); break;
        case 'type':    cmp = a.customerType.compareTo(b.customerType); break;
        case 'balance': cmp = a.balance.compareTo(b.balance); break;
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
        return Consumer<CustomerProvider>(
          builder: (context, provider, _) {
            final sorted = List<Customer>.from(provider.customers);
            _sortCustomers(sorted);

            return Scaffold(
              backgroundColor: _C.bg,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = constraints.maxWidth >= _C.tabletBreakpoint;
                  return _ResponsiveScaffold(
                    isMobile: _isMobile,
                    isTablet: _isTablet,
                    isWeb: isWeb,
                    child: RefreshIndicator(
                      color: _C.brand,
                      onRefresh: _refreshCustomers,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                _Header(
                                  provider: provider,
                                  onReports: _navigateToReports,
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
                                  languageProvider: languageProvider,
                                  isMobile: _isMobile,
                                  isWeb: isWeb,
                                ),
                                _TypeChips(
                                  selected: _selectedType,
                                  onSelect: _handleTypeFilter,
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
                            child: SizedBox(height: _isMobile ? 80 : 32),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              floatingActionButton: _isMobile
                  ? _AddFAB(
                onPressed: () => _showAddCustomerDialog(languageProvider),
                languageProvider: languageProvider,
                isWeb: false,
              )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildBodyWithSliver(CustomerProvider provider, List<Customer> customers, LanguageProvider lp, bool isWeb) {
    if (provider.isLoading && customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              const CircularProgressIndicator(color: _C.brand),
              const SizedBox(height: 16),
              Text(
                lp.isEnglish ? 'Loading customers...' : 'کسٹمرز لوڈ ہو رہے ہیں...',
                style: TextStyle(
                  color: _C.text3,
                  fontFamily: lp.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (customers.isEmpty) {
      return _EmptyState(
        hasSearch: _currentSearch.isNotEmpty,
        onAdd: () => _showAddCustomerDialog(lp),
        languageProvider: lp,
        isWeb: isWeb,
      );
    }

    final padding = isWeb
        ? EdgeInsets.symmetric(horizontal: _getWebPadding(), vertical: 8)
        : const EdgeInsets.fromLTRB(16, 8, 16, 16);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      controller: _scrollController,
      padding: padding,
      itemCount: customers.length + 1,
      itemBuilder: (context, i) {
        if (i < customers.length) {
          return _CustomerRow(
            customer: customers[i],
            index: i,
            isMobile: _isMobile,
            isWeb: isWeb,
            onTap: () => _showCustomerDetails(customers[i], lp),
            onEdit: () => _showEditCustomerDialog(customers[i], lp),
            onToggle: () => _toggleCustomerStatus(customers[i]),
            onDelete: () => _deleteCustomer(customers[i]),
            languageProvider: lp,
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

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerBalanceReportScreen()),
    ).then((_) => _refreshCustomers());
  }

  Future<void> _showAddCustomerDialog(LanguageProvider lp) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CustomerFormDialog(languageProvider: lp),
    );
    if (result?['success'] == true) {
      _showSnack(result!['message'], _C.green, lp);
      _refreshCustomers();
    }
  }

  Future<void> _showEditCustomerDialog(Customer customer, LanguageProvider lp) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CustomerFormDialog(
        customer: customer,
        languageProvider: lp,
      ),
    );
    if (result?['success'] == true) {
      _showSnack(result!['message'], _C.green, lp);
      _refreshCustomers();
    }
  }

  void _showCustomerDetails(Customer customer, LanguageProvider lp) {
    final isWeb = MediaQuery.of(context).size.width >= _C.tabletBreakpoint;

    if (isWeb) {
      _showWebCustomerDetails(customer, lp);
    } else {
      _showMobileCustomerDetails(customer, lp);
    }
  }

  void _showWebCustomerDetails(Customer customer, LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: CustomerDetailsSheet(
            customer: customer,
            languageProvider: lp,
            isWeb: true,
            onEdit: () { Navigator.pop(context); _showEditCustomerDialog(customer, lp); },
            onToggleStatus: () { Navigator.pop(context); _toggleCustomerStatus(customer); },
            onViewLedger: () { Navigator.pop(context); _viewCustomerLedger(customer, lp); },
            onViewPayments: () { Navigator.pop(context); _viewCustomerPayments(customer, lp); },
            onReceivePayment: () { Navigator.pop(context); _receiveCustomerPayment(customer, lp); },
            onAdjustBalance: () { Navigator.pop(context); _adjustCustomerBalance(customer, lp); },
          ),
        ),
      ),
    );
  }

  void _showMobileCustomerDetails(Customer customer, LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerDetailsSheet(
        customer: customer,
        languageProvider: lp,
        isWeb: false,
        onEdit: () { Navigator.pop(context); _showEditCustomerDialog(customer, lp); },
        onToggleStatus: () { Navigator.pop(context); _toggleCustomerStatus(customer); },
        onViewLedger: () { Navigator.pop(context); _viewCustomerLedger(customer, lp); },
        onViewPayments: () { Navigator.pop(context); _viewCustomerPayments(customer, lp); },
        onReceivePayment: () { Navigator.pop(context); _receiveCustomerPayment(customer, lp); },
        onAdjustBalance: () { Navigator.pop(context); _adjustCustomerBalance(customer, lp); },
      ),
    );
  }

  void _viewCustomerLedger(Customer c, LanguageProvider lp) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => CustomerLedgerScreen(customer: c, languageProvider: lp)));
  }

  void _viewCustomerPayments(Customer c, LanguageProvider lp) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => CustomerPaymentsScreen(customer: c, languageProvider: lp)));
  }

  Future<void> _receiveCustomerPayment(Customer c, LanguageProvider lp) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerInvoicePaymentScreen(customer: c, languageProvider: lp)),
    );
    if (ok == true) {
      _refreshCustomers();
      _showSnack(lp.isEnglish ? 'Payment recorded successfully' : 'ادائیگی کامیابی سے ریکارڈ ہوگئی', _C.green, lp);
    }
  }

  Future<void> _adjustCustomerBalance(Customer c, LanguageProvider lp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerAdjustmentDialog(customer: c, languageProvider: lp),
    );
    if (ok == true) {
      _refreshCustomers();
      _showSnack(lp.isEnglish ? 'Balance adjusted successfully' : 'بیلنس کامیابی سے ایڈجسٹ ہوگیا', _C.brand, lp);
    }
  }

  Future<void> _toggleCustomerStatus(Customer c) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final ok = await showConfirmationDialog(
      context,
      title: c.isActive
          ? (lp.isEnglish ? 'Deactivate Customer' : 'کسٹمر غیر فعال کریں')
          : (lp.isEnglish ? 'Activate Customer' : 'کسٹمر فعال کریں'),
      message: c.isActive
          ? (lp.isEnglish ? 'Are you sure you want to deactivate ${c.name}?' : 'کیا آپ واقعی ${c.name} کو غیر فعال کرنا چاہتے ہیں؟')
          : (lp.isEnglish ? 'Are you sure you want to activate ${c.name}?' : 'کیا آپ واقعی ${c.name} کو فعال کرنا چاہتے ہیں؟'),
      confirmText: c.isActive
          ? (lp.isEnglish ? 'Deactivate' : 'غیر فعال کریں')
          : (lp.isEnglish ? 'Activate' : 'فعال کریں'),
      confirmColor: c.isActive ? _C.red : _C.green,
    );
    if (ok == true) {
      final p = Provider.of<CustomerProvider>(context, listen: false);
      final result = await p.toggleCustomerStatus(c.id);
      _showSnack(result['message'], result['success'] ? _C.green : _C.red, lp);
      if (result['success']) _refreshCustomers();
    }
  }

  Future<void> _deleteCustomer(Customer c) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final ok = await showConfirmationDialog(
      context,
      title: lp.isEnglish ? 'Delete Customer' : 'کسٹمر حذف کریں',
      message: lp.isEnglish
          ? 'Are you sure you want to delete ${c.name}? This cannot be undone.'
          : 'کیا آپ واقعی ${c.name} کو حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں کیا جا سکتا۔',
      confirmText: lp.isEnglish ? 'Delete' : 'حذف کریں',
      confirmColor: _C.red,
    );
    if (ok == true) {
      final p = Provider.of<CustomerProvider>(context, listen: false);
      final result = await p.deleteCustomer(c.id);
      _showSnack(result['message'], result['success'] ? _C.green : _C.red, lp);
      if (result['success']) _refreshCustomers();
    }
  }

  void _showSnack(String msg, Color color, LanguageProvider lp) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontWeight: FontWeight.w500, fontFamily: lp.fontFamily)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ─── Responsive Scaffold ──────────────────────────────────────────────────
class _ResponsiveScaffold extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isWeb;
  final Widget child;

  const _ResponsiveScaffold({
    required this.isMobile,
    required this.isTablet,
    required this.isWeb,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isWeb) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: child,
        ),
      );
    }
    return child;
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final CustomerProvider provider;
  final VoidCallback onReports;
  final LanguageProvider languageProvider;
  final bool isMobile;
  final bool isWeb;

  const _Header({
    required this.provider,
    required this.onReports,
    required this.languageProvider,
    required this.isMobile,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final active = provider.customers.where((c) => c.isActive).length;
    final withBal = provider.customers.where((c) => c.balance > 0).length;
    final total = provider.totalOutstandingBalance;

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
                child: Icon(Icons.people_alt_rounded, color: _C.brand, size: isMobile ? 18 : 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.isEnglish ? 'Customers' : 'کسٹمرز',
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
                      languageProvider.isEnglish ? 'Manage relationships & balances' : 'تعلقات اور بیلنس کا انتظام کریں',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.grey.shade500,
                        fontFamily: languageProvider.fontFamily,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              _ReportsButton(
                onPressed: onReports,
                languageProvider: languageProvider,
                isMobile: isMobile,
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12.0 : 20.0),
          _buildStatsRow(active, withBal, total, context),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int active, int withBal, double total, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    if (isWide) {
      return Row(
        children: [
          _StatTile(
            label: languageProvider.isEnglish ? 'Total' : 'کل',
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
            label: languageProvider.isEnglish ? 'With Balance' : 'بیلنس والے',
            value: withBal.toString(),
            color: _C.orange,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
          _divider(),
          _StatTile(
            label: languageProvider.isEnglish ? 'Total Owed' : 'کل بقایا',
            value: total.toStringAsFixed(2),
            color: _C.red,
            isAmount: true,
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
            label: languageProvider.isEnglish ? 'Total' : 'کل',
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
            label: languageProvider.isEnglish ? 'With Balance' : 'بیلنس والے',
            value: withBal.toString(),
            color: _C.orange,
            languageProvider: languageProvider,
            isMobile: isMobile,
          ),
          _StatTile(
            label: languageProvider.isEnglish ? 'Total Owed' : 'کل بقایا',
            value: total.toStringAsFixed(2),
            color: _C.red,
            isAmount: true,
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
  final bool isAmount;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.isAmount = false,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (isAmount) Text(
                'PKR ',
                style: TextStyle(
                  fontSize: isMobile ? 9.0 : 10.0,
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
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
        ],
      ),
    );
  }
}

class _ReportsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _ReportsButton({
    required this.onPressed,
    required this.languageProvider,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.brand,
          side: const BorderSide(color: _C.brand),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(40, 40),
        ),
        child: Icon(Icons.bar_chart_rounded, size: 14),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.bar_chart_rounded, size: 16),
      label: Text(
        languageProvider.isEnglish ? 'Reports' : 'رپورٹس',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.brand,
        side: const BorderSide(color: _C.brand),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  final LanguageProvider languageProvider;
  final bool isMobile;
  final bool isWeb;

  const _SearchBar({
    required this.controller,
    required this.currentSearch,
    required this.showActiveOnly,
    required this.onSearch,
    required this.onToggleActive,
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
                      : (languageProvider.isEnglish ? 'Search by name, contact, email…' : 'نام، رابطہ، ای میل سے تلاش کریں…'),
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

// ─── Type Chips ──────────────────────────────────────────────────────────────
class _TypeChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final LanguageProvider languageProvider;
  final bool isMobile;
  final bool isWeb;

  const _TypeChips({
    required this.selected,
    required this.onSelect,
    required this.languageProvider,
    required this.isMobile,
    required this.isWeb,
  });

  List<Map<String, dynamic>> get _types => [
    {'id': 'all',       'label': languageProvider.isEnglish ? 'All' : 'سب',       'color': _C.brand,   'icon': Icons.grid_view_rounded},
    {'id': 'regular',   'label': languageProvider.isEnglish ? 'Regular' : 'عام',   'color': _C.blue,    'icon': Icons.person_rounded},
    {'id': 'retail',    'label': languageProvider.isEnglish ? 'Retail' : 'خوردہ',    'color': _C.green,   'icon': Icons.shopping_bag_rounded},
    {'id': 'wholesale', 'label': languageProvider.isEnglish ? 'Wholesale' : 'تھوک', 'color': _C.orange,  'icon': Icons.warehouse_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 24.0,
        vertical: isMobile ? 8.0 : 10.0,
      ),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _types.map((t) {
            final id = t['id'] as String;
            final label = t['label'] as String;
            final color = t['color'] as Color;
            final icon = t['icon'] as IconData;
            final isSelected = selected == id;
            return Padding(
              padding: EdgeInsets.only(right: isMobile ? 6.0 : 8.0),
              child: GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10.0 : 14.0,
                    vertical: isMobile ? 6.0 : 7.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color : _C.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: isMobile ? 12.0 : 14.0,
                          color: isSelected ? Colors.white : color),
                      const SizedBox(width: 6),
                      if (!isMobile)
                        Text(label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : _C.text2,
                              fontFamily: languageProvider.fontFamily,
                            )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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

    final headers = [
      {'label': languageProvider.isEnglish ? 'Customer' : 'کسٹمر', 'column': 'name', 'flex': isWide ? 3 : 2, 'rightAlign': false},
      {'label': languageProvider.isEnglish ? 'Contact' : 'رابطہ', 'column': 'contact', 'flex': isWide ? 2 : 1, 'rightAlign': false},
      if (isWide)
        {'label': languageProvider.isEnglish ? 'Email' : 'ای میل', 'column': 'email', 'flex': 3, 'rightAlign': false},
      {'label': languageProvider.isEnglish ? 'Type' : 'قسم', 'column': 'type', 'flex': isWide ? 2 : 1, 'rightAlign': false},
      {'label': languageProvider.isEnglish ? 'Balance' : 'بیلنس', 'column': 'balance', 'flex': isWide ? 2 : 1, 'rightAlign': true},
      {'label': languageProvider.isEnglish ? 'Status' : 'حالت', 'column': 'status', 'flex': isWide ? 2 : 1, 'rightAlign': false},
    ];

    final padding = isWeb
        ? EdgeInsets.symmetric(horizontal: _getWebPadding(screenWidth), vertical: 10.0)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return Container(
      margin: EdgeInsets.fromLTRB(
        isWeb ? _getWebPadding(screenWidth) : 16.0,
        12.0,
        isWeb ? _getWebPadding(screenWidth) : 16.0,
        0.0,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFD),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: const Color(0xFFDDD8FA)),
      ),
      child: Row(
        children: [
          ...headers.map((h) => Expanded(
            flex: h['flex'] as int,
            child: GestureDetector(
              onTap: () => onSort(h['column'] as String),
              child: Row(
                mainAxisAlignment: (h['rightAlign'] as bool) ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(h['label'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.text2,
                        letterSpacing: 0.5,
                      )),
                  const SizedBox(width: 3),
                  Icon(
                    sortColumn == h['column']
                        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 13,
                    color: sortColumn == h['column'] ? _C.brand : _C.text3,
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(width: 100),
        ],
      ),
    );
  }

  double _getWebPadding(double screenWidth) {
    if (screenWidth > 1400) return 48;
    if (screenWidth > 1200) return 32;
    return 24;
  }
}

// ─── Customer Row ─────────────────────────────────────────────────────────────
class _CustomerRow extends StatefulWidget {
  final Customer customer;
  final int index;
  final bool isMobile;
  final bool isWeb;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final LanguageProvider languageProvider;

  const _CustomerRow({
    required this.customer,
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
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  bool _hovered = false;

  Color _typeColor(String t) {
    switch (t) {
      case 'wholesale': return _C.orange;
      case 'retail':    return _C.green;
      default:          return _C.blue;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'wholesale': return Icons.warehouse_rounded;
      case 'retail':    return Icons.shopping_bag_rounded;
      default:          return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final isEven = widget.index % 2 == 0;
    final tc = _typeColor(c.customerType);
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
                color: _hovered ? tc : Colors.transparent,
                width: 3.0,
              ),
              bottom: const BorderSide(color: _C.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: widget.isMobile
              ? _buildMobileRow(c, tc)
              : _buildDesktopRow(c, tc, isWide, screenWidth),
        ),
      ),
    );
  }

  Widget _buildMobileRow(Customer c, Color tc) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_typeIcon(c.customerType), color: tc, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.text1,
                        fontFamily: widget.languageProvider.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(c.contact,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _BalanceBadge(
              balance: c.balance,
              formatted: c.formattedBalance,
              languageProvider: widget.languageProvider,
              isMobile: true,
            ),
            const SizedBox(height: 4),
            _StatusDot(
              active: c.isActive,
              languageProvider: widget.languageProvider,
              isMobile: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopRow(Customer c, Color tc, bool isWide, double screenWidth) {
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
                  color: tc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_typeIcon(c.customerType), color: tc, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.text1,
                        fontFamily: widget.languageProvider.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.address != null && c.address!.isNotEmpty)
                      Text(c.address!,
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
          child: Text(c.contact,
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
            flex: 3,
            child: Text(c.email ?? '—',
              style: TextStyle(
                fontSize: 12,
                color: c.email != null ? _C.text2 : _C.text3,
                fontFamily: widget.languageProvider.fontFamily,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Expanded(
          flex: isWide ? 2 : 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: tc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(c.typeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tc,
                  fontFamily: widget.languageProvider.fontFamily,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: isWide ? 2 : 1,
          child: Align(
            alignment: Alignment.centerRight,
            child: _BalanceBadge(
              balance: c.balance,
              formatted: c.formattedBalance,
              languageProvider: widget.languageProvider,
              isMobile: false,
            ),
          ),
        ),
        Expanded(
          flex: isWide ? 2 : 1,
          child: _StatusDot(
            active: c.isActive,
            languageProvider: widget.languageProvider,
            isMobile: false,
          ),
        ),
        SizedBox(
          width: isWide ? 100.0 : 80.0,
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
                  icon: c.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: c.isActive ? _C.orange : _C.green,
                  tooltip: c.isActive
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

class _BalanceBadge extends StatelessWidget {
  final double balance;
  final String formatted;
  final LanguageProvider languageProvider;
  final bool isMobile;

  const _BalanceBadge({
    required this.balance,
    required this.formatted,
    required this.languageProvider,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final owing = balance > 0.01;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6.0 : 8.0,
        vertical: isMobile ? 2.0 : 3.0,
      ),
      decoration: BoxDecoration(
        color: owing ? _C.red.withOpacity(0.08) : _C.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatted,
        style: TextStyle(
          fontSize: isMobile ? 11.0 : 12.0,
          fontWeight: FontWeight.w700,
          color: owing ? _C.red : _C.green,
          fontFamily: languageProvider.fontFamily,
        ),
      ),
    );
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
                Icons.people_outline_rounded,
                size: isWeb ? 50 : 40,
                color: _C.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch
                  ? (languageProvider.isEnglish ? 'No customers found' : 'کوئی کسٹمر نہیں ملا')
                  : (languageProvider.isEnglish ? 'No customers yet' : 'ابھی تک کوئی کسٹمر نہیں'),
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
                  : (languageProvider.isEnglish ? 'Add your first customer to get started' : 'شروع کرنے کے لیے اپنا پہلا کسٹمر شامل کریں'),
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
                icon: Icon(Icons.person_add_rounded, size: isWeb ? 19 : 17),
                label: Text(
                  languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں',
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
  final bool isWeb;

  const _AddFAB({
    required this.onPressed,
    required this.languageProvider,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    if (isWeb) {
      return FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: _C.brand,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_rounded, size: 24),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
    }
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: _C.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_rounded, size: 20),
      label: Text(
        languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ─── Customer Details Sheet ──────────────────────────────────────────────────
class CustomerDetailsSheet extends StatelessWidget {
  final Customer customer;
  final LanguageProvider languageProvider;
  final bool isWeb;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewLedger;
  final VoidCallback onViewPayments;
  final VoidCallback onReceivePayment;
  final VoidCallback onAdjustBalance;

  const CustomerDetailsSheet({
    Key? key,
    required this.customer,
    required this.languageProvider,
    required this.isWeb,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onViewLedger,
    required this.onViewPayments,
    required this.onReceivePayment,
    required this.onAdjustBalance,
  }) : super(key: key);

  Color _typeColor(String t) {
    switch (t) {
      case 'wholesale': return _C.orange;
      case 'retail':    return _C.green;
      default:          return _C.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final owing      = customer.balance > 0.01;
    final hasDiscount = customer.discountPercent > 0;
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
                child: const Icon(Icons.person_outline_rounded, color: _C.brand, size: 19),
              ),
              const SizedBox(width: 12),
              Text(
                languageProvider.isEnglish ? 'Customer Details' : 'کسٹمر کی تفصیلات',
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
                      Text(customer.name,
                          style: TextStyle(
                            fontSize: isWeb ? 19.0 : 17.0,
                            fontWeight: FontWeight.w700,
                            color: _C.text1,
                            fontFamily: languageProvider.fontFamily,
                          )),
                      const SizedBox(height: 3),
                      Text(customer.contact,
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
                    color: owing ? _C.red.withOpacity(0.1) : _C.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: owing ? _C.red.withOpacity(0.3) : _C.green.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(owing
                          ? (languageProvider.isEnglish ? 'OWING' : 'بقایا')
                          : (languageProvider.isEnglish ? 'CLEAR' : 'صاف'),
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            color: owing ? _C.red : _C.green,
                            letterSpacing: 0.8,
                            fontFamily: languageProvider.fontFamily,
                          )),
                      const SizedBox(height: 3),
                      Text(customer.formattedBalance,
                          style: TextStyle(
                            fontSize: isWeb ? 17.0 : 15.0,
                            fontWeight: FontWeight.w700,
                            color: owing ? _C.red : _C.green,
                            fontFamily: languageProvider.fontFamily,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _Info(languageProvider.isEnglish ? 'Contact' : 'رابطہ', customer.contact, Icons.phone_rounded, languageProvider: languageProvider),
          if (customer.email?.isNotEmpty ?? false)
            _Info(languageProvider.isEnglish ? 'Email' : 'ای میل', customer.email!, Icons.email_rounded, languageProvider: languageProvider),
          if (customer.address?.isNotEmpty ?? false)
            _Info(languageProvider.isEnglish ? 'Address' : 'پتہ', customer.address!, Icons.location_on_rounded, languageProvider: languageProvider),
          if (hasDiscount)
            _Info(languageProvider.isEnglish ? 'Discount' : 'چھوٹ', '${customer.discountPercent.toStringAsFixed(1)}%',
                Icons.local_offer_rounded, color: _C.brand, languageProvider: languageProvider),
          _Info(languageProvider.isEnglish ? 'Type' : 'قسم', customer.typeLabel, Icons.category_rounded,
              color: _typeColor(customer.customerType), languageProvider: languageProvider),
          _Info(languageProvider.isEnglish ? 'Status' : 'حالت',
              customer.isActive
                  ? (languageProvider.isEnglish ? 'Active' : 'فعال')
                  : (languageProvider.isEnglish ? 'Inactive' : 'غیر فعال'),
              customer.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: customer.isActive ? _C.green : _C.red,
              languageProvider: languageProvider),
          _Info(languageProvider.isEnglish ? 'Created' : 'بنایا گیا',
              '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
              Icons.calendar_today_rounded, languageProvider: languageProvider),

          const SizedBox(height: 22),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SheetBtn(
                icon: Icons.receipt_long_rounded,
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
              if (owing) ...[
                _SheetBtn(
                  icon: Icons.payments_rounded,
                  label: languageProvider.isEnglish ? 'Receive Payment' : 'ادائیگی وصول کریں',
                  color: _C.green,
                  onTap: onReceivePayment,
                  primary: true,
                  languageProvider: languageProvider,
                  isWeb: isWeb,
                ),
                _SheetBtn(
                  icon: Icons.swap_horiz_rounded,
                  label: languageProvider.isEnglish ? 'Adjust' : 'ایڈجسٹ کریں',
                  color: _C.orange,
                  onTap: onAdjustBalance,
                  languageProvider: languageProvider,
                  isWeb: isWeb,
                ),
              ] else ...[
                _SheetBtn(
                  icon: Icons.edit_rounded,
                  label: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                  color: _C.brand,
                  onTap: onEdit,
                  languageProvider: languageProvider,
                  isWeb: isWeb,
                ),
                _SheetBtn(
                  icon: customer.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  label: customer.isActive
                      ? (languageProvider.isEnglish ? 'Deactivate' : 'غیر فعال کریں')
                      : (languageProvider.isEnglish ? 'Activate' : 'فعال کریں'),
                  color: customer.isActive ? _C.red : _C.green,
                  onTap: onToggleStatus,
                  languageProvider: languageProvider,
                  isWeb: isWeb,
                ),
              ],
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