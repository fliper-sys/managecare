import 'package:flutter/material.dart';
import '../providers/real_estate_provider.dart';

typedef OnTenantSubmit = Future<void> Function(Tenant tenant);

class TenantForm extends StatefulWidget {
  final Tenant? initial;
  final OnTenantSubmit onSubmit;
  final String submitText;

  const TenantForm({
    Key? key,
    this.initial,
    required this.onSubmit,
    this.submitText = 'Save',
  }) : super(key: key);

  @override
  State<TenantForm> createState() => _TenantFormState();
}

class _TenantFormState extends State<TenantForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _propertyCtrl;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.initial?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.initial?.phone ?? '');
    _propertyCtrl = TextEditingController(text: widget.initial?.propertyId ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _propertyCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$').hasMatch(phone);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final tenant = Tenant(
        id: widget.initial?.id ?? '',
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        propertyId: _propertyCtrl.text.trim(),
        status: widget.initial?.status ?? 'active',
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
      );

      await widget.onSubmit(tenant);
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
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!_isValidEmail(v)) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone number is required';
              if (!_isValidPhone(v)) return 'Please enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _propertyCtrl,
            decoration: InputDecoration(labelText: 'Property ID (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
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
