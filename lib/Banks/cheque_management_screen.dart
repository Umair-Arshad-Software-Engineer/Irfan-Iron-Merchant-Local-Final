// lib/screens/banks/cheque_management_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bank_provider.dart';
import '../../models/bank.dart';
import '../config/api_config.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class Cheque {
  final int id;
  final int bankId;
  final String bankName;
  final String bankIconPath;
  final String chequeNumber;
  final String chequeType;
  final String status;
  final double amount;
  final String payeePayerName;
  final String? description;
  final DateTime issueDate;
  final DateTime? dueDate;
  final DateTime? clearedDate;
  final String? bounceReason;

  const Cheque({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.bankIconPath,
    required this.chequeNumber,
    required this.chequeType,
    required this.status,
    required this.amount,
    required this.payeePayerName,
    this.description,
    required this.issueDate,
    this.dueDate,
    this.clearedDate,
    this.bounceReason,
  });

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory Cheque.fromJson(Map<String, dynamic> json) {
    final bank = json['bank'] as Map<String, dynamic>?;
    return Cheque(
      id: json['id'] as int,
      bankId: json['bank_id'] as int,
      bankName: bank?['name'] as String? ?? '',
      bankIconPath: bank?['icon_path'] as String? ?? '',
      chequeNumber: json['cheque_number'] as String,
      chequeType: json['cheque_type'] as String,
      status: json['status'] as String,
      amount: _parseDouble(json['amount']),
      payeePayerName: json['payee_payer_name'] as String,
      description: json['description'] as String?,
      issueDate: DateTime.parse(json['issue_date'] as String),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      clearedDate: json['cleared_date'] != null ? DateTime.parse(json['cleared_date'] as String) : null,
      bounceReason: json['bounce_reason'] as String?,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────

class ChequeManagementScreen extends StatefulWidget {
  const ChequeManagementScreen({super.key});

  @override
  State<ChequeManagementScreen> createState() => _ChequeManagementScreenState();
}

class _ChequeManagementScreenState extends State<ChequeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Cheque> _cheques = [];
  List<Bank> _banks = [];
  bool _isLoading = false;
  String? _error;

  String _filterStatus = 'all';
  String _filterType = 'all';
  int? _filterBankId;

  final _currencyFmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _token() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.user?.token;
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final bankProvider = Provider.of<BankProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await bankProvider.fetchBanks(authProvider: authProvider);
      _banks = bankProvider.banks;

      final params = <String, String>{};
      if (_filterStatus != 'all') params['status'] = _filterStatus;
      if (_filterType != 'all') params['cheque_type'] = _filterType;
      if (_filterBankId != null) params['bank_id'] = _filterBankId.toString();
      params['limit'] = '200';

      final uri = Uri.parse('${ApiConfig.baseUrl}/cheques').replace(queryParameters: params);

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (_token() != null) 'Authorization': 'Bearer ${_token()}',
      });

      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        throw Exception('Server returned HTML. API endpoint may be misconfigured.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _cheques = (data['data']['cheques'] as List)
                .map((j) => Cheque.fromJson(j as Map<String, dynamic>))
                .toList();
          });
        } else {
          _error = data['message'] ?? 'Failed to load cheques';
        }
      } else if (response.statusCode == 401) {
        _error = 'Authentication failed. Please login again.';
      } else if (response.statusCode == 404) {
        _error = 'Cheque API endpoint not found.';
      } else {
        _error = 'Failed to load cheques (${response.statusCode})';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _patchStatus(int id, String action, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/cheques/$id/$action');
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (_token() != null) 'Authorization': 'Bearer ${_token()}',
        },
        body: body != null ? json.encode(body) : null,
      );

      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        throw Exception('Server returned HTML. API endpoint may be incorrect.');
      }

      final data = json.decode(response.body);
      if (data['success'] == true) {
        // Refresh bank balances after clearing (balance changes)
        if (action == 'clear' || action == 'bounce' || action == 'cancel' || action == 'revert') {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final bankProvider = Provider.of<BankProvider>(context, listen: false);
          await bankProvider.fetchBanks(authProvider: authProvider);
        }
        return true;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'Action failed'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red,
        ));
      }
      return false;
    }
  }

  Future<bool> _deleteCheque(int id) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/cheques/$id');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (_token() != null) 'Authorization': 'Bearer ${_token()}',
        },
      );

      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        throw Exception('Server returned HTML');
      }

      final data = json.decode(response.body);
      if (data['success'] == true) {
        // Refresh bank balances (deletion reverses cleared cheques)
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final bankProvider = Provider.of<BankProvider>(context, listen: false);
        await bankProvider.fetchBanks(authProvider: authProvider);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Status helpers ───────────────────────────────────────────────────────

  Color _statusColor(String status) => switch (status) {
    'cleared'   => const Color(0xFF10B981),
    'pending'   => const Color(0xFFF59E0B),
    'bounced'   => const Color(0xFFEF4444),
    'cancelled' => const Color(0xFF8E8E93),
    _           => const Color(0xFF8E8E93),
  };

  IconData _statusIcon(String status) => switch (status) {
    'cleared'   => Icons.check_circle_outline,
    'pending'   => Icons.hourglass_empty,
    'bounced'   => Icons.cancel_outlined,
    'cancelled' => Icons.block_outlined,
    _           => Icons.help_outline,
  };

  String _statusLabel(String status) => switch (status) {
    'cleared'   => 'Cleared',
    'pending'   => 'Pending',
    'bounced'   => 'Bounced',
    'cancelled' => 'Cancelled',
    _           => status,
  };

  Color _typeColor(String type) => type == 'issued'
      ? const Color(0xFFEF4444)
      : const Color(0xFF10B981);

  IconData _typeIcon(String type) => type == 'issued'
      ? Icons.arrow_upward
      : Icons.arrow_downward;

  // ── Summary ──────────────────────────────────────────────────────────────

  Map<String, double> get _summary {
    double pendingIssued = 0, pendingReceived = 0, cleared = 0;
    for (final c in _cheques) {
      if (c.status == 'pending') {
        if (c.chequeType == 'issued') pendingIssued += c.amount;
        else pendingReceived += c.amount;
      }
      if (c.status == 'cleared') cleared += c.amount;
    }
    return {
      'pendingIssued': pendingIssued,
      'pendingReceived': pendingReceived,
      'cleared': cleared,
    };
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddChequeSheet(),
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Cheque', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _error != null
          ? _buildError()
          : Column(
        children: [
          _buildSummaryRow(),
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChequeList('all'),
                _buildChequeList('pending'),
              ],
            ),
          ),
        ],
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
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cheque Management',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
          Text('Track & update cheque status',
              style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
          onPressed: _loadData,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF7C3AED),
        unselectedLabelColor: const Color(0xFF8E8E93),
        indicatorColor: const Color(0xFF7C3AED),
        tabs: [
          Tab(
            text: 'ALL (${_cheques.length})',
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
          ),
          Tab(
            text: 'PENDING (${_cheques.where((c) => c.status == 'pending').length})',
            icon: const Icon(Icons.hourglass_empty, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final s = _summary;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _summaryTile('Pending Out', s['pendingIssued']!, const Color(0xFFEF4444)),
          _vDivider(),
          _summaryTile('Pending In', s['pendingReceived']!, const Color(0xFF10B981)),
          _vDivider(),
          _summaryTile('Total Cleared', s['cleared']!, const Color(0xFF7C3AED)),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Rs ${_currencyFmt.format(amount)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 32,
    color: const Color(0xFFE5E5EA),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('All Types',  _filterType == 'all',      () => setState(() { _filterType = 'all';      _loadData(); })),
          const SizedBox(width: 8),
          _filterChip('Issued',     _filterType == 'issued',   () => setState(() { _filterType = 'issued';   _loadData(); }), color: const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _filterChip('Received',   _filterType == 'received', () => setState(() { _filterType = 'received'; _loadData(); }), color: const Color(0xFF10B981)),
          const SizedBox(width: 16),
          _filterChip('All Status', _filterStatus == 'all',       () => setState(() { _filterStatus = 'all';       _loadData(); })),
          const SizedBox(width: 8),
          _filterChip('Pending',    _filterStatus == 'pending',   () => setState(() { _filterStatus = 'pending';   _loadData(); }), color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _filterChip('Cleared',    _filterStatus == 'cleared',   () => setState(() { _filterStatus = 'cleared';   _loadData(); }), color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _filterChip('Bounced',    _filterStatus == 'bounced',   () => setState(() { _filterStatus = 'bounced';   _loadData(); }), color: const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _filterChip('Cancelled',  _filterStatus == 'cancelled', () => setState(() { _filterStatus = 'cancelled'; _loadData(); }), color: const Color(0xFF8E8E93)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    final c = color ?? const Color(0xFF7C3AED);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : const Color(0xFFE5E5EA), width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? c : const Color(0xFF8E8E93))),
      ),
    );
  }

  Widget _buildChequeList(String tabFilter) {
    final list = tabFilter == 'pending'
        ? _cheques.where((c) => c.status == 'pending').toList()
        : _cheques;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No cheques found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Tap + to add a new cheque', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildChequeCard(list[i]),
    );
  }

  Widget _buildChequeCard(Cheque cheque) {
    final statusColor = _statusColor(cheque.status);
    final typeColor   = _typeColor(cheque.chequeType);
    final isPending   = cheque.status == 'pending';

    // Border color hint per status
    Color? borderColor;
    if (isPending) borderColor = const Color(0xFFF59E0B).withOpacity(0.4);
    if (cheque.status == 'bounced') borderColor = const Color(0xFFEF4444).withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ── Row 1: Type badge + Cheque # + Amount ────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(_typeIcon(cheque.chequeType), size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        cheque.chequeType == 'issued' ? 'ISSUED' : 'RECEIVED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('#${cheque.chequeNumber}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
                const Spacer(),
                Text(
                  'Rs ${_currencyFmt.format(cheque.amount)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: Payee/Payer + Bank ─────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF8E8E93)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(cheque.payeePayerName,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E), fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.asset(
                          cheque.bankIconPath, width: 14, height: 14,
                          errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, size: 12, color: Color(0xFF7C3AED)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(cheque.bankName, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                    ],
                  ),
                ),
              ],
            ),

            if (cheque.description != null && cheque.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.notes, size: 13, color: Color(0xFF8E8E93)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(cheque.description!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],

            // ── Bounce reason ─────────────────────────────────────────────
            if (cheque.status == 'bounced' && cheque.bounceReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 13, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Bounce reason: ${cheque.bounceReason}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Row 3: Dates + Status badge ───────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF8E8E93)),
                const SizedBox(width: 4),
                Text('Issued: ${_dateFmt.format(cheque.issueDate)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                if (cheque.dueDate != null) ...[
                  const SizedBox(width: 6),
                  Text('•', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 6),
                  Text(
                    'Due: ${_dateFmt.format(cheque.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cheque.dueDate!.isBefore(DateTime.now()) && isPending
                          ? const Color(0xFFEF4444) : const Color(0xFF8E8E93),
                      fontWeight: cheque.dueDate!.isBefore(DateTime.now()) && isPending
                          ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(cheque.status), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(_statusLabel(cheque.status),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),

            // ── Cleared date ──────────────────────────────────────────────
            if (cheque.status == 'cleared' && cheque.clearedDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text('Cleared on ${_dateFmt.format(cheque.clearedDate!)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500)),
                ],
              ),
            ],

            // ── Action Buttons (ALL cheques, context-aware) ───────────────
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),
            _buildActionButtons(cheque),
          ],
        ),
      ),
    );
  }

  /// Builds context-aware action buttons depending on current status.
  /// Always shows Delete. Other buttons show only if they'd change state.
  Widget _buildActionButtons(Cheque cheque) {
    final status = cheque.status;

    return Row(
      children: [
        // Clear — show if not already cleared
        if (status != 'cleared') ...[
          Expanded(
            child: _actionBtn(
              label: 'Clear',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
              onTap: () => _confirmClear(cheque),
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Bounce — show if not already bounced
        if (status != 'bounced') ...[
          Expanded(
            child: _actionBtn(
              label: 'Bounce',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
              onTap: () => _confirmBounce(cheque),
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Cancel — show if not already cancelled
        if (status != 'cancelled') ...[
          Expanded(
            child: _actionBtn(
              label: 'Cancel',
              icon: Icons.block_outlined,
              color: const Color(0xFF8E8E93),
              onTap: () => _confirmCancel(cheque),
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Revert to Pending — show only when not already pending
        if (status != 'pending') ...[
          Expanded(
            child: _actionBtn(
              label: 'Revert',
              icon: Icons.undo_outlined,
              color: const Color(0xFF7C3AED),
              onTap: () => _confirmRevert(cheque),
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Delete — always visible
        GestureDetector(
          onTap: () => _confirmDelete(cheque),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _confirmClear(Cheque cheque) async {
    DateTime clearedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Clear Cheque'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _chequeInfoBox(cheque),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cheque.chequeType == 'issued'
                            ? 'Rs ${_currencyFmt.format(cheque.amount)} will be DEBITED from ${cheque.bankName}'
                            : 'Rs ${_currencyFmt.format(cheque.amount)} will be CREDITED to ${cheque.bankName}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: clearedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (c, child) => Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED), onPrimary: Colors.white),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setS(() => clearedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 8),
                      Text('Cleared: ${_dateFmt.format(clearedDate)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF8E8E93)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, color: Colors.white, size: 16),
              label: const Text('Clear Cheque', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final ok = await _patchStatus(cheque.id, 'clear', body: {
      'cleared_date': DateFormat('yyyy-MM-dd').format(clearedDate),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Cheque #${cheque.chequeNumber} cleared. Bank balance updated.'
            : 'Failed to clear cheque'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) await _loadData();
    }
  }

  Future<void> _confirmBounce(Cheque cheque) async {
    final reasonCtrl = TextEditingController(text: 'Dishonoured by bank');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Bounced'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chequeInfoBox(cheque),
            const SizedBox(height: 12),
            // Show reversal warning if was cleared
            if (cheque.status == 'cleared')
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFFF59E0B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This cheque was cleared. Bank balance will be REVERSED.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No bank balance change. Cheque will be marked as dishonoured.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Bounce Reason',
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 16),
            label: const Text('Mark Bounced', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _patchStatus(cheque.id, 'bounce', body: {
      'bounce_reason': reasonCtrl.text.trim().isEmpty ? 'Dishonoured by bank' : reasonCtrl.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Cheque #${cheque.chequeNumber} marked as bounced' : 'Failed'),
        backgroundColor: ok ? Colors.orange : Colors.red,
      ));
      if (ok) await _loadData();
    }
  }

  Future<void> _confirmCancel(Cheque cheque) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Cheque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chequeInfoBox(cheque),
            const SizedBox(height: 12),
            if (cheque.status == 'cleared')
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFFF59E0B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This cheque was cleared. Bank balance will be REVERSED.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'This will void the cheque. No bank balance change.',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E8E93),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _patchStatus(cheque.id, 'cancel');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Cheque #${cheque.chequeNumber} cancelled' : 'Failed'),
        backgroundColor: ok ? Colors.orange : Colors.red,
      ));
      if (ok) await _loadData();
    }
  }

  Future<void> _confirmRevert(Cheque cheque) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revert to Pending'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chequeInfoBox(cheque),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.undo_outlined, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cheque.status == 'cleared'
                          ? 'Status will change to Pending. Bank balance will be REVERSED.'
                          : 'Cheque #${cheque.chequeNumber} will be reset to Pending.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.undo_outlined, color: Colors.white, size: 16),
            label: const Text('Revert to Pending', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _patchStatus(cheque.id, 'revert');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Cheque #${cheque.chequeNumber} reverted to pending' : 'Failed'),
        backgroundColor: ok ? const Color(0xFF7C3AED) : Colors.red,
      ));
      if (ok) await _loadData();
    }
  }

  Future<void> _confirmDelete(Cheque cheque) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Cheque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chequeInfoBox(cheque),
            const SizedBox(height: 12),
            if (cheque.status == 'cleared')
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This cheque was cleared. Deleting it will REVERSE the bank balance. This cannot be undone.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _deleteCheque(cheque.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Cheque deleted successfully' : 'Failed to delete cheque'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) await _loadData();
    }
  }

  Widget _chequeInfoBox(Cheque cheque) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${cheque.chequeNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(
                'Rs ${_currencyFmt.format(cheque.amount)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _typeColor(cheque.chequeType)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(cheque.payeePayerName, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          const SizedBox(height: 2),
          Text('Bank: ${cheque.bankName}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }

  // ── Add Cheque Bottom Sheet ───────────────────────────────────────────────

  void _showAddChequeSheet() {
    final formKey = GlobalKey<FormState>();
    final chequeNumCtrl = TextEditingController();
    final amountCtrl    = TextEditingController();
    final payeeCtrl     = TextEditingController();
    final descCtrl      = TextEditingController();

    String chequeType = 'issued';
    int? selectedBankId = _banks.isNotEmpty ? _banks.first.id : null;
    DateTime issueDate = DateTime.now();
    DateTime? dueDate;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text('New Cheque',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: _typeToggle('issued',   'Issued',   chequeType, (v) => setS(() => chequeType = v))),
                        const SizedBox(width: 10),
                        Expanded(child: _typeToggle('received', 'Received', chequeType, (v) => setS(() => chequeType = v))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<int>(
                      value: selectedBankId,
                      decoration: _inputDec('Bank', Icons.account_balance_outlined),
                      items: _banks.map((b) => DropdownMenuItem<int>(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (v) => setS(() => selectedBankId = v),
                      validator: (v) => v == null ? 'Select a bank' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: chequeNumCtrl,
                      decoration: _inputDec('Cheque Number', Icons.tag),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: payeeCtrl,
                      decoration: _inputDec(
                        chequeType == 'issued' ? 'Payee Name' : 'Payer Name',
                        Icons.person_outline,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      decoration: _inputDec('Amount', Icons.currency_exchange),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if ((double.tryParse(v) ?? 0) <= 0) return 'Enter valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: descCtrl,
                      decoration: _inputDec('Description (optional)', Icons.notes),
                    ),
                    const SizedBox(height: 12),

                    _dateTile(
                      label: 'Issue Date',
                      date: issueDate,
                      onTap: () async {
                        final d = await _pickDate(ctx, issueDate);
                        if (d != null) setS(() => issueDate = d);
                      },
                    ),
                    const SizedBox(height: 10),

                    _dateTile(
                      label: dueDate != null ? 'Due Date: ${_dateFmt.format(dueDate!)}' : 'Due Date (optional)',
                      date: dueDate,
                      optional: true,
                      onTap: () async {
                        final d = await _pickDate(ctx, dueDate ?? DateTime.now().add(const Duration(days: 30)));
                        if (d != null) setS(() => dueDate = d);
                      },
                      onClear: dueDate != null ? () => setS(() => dueDate = null) : null,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          setS(() => isSubmitting = true);

                          try {
                            final uri = Uri.parse('${ApiConfig.baseUrl}/cheques');
                            final requestBody = {
                              'bank_id':          selectedBankId,
                              'cheque_number':    chequeNumCtrl.text.trim(),
                              'cheque_type':      chequeType,
                              'amount':           double.parse(amountCtrl.text.trim()),
                              'payee_payer_name': payeeCtrl.text.trim(),
                              'description':      descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              'issue_date':       DateFormat('yyyy-MM-dd').format(issueDate),
                              'due_date':         dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
                            };

                            final response = await http.post(
                              uri,
                              headers: {
                                'Content-Type': 'application/json',
                                if (_token() != null) 'Authorization': 'Bearer ${_token()}',
                              },
                              body: json.encode(requestBody),
                            );

                            if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Server error: API endpoint not found.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 5),
                                ));
                              }
                              setS(() => isSubmitting = false);
                              return;
                            }

                            final data = json.decode(response.body);
                            if (ctx.mounted) Navigator.pop(ctx);

                            if (mounted) {
                              if (data['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Cheque #${chequeNumCtrl.text.trim()} created successfully'),
                                  backgroundColor: Colors.green,
                                ));
                                await _loadData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(data['message'] ?? 'Failed to create cheque'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          } catch (e) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ));
                            }
                          } finally {
                            if (mounted) setS(() => isSubmitting = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Create Cheque', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeToggle(String value, String label, String current, ValueChanged<String> onChange) {
    final isSelected = current == value;
    final color = value == 'issued' ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final icon  = value == 'issued' ? Icons.arrow_upward : Icons.arrow_downward;

    return GestureDetector(
      onTap: () => onChange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : const Color(0xFFE5E5EA), width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : const Color(0xFF8E8E93)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? color : const Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool optional = false,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF7C3AED)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date != null ? 'Issue Date: ${_dateFmt.format(date)}' : label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
                  fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(onTap: onClear, child: const Icon(Icons.clear, size: 16, color: Color(0xFF8E8E93)))
            else
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime initial) {
    return showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED), onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
  }
}