import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';

class DateRangeOption {
  final String label;
  final DateTimeRange range;

  DateRangeOption({required this.label, required this.range});
}

/// Widget for selecting date ranges with preset options
class DateRangeSelector extends StatefulWidget {
  final Function(DateTimeRange) onRangeChanged;
  final DateTimeRange initialRange;
  final Color? backgroundColor;
  final Color? textColor;

  const DateRangeSelector({
    super.key,
    required this.onRangeChanged,
    required this.initialRange,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  late DateTimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialRange;
  }

  List<DateRangeOption> _getPresets() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final startOfWeek =
        startOfToday.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final startOfMonth = DateTime(today.year, today.month, 1);
    final endOfMonth = DateTime(today.year, today.month + 1, 1);

    final startOfYear = DateTime(today.year, 1, 1);
    final endOfYear = DateTime(today.year + 1, 1, 1);

    return [
      DateRangeOption(
        label: 'Today',
        range: DateTimeRange(start: startOfToday, end: endOfToday),
      ),
      DateRangeOption(
        label: 'This Week',
        range: DateTimeRange(start: startOfWeek, end: endOfWeek),
      ),
      DateRangeOption(
        label: 'This Month',
        range: DateTimeRange(start: startOfMonth, end: endOfMonth),
      ),
      DateRangeOption(
        label: 'This Year',
        range: DateTimeRange(start: startOfYear, end: endOfYear),
      ),
    ];
  }

  Future<void> _showCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedRange = picked);
      widget.onRangeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = _getPresets();
    final formatter = DateFormat('dd MMM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset Buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...presets.map((preset) {
                final isSelected =
                    _selectedRange.start.compareTo(preset.range.start) == 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedRange = preset.range);
                        widget.onRangeChanged(preset.range);
                      }
                    },
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: const Text('Custom'),
                  onPressed: _showCustomDatePicker,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Selected Date Range Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatter.format(_selectedRange.start)} - ${formatter.format(_selectedRange.end)}',
                style: AppTextStyles.body1.copyWith(
                  color: widget.textColor ?? (widget.backgroundColor != null ? Colors.white : AppColors.primary),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_selectedRange.duration.inDays} days',
                style: AppTextStyles.body2.copyWith(
                  color: widget.textColor ?? (widget.backgroundColor != null ? Colors.white70 : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

