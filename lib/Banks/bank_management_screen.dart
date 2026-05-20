// lib/screens/banks/bank_management_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/bank_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/bank.dart';
import '../config/api_config.dart';
import 'bank_transaction_screen.dart';

class BankManagementScreen extends StatefulWidget {
  const BankManagementScreen({super.key});

  @override
  State<BankManagementScreen> createState() => _BankManagementScreenState();
}

class _BankManagementScreenState extends State<BankManagementScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBanks();
    });
  }

  Future<void> _loadBanks() async {
    if (mounted) setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bankProvider = Provider.of<BankProvider>(context, listen: false);
    await bankProvider.fetchBanks(authProvider: authProvider);

    // Auto-initialize if no banks exist yet
    if (bankProvider.banks.isEmpty && bankProvider.error == null) {
      debugPrint('No banks found — auto-initializing...');
      await _initializeBanks(context);
      return; // _initializeBanks calls _loadBanks again after success
    }

    if (mounted) setState(() => _isLoading = false);
  }


  Future<void> _initializeBanks(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.user?.token;

      debugPrint('=== initializeBanks ===');
      debugPrint('Token: ${token != null ? "present" : "NULL"}');
      debugPrint('URL: ${ApiConfig.baseUrl}/banks/initialize');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/banks/initialize'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      // Guard against HTML response
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        throw Exception('Server returned HTML. Status: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Done'),
            backgroundColor: data['success'] == true ? Colors.green : Colors.red,
          ),
        );
        if (data['success'] == true) {
          await _loadBanks();
        }
      }
    } catch (e) {
      debugPrint('initializeBanks error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bank Management',
          style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
            onPressed: _loadBanks,
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart_outline, color: Color(0xFF7C3AED)),
            onPressed: () => _showSummaryDialog(context),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1C1C1E)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Text('Reset All Balances'),
              ),
            ],
            onSelected: (value) {
              if (value == 'reset') {
                _confirmReset(context);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : Consumer<BankProvider>(
        builder: (context, provider, _) {
          // Show error if any
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBanks,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.banks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_outlined,
                      color: Color(0xFF7C3AED), size: 64),
                  const SizedBox(height: 16),
                  const Text('No banks found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Initialize default banks to get started',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _initializeBanks(context),
                    icon: const Icon(Icons.add_business),
                    label: const Text('Initialize Default Banks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildSummaryCard(provider),
              const SizedBox(height: 8),
              Expanded(child: _buildBankList(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BankProvider provider) {
    final totalBalance = provider.getTotalBalance();
    final activeBanks = provider.banks.where((b) => b.balance > 0).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9B6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All Accounts',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Active Banks',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$activeBanks/${provider.banks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rs ${NumberFormat('#,##0.00').format(totalBalance)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankList(BankProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.banks.length,
      itemBuilder: (context, index) {
        final bank = provider.banks[index];
        return _buildBankCard(context, bank);
      },
    );
  }

  Widget _buildBankCard(BuildContext context, Bank bank) {
    final isBalancePositive = bank.balance > 0;
    final balanceColor = isBalancePositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BankTransactionScreen(bank: bank),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Bank Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      bank.iconPath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance,
                        size: 32,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bank Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bank.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: balanceColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Balance: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Rs ${NumberFormat('#,##0.00').format(bank.balance)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                      if (bank.accountNumber != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'A/C: ${bank.accountNumber}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSummaryDialog(BuildContext context) {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final activeBanks = provider.banks.where((b) => b.balance > 0).toList();
    final inactiveBanks = provider.banks.where((b) => b.balance == 0).toList().take(10).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Bank Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (activeBanks.isNotEmpty) ...[
                      const Text(
                        'Active Banks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...activeBanks.map((bank) => ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            bank.iconPath,
                            width: 32,
                            height: 32,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.account_balance,
                              size: 24,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        title: Text(bank.name),
                        trailing: Text(
                          'Rs ${NumberFormat('#,##0.00').format(bank.balance)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (inactiveBanks.isNotEmpty) ...[
                      const Text(
                        'Inactive Banks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...inactiveBanks.map((bank) => ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            bank.iconPath,
                            width: 32,
                            height: 32,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.account_balance,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        title: Text(bank.name),
                        trailing: const Text(
                          'Rs 0.00',
                          style: TextStyle(color: Color(0xFF8E8E93)),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset All Balances'),
        content: const Text(
          'This will reset all bank balances to zero and clear all transaction history. This action cannot be undone.',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<BankProvider>(context, listen: false);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await provider.resetAllBalances(authProvider: authProvider);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All bank balances have been reset'),
                    backgroundColor: Colors.orange,
                  ),
                );
                await _loadBanks();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}