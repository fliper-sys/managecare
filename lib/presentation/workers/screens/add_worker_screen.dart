import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/constants/routes.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as fb_core;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/workers_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../industry_specific/barber_shop/providers/barber_shop_provider.dart';
import '../../industry_specific/salon/providers/salon_provider.dart';
import '../../../services/email_service.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../data/repositories/worker_repository_impl.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../widgets/loading_indicator.dart';

class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _commissionController = TextEditingController();
  final _pinController = TextEditingController();
  // support multiple roles for workers (salon/barber may need multiple roles)
  final Set<String> _selectedRoles = {'staff'}; 
  final List<String> _selectedServiceIds = [];
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _sendInvitationEmail = true;
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    // Ensure stores are loaded so the store dropdown is populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final retail = context.read<RetailProvider>();
        if (retail.stores.isEmpty) retail.loadStores();
      } catch (_) {}
    });
    // Prefill a simple 4-digit PIN to make onboarding quick
    _pinController.text = _generateRandomPin();
  }

  String _generateRandomPin() {
    return (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
  }

  Future<bool> _workerEmailExists(
    String normalizedEmail, {
    String? businessId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final trimmedBusinessId = businessId?.trim() ?? '';

    Future<bool> _hasMatch(
      String collection, {
      required String field,
    }) async {
      final query = await firestore
          .collection(collection)
          .where(field, isEqualTo: normalizedEmail)
          .limit(5)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        final isActive = data['isActive'];
        if (isActive is bool && !isActive) continue;
        final docBusinessId = (data['businessId'] ?? '').toString().trim();
        if (trimmedBusinessId.isEmpty || docBusinessId == trimmedBusinessId) {
          return true;
        }
      }
      return false;
    }

    if (await _hasMatch('workers', field: 'emailLowercase')) return true;
    if (await _hasMatch('workers', field: 'email')) return true;
    if (await _hasMatch('users', field: 'email')) return true;
    return false;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _commissionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  List<String> _getRolesForBusiness(String businessType) {
    switch (businessType.toLowerCase()) {
      case 'restaurant':
        return ['sub_admin', 'manager', 'chef', 'cashier', 'waiter', 'staff'];
      case 'salon':
      case 'barber':
      case 'barbershop':
      case 'beauty':
        return ['manager', 'hairstylist', 'barber', 'cashier', 'staff'];
      case 'pharmacy':
        return ['manager', 'pharmacist', 'cashier', 'staff'];
      case 'hotel':
      case 'hospitality':
      case 'apartment':
        return [
          'manager',
          'receptionist',
          'frontdesk',
          'waiter',
          'housekeeper',
          'hr',
          'staff',
        ];
      case 'auto':
      case 'auto repair':
      case 'autorepair':
        return [
          'manager',
          'mechanic',
          'electrician',
          'body_technician',
          'painter',
          'valucnizer',
          'staff',
        ];
      default:
        return ['manager', 'cashier', 'staff', 'assistant'];
    }
  }

  String _readableRole(String role) {
    if (role.isEmpty) return role;
    return role.splitMapJoin(RegExp(r'[_\s]'), onMatch: (m) => ' ', onNonMatch: (s) => s)
        .split(' ')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  String _roleDescription(String role) {
    final description = WorkerPermissions.getRoleDescription(role);
    return description.isEmpty
        ? 'Assigned to ${_readableRole(role).toLowerCase()} duties.'
        : description;
  }

  List<String> _effectivePermissionsForSelection() {
    return WorkerPermissions.getPermissionsForRoles(_selectedRoles).toList();
  }

  Future<void> _handleAddWorker() async {
    if (!_formKey.currentState!.validate()) return;

    final businessProvider = context.read<BusinessProvider>();
    final workersProvider = context.read<WorkersProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';
    if (businessId.isNotEmpty) {
      await workersProvider.refreshForBusiness(businessId);
    }
    final currentWorkerCount = workersProvider.workers.length;

    if (!businessProvider.isWithinLimit('workers', currentWorkerCount)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Worker limit reached'),
          content: Text(
            businessProvider.getLimitReachedMessage('workers'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No authenticated user')),
      );
      return;
    }

    final currentUser = authProvider.currentUser!;
    if (!WorkerPermissions.canManageStaffForUser(
      currentUser.role,
      currentUser.permissions,
    )) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to add workers.'),
        ),
      );
      return;
    }

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();
      final duplicateWorkerExists = workersProvider.workers.any((worker) {
        final existingEmail =
            (worker['email'] ?? '').toString().trim().toLowerCase();
        return existingEmail == normalizedEmail;
      });
      if (duplicateWorkerExists) {
        throw Exception('A worker with this email already exists.');
      }
      final duplicateWorkerInStore = await _workerEmailExists(
        normalizedEmail,
        businessId: businessId,
      );
      if (duplicateWorkerInStore) {
        throw Exception(
          'A worker login with this email already exists for this business.',
        );
      }

      // Prepare password (owner may supply it) or generate a temporary one
      var password = _passwordController.text.trim();
      if (password.isEmpty) {
        password =
            'Temp${DateTime.now().millisecondsSinceEpoch}'.substring(0, 12);
      }

      // Hash password before storing in Firestore (better than plaintext).
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      final businessType = context.read<BusinessProvider>().currentBusiness?.businessType;

      final primaryRole = _selectedRoles.isNotEmpty ? _selectedRoles.first : 'staff';
      final effectivePermissions = _effectivePermissionsForSelection();

      // Commission percentage (if worker is barber/stylist)
      final commissionPct = (_selectedRoles.contains('barber') || _selectedRoles.contains('hairstylist') || _selectedRoles.contains('stylist'))
          ? (double.tryParse(_commissionController.text.trim()) ?? 0.0)
          : 0.0;

      late final UserModel worker;
      fb_core.FirebaseApp? tempApp;
      fb_auth.FirebaseAuth? tempAuth;
      var authAccountCreated = false;
      try {
        final defaultApp = fb_core.Firebase.app();
        final tempAppName =
            'temp_worker_create_${DateTime.now().millisecondsSinceEpoch}';
        tempApp = await fb_core.Firebase.initializeApp(
          name: tempAppName,
          options: defaultApp.options,
        );
        tempAuth = fb_auth.FirebaseAuth.instanceFor(app: tempApp);

        final authResult = await tempAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        final firebaseUser = authResult.user;
        if (firebaseUser == null) {
          throw Exception('Failed to create worker login account.');
        }
        authAccountCreated = true;

        worker = UserModel(
          id: firebaseUser.uid,
          email: normalizedEmail,
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          role: primaryRole,
          permissions: effectivePermissions,
          businessId: authProvider.currentUser!.businessId,
          businessType: businessType,
          storeId: _selectedStoreId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
          isOwner: false,
          pin: _pinController.text.trim(),
          // Reuse subscriptionTransactionId as a temporary storage for the password hash.
          subscriptionTransactionId: passwordHash,
        );

        final repo =
            AuthRepositoryImpl(firebaseAuth: fb_auth.FirebaseAuth.instance);
        await repo.createOrUpdateUser(worker);
      } on fb_auth.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw Exception(
            'This email is already linked to an existing worker login.',
          );
        }
        rethrow;
      } catch (e) {
        if (authAccountCreated && tempAuth?.currentUser != null) {
          try {
            await tempAuth!.currentUser!.delete();
          } catch (deleteError) {
            print('[AddWorker] Failed to rollback auth user creation: $deleteError');
          }
        }
        rethrow;
      } finally {
        try {
          await tempAuth?.signOut();
        } catch (_) {}
        try {
          await tempApp?.delete();
        } catch (_) {}
      }

      // ALSO save to workers collection for WorkersProvider to find
      try {
        final workerRepo =
            WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
        final businessType = context.read<BusinessProvider>().currentBusiness?.businessType;

        // Resolve selected service names for convenience
        List<String> selectedServiceNames = [];
        if (_selectedServiceIds.isNotEmpty) {
          if ((businessType ?? '').toLowerCase() == 'barber' || (businessType ?? '').toLowerCase() == 'barbershop') {
            final barberProvider = context.read<BarberShopProvider>();
            selectedServiceNames = barberProvider.services
                .where((s) => _selectedServiceIds.contains(s.id))
                .map((s) => s.name)
                .toList();
          } else if ((businessType ?? '').toLowerCase() == 'salon') {
            final salonProvider = context.read<SalonProvider>();
            selectedServiceNames = salonProvider.services
                .where((s) => _selectedServiceIds.contains(s.id))
                .map((s) => s.name)
                .toList();
          }
        }



        final workerData = {
          'id': worker.id,
          'name': _fullNameController.text.trim(),
          'fullName': _fullNameController.text.trim(),
          'email': normalizedEmail,
          'emailLowercase': normalizedEmail,
          'phoneNumber': _phoneController.text.trim(),
          'role': primaryRole,
          'roles': _selectedRoles.toList(),
          'permissions': effectivePermissions,
          'customPermissions': effectivePermissions,
          'serviceIds': _selectedServiceIds,
          'serviceNames': selectedServiceNames,
          'commissionPercentage': commissionPct,
          'businessId': authProvider.currentUser!.businessId,
          'businessType': businessType,
          'storeId': _selectedStoreId,
          'pin': _pinController.text.trim(),
          'isActive': true,
          'hireDate': DateTime.now()
              .toString()
              .split(' ')[0], // Store as YYYY-MM-DD format
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        };
        print(
            '[AddWorker] Saving worker with ID: ${worker.id}, data: $workerData');
        await workerRepo.addWorker(workerData);
        print('[AddWorker] Worker saved successfully');
      } catch (e) {
        print('Failed to save worker to workers collection: $e');
        rethrow;
      }

      // Send invitation email if enabled
      if (_sendInvitationEmail && _emailController.text.isNotEmpty) {
        try {
          EmailService().sendWorkerInvitationEmail(normalizedEmail, {
            'name': _fullNameController.text.trim(),
            'role': _selectedRoles.map((r) => _readableRole(r)).join(', '),
            'businessName': authProvider.currentUser!.fullName,
            'email': normalizedEmail,
            'temporaryPassword': password,
          });
        } catch (e) {
          // Log but don't block worker creation
          print('Failed to send invitation email: $e');
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Worker added successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Refresh workers list for current business and wait for it to complete
        try {
          final businessProvider = context.read<BusinessProvider>();
          final bid = businessProvider.currentBusiness?.id ?? '';
          if (bid.isNotEmpty) {
            await context.read<WorkersProvider>().refreshForBusiness(bid);
            await businessProvider.refreshBusinessStats(bid);
          }

          // If worker has barber role and business is barbershop, also create a barber entry
          final businessTypeLow = (businessType ?? '').toLowerCase();
          if ((_selectedRoles.contains('barber') || primaryRole == 'barber') && (businessTypeLow == 'barber' || businessTypeLow == 'barbershop')) {
            try {
              final barberDoc = FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(authProvider.currentUser!.businessId)
                  .collection('barbers')
                  .doc(worker.id);

              await barberDoc.set({
                'id': worker.id,
                'name': _fullNameController.text.trim(),
                'email': normalizedEmail,
                'phone': _phoneController.text.trim(),
                'specialization': 'general',
                'serviceIds': _selectedServiceIds,
                'commissionPercentage': commissionPct,
                'isActive': true,
                'createdAt': Timestamp.fromDate(DateTime.now()),
              });

              // Attempt to refresh barber provider state if available
              try {
                final barberProvider = context.read<BarberShopProvider>();
                await barberProvider.loadBarbers();
              } catch (_) {}
            } catch (e) {
              print('[AddWorker] Failed to add barber document: $e');
            }
          }

          // If stylist/hairstylist role and business is a salon, create stylist document
          if ((_selectedRoles.contains('hairstylist') || _selectedRoles.contains('stylist') || primaryRole == 'hairstylist' || primaryRole == 'stylist') && businessTypeLow == 'salon') {
            try {
              final stylistDoc = FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(authProvider.currentUser!.businessId)
                  .collection('stylists')
                  .doc(worker.id);

              await stylistDoc.set({
                'id': worker.id,
                'name': _fullNameController.text.trim(),
                'email': normalizedEmail,
                'phone': _phoneController.text.trim(),
                'specialization': 'stylist',
                'serviceIds': _selectedServiceIds,
                'commissionPercentage': commissionPct,
                'isActive': true,
                'createdAt': Timestamp.fromDate(DateTime.now()),
              });

              // Attempt to refresh salon provider state if available
              try {
                final salonProvider = context.read<SalonProvider>();
                await salonProvider.loadStylists();
              } catch (_) {}
            } catch (e) {
              print('[AddWorker] Failed to add stylist document: $e');
            }
          }
        } catch (_) {}

        // If current user is the owner, send them back to the refreshed
        // workers list so they can see/manage the newly added worker.
        if (authProvider.isOwnerUser) {
          Navigator.pushReplacementNamed(context, Routes.workers);
        } else {
          // Navigate to worker details and include business context so
          // the details screen can scope data by businessId/businessType.
          final businessProvider = context.read<BusinessProvider>();
          final businessType =
              businessProvider.currentBusiness?.businessType ?? '';

          Navigator.pushNamed(
            context,
            Routes.workerDetails,
            arguments: {
              'id': worker.id,
              'businessId': worker.businessId,
              'businessType': businessType,
            },
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add worker: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final canManageStaff = currentUser != null &&
        WorkerPermissions.canManageStaffForUser(
          currentUser.role,
          currentUser.permissions,
        );

    if (!canManageStaff) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add Worker'),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have permission to add or manage workers.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Worker'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Register a new team member',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 4),
              const Text(
                'Add a worker to your business',
                style: AppTextStyles.body2Secondary,
              ),
              const SizedBox(height: 24),

              // Full Name
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter full name' : null,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Password (optional) - owner can set a password for the worker
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password (optional)',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return null; // allow empty -> generate temporary
                  if (value.length < 6)
                    return 'Password must be at least 6 characters';
                  return null;
                },
              ),

              // PIN (4-digit) - owner can set or generate quickly
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pinController,
                      decoration: InputDecoration(
                        labelText: '4-digit PIN (optional)',
                        prefixIcon: const Icon(Icons.pin),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final t = value.trim();
                        if (t.length != 4 || int.tryParse(t) == null) return 'Enter a 4-digit PIN';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () { setState(() => _pinController.text = _generateRandomPin()); },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Role Selection (multiple)
              Builder(builder: (context) {
                final businessType = context.read<BusinessProvider>().currentBusiness?.businessType ?? '';
                final roles = _getRolesForBusiness(businessType);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Choose one or more roles for this worker.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: roles.map((r) {
                        final selected = _selectedRoles.contains(r);
                        return FilterChip(
                          label: Text(_readableRole(r)),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            if (selected) {
                              _selectedRoles.remove(r);
                              if (_selectedRoles.isEmpty) _selectedRoles.add('staff');
                            } else {
                              _selectedRoles.add(r);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Role details',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...roles.map((role) {
                            final selected = _selectedRoles.contains(role);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.info_outline,
                                    size: 18,
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _readableRole(role),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _roleDescription(role),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 12),

              // Store assignment (optional)
              Consumer<RetailProvider>(builder: (context, retail, _) {
                final stores = retail.stores;
                if (stores.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String>(
                  value: _selectedStoreId,
                  decoration: InputDecoration(
                    labelText: 'Assign to Store (optional)',
                    prefixIcon: const Icon(Icons.store),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: stores
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStoreId = val),
                );
              }),

              const SizedBox(height: 12),

              // Service assignment (for Salon/Barber businesses)
              Builder(builder: (context) {
                final businessType = context.read<BusinessProvider>().currentBusiness?.businessType ?? '';
                if (!(businessType.toLowerCase() == 'salon' || businessType.toLowerCase() == 'barber' || businessType.toLowerCase() == 'barbershop')) {
                  return const SizedBox.shrink();
                }

                // Load services from the appropriate provider
                if (businessType.toLowerCase() == 'barber' || businessType.toLowerCase() == 'barbershop') {
                  final barberProvider = context.read<BarberShopProvider>();
                  if (barberProvider.services.isEmpty) barberProvider.loadServices();
                  final services = barberProvider.services;
                  if (services.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Services', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...services.map((s) => CheckboxListTile(
                            title: Text(s.name),
                            subtitle: Text('₦${s.price.toStringAsFixed(0)} • ${s.durationMinutes}min'),
                            value: _selectedServiceIds.contains(s.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedServiceIds.add(s.id);
                              } else {
                                _selectedServiceIds.remove(s.id);
                              }
                            }),
                          )),
                    ],
                  );
                } else {
                  final salonProvider = context.read<SalonProvider>();
                  if (salonProvider.services.isEmpty) salonProvider.loadServices();
                  final services = salonProvider.services;
                  if (services.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Services', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...services.map((s) => CheckboxListTile(
                            title: Text(s.name),
                            subtitle: Text('₦${s.price.toStringAsFixed(0)} • ${s.durationMinutes}min'),
                            value: _selectedServiceIds.contains(s.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedServiceIds.add(s.id);
                              } else {
                                _selectedServiceIds.remove(s.id);
                              }
                            }),
                          )),
                    ],
                  );
                }
              }),

              const SizedBox(height: 20),

              // Commission percentage for barbers/stylists (optional)
              if ((_selectedRoles.contains('barber') || _selectedRoles.contains('hairstylist') || _selectedRoles.contains('stylist')))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _commissionController,
                    decoration: InputDecoration(
                      labelText: 'Commission (%)',
                      prefixIcon: const Icon(Icons.percent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final v = double.tryParse(value);
                      if (v == null) return 'Enter a valid number';
                      if (v < 0 || v > 100) return 'Enter a percentage between 0 and 100';
                      return null;
                    },
                  ),
                ),

              // Send Invitation Email
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 0.5),
                ),
                child: CheckboxListTile(
                  title: const Text('Send invitation email'),
                  subtitle: const Text('Worker will receive login credentials'),
                  value: _sendInvitationEmail,
                  onChanged: (value) =>
                      setState(() => _sendInvitationEmail = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Access level',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This worker will inherit permissions from the selected role(s).',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _effectivePermissionsForSelection()
                          .map(
                            (permission) => Chip(
                              label: Text(
                                WorkerPermissions.getPermissionLabel(permission),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Add Worker Button
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(child: CustomLoadingIndicator())
                    : ElevatedButton.icon(
                        onPressed: _handleAddWorker,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Worker'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

