import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:irfan_iron_merchant_local/screens/profit_loss_dashboard_screen.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_balance_report_screen.dart';
import 'package:provider/provider.dart';
import 'package:irfan_iron_merchant_local/Customers/customer_screen.dart';
import 'package:irfan_iron_merchant_local/Products/products_list_screen.dart';
import 'package:irfan_iron_merchant_local/screens/profit_loss_dashboard_screen.dart';
import 'package:irfan_iron_merchant_local/Purchase/purchase_orders_list_screen.dart';
import 'package:irfan_iron_merchant_local/Purchase/purchase_report_screen.dart';
import '../Auth/register_screen.dart';
import '../Banks/bank_management_screen.dart';
import '../Banks/cheque_management_screen.dart'; // Add this import
import '../Customers/customer_balance_report_screen.dart';
import '../Employee Management/employee_screen.dart';
import '../Expense Management/DailyExpenseScreen.dart';
import '../Expense Management/bill_history_screen.dart';
import '../Products/build_bom_screen.dart';
import '../Sales/sale_reports.dart';
import '../Sales/sales_list_screen.dart';
import '../cashbook/cashbook_screen.dart';
import '../components/ChartCard.dart';
import '../components/StatCard.dart';
import '../components/custom_button.dart';
import '../config/api_config.dart';
import '../models/category.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/lanprovider.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/sale_provider.dart';
import '../screens/CategoryScreen.dart';
import '../screens/UnitScreen.dart';
import '../Suppliers/SupplierScreen.dart';
import '../Auth/login_screen.dart';
import 'package:intl/intl.dart';

import '../simplecashbook/simplecashbookscreen.dart';

