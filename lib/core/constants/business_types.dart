import 'package:flutter/material.dart';
import '../theme/colors.dart';

class BusinessType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  const BusinessType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}

class BusinessTypes {
  static const List<BusinessType> all = [
    BusinessType(
      id: 'pharmacy',
      name: 'Pharmacy',
      description: 'Manage prescriptions, drug inventory, and patient records',
      icon: Icons.local_pharmacy,
      color: AppColors.pharmacy,
      features: [
        'Prescription Management',
        'Drug Inventory',
        'Expiry Tracking',
        'Patient Records',
        'Controlled Substances',
      ],
    ),
    BusinessType(
      id: 'retail',
      name: 'Retail Store',
      description: 'Point of sale, inventory, and multi-store management',
      icon: Icons.store,
      color: AppColors.retail,
      features: [
        'Point of Sale',
        'Product Catalog',
        'Multi-Store Support',
        'Supplier Management',
        'Promotions & Discounts',
      ],
    ),
    BusinessType(
      id: 'wholesale',
      name: 'Wholesale',
      description: 'Wholesale distribution: bulk orders, purchase orders and stock transfers',
      icon: Icons.local_shipping,
      color: AppColors.primary,
      features: [
        'Purchase Orders',
        'Stock Transfers',
        'Bulk Pricing',
        'B2B Orders',
        'Inventory Management (Warehouse)',
        'Wholesale POS',
      ],
    ),
    BusinessType(
      id: 'agri',

      name: 'Agriculture',
      description: 'Farm management, crop tracking, and livestock monitoring',
      icon: Icons.agriculture,
      color: AppColors.agri,
      features: [
        'Farm Management',
        'Crop Cycles',
        'Livestock Tracking',
        'Harvest Records',
        'Input Inventory',
        'Weather Integration',
      ],
    ),
    BusinessType(
      id: 'auto',
      name: 'Auto Service',
      description: 'Vehicle service orders, job cards, and parts inventory',
      icon: Icons.car_repair,
      color: AppColors.auto,
      features: [
        'Service Orders',
        'Job Cards',
        'Vehicle History',
        'Parts Inventory',
        'Mechanic Schedules',
        'Diagnostics',
      ],
    ),
    BusinessType(
      id: 'salon',
      name: 'Salon & Spa',
      description: 'Appointment booking, stylist management, and services',
      icon: Icons.content_cut,
      color: AppColors.salon,
      features: [
        'Appointment Booking',
        'Calendar View',
        'Stylist Schedules',
        'Service Catalog',
        'Tips Tracking',
        'Commission Management',
      ],
    ),
    BusinessType(
      id: 'barbershop',
      name: 'Barbershop',
      description: 'Barber appointments, payments, and sales reporting',
      icon: Icons.content_cut,
      color: AppColors.salon,
      features: [
        'Appointment Booking',
        'Payments & Sales',
        'Sales History',
        'Barber Management',
        'Commission & Tips',
      ],
    ),
    BusinessType(
      id: 'hotel',
      name: 'Hotel',
      description: 'Room management, bookings, and guest services',
      icon: Icons.hotel,
      color: AppColors.hotel,
      features: [
        'Front Desk',
        'Room Management',
        'Booking System',
        'Check-in/Check-out',
        'Guest Management',
        'Housekeeping',
        'Restaurant POS',
        'Bar POS',
      ],
    ),
    BusinessType(
      id: 'drink',
      name: 'Bar & Lounge',
      description: 'Beverage inventory, bottle tracking, and tabs management',
      icon: Icons.local_bar,
      color: AppColors.drink,
      features: [
        'Bar POS',
        'Beverage Inventory',
        'Bottle Tracking',
        'Bar Tabs',
        'Pour Size Tracking',
      ],
    ),
    BusinessType(
      id: 'restaurant',
      name: 'Restaurant',
      description: 'Table management, orders, and kitchen operations',
      icon: Icons.restaurant,
      color: AppColors.restaurant,
      features: [
        'Table Management',
        'Order Taking',
        'Kitchen Display',
        'Menu Management',
        'Reservations',
        'Delivery Orders',
        'Waiter Assignment',
      ],
    ),
    BusinessType(
      id: 'realestate',
      name: 'Real Estate',
      description: 'Property management, tenants, and maintenance tracking',
      icon: Icons.apartment,
      color: AppColors.realEstate,
      features: [
        'Property Management',
        'Tenant Management',
        'Lease Tracking',
        'Rent Collection',
        'Maintenance Tickets',
        'Document Storage',
      ],
    ),
    BusinessType(
      id: 'apartment',
      name: 'Apartment Management',
      description: 'Manage apartment blocks, units, bookings and tenant deposits',
      icon: Icons.home,
      color: AppColors.realEstate,
      features: [
        'Apartment & Unit Management',
        'Unit Bookings',
        'Deposit & Cancellation Policy',
        'Tenant Management',
        'Availability Enforcement',
        'Receipts & Payments',
      ],
    ),
    BusinessType(
      id: 'gym',
      name: 'Gym & Fitness',
      description: 'Member management, class schedules, and billing',
      icon: Icons.fitness_center,
      color: AppColors.primary,
      features: [
        'Member Management',
        'Class Schedules',
        'Membership Plans',
        'Billing & Payments',
        'Attendance Tracking',
        'Member Engagement',
      ],
    ),
    BusinessType(
      id: 'gas',
      name: 'Gas & Petrol Station',
      description: 'Fuel inventory and pump sales for petrol and gas (litres/kg)',
      icon: Icons.local_gas_station,
      color: AppColors.primary,
      features: [
        'Fuel Inventory (litres/kg)',
        'Set price per litre/kg',
        'Sell by amount or volume',
        'Pump / Quick Sale UI',
        'Receipt printing',
        'Sales Notifications',
      ],
    ),
  ];

  static BusinessType? getById(String id) {
    try {
      final normalized = _normalizeId(id);
      return all.firstWhere((type) => type.id == normalized || type.id == id);
    } catch (e) {
      return null;
    }
  }

  static String getName(String id) {
    final type = getById(id);
    return type?.name ?? 'Business';
  }

  static Color getColor(String id) {
    final type = getById(id);
    return type?.color ?? AppColors.primary;
  }

  static IconData getIcon(String id) {
    final type = getById(id);
    return type?.icon ?? Icons.business;
  }

  static List<String> getFeatures(String id) {
    final type = getById(id);
    return type?.features ?? [];
  }

  static String _normalizeId(String id) {
    if (id.isEmpty) return id;
    final s = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const Map<String, String> map = {
      'bar': 'drink',
      'barlounge': 'drink',
      'barandlounge': 'drink',
      'bars': 'drink',
      'pub': 'drink',
      'drink': 'drink',
      'barber': 'barbershop',
      'barbershop': 'barbershop',
      'retailstore': 'retail',
      'realestate': 'realestate',
    };
    // Normalize common plural/synonym forms
    const additional = {
      'apartments': 'apartment',
      'apartment': 'apartment',
    };
    final merged = {...map, ...additional};
    return merged[s] ?? id;
  }
}

