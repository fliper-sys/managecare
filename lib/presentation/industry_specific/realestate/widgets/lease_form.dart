import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/real_estate_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../../services/email_service.dart';

typedef OnLeaseSubmit = Future<void> Function(Lease lease);

class LeaseForm extends StatefulWidget {
  final Lease? initial;
  final OnLeaseSubmit onSubmit;
  final List<Property> properties;
  final List<Tenant> tenants;
  final String submitText;

  const LeaseForm({
    Key? key,
    this.initial,
    required this.onSubmit,
    required this.properties,
    required this.tenants,
    this.submitText = 'Save',
  }) : super(key: key);

  @override
  State<LeaseForm> createState() => _LeaseFormState();
}

class _LeaseFormState extends State<LeaseForm> {
  final _formKey = GlobalKey<FormState>();
  final dateFormat = DateFormat('yyyy-MM-dd');

  late TextEditingController _monthlyRentCtrl;
  late TextEditingController _depositCtrl;
  late TextEditingController _startDateCtrl;
  late TextEditingController _endDateCtrl;
  late TextEditingController _documentCtrl;

  String _selectedPropertyId = '';
  String _selectedTenantId = '';
  String _selectedStatus = 'active';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _monthlyRentCtrl = TextEditingController(text: widget.initial?.monthlyRent.toString() ?? '');
    _depositCtrl = TextEditingController(text: widget.initial?.deposit.toString() ?? '');
    _startDateCtrl = TextEditingController(text: widget.initial != null ? dateFormat.format(widget.initial!.startDate) : '');
    _endDateCtrl = TextEditingController(text: widget.initial != null ? dateFormat.format(widget.initial!.endDate) : '');
    _documentCtrl = TextEditingController(text: widget.initial?.documentUrl ?? '');

    _selectedPropertyId = widget.initial?.propertyId ?? (widget.properties.isNotEmpty ? widget.properties[0].id : '');
    _selectedTenantId = widget.initial?.tenantId ?? (widget.tenants.isNotEmpty ? widget.tenants[0].id : '');
    _selectedStatus = widget.initial?.status ?? 'active';
  }

  @override
  void dispose() {
    _monthlyRentCtrl.dispose();
    _depositCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _documentCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 10);

    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selected != null) {
      setState(() => controller.text = dateFormat.format(selected));
    }
  }

  double _parseAmount(String raw) {
    final s = raw.replaceAll(RegExp(r'[^0-9\.]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final startDate = dateFormat.parse(_startDateCtrl.text);
      final endDate = dateFormat.parse(_endDateCtrl.text);

      if (endDate.isBefore(startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
        return;
      }

      final lease = Lease(
        id: widget.initial?.id ?? '',
        propertyId: _selectedPropertyId,
        tenantId: _selectedTenantId,
        startDate: startDate,
        endDate: endDate,
        monthlyRent: _parseAmount(_monthlyRentCtrl.text),
        deposit: _parseAmount(_depositCtrl.text),
        status: _selectedStatus,
        documentUrl: _documentCtrl.text.trim().isEmpty ? null : _documentCtrl.text.trim(),
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
      );

      await widget.onSubmit(lease);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.submitText} successful')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Property', style: AppTextStyles.body1),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedPropertyId.isNotEmpty ? _selectedPropertyId : null,
            isExpanded: true,
            items: widget.properties.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.title} (${p.location})'))).toList(),
            onChanged: (v) => setState(() => _selectedPropertyId = v ?? ''),
          ),
          const SizedBox(height: 12),
          const Text('Tenant', style: AppTextStyles.body1),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedTenantId.isNotEmpty ? _selectedTenantId : null,
            isExpanded: true,
            items: widget.tenants.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => _selectedTenantId = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _startDateCtrl,
            decoration: InputDecoration(labelText: 'Start Date (YYYY-MM-DD)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(_startDateCtrl))),
            readOnly: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Start date is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _endDateCtrl,
            decoration: InputDecoration(labelText: 'End Date (YYYY-MM-DD)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(_endDateCtrl))),
            readOnly: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'End date is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _monthlyRentCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Monthly Rent (₦)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) {
              final val = _parseAmount(v ?? '');
              if (val <= 0) return 'Monthly rent must be greater than zero';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _depositCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Security Deposit (₦)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) {
              final val = _parseAmount(v ?? '');
              if (val < 0) return 'Deposit cannot be negative';
              return null;
            },
          ),
          const SizedBox(height: 12),
          const Text('Lease Status', style: AppTextStyles.body1),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedStatus,
            isExpanded: true,
            items: ['active', 'expired', 'terminated']
                .map((status) => DropdownMenuItem(value: status, child: Text(status.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _selectedStatus = v ?? 'active'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _documentCtrl,
                  decoration: InputDecoration(labelText: 'Lease Document URL (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload'),
                onPressed: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                    );
                    if (result == null || result.files.isEmpty) return;
                    final picked = result.files.single;
                    String? url;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading document...')));
                    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
                      url = await EmailService().uploadBytes(picked.bytes!, picked.name);
                    } else if (picked.path != null && picked.path!.isNotEmpty) {
                      url = await EmailService().uploadFile(File(picked.path!));
                    }

                    if (url != null) {
                      final cache = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
                      setState(() => _documentCtrl.text = cache);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
                  }
                },
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: _isSubmitting ? null : _handleSubmit, child: _isSubmitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white), strokeWidth: 2)) : Text(widget.submitText)))
          ])
        ],
      ),
    );
  }
}
