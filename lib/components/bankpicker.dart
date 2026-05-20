// ─── Bank Picker Bottom Sheet ──────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/api_config.dart';

class DbBankSheet extends StatefulWidget {
  final Color accentColor;
  final String? token;
  const DbBankSheet({required this.accentColor, required this.token});

  @override
  State<DbBankSheet> createState() => DbBankSheetState();
}

class DbBankSheetState extends State<DbBankSheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _allBanks = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetchBanks() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/banks/active'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.token != null) 'Authorization': 'Bearer ${widget.token}',
        },
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final banks = (data['data'] as List)
            .map<Map<String, dynamic>>((b) => Map<String, dynamic>.from(b))
            .toList();
        setState(() {
          _allBanks = banks;
          _filtered = banks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load banks';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _filter(String q) {
    setState(() {
      _filtered = _allBanks
          .where((b) => (b['name'] as String)
          .toLowerCase()
          .contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(children: [
            const Text('Select Bank',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8E8E93))),
            ),
          ]),
          const SizedBox(height: 10),

          // Search
          TextField(
            controller: _search,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Search banks…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accentColor, width: 1.5),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 8),

          // Body
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: widget.accentColor))
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _fetchBanks();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor),
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
                : _filtered.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined,
                      size: 48,
                      color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    _search.text.isEmpty
                        ? 'No active banks found.\nInitialize banks first.'
                        : 'No banks match your search',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final b = _filtered[i];
                final name = b['name'] as String;
                final icon = b['icon_path'] as String? ?? '';
                final balance = double.tryParse(
                    b['balance']?.toString() ?? '0') ??
                    0;
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        icon,
                        width: 40, height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: widget.accentColor
                                    .withOpacity(0.1),
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.account_balance,
                                  size: 20,
                                  color: widget.accentColor),
                            ),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1C1C1E))),
                    subtitle: Text(
                      'Balance: Rs ${NumberFormat('#,##0.00').format(balance)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: balance > 0
                            ? const Color(0xFF10B981)
                            : Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, b),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}