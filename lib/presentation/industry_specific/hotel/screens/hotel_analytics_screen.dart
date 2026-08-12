// ═══════════════════════════════════════════════════════════════════════════
// HOTEL ANALYTICS SCREEN
// ═══════════════════════════════════════════════════════════════════════════
//
// Hotel-specific analytics that replaces the generic advanced analytics
// routing for the hotel dashboard. Every metric is computed client-side
// from HotelProvider.reservations filtered by the selected date range, so
// no additional Firestore reads are needed.
//
// Sections (per the requirements doc + practical hotel operations needs):
//
//   1. Date range selector — controls all sections below (default: last 30d)
//   2. Top KPIs — Total revenue, ADR (average daily rate),
//      Occupancy %, RevPAR (revenue per available room)
//   3. Revenue trend — line chart, daily revenue across the selected range
//   4. Room type revenue comparison — bar chart, revenue grouped by
//      room type (single/double/suite/deluxe/etc)
//   5. Top-performing rooms leaderboard — 10 rooms with the most revenue
//      in the range, showing bookings + occupancy % + revenue
//   6. Most profitable periods — three cards showing the single most
//      profitable day, week, and month within the selected range
//   7. Booking source breakdown — pie chart (walk-in / phone / online etc)
//
// Only reservations with status in {'checked-in', 'checked-out'} count
// toward revenue (confirmed but not-yet-arrived, and cancelled are excluded).

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/hotel_provider.dart';
import '../../../../widgets/date_range_selector.dart';

class HotelAnalyticsScreen extends StatefulWidget {
  const HotelAnalyticsScreen({super.key});

  @override
  State<HotelAnalyticsScreen> createState() => _HotelAnalyticsScreenState();
}