// Add this enum for chart type selection
enum SalesChartType {
  daily,
  monthly,
  byCategory,
  byPaymentMethod,
  byDayOfWeek,
}

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidePanelCollapsed = false;

  // Dashboard data
  Map<String, dynamic> _dashboardData = {
    'totalProducts': 0,
    'lowStockCount': 0,
    'totalInventoryValue': 0.0,
    'todayOrders': 0,
    'recentSales': [],
    'recentPurchases': [],
    'categoryDistribution': {},
    'monthlyTrend': [],
    'pendingChequesTotal': 0.0,  // Add this
    'chequesCount': 0,
    'totalEmployees': 0,
    'activeEmployees': 0,// Add this
  };

  bool _isDashboardLoading = true;
  String _selectedChartType = 'daily';
  bool _showComparison = false;

  bool get _isAdminUser {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return user?.email == 'techsoft@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
      _loadDashboardData();
    });
  }

  Future<void> _checkAuthentication() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    if (authProvider.isLoggedIn && authProvider.user == null) {
      final result = await authProvider.getProfile();
      if (!result['success'] && mounted) {
        await authProvider.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  // Add method to load cheque data
  Future<void> _loadChequeData() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).user?.token;
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/cheques?limit=200'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final cheques = data['data']['cheques'] as List;

          // Calculate pending cheques total
          double pendingTotal = 0;
          for (var cheque in cheques) {
            if (cheque['status'] == 'pending') {
              pendingTotal += (cheque['amount'] as num).toDouble();
            }
          }

          setState(() {
            _dashboardData['pendingChequesTotal'] = pendingTotal;
            _dashboardData['chequesCount'] = cheques.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cheque data: $e');
    }
  }

  // ── Load employee stats for dashboard ────────────────────────────────────────
  Future<void> _loadEmployeeStats() async {
    try {
      final empProvider = Provider.of<EmployeeProvider>(context, listen: false);
      await empProvider.loadEmployees();
      if (mounted) {
        setState(() {
          _dashboardData['totalEmployees']  = empProvider.employees.length;
          _dashboardData['activeEmployees'] = empProvider.employees.where((e) => e.isActive).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading employee stats: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isDashboardLoading = true);

    try {
      // Load all data providers
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      final purchaseProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

      await Future.wait([
        productProvider.fetchProducts(),
        categoryProvider.loadCategories(),
        saleProvider.fetchSales(),
        purchaseProvider.fetchPurchaseOrders(),
        customerProvider.fetchCustomers(),
        supplierProvider.fetchSuppliers(context: context),
        _loadChequeData(), // Add this line
        _loadEmployeeStats(),   // ← ADD THIS
      ]);

      // Calculate category distribution
      Map<String, int> categoryCount = {};
      for (var product in productProvider.products) {
        if (product.categoryId != null) {
          final category = categoryProvider.categories.firstWhere(
                (c) => c.id == product.categoryId.toString(),
            orElse: () => Category(
              id: '0',
              name: 'Uncategorized',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          categoryCount[category.name] = (categoryCount[category.name] ?? 0) + 1;
        }
      }

      // Calculate today's orders
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todaySales = saleProvider.sales.where((sale) {
        return sale.saleDate.isAfter(todayStart) && sale.saleDate.isBefore(todayEnd);
      }).length;

      final todayPurchases = purchaseProvider.purchaseOrders.where((po) {
        return po.orderDate.isAfter(todayStart) && po.orderDate.isBefore(todayEnd);
      }).length;

      final todayOrders = todaySales + todayPurchases;

      // Calculate sales by category for the chart
      Map<String, double> salesByCategory = {};
      Map<String, double> salesByPaymentMethod = {};
      Map<String, double> salesByDayOfWeek = {};
      List<Map<String, dynamic>> dailySales = [];

      // Process sales data for graphs
      for (var sale in saleProvider.sales) {
        // Sales by category
        if (sale.items != null) {
          for (var item in sale.items!) {
            final product = productProvider.products.firstWhere(
                  (p) => p.id == item.productId,
              orElse: () => ProductModel(
                id: 0,
                itemName: 'Unknown',
                costPrice: 0,
                salePrice: 0,
                physicalQty: 0,
                availableQty: 0,
                minStock: 0,
                categoryId: 0,
                unitId: 0,
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                barcode: null,
                description: null,
                category: null,
                subcategory: null,
                unit: null,
              ),
            );

            if (product.category != null) {
              final categoryName = product.category!.name;
              salesByCategory[categoryName] =
                  (salesByCategory[categoryName] ?? 0) + item.totalPrice;
            }
          }
        }

        // Sales by payment method
        final method = sale.paymentMethod ?? 'cash';
        salesByPaymentMethod[method] =
            (salesByPaymentMethod[method] ?? 0) + sale.grandTotal;

        // Sales by day of week
        final weekday = DateFormat('EEEE').format(sale.saleDate);
        salesByDayOfWeek[weekday] =
            (salesByDayOfWeek[weekday] ?? 0) + sale.grandTotal;

        // Daily sales trend (last 30 days)
        if (sale.saleDate.isAfter(DateTime.now().subtract(const Duration(days: 30)))) {
          final dateKey = DateFormat('MMM dd').format(sale.saleDate);
          dailySales.add({
            'date': dateKey,
            'amount': sale.grandTotal,
          });
        }
      }

      // Sort and limit to top 5 categories
      final sortedCategories = salesByCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCategories = sortedCategories.take(5).toList();

      // Add "Others" category
      if (sortedCategories.length > 5) {
        final othersValue = sortedCategories.skip(5).fold(0.0,
                (sum, item) => sum + item.value);
        topCategories.add(MapEntry('Others', othersValue));
      }

      // Calculate monthly trend data (last 6 months)
      List<Map<String, dynamic>> monthlyTrend = [];
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);

        double monthlySales = saleProvider.sales
            .where((sale) => sale.saleDate.isAfter(month) && sale.saleDate.isBefore(nextMonth))
            .fold(0.0, (sum, sale) => sum + sale.grandTotal);

        double monthlyPurchases = purchaseProvider.purchaseOrders
            .where((po) => po.orderDate.isAfter(month) && po.orderDate.isBefore(nextMonth))
            .fold(0.0, (sum, po) => sum + po.totalAmount);

        monthlyTrend.add({
          'month': DateFormat('MMM').format(month),
          'sales': monthlySales,
          'purchases': monthlyPurchases,
        });
      }

      setState(() {
        _dashboardData = {
          ..._dashboardData,
          'totalProducts': productProvider.products.length,
          'lowStockCount': productProvider.lowStockCount,
          'totalInventoryValue': productProvider.totalInventoryValue,
          'todayOrders': todayOrders,
          'recentSales': saleProvider.sales.take(5).toList(),
          'recentPurchases': purchaseProvider.purchaseOrders.take(5).toList(),
          'categoryDistribution': categoryCount,
          'monthlyTrend': monthlyTrend,
          'salesByCategory': topCategories,
          'salesByPaymentMethod': salesByPaymentMethod.entries.toList(),
          'salesByDayOfWeek': salesByDayOfWeek.entries.toList(),
          'dailySales': dailySales,
        };
        _isDashboardLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isDashboardLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAFAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authProvider.isLoggedIn || authProvider.user == null) {
          return const LoginScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          body: Row(
            children: [
              _buildSidePanel(authProvider),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(authProvider,languageProvider),
                    Expanded(child: _getSelectedContent(authProvider)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getSelectedContent(AuthProvider authProvider) {
    if (_isDashboardLoading && _selectedIndex == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_selectedIndex) {
      case 0:  return _buildMainContent(authProvider);
      case 1:  return ProductsListScreen();
      case 2:  return const CategoryScreen();
      case 3:  return const UnitScreen();
      case 4:  return SalesListScreen();
      case 5:  return const SupplierScreen();
      case 6:  return CustomerScreen();
      case 7:  return PurchaseOrdersListScreen();
      case 8:  return const SupplierBalanceReportScreen();
      case 9:  return const CustomerBalanceReportScreen();
      case 10: return const SaleReportScreen();
      case 11: return const PurchaseReportScreen();
      case 12: return const BuildBomScreen();
      case 13: return const ProfitLossDashboardScreen();
      case 14: return const BankManagementScreen();
      case 15: return const ChequeManagementScreen(); // Add Cheque Management at index 15
      case 16: return const CashbookScreen();  // Add CashbookScreen at index 16
      case 17: return const DailyExpenseScreen();  // Add CashbookScreen at index 16
      case 18: return const BillHistoryScreen();  // Add CashbookScreen at index 16
      case 19: return const SimpleCashbookScreen();  // Add CashbookScreen at index 16
      case 20: return const EmployeeScreen();
      case 99: return const RegisterScreen();
      default: return _buildMainContent(authProvider);
    }
  }

  Widget _buildNavItemWithCount({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    String? badge,
    int count = 0,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: _isSidePanelCollapsed ? 0 : 16, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF7C3AED).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: _isSidePanelCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                // Icon with green dot indicator when there are employees
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF6B7280),
                      size: 22,
                    ),
                    if (count > 0)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!_isSidePanelCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF6B7280),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Employee count pill
                  if (count > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  // NEW badge
                  if (badge != null)
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(AuthProvider authProvider) {
    final user = authProvider.user!;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Container(
      width: _isSidePanelCollapsed ? 80 : 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF0F0F5), width: 1)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 80,
            padding: EdgeInsets.symmetric(horizontal: _isSidePanelCollapsed ? 16 : 24),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2, color: Colors.white, size: 24),
                ),
                if (!_isSidePanelCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tech Soft', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142), letterSpacing: -0.5)),
                        Text('Innovate. Integrate.', style: TextStyle(fontSize: 11,
                            color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // User Profile
          if (!_isSidePanelCollapsed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                    child: Center(child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.bold, fontSize: 18),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(user.email, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard,
                    label: languageProvider.isEnglish
                        ? 'Over View'
                        : 'اورویو', index: 0),
                _buildNavItem(
                  icon: Icons.inventory_2_outlined,
                  selectedIcon: Icons.inventory_2,
                  label: languageProvider.isEnglish ? 'Products' : 'پروڈکٹس',
                  index: 1,
                ),

                _buildNavItem(
                  icon: Icons.category_outlined,
                  selectedIcon: Icons.category,
                  label: languageProvider.isEnglish ? 'Categories' : 'کیٹیگریز',
                  index: 2,
                ),

                _buildNavItem(
                  icon: Icons.square_foot_outlined,
                  selectedIcon: Icons.square_foot,
                  label: languageProvider.isEnglish ? 'Units' : 'یونٹس',
                  index: 3,
                ),

                _buildNavItem(
                  icon: Icons.shopping_cart_outlined,
                  selectedIcon: Icons.shopping_cart,
                  label: languageProvider.isEnglish ? 'Sales' : 'سیلز',
                  index: 4,
                ),

                _buildNavItem(
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  label: languageProvider.isEnglish ? 'Suppliers' : 'سپلائرز',
                  index: 5,
                ),

                _buildNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: languageProvider.isEnglish ? 'Customers' : 'کسٹمرز',
                  index: 6,
                ),
                _buildNavItem(
                  icon: Icons.shopping_bag_outlined,
                  selectedIcon: Icons.shopping_bag,
                  label: languageProvider.isEnglish ? 'Purchase' : 'پرچیز',
                  index: 7,
                ),
                // ── HR separator ──────────────────────────────────────
                const SizedBox(height: 8),
                if (!_isSidePanelCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                    child: Text(
                      languageProvider.isEnglish ? 'HR & PAYROLL' : 'ایچ آر',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: Colors.grey[200], height: 1),
                  ),

                _buildNavItemWithCount(
                  icon: Icons.badge_outlined,
                  selectedIcon: Icons.badge,
                  label: languageProvider.isEnglish ? 'Employees' : 'ملازمین',
                  index: 20,
                  badge: 'NEW',
                  count: _dashboardData['totalEmployees'] as int? ?? 0,
                ),



                // ── Banking Section ──────────────────────────────────────
                const SizedBox(height: 8),

                if (!_isSidePanelCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                    child: Text(
                      languageProvider.isEnglish ? 'BANKING' : 'بینکنگ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: Colors.grey[200], height: 1),
                  ),

                _buildNavItem(
                  icon: Icons.account_balance_outlined,
                  selectedIcon: Icons.account_balance,
                  label: languageProvider.isEnglish ? 'Bank Management' : 'بینک مینجمنٹ',
                  index: 14,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.receipt_outlined,
                  selectedIcon: Icons.receipt,
                  label: languageProvider.isEnglish ? 'Cheque Management' : 'چیک مینجمنٹ',
                  index: 15,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet,
                  label: languageProvider.isEnglish ? 'Cashbook' : 'کیش بک',
                  index: 16,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet,
                  label: languageProvider.isEnglish ? 'Simple Cashbook' : 'سادہ کیش بک',
                  index: 19,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet,
                  label: languageProvider.isEnglish ? 'Expense Management' : 'اخراجات مینجمنٹ',
                  index: 17,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet,
                  label: languageProvider.isEnglish ? 'Bill History Page' : 'بل ہسٹری پیج',
                  index: 18,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.build_outlined,
                  selectedIcon: Icons.build,
                  label: languageProvider.isEnglish ? 'Build BOM' : 'BOM بنائیں',
                  index: 12,
                  badge: 'BOM',
                ),

// ── Reports Section ──────────────────────────────────────
                const SizedBox(height: 8),

                if (!_isSidePanelCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                    child: Text(
                      languageProvider.isEnglish ? 'REPORTS' : 'رپورٹس',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: Colors.grey[200], height: 1),
                  ),

                _buildNavItem(
                  icon: Icons.assessment_outlined,
                  selectedIcon: Icons.assessment,
                  label: languageProvider.isEnglish ? 'Supplier Report' : 'سپلائر رپورٹ',
                  index: 8,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.assessment_outlined,
                  selectedIcon: Icons.assessment,
                  label: languageProvider.isEnglish ? 'Customer Report' : 'کسٹمر رپورٹ',
                  index: 9,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.assessment_outlined,
                  selectedIcon: Icons.assessment,
                  label: languageProvider.isEnglish ? 'Sale Report' : 'سیل رپورٹ',
                  index: 10,
                  badge: 'NEW',
                ),

                _buildNavItem(
                  icon: Icons.assessment_outlined,
                  selectedIcon: Icons.assessment,
                  label: languageProvider.isEnglish ? 'Purchase Report' : 'پرچیز رپورٹ',
                  index: 11,
                  badge: 'NEW',
                ),

// ── Settings Section ──────────────────────────────────────
                const SizedBox(height: 8),

                if (!_isSidePanelCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                    child: Text(
                      languageProvider.isEnglish ? 'SETTINGS' : 'سیٹنگز',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                _buildNavItem(
                  icon: Icons.trending_up_outlined,
                  selectedIcon: Icons.trending_up,
                  label: languageProvider.isEnglish ? 'Profit & Loss' : 'منافع و نقصان',
                  index: 13,
                  badge: 'NEW',
                ),

// ── Admin Section ──────────────────────────────────────
                if (_isAdminUser) ...[
                  const SizedBox(height: 8),

                  if (!_isSidePanelCollapsed)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                      child: Text(
                        languageProvider.isEnglish ? 'ADMIN' : 'ایڈمن',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400],
                          letterSpacing: 1.2,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),

                  _buildNavItem(
                    icon: Icons.person_add_outlined,
                    selectedIcon: Icons.person_add,
                    label: languageProvider.isEnglish ? 'Register User' : 'صارف رجسٹر کریں',
                    index: 99,
                    badge: 'ADMIN',
                  ),
                ],
              ],
            ),
          ),

          // Collapse & Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0F0F5), width: 1))),
            child: Column(
              children: [
                if (!_isSidePanelCollapsed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(authProvider),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else
                  IconButton(onPressed: () => _showLogoutDialog(authProvider),
                      icon: const Icon(Icons.logout), color: const Color(0xFFEF4444)),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => setState(() => _isSidePanelCollapsed = !_isSidePanelCollapsed),
                  icon: Icon(_isSidePanelCollapsed ? Icons.chevron_right : Icons.chevron_left),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    String? badge,
  })
  {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: _isSidePanelCollapsed ? 0 : 16, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: _isSidePanelCollapsed
                  ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(isSelected ? selectedIcon : icon,
                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF6B7280),
                    size: 22),
                if (!_isSidePanelCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: TextStyle(fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF6B7280),
                      letterSpacing: 0.2))),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge, style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AuthProvider authProvider,LanguageProvider languageProvider) {
    final user = authProvider.user!;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              height: 45,
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12)),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search inventory, orders, suppliers...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                    shape: BoxShape.circle),
                child: Center(child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                )),
              ),
              const SizedBox(width: 10),
              Text(user.name, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: languageProvider.toggleLanguage,
            tooltip: languageProvider.isEnglish ? 'Switch to Urdu' : 'انگریزی میں تبدیل کریں',
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AuthProvider authProvider) {
    if (_isDashboardLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_getPageTitle(), style: const TextStyle(fontSize: 28,
                      fontWeight: FontWeight.bold, color: Color(0xFF2D3142), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(_getPageSubtitle(), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ]),
                CustomButton(text: 'Add Product', icon: Icons.add, onPressed: () {
                  setState(() => _selectedIndex = 1);
                },
                    width: 160, height: 48, useGradient: true,
                    gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)]),
              ],
            ),
            const SizedBox(height: 32),

            // Stats Cards with Dynamic Data - Add Cheque Stats
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.3,
              children: [
                StatCard(
                  title: 'Total Products',
                  value: _formatNumber(_dashboardData['totalProducts']),
                  icon: Icons.inventory_2,
                  color: const Color(0xFF7C3AED),
                  showTrend: true,
                  trendValue: '+${_dashboardData['totalProducts'] > 0 ? "12%" : "0%"}',
                  isPositiveTrend: true,
                ),
                StatCard(
                  title: 'Low Stock',
                  value: _dashboardData['lowStockCount'].toString(),
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFFF6B6B),
                  showTrend: true,
                  trendValue: '+${_dashboardData['lowStockCount']}',
                  isPositiveTrend: false,
                ),
                StatCard(
                  title: 'Total Value',
                  value: 'Rs ${_formatCurrency(_dashboardData['totalInventoryValue'])}',
                  icon: Icons.attach_money,
                  color: const Color(0xFF10B981),
                  showTrend: true,
                  trendValue: '+8%',
                  isPositiveTrend: true,
                ),
                StatCard(
                  title: 'Pending Cheques',
                  value: 'Rs ${_formatCurrency(_dashboardData['pendingChequesTotal'] ?? 0)}',
                  icon: Icons.receipt,
                  color: const Color(0xFFF59E0B),
                  showTrend: true,
                  trendValue: '${_dashboardData['chequesCount'] ?? 0} total',
                  isPositiveTrend: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Enhanced Sales Chart Section with Filters
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sales Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      Row(
                        children: [
                          // Chart Type Selector
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _buildChartTypeButton('Daily', 'daily', Icons.calendar_view_day),
                                _buildChartTypeButton('Monthly', 'monthly', Icons.calendar_view_month),
                                _buildChartTypeButton('Category', 'category', Icons.category),
                                _buildChartTypeButton('Payment', 'payment', Icons.payment),
                                _buildChartTypeButton('Weekday', 'weekday', Icons.event),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Comparison Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _buildToggleButton(
                                  label: 'Sales',
                                  isSelected: !_showComparison,
                                  onTap: () => setState(() => _showComparison = false),
                                ),
                                _buildToggleButton(
                                  label: 'vs Purchases',
                                  isSelected: _showComparison,
                                  onTap: () => setState(() => _showComparison = true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Dynamic Chart based on selection
                  _buildDynamicSalesChart(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Recent Orders and Quick Stats
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: _buildRecentOrders()),
              const SizedBox(width: 20),
              Expanded(child: _buildQuickStats()),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTypeButton(String label, String value, IconData icon) {
    final isSelected = _selectedChartType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedChartType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicSalesChart() {
    if (_showComparison) {
      // Show Sales vs Purchases comparison
      final monthlyTrend = _dashboardData['monthlyTrend'] as List? ?? [];

      if (monthlyTrend.isEmpty) {
        return _buildEmptyChart('No comparison data available');
      }

      final maxValue = monthlyTrend.fold<double>(
          0,
              (max, item) => max > (item['sales'] as num).toDouble()
              ? max
              : (item['sales'] as num).toDouble()
      );

      final chartData = monthlyTrend.map<BarChartData>((item) {
        return BarChartData(
          label: item['month'],
          value1: (item['sales'] as num).toDouble(),
          value2: (item['purchases'] as num).toDouble(),
        );
      }).toList();

      return Column(
        children: [
          SizedBox(
            height: 250,
            child: SimpleBarChart(
              data: chartData,
              maxValue: maxValue * 1.2,
              primaryColor: const Color(0xFF7C3AED),
              secondaryColor: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Sales', const Color(0xFF7C3AED)),
              const SizedBox(width: 24),
              _buildLegendItem('Purchases', const Color(0xFF3B82F6)),
            ],
          ),
        ],
      );
    }

    // Show different sales charts based on selected type
    switch (_selectedChartType) {
      case 'daily':
        return _buildDailySalesChart();
      case 'monthly':
        return _buildMonthlySalesChart();
      case 'category':
        return _buildCategorySalesChart();
      case 'payment':
        return _buildPaymentMethodChart();
      case 'weekday':
        return _buildWeekdaySalesChart();
      default:
        return _buildDailySalesChart();
    }
  }

  Widget _buildDailySalesChart() {
    final dailySales = _dashboardData['dailySales'] as List? ?? [];

    if (dailySales.isEmpty) {
      return _buildEmptyChart('No daily sales data available');
    }

    // Group by date and sum amounts
    final Map<String, double> groupedSales = {};
    for (var sale in dailySales) {
      final date = sale['date'] as String;
      groupedSales[date] = (groupedSales[date] ?? 0) + (sale['amount'] as num).toDouble();
    }

    final sortedDates = groupedSales.keys.toList()..sort();
    final chartData = sortedDates.map((date) {
      return BarChartData(
        label: date,
        value1: groupedSales[date]!,
      );
    }).toList();

    final maxValue = chartData.fold<double>(
        0,
            (max, item) => max > item.value1 ? max : item.value1
    );

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: SimpleBarChart(
            data: chartData,
            maxValue: maxValue * 1.2,
            primaryColor: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Last 30 Days Sales Trend',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlySalesChart() {
    final monthlyTrend = _dashboardData['monthlyTrend'] as List? ?? [];

    if (monthlyTrend.isEmpty) {
      return _buildEmptyChart('No monthly sales data available');
    }

    final chartData = monthlyTrend.map<BarChartData>((item) {
      return BarChartData(
        label: item['month'],
        value1: (item['sales'] as num).toDouble(),
      );
    }).toList();

    final maxValue = chartData.fold<double>(
        0,
            (max, item) => max > item.value1 ? max : item.value1
    );

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: SimpleBarChart(
            data: chartData,
            maxValue: maxValue * 1.2,
            primaryColor: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Monthly Sales (Last 6 Months)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];

    final hash = category.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySalesChart() {
    final salesByCategory = _dashboardData['salesByCategory'] as List<MapEntry<String, double>>? ?? [];

    if (salesByCategory.isEmpty) {
      return _buildEmptyChart('No category sales data available');
    }

    final total = salesByCategory.fold(0.0, (sum, item) => sum + item.value);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Row(
            children: salesByCategory.map((item) {
              final percentage = total > 0 ? (item.value / total) : 0;
              return Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 40,
                        height: 140 * percentage.toDouble(),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(item.key),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      item.key.length > 8 ? '${item.key.substring(0, 6)}...' : item.key,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        color: _getCategoryColor(item.key),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: salesByCategory.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(item.key),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.key,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Rs ${_formatCurrency(item.value)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodChart() {
    final salesByPayment = _dashboardData['salesByPaymentMethod'] as List<MapEntry<String, double>>? ?? [];

    if (salesByPayment.isEmpty) {
      return _buildEmptyChart('No payment method data available');
    }

    final paymentColors = {
      'cash': const Color(0xFF10B981),
      'bank': const Color(0xFF3B82F6),
      'cheque': const Color(0xFFF59E0B),
      'slip': const Color(0xFF8B5CF6),
      'credit': const Color(0xFFEF4444),
    };

    final total = salesByPayment.fold(0.0, (sum, item) => sum + item.value);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Row(
            children: salesByPayment.map((item) {
              final percentage = total > 0 ? (item.value / total) : 0;
              final color = paymentColors[item.key] ?? Colors.grey;
              return Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 40,
                        height: 140 * percentage.toDouble(),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      item.key,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          children: salesByPayment.map((item) {
            final color = paymentColors[item.key] ?? Colors.grey;
            return _buildLegendItem('${item.key} (${(item.value / total * 100).toStringAsFixed(1)}%)', color);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWeekdaySalesChart() {
    final salesByWeekday = _dashboardData['salesByDayOfWeek'] as List<MapEntry<String, double>>? ?? [];

    if (salesByWeekday.isEmpty) {
      return _buildEmptyChart('No weekday sales data available');
    }

    // Order days correctly
    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final orderedData = dayOrder
        .map((day) => salesByWeekday.firstWhere(
          (item) => item.key == day,
      orElse: () => MapEntry(day, 0.0),
    ))
        .toList();

    final maxValue = orderedData.fold<double>(
        0,
            (max, item) => max > item.value ? max : item.value
    );

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Row(
            children: orderedData.map((item) {
              final percentage = maxValue > 0 ? (item.value / maxValue) : 0;
              return Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 30,
                        height: 140 * percentage.toDouble(),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.7),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      item.key.substring(0, 3),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Rs ${_formatCurrency(item.value)}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sales by Day of Week',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    if (value is int) {
      if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
      return value.toString();
    }
    return value.toString();
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  Widget _buildRecentOrders() {
    final recentSales = _dashboardData['recentSales'] as List;
    final recentPurchases = _dashboardData['recentPurchases'] as List;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent Orders', style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
          TextButton(onPressed: () => setState(() => _selectedIndex = 4), child: const Text('View All')),
        ]),
        const SizedBox(height: 20),

        if (recentSales.isEmpty && recentPurchases.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No recent orders', style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
          )
        else ...[
          // Show recent sales
          ...recentSales.take(3).map((sale) => _buildOrderItem(
            'SALE-${sale.id}',
            '${sale.items?.length ?? 0} items',
            'Rs ${_formatCurrency(sale.grandTotal)}',
            sale.paymentStatus == 'paid' ? 'Completed' : sale.paymentStatus,
            sale.paymentStatus == 'paid' ? Colors.green : Colors.orange,
          )),

          // Show recent purchases
          ...recentPurchases.take(2).map((purchase) => _buildOrderItem(
            purchase.poNumber,
            purchase.supplier?.name ?? 'Unknown',
            'Rs ${_formatCurrency(purchase.totalAmount)}',
            purchase.statusText,
            purchase.status == 'received' ? Colors.green :
            purchase.status == 'ordered' ? Colors.blue :
            purchase.status == 'partial' ? Colors.orange : Colors.grey,
          )),
        ],
      ]),
    );
  }

  Widget _buildOrderItem(String orderId, String product, String price, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFC), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0F0F5))),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF7C3AED))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(orderId, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(product, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildQuickStats() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);

    // Calculate total revenue from sales
    double totalRevenue = saleProvider.sales.fold(
        0.0,
            (sum, sale) => sum + sale.grandTotal
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.trending_up, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text('Quick Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        const SizedBox(height: 24),
        _buildQuickStatItem(
            'Total Revenue',
            'Rs ${_formatCurrency(totalRevenue)}',
            Icons.attach_money
        ),
        _buildQuickStatItem(
            'Total Products',
            '${productProvider.products.length}',
            Icons.inventory_2
        ),
        _buildQuickStatItem(
            'Customers',
            '${customerProvider.customers.length}',
            Icons.people
        ),
        _buildQuickStatItem(
            'Suppliers',
            '${supplierProvider.suppliers.length}',
            Icons.business
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedIndex = 8),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Detailed Report', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ])),
      ]),
    );
  }

  String _getPageTitle() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    switch (_selectedIndex) {
      case 0:  return languageProvider.isEnglish ? 'Dashboard' : 'ڈیش بورڈ';
      case 1:  return languageProvider.isEnglish ? 'Products' : 'آئٹمز';
      case 2:  return languageProvider.isEnglish ? 'Categories' : 'کیٹاگوریز';
      case 3:  return 'Units Management';
      case 4:  return 'Sales';
      case 5:  return 'Suppliers';
      case 6:  return 'Customers';
      case 7:  return 'Purchase Orders';
      case 8:  return 'Supplier Balance Report';
      case 9:  return 'Customer Balance Report';
      case 10: return 'Sale Report';
      case 11: return 'Purchase Report';
      case 12: return 'Build BOM';
      case 13: return 'Profit & Loss Dashboard';
      case 14: return 'Bank Management';
      case 15: return 'Cheque Management';
      case 16: return 'Cashbook';  // Add this
      case 19: return 'Simple Cashbook';  // Add this
      case 17: return 'Expense Management';  // Add this
      case 18: return 'Bill History Page';  // Add this
      case 20: return languageProvider.isEnglish ? 'Employees' : 'ملازمین';
      case 99: return 'Register New User';
      default: return 'Dashboard';
    }
  }

  String _getPageSubtitle() {
    switch (_selectedIndex) {
      case 0:  return 'Welcome back! Here\'s what\'s happening with your inventory.';
      case 1:  return 'Manage your product inventory';
      case 2:  return 'Organize products into categories';
      case 3:  return 'Configure measurement units for your inventory';
      case 4:  return 'Track and manage orders';
      case 5:  return 'Manage your supplier relationships';
      case 6:  return 'View customer records';
      case 7:  return 'Track purchase orders and receipts';
      case 8:  return 'Outstanding balances and payment status for all suppliers';
      case 9:  return 'Outstanding balances and payment status for all customers';
      case 10: return 'Sales analytics and performance overview';
      case 11: return 'Purchase analytics and procurement overview';
      case 12: return 'Build finished goods from component inventory';
      case 13: return 'Track your profits, losses, and savings from sales and purchases';
      case 14: return 'Manage bank accounts, track balances, and record transactions';
      case 15: return 'Track cheques, manage clearing, bouncing, and cancellation';
      case 16: return 'Track all cash transactions, inflows, and outflows';  // Add this
      case 19: return 'Track all cash transactions, inflows, and outflows in Simple Cashbook';  // Add this
      case 17: return 'Track all Expense transactions, inflows, and outflows';  // Add this
      case 18: return 'Track all Bills, inflows, and outflows';  // Add this
      case 20: return 'Manage employees, attendance, and salary calculations';
      case 99: return 'Create a new user account';
      default: return '';
    }
  }

  Future<void> _showLogoutDialog(AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }
}

// Simple Bar Chart Widget
class BarChartData {
  final String label;
  final double value1;
  final double value2;

  BarChartData({
    required this.label,
    required this.value1,
    this.value2 = 0,
  });
}

class SimpleBarChart extends StatelessWidget {
  final List<BarChartData> data;
  final double maxValue;
  final Color primaryColor;
  final Color secondaryColor;

  const SimpleBarChart({
    super.key,
    required this.data,
    required this.maxValue,
    required this.primaryColor,
    this.secondaryColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((item) {
        final height1 = (item.value1 / maxValue) * 200;
        final height2 = (item.value2 / maxValue) * 200;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (secondaryColor != Colors.transparent && item.value2 > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: height2,
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              if (item.value1 > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: height1,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
