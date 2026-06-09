// screens/advance_ledger_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/advance_expense.dart';
import '../providers/employee_provider.dart';

class AdvanceLedgerScreen extends StatefulWidget {
  final Employee employee;
  const AdvanceLedgerScreen({super.key, required this.employee});

  @override
  State<AdvanceLedgerScreen> createState() => _AdvanceLedgerScreenState();
}

class _AdvanceLedgerScreenState extends State<AdvanceLedgerScreen> {
  String _filter = 'all'; // all | pending | recovered

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    Provider.of<EmployeeProvider>(context, listen: false)
        .loadAdvances(widget.employee.id,
        status: _filter == 'all' ? null : _filter);
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────
  void _showDialog({AdvancePayment? existing}) {
    final amtCtrl  = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.payments_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(existing == null ? 'Add Advance' : 'Edit Advance',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  ]),
                  const SizedBox(height: 20),

                  // Date picker
                  _label('Date'),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (c, ch) => Theme(data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1))), child: ch!),
                      );
                      if (d != null) setS(() => selectedDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(_fmt(selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  _label('Amount (Rs.)'),
                  TextFormField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDec(Icons.currency_rupee),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Description
                  _label('Description (optional)'),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: _inputDec(Icons.notes_outlined),
                  ),
                  const SizedBox(height: 20),

                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        debugPrint('=== Advance Submit Started ===');

                        if (!formKey.currentState!.validate()) {
                          debugPrint('Form validation failed');
                          return;
                        }

                        final provider = Provider.of<EmployeeProvider>(context, listen: false);

                        final payload = {
                          'employee_id': widget.employee.id,
                          'amount': double.parse(amtCtrl.text.trim()),
                          'date': selectedDate.toIso8601String().split('T')[0],
                          'description': descCtrl.text.trim(),
                        };

                        debugPrint('Employee ID: ${widget.employee.id}');
                        debugPrint('Existing Advance: ${existing?.id}');
                        debugPrint('Payload: $payload');

                        Map<String, dynamic> res;

                        try {
                          if (existing == null) {
                            debugPrint('Calling createAdvance...');
                            res = await provider.createAdvance(payload);
                          } else {
                            debugPrint('Calling updateAdvance...');
                            res = await provider.updateAdvance(
                              existing.id,
                              payload,
                              widget.employee.id,
                            );
                          }

                          debugPrint('API Response: $res');
                        } catch (e, stackTrace) {
                          debugPrint('Error while saving advance: $e');
                          debugPrint('StackTrace: $stackTrace');
                          return;
                        }

                        if (!ctx.mounted) {
                          debugPrint('Context not mounted');
                          return;
                        }

                        debugPrint('Closing dialog');
                        Navigator.pop(ctx);

                        if (!res['success']) {
                          debugPrint('Operation failed: ${res['message']}');

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          debugPrint('Operation successful');
                        }

                        debugPrint('=== Advance Submit Finished ===');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(existing == null ? 'Add' : 'Update'),
                    )
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(AdvancePayment adv) async {
    if (adv.status == AdvanceStatus.recovered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete a recovered advance'), backgroundColor: Colors.orange),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Advance'),
        content: Text('Delete advance of Rs. ${adv.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await Provider.of<EmployeeProvider>(context, listen: false)
          .deleteAdvance(adv.id, widget.employee.id);
    }
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final advances = provider.advances;
        final summary  = provider.advanceSummary;

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.employee.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const Text('Advance Payments', style: TextStyle(fontSize: 13, color: Color(0xFF6366F1))),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1), size: 28),
                onPressed: () => _showDialog(),
                tooltip: 'Add Advance',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: provider.advanceLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
            // ── Summary banner ──────────────────────────────────────
            if (summary != null) _buildSummaryBanner(summary),

            // ── Filter chips ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                _filterChip('All',       'all'),
                const SizedBox(width: 8),
                _filterChip('Pending',   'pending'),
                const SizedBox(width: 8),
                _filterChip('Recovered', 'recovered'),
              ]),
            ),

            // ── Ledger list ─────────────────────────────────────────
            Expanded(
              child: advances.isEmpty
                  ? _empty('No advance records found')
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: advances.length,
                itemBuilder: (_, i) => _buildRow(advances[i], i, advances.length),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Summary banner ──────────────────────────────────────────────────────────
  Widget _buildSummaryBanner(LedgerSummary s) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _bannerStat('Total Given',  s.totalAmount,    Colors.white),
        _vDivider(),
        _bannerStat('Recovered',    s.totalRecovered, const Color(0xFFA5F3FC)),
        _vDivider(),
        _bannerStat('Pending',      s.pendingBalance, const Color(0xFFFDE68A)),
      ],
    ),
  );

  Widget _bannerStat(String label, double val, Color color) => Column(children: [
    Text('Rs. ${val.toStringAsFixed(0)}',
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
  ]);

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3));

  // ── Ledger row ──────────────────────────────────────────────────────────────
  Widget _buildRow(AdvancePayment adv, int index, int total) {
    final isPending   = adv.status == AdvanceStatus.pending;
    final statusColor = isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final isFirst     = index == 0;
    final isLast      = index == total - 1;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 20 : 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Timeline line ───────────────────────────────────────────
            SizedBox(
              width: 40,
              child: Column(children: [
                if (!isFirst)
                  Expanded(child: Center(child: Container(width: 2, color: Colors.grey[200]))),
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4)],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Center(child: Container(width: 2, color: Colors.grey[200]))),
              ]),
            ),

            // ── Card ────────────────────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 8, bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0F0F5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(adv.date),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(isPending ? 'Pending' : 'Recovered',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Rs. ${adv.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  if (adv.description != null && adv.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(adv.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _iconBtn(Icons.edit_outlined, const Color(0xFF6366F1), () => _showDialog(existing: adv)),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.delete_outline, const Color(0xFFEF4444), () => _delete(adv)),
                    ]),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey[600],
        )),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    ),
  );

  Widget _empty(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.payments_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: () => _showDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Advance'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
  );

  InputDecoration _inputDec(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
    filled: true, fillColor: const Color(0xFFF5F6FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}