class _HotelAnalyticsScreenState extends State<HotelAnalyticsScreen> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  // Reservations that fall within the selected date range and count for
  // revenue purposes. We take anything whose check-in date is within the
  // window and whose status shows it actually happened.
  List<Reservation> _reservationsInRange(HotelProvider provider) {
    return provider.reservations.where((r) {
      if (r.status == 'cancelled') return false;
      if (r.status == 'confirmed') return false; // not yet arrived
      return !r.checkIn.isBefore(_range.start) &&
          !r.checkIn.isAfter(_range.end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hotel Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<HotelProvider>(
        builder: (context, provider, _) {
          final relevant = _reservationsInRange(provider);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateRangeSelector(
                  initialRange: _range,
                  onRangeChanged: (r) => setState(() => _range = r),
                ),
                const SizedBox(height: 16),
                _KpiRow(reservations: relevant, provider: provider, range: _range),
                const SizedBox(height: 20),
                _SectionTitle('Revenue trend', subtitle: 'Daily revenue across the range'),
                const SizedBox(height: 10),
                _RevenueTrendChart(reservations: relevant, range: _range),
                const SizedBox(height: 24),
                _SectionTitle('Room type comparison',
                    subtitle: 'Total revenue per room type'),
                const SizedBox(height: 10),
                _RoomTypeChart(reservations: relevant, provider: provider),
                const SizedBox(height: 24),
                _SectionTitle('Top-performing rooms',
                    subtitle: 'Highest revenue in the selected range'),
                const SizedBox(height: 10),
                _TopRoomsList(
                    reservations: relevant, provider: provider, range: _range),
                const SizedBox(height: 24),
                _SectionTitle('Most profitable periods',
                    subtitle: 'Best day, week and month within range'),
                const SizedBox(height: 10),
                _ProfitablePeriods(reservations: relevant),
                const SizedBox(height: 24),
                _SectionTitle('Booking sources',
                    subtitle: 'Where your guests came from'),
                const SizedBox(height: 10),
                _BookingSourcePie(reservations: relevant),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section title
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle(this.title, {this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// KPI row: Revenue, ADR, Occupancy, RevPAR
// ═══════════════════════════════════════════════════════════════════════════

class _KpiRow extends StatelessWidget {
  final List<Reservation> reservations;
  final HotelProvider provider;
  final DateTimeRange range;
  const _KpiRow(
      {required this.reservations,
      required this.provider,
      required this.range});

  @override
  Widget build(BuildContext context) {
    final totalRevenue = reservations.fold<double>(0, (s, r) => s + r.totalPrice);
    final totalNights = reservations.fold<int>(0, (s, r) {
      final n = r.checkOut.difference(r.checkIn).inDays;
      return s + (n > 0 ? n : 1);
    });
    final adr = totalNights == 0 ? 0.0 : totalRevenue / totalNights;
    final totalRooms = provider.rooms.length;
    final rangeDays = range.duration.inDays + 1;
    final availableRoomNights = totalRooms * rangeDays;
    final occupancy = availableRoomNights == 0
        ? 0.0
        : (totalNights / availableRoomNights) * 100;
    final revPar = totalRooms == 0 ? 0.0 : totalRevenue / (totalRooms * rangeDays);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _KpiCard(
          label: 'Total revenue',
          value: formatCurrency(totalRevenue, decimalDigits: 0),
          icon: Icons.payments_outlined,
          color: Colors.green,
        ),
        _KpiCard(
          label: 'ADR',
          hint: 'Avg daily rate',
          value: formatCurrency(adr, decimalDigits: 0),
          icon: Icons.trending_up,
          color: Colors.blue,
        ),
        _KpiCard(
          label: 'Occupancy',
          value: '${occupancy.toStringAsFixed(1)}%',
          icon: Icons.hotel_rounded,
          color: Colors.orange,
        ),
        _KpiCard(
          label: 'RevPAR',
          hint: 'Rev per avail room',
          value: formatCurrency(revPar, decimalDigits: 0),
          icon: Icons.insights_outlined,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String? hint;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.label,
    this.hint,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (hint != null)
                Text(hint!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Revenue trend line chart
// ═══════════════════════════════════════════════════════════════════════════

class _RevenueTrendChart extends StatelessWidget {
  final List<Reservation> reservations;
  final DateTimeRange range;
  const _RevenueTrendChart(
      {required this.reservations, required this.range});

  @override
  Widget build(BuildContext context) {
    // Bucket revenue by day.
    final byDay = <DateTime, double>{};
    final start =
        DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      byDay[d] = 0;
    }
    for (final r in reservations) {
      final key = DateTime(r.checkIn.year, r.checkIn.month, r.checkIn.day);
      byDay[key] = (byDay[key] ?? 0) + r.totalPrice;
    }

    final entries = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty || entries.every((e) => e.value == 0)) {
      return _emptyCard('No revenue in this range yet.');
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }

    final maxY =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.15;

    return Container(
      padding: const EdgeInsets.all(12),
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (entries.length - 1).toDouble(),
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  _shortMoney(value),
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (entries.length / 5).ceilToDouble().clamp(1, 30),
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox();
                  return Text(DateFormat('d/M').format(entries[i].key),
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]));
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: entries.length <= 15,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.primary,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Room type revenue comparison
// ═══════════════════════════════════════════════════════════════════════════

class _RoomTypeChart extends StatelessWidget {
  final List<Reservation> reservations;
  final HotelProvider provider;
  const _RoomTypeChart({required this.reservations, required this.provider});

  @override
  Widget build(BuildContext context) {
    final byType = <String, double>{};
    for (final r in reservations) {
      final room = provider.getRoomById(r.roomId);
      final type = (room?.type ?? 'Other').trim();
      final key = type.isEmpty ? 'Other' : type;
      byType[key] = (byType[key] ?? 0) + r.totalPrice;
    }
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _emptyCard('No completed bookings yet in this range.');
    }

    final maxY = entries.first.value * 1.15;
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  _shortMoney(value),
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      entries[i].key,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value,
                    color: colors[i % colors.length],
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top rooms leaderboard
// ═══════════════════════════════════════════════════════════════════════════

class _TopRoomsList extends StatelessWidget {
  final List<Reservation> reservations;
  final HotelProvider provider;
  final DateTimeRange range;
  const _TopRoomsList({
    required this.reservations,
    required this.provider,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final byRoom = <String, _RoomAgg>{};
    for (final r in reservations) {
      final agg = byRoom.putIfAbsent(r.roomId, () => _RoomAgg());
      agg.revenue += r.totalPrice;
      agg.bookings += 1;
      final nights = r.checkOut.difference(r.checkIn).inDays;
      agg.nights += nights > 0 ? nights : 1;
    }

    final rangeDays = range.duration.inDays + 1;
    final entries = byRoom.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    final top = entries.take(10).toList();

    if (top.isEmpty) {
      return _emptyCard('No completed bookings yet in this range.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++)
            _leaderboardRow(
              rank: i + 1,
              room: provider.getRoomById(top[i].key),
              agg: top[i].value,
              maxNightsInRange: rangeDays,
              isLast: i == top.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _leaderboardRow({
    required int rank,
    required Room? room,
    required _RoomAgg agg,
    required int maxNightsInRange,
    required bool isLast,
  }) {
    final occupancyPct =
        maxNightsInRange == 0 ? 0.0 : (agg.nights / maxNightsInRange) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1
                  ? Colors.amber
                  : rank <= 3
                      ? Colors.grey.shade400
                      : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.white : Colors.grey[700],
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room ${room?.number ?? '—'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                    '${room?.type ?? 'Unknown'} • '
                    '${agg.bookings} booking${agg.bookings == 1 ? '' : 's'} • '
                    '${occupancyPct.toStringAsFixed(0)}% occupancy',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Text(formatCurrency(agg.revenue, decimalDigits: 0),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _RoomAgg {
  double revenue = 0;
  int bookings = 0;
  int nights = 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// Most profitable periods (best day, best week, best month)
// ═══════════════════════════════════════════════════════════════════════════

class _ProfitablePeriods extends StatelessWidget {
  final List<Reservation> reservations;
  const _ProfitablePeriods({required this.reservations});

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return _emptyCard('No completed bookings yet in this range.');
    }

    // Best day
    final byDay = <DateTime, double>{};
    for (final r in reservations) {
      final k = DateTime(r.checkIn.year, r.checkIn.month, r.checkIn.day);
      byDay[k] = (byDay[k] ?? 0) + r.totalPrice;
    }
    final bestDay = byDay.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Best week (year + iso week)
    final byWeek = <String, _PeriodAgg>{};
    for (final r in reservations) {
      final wk = _isoWeekKey(r.checkIn);
      final agg = byWeek.putIfAbsent(wk, () => _PeriodAgg(anyDate: r.checkIn));
      agg.total += r.totalPrice;
    }
    final bestWeek =
        byWeek.entries.reduce((a, b) => a.value.total >= b.value.total ? a : b);

    // Best month
    final byMonth = <String, _PeriodAgg>{};
    for (final r in reservations) {
      final mk = DateFormat('yyyy-MM').format(r.checkIn);
      final agg = byMonth.putIfAbsent(mk, () => _PeriodAgg(anyDate: r.checkIn));
      agg.total += r.totalPrice;
    }
    final bestMonth = byMonth.entries
        .reduce((a, b) => a.value.total >= b.value.total ? a : b);

    return Column(
      children: [
        _periodCard(
          icon: Icons.wb_sunny,
          color: Colors.orange,
          label: 'Best day',
          period: DateFormat('EEE, d MMM y').format(bestDay.key),
          value: bestDay.value,
        ),
        const SizedBox(height: 10),
        _periodCard(
          icon: Icons.view_week,
          color: Colors.blue,
          label: 'Best week',
          period: _weekLabelFromDate(bestWeek.value.anyDate),
          value: bestWeek.value.total,
        ),
        const SizedBox(height: 10),
        _periodCard(
          icon: Icons.calendar_month,
          color: Colors.green,
          label: 'Best month',
          period: DateFormat('MMMM y').format(bestMonth.value.anyDate),
          value: bestMonth.value.total,
        ),
      ],
    );
  }

  Widget _periodCard({
    required IconData icon,
    required Color color,
    required String label,
    required String period,
    required double value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 2),
                Text(period,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          Text(formatCurrency(value, decimalDigits: 0),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        ],
      ),
    );
  }

  static String _isoWeekKey(DateTime d) {
    final year = d.year;
    // ISO 8601-ish week number
    final startOfYear = DateTime(year, 1, 1);
    final days = d.difference(startOfYear).inDays;
    final week = ((days + startOfYear.weekday - 1) / 7).ceil();
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  static String _weekLabelFromDate(DateTime d) {
    // Show "Week of Mon d MMM" (Monday-anchored)
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return 'Week of ${DateFormat('EEE, d MMM').format(monday)}';
  }
}

class _PeriodAgg {
  double total = 0;
  DateTime anyDate;
  _PeriodAgg({required this.anyDate});
}

// ═══════════════════════════════════════════════════════════════════════════
// Booking source pie chart
// ═══════════════════════════════════════════════════════════════════════════

class _BookingSourcePie extends StatelessWidget {
  final List<Reservation> reservations;
  const _BookingSourcePie({required this.reservations});

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return _emptyCard('No completed bookings yet in this range.');
    }

    final byCount = <String, int>{};
    for (final r in reservations) {
      final src = (r.bookingSource.isEmpty ? 'walk-in' : r.bookingSource)
          .toLowerCase();
      byCount[src] = (byCount[src] ?? 0) + 1;
    }
    final entries = byCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      color: colors[i % colors.length],
                      value: entries[i].value.toDouble(),
                      title: '${((entries[i].value / total) * 100).round()}%',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _humanSource(entries[i].key),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                        Text('${entries[i].value}',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _humanSource(String s) {
    if (s.isEmpty) return 'Walk-in';
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

Widget _emptyCard(String message) {
  return Container(
    height: 140,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Center(
      child: Text(message,
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center),
    ),
  );
}

/// Format a number as compact money for chart axes: "₦12k", "₦1.2M".
String _shortMoney(double value) {
  if (value.abs() >= 1000000) return '₦${(value / 1000000).toStringAsFixed(1)}M';
  if (value.abs() >= 1000) return '₦${(value / 1000).toStringAsFixed(0)}k';
  return '₦${value.toStringAsFixed(0)}';
}
