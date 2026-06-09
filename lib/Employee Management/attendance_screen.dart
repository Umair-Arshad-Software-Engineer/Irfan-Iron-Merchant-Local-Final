// screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../providers/employee_provider.dart';

class AttendanceScreen extends StatefulWidget {
  final Employee employee;
  const AttendanceScreen({super.key, required this.employee});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late int _currentMonth;
  late int _currentYear;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear  = now.year;
    _loadAttendance();
  }

  void _loadAttendance() {
    Provider.of<EmployeeProvider>(context, listen: false)
        .loadAttendanceForEmployee(widget.employee.id, _currentMonth, _currentYear);
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) { _currentMonth = 12; _currentYear--; }
      else _currentMonth--;
    });
    _loadAttendance();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_currentYear == now.year && _currentMonth == now.month) return;   // don't go into future
    setState(() {
      if (_currentMonth == 12) { _currentMonth = 1; _currentYear++; }
      else _currentMonth++;
    });
    _loadAttendance();
  }

  // ── Status helpers ──────────────────────────────────────────────────────
  Color _statusColor(AttendanceStatus? s) {
    switch (s) {
      case AttendanceStatus.Present:  return const Color(0xFF10B981);
      case AttendanceStatus.Absent:   return const Color(0xFFEF4444);
      case AttendanceStatus.Half_Day: return const Color(0xFFF59E0B);
      case AttendanceStatus.Leave:    return const Color(0xFF8B5CF6);
      default:                        return const Color(0xFFE5E7EB);
    }
  }

  String _statusLabel(AttendanceStatus? s) {
    switch (s) {
      case AttendanceStatus.Present:  return 'P';
      case AttendanceStatus.Absent:   return 'A';
      case AttendanceStatus.Half_Day: return '½';
      case AttendanceStatus.Leave:    return 'L';
      default:                        return '';
    }
  }

  // ── Mark/cycle attendance ───────────────────────────────────────────────
  Future<void> _toggleAttendance(DateTime date, AttendanceStatus? current) async {
    // Cycle: null -> Present -> Absent -> Half_Day -> Leave -> Present
    final next = current == null
        ? AttendanceStatus.Present
        : current == AttendanceStatus.Present
        ? AttendanceStatus.Absent
        : current == AttendanceStatus.Absent
        ? AttendanceStatus.Half_Day
        : current == AttendanceStatus.Half_Day
        ? AttendanceStatus.Leave
        : AttendanceStatus.Present;

    await Provider.of<EmployeeProvider>(context, listen: false)
        .markAttendance(widget.employee.id, date, next);
  }

  // ── Quick-set bottom sheet for a specific day ───────────────────────────
  void _showStatusPicker(DateTime date, AttendanceStatus? current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark ${_dayName(date)}, ${date.day} ${_months[date.month - 1]} $_currentYear',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AttendanceStatus.values.map((s) {
                final isSelected = s == current;
                final color = _statusColor(s);
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Provider.of<EmployeeProvider>(context, listen: false)
                        .markAttendance(widget.employee.id, date, s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon(s), color: isSelected ? Colors.white : color, size: 18),
                      const SizedBox(width: 8),
                      Text(_statusFullLabel(s), style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : color,
                      )),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _dayName(DateTime d) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return days[d.weekday - 1];
  }

  IconData _statusIcon(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.Present:  return Icons.check_circle_outline;
      case AttendanceStatus.Absent:   return Icons.cancel_outlined;
      case AttendanceStatus.Half_Day: return Icons.timelapse_outlined;
      case AttendanceStatus.Leave:    return Icons.beach_access_outlined;
    }
  }

  String _statusFullLabel(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.Present:  return 'Present';
      case AttendanceStatus.Absent:   return 'Absent';
      case AttendanceStatus.Half_Day: return 'Half Day';
      case AttendanceStatus.Leave:    return 'Leave';
    }
  }

  // ── Compute summary from attendanceMap ──────────────────────────────────
  Map<String, int> _computeSummary(Map<String, AttendanceStatus> map, int daysInMonth) {
    int present = 0, absent = 0, halfDay = 0, leave = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final key = '$_currentYear-${_currentMonth.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}';
      final status = map[key];
      if (status == null) { absent++; continue; }   // unmarked = absent
      switch (status) {
        case AttendanceStatus.Present:  present++;  break;
        case AttendanceStatus.Absent:   absent++;   break;
        case AttendanceStatus.Half_Day: halfDay++;  break;
        case AttendanceStatus.Leave:    leave++;    break;
      }
    }
    return {'present': present, 'absent': absent, 'halfDay': halfDay, 'leave': leave};
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final map = provider.attendanceMap;
        final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;
        final firstWeekday = DateTime(_currentYear, _currentMonth, 1).weekday; // 1=Mon
        final summary = _computeSummary(map, daysInMonth);
        final now = DateTime.now();

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
              Text(widget.employee.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              Text('Attendance', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ]),
          ),
          body: provider.attendanceLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              // ── Month navigator ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left, color: Color(0xFF7C3AED)),
                    ),
                    Text(
                      '${_months[_currentMonth - 1]} $_currentYear',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                    ),
                    IconButton(
                      onPressed: (_currentYear == now.year && _currentMonth == now.month) ? null : _nextMonth,
                      icon: Icon(Icons.chevron_right,
                          color: (_currentYear == now.year && _currentMonth == now.month)
                              ? Colors.grey[300]
                              : const Color(0xFF7C3AED)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Summary cards ────────────────────────────────────
              Row(children: [
                _summaryCard('Present',  summary['present']!.toString(), const Color(0xFF10B981), Icons.check_circle),
                const SizedBox(width: 8),
                _summaryCard('Absent',   summary['absent']!.toString(),  const Color(0xFFEF4444), Icons.cancel),
                const SizedBox(width: 8),
                _summaryCard('Half Day', summary['halfDay']!.toString(), const Color(0xFFF59E0B), Icons.timelapse),
                const SizedBox(width: 8),
                _summaryCard('Leave',    summary['leave']!.toString(),   const Color(0xFF8B5CF6), Icons.beach_access),
              ]),
              const SizedBox(height: 16),

              // ── Calendar grid ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  // Weekday headers
                  Row(children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
                      .map((d) => Expanded(
                    child: Center(child: Text(d, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500]))),
                  )).toList()),
                  const SizedBox(height: 8),

                  // Day cells
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, childAspectRatio: 1, crossAxisSpacing: 4, mainAxisSpacing: 4),
                    itemCount: (firstWeekday - 1) + daysInMonth,
                    itemBuilder: (ctx, idx) {
                      if (idx < firstWeekday - 1) return const SizedBox.shrink();
                      final day = idx - (firstWeekday - 1) + 1;
                      final date = DateTime(_currentYear, _currentMonth, day);
                      final key = '${_currentYear}-${_currentMonth.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
                      final status = map[key];
                      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                      final isFuture = date.isAfter(now);
                      final color = isFuture ? const Color(0xFFF5F6FA) : _statusColor(status);

                      return GestureDetector(
                        onTap: isFuture ? null : () => _showStatusPicker(date, status),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isFuture ? const Color(0xFFF5F6FA) : (status == null ? const Color(0xFFFEF2F2) : color),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday ? Border.all(color: const Color(0xFF7C3AED), width: 2) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$day', style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                color: isFuture ? Colors.grey[300]
                                    : status == null ? const Color(0xFFEF4444)
                                    : Colors.white,
                              )),
                              if (!isFuture && status != null) ...[
                                const SizedBox(height: 1),
                                Text(_statusLabel(status), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                              if (!isFuture && status == null)
                                const Text('A', style: TextStyle(fontSize: 9, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Legend ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _legendItem(const Color(0xFF10B981), 'P', 'Present'),
                    _legendItem(const Color(0xFFEF4444), 'A', 'Absent'),
                    _legendItem(const Color(0xFFF59E0B), '½', 'Half Day'),
                    _legendItem(const Color(0xFF8B5CF6), 'L', 'Leave'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Tap a day to mark attendance. Tap again to cycle status.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]), textAlign: TextAlign.center),
            ]),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _legendItem(Color color, String symbol, String label) {
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }
}