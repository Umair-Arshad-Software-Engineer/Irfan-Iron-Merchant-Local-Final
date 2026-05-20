import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_ledger_screen.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_payment_dialog.dart';
import 'package:irfan_iron_merchant_local/Suppliers/supplier_payments_screen.dart';
import '../components/confirmation_dialog.dart';
import '../components/supplier_form_dialog.dart';
import '../components/supplier_list_item.dart';
import '../models/supplier.dart';
import '../providers/supplier_provider.dart';
import '../providers/auth_provider.dart';
import '../components/custom_button.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({Key? key}) : super(key: key);

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showActiveOnly = false;
  bool _isSearching = false;
  String _currentSearch = '';
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Defer initialization until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeData();
      }
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

    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

    _hasInitialized = true;
    await supplierProvider.fetchSuppliers(context: context);
    await supplierProvider.fetchActiveSuppliers(context);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreSuppliers();
    }
  }

  Future<void> _loadMoreSuppliers() async {
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

    if (supplierProvider.hasMorePages && !supplierProvider.isLoading) {
      await supplierProvider.fetchSuppliers(
        context: context,
        page: supplierProvider.currentPage + 1,
        search: _currentSearch,
        active: _showActiveOnly ? true : null,
      );
    }
  }

  Future<void> _refreshSuppliers() async {
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
    await supplierProvider.fetchSuppliers(
      context: context,
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
    );
  }

  void _handleSearch(String value) {
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

    if (value != _currentSearch) {
      _currentSearch = value;
      supplierProvider.clearSuppliers();
      supplierProvider.fetchSuppliers(
        context: context,
        search: value,
        active: _showActiveOnly ? true : null,
      );
    }
  }

  void _toggleActiveFilter() {
    setState(() {
      _showActiveOnly = !_showActiveOnly;
    });

    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
    supplierProvider.clearSuppliers();
    supplierProvider.fetchSuppliers(
      context: context,
      search: _currentSearch,
      active: _showActiveOnly ? true : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isLoggedIn) {
          return const Center(
            child: Text('Please login to access suppliers'),
          );
        }

        return Consumer<SupplierProvider>(
          builder: (context, supplierProvider, child) {
            return Scaffold(
              backgroundColor: const Color(0xFFFAFAFC),
              body: Column(
                children: [
                  // Header Section
                  _buildHeader(supplierProvider),

                  // Search and Filter Section
                  _buildSearchFilterSection(),

                  // Main Content
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshSuppliers,
                      child: _buildSupplierList(supplierProvider),
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showAddSupplierDialog(),
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(SupplierProvider supplierProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F5), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suppliers Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your supplier relationships and contacts',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              CustomButton(
                text: 'Export',
                icon: Icons.download,
                onPressed: () {},
                width: 120,
                height: 48,
                backgroundColor: Colors.white,
                textColor: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                'Total Suppliers',
                supplierProvider.totalItems.toString(),
                Icons.people,
                const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Active',
                supplierProvider.suppliers
                    .where((s) => s.isActive)
                    .length
                    .toString(),
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F5), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => _handleSearch(value),
                decoration: InputDecoration(
                  hintText: 'Search suppliers by name, contact or address...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _currentSearch.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _handleSearch('');
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: Text(
              'Active Only',
              style: TextStyle(
                color: _showActiveOnly ? Colors.white : const Color(0xFF7C3AED),
              ),
            ),
            selected: _showActiveOnly,
            onSelected: (_) => _toggleActiveFilter(),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF7C3AED),
            side: BorderSide(color: const Color(0xFF7C3AED)),
            checkmarkColor: Colors.white,
          ),
          const SizedBox(width: 12),
          PopupMenuButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.sort, color: Color(0xFF6B7280)),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'name_asc',
                child: Text('Name A-Z'),
              ),
              const PopupMenuItem(
                value: 'name_desc',
                child: Text('Name Z-A'),
              ),
              const PopupMenuItem(
                value: 'recent',
                child: Text('Recently Added'),
              ),
              const PopupMenuItem(
                value: 'oldest',
                child: Text('Oldest'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierList(SupplierProvider supplierProvider) {
    if (supplierProvider.isLoading && supplierProvider.suppliers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (supplierProvider.suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              _currentSearch.isEmpty
                  ? 'No suppliers found'
                  : 'No suppliers match your search',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentSearch.isEmpty
                  ? 'Add your first supplier to get started'
                  : 'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            if (_currentSearch.isEmpty)
              CustomButton(
                text: 'Add Supplier',
                icon: Icons.add,
                onPressed: () => _showAddSupplierDialog(),
                width: 160,
                height: 48,
                useGradient: true,
                gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      itemCount: supplierProvider.suppliers.length + 1,
      itemBuilder: (context, index) {
        if (index < supplierProvider.suppliers.length) {
          final supplier = supplierProvider.suppliers[index];
          return SupplierListItem(
            supplier: supplier,
            onTap: () => _showSupplierDetails(supplier),
            onEdit: () => _showEditSupplierDialog(supplier),
            onToggleStatus: () => _toggleSupplierStatus(supplier),
            onDelete: () => _deleteSupplier(supplier),
          );
        } else {
          return supplierProvider.isLoading
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
              : supplierProvider.hasMorePages
              ? const SizedBox(height: 20)
              : Container();
        }
      },
    );
  }

  Future<void> _showAddSupplierDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const SupplierFormDialog(),
    );

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showEditSupplierDialog(Supplier supplier) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SupplierFormDialog(supplier: supplier),
    );

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSupplierDetails(Supplier supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SupplierDetailsSheet(
        supplier: supplier,
        onEdit: () {
          Navigator.pop(context);
          _showEditSupplierDialog(supplier);
        },
        onToggleStatus: () {
          Navigator.pop(context);
          _toggleSupplierStatus(supplier);
        },
        onViewLedger: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupplierLedgerScreen(supplier: supplier),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleSupplierStatus(Supplier supplier) async {
    final confirm = await showConfirmationDialog(
      context,
      title: supplier.isActive ? 'Deactivate Supplier' : 'Activate Supplier',
      message: supplier.isActive
          ? 'Are you sure you want to deactivate ${supplier.name}?'
          : 'Are you sure you want to activate ${supplier.name}?',
      confirmText: supplier.isActive ? 'Deactivate' : 'Activate',
      confirmColor: supplier.isActive ? Colors.red : Colors.green,
    );

    if (confirm == true) {
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
      final result = await supplierProvider.toggleSupplierStatus(supplier.id, context);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirm = await showConfirmationDialog(
      context,
      title: 'Delete Supplier',
      message: 'Are you sure you want to delete ${supplier.name}? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
      final result = await supplierProvider.deleteSupplier(supplier.id, context);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class SupplierDetailsSheet extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewLedger; // ADD THIS

  const SupplierDetailsSheet({
    Key? key,
    required this.supplier,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onViewLedger, // ADD THIS

  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Supplier Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailItem('Name', supplier.name, Icons.business),
          _buildDetailItem('Contact', supplier.contact, Icons.phone),
          if (supplier.address != null && supplier.address!.isNotEmpty)
            _buildDetailItem('Address', supplier.address!, Icons.location_on),
          _buildDetailItem('Status',
            supplier.isActive ? 'Active' : 'Inactive',
            supplier.isActive ? Icons.check_circle : Icons.cancel,
            color: supplier.isActive ? Colors.green : Colors.red,
          ),
          if (supplier.discountPercent > 0)
            _buildDetailItem(
              'Discount',
              '${supplier.discountPercent.toStringAsFixed(1)}%',
              Icons.discount_outlined,
              color: const Color(0xFF7C3AED),
            ),
          _buildDetailItem('Created',
            '${supplier.createdAt.day}/${supplier.createdAt.month}/${supplier.createdAt.year}',
            Icons.calendar_today,
          ),

          const SizedBox(height: 24),
          Text(
            'No products associated yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          CustomButton(
            text: 'Pay Supplier',
            icon: Icons.payments_outlined,
            onPressed: () async {
              Navigator.pop(context); // sheet band karo
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => SupplierPaymentDialog(supplier: supplier),
              );
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment recorded successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            backgroundColor: const Color(0xFFECFDF5),
            textColor: const Color(0xFF10B981),
          ),
          CustomButton(
            text: 'Payment History',
            icon: Icons.history_outlined,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SupplierPaymentsScreen(supplier: supplier),
              ));
            },
            backgroundColor: const Color(0xFFECFDF5),
            textColor: const Color(0xFF10B981),
          ),
          CustomButton(
            text: 'View Ledger',
            icon: Icons.account_balance_wallet_outlined,
            onPressed: onViewLedger,
            backgroundColor: const Color(0xFFF5F3FF),
            textColor: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Edit Supplier',
                  icon: Icons.edit,
                  onPressed: onEdit, // Use the passed callback
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: supplier.isActive ? 'Deactivate' : 'Activate',
                  icon: supplier.isActive ? Icons.pause : Icons.play_arrow,
                  onPressed: onToggleStatus, // Use the passed callback
                  backgroundColor: supplier.isActive ? Colors.red : Colors.green,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? const Color(0xFF6B7280), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}