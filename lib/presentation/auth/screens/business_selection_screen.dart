import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';

/// Business selection screen
class BusinessSelectionScreen extends StatelessWidget {
  final List<BusinessTypeOption> businessTypes = [
    BusinessTypeOption(
      name: 'Pharmacy',
      id: 'pharmacy',
      icon: Icons.local_pharmacy,
      color: const Color(0xFF4CAF50),
    ),
    BusinessTypeOption(
      name: 'Retail',
      id: 'retail',
      icon: Icons.shopping_cart,
      color: const Color(0xFFFF9800),
    ),
    BusinessTypeOption(
      name: 'Bakery',
      id: 'bakery',
      icon: Icons.bakery_dining,
      color: const Color(0xFFD97706),
    ),
    BusinessTypeOption(
      name: 'Wholesale',
      id: 'wholesale',
      icon: Icons.local_shipping,
      color: const Color(0xFF7B1FA2),
    ),
    BusinessTypeOption(
      name: 'Agriculture',
      id: 'agri',
      icon: Icons.agriculture,
      color: const Color(0xFF8BC34A),
    ),
    BusinessTypeOption(
      name: 'Auto Repair',
      id: 'auto',
      icon: Icons.directions_car,
      color: const Color(0xFF616161),
    ),
    BusinessTypeOption(
      name: 'Salon',
      id: 'salon',
      icon: Icons.content_cut,
      color: const Color(0xFFE91E63),
    ),
    BusinessTypeOption(
      name: 'Barbershop',
      id: 'barbershop',
      icon: Icons.content_cut,
      color: const Color(0xFF9C27B0),
    ),
    BusinessTypeOption(
      name: 'Hotel',
      id: 'hotel',
      icon: Icons.hotel,
      color: const Color(0xFF2196F3),
    ),
    BusinessTypeOption(
      name: 'Restaurant',
      id: 'restaurant',
      icon: Icons.restaurant,
      color: const Color(0xFFF44336),
    ),
    BusinessTypeOption(
      name: 'Bar/Drink',
      id: 'drink',
      icon: Icons.local_bar,
      color: const Color(0xFFA52A2A),
    ),
    BusinessTypeOption(
      name: 'Gas & Petrol',
      id: 'gas',
      icon: Icons.local_gas_station,
      color: const Color(0xFFFFC107),
    ),
    BusinessTypeOption(
      name: 'Petroleum Station',
      id: 'petroleum',
      icon: Icons.local_gas_station,
      color: const Color(0xFF0F766E),
    ),
    BusinessTypeOption(
      name: 'Real Estate',
      id: 'realestate',
      icon: Icons.home,
      color: const Color(0xFF795548),
    ),
    BusinessTypeOption(
      name: 'Apartment',
      id: 'apartment',
      icon: Icons.apartment,
      color: const Color(0xFF009688),
    ),
    BusinessTypeOption(
      name: 'Gym & Fitness',
      id: 'gym',
      icon: Icons.fitness_center,
      color: const Color(0xFFE53935),
    ),
  ];

  BusinessSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark ? const Color(0xFF081126) : const Color(0xFFF4F8FD),
                  isDark ? const Color(0xFF0D2445) : const Color(0xFFEAF1FA),
                  isDark ? const Color(0xFF13386A) : const Color(0xFFF8FBFF),
                ],
              ),
            ),
          ),
          _buildAccentOrb(
            top: -100,
            right: -60,
            size: 220,
            color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.10),
          ),
          _buildAccentOrb(
            bottom: -120,
            left: -70,
            size: 240,
            color: const Color(0xFFF3B35C).withOpacity(isDark ? 0.10 : 0.12),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.white,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.12 : 0.06,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (Navigator.of(context).canPop())
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.arrow_back_rounded,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF10223F),
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : const Color(0xFFF3F6FB),
                                  ),
                                ),
                              if (Navigator.of(context).canPop())
                                const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(
                                    isDark ? 0.18 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Business setup',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Choose the business you are setting up.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF10223F),
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pick the category that matches your operations. We will use it to tailor dashboards, inventory tools, and subscription options.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.70)
                                  : const Color(0xFF61708A),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 210,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final business = businessTypes[index];
                        return _BusinessTypeCard(
                          business: business,
                          index: index,
                        )
                            .animate()
                            .fadeIn(
                              duration:
                                  Duration(milliseconds: 300 + (index * 50)),
                            )
                            .slideY(
                              begin: 0.12,
                              end: 0,
                              duration:
                                  Duration(milliseconds: 350 + (index * 40)),
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: businessTypes.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccentOrb({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class BusinessTypeOption {
  final String name;
  final String id;
  final IconData icon;
  final Color color;

  BusinessTypeOption({
    required this.name,
    this.id = '',
    required this.icon,
    required this.color,
  });

  String get tagline {
    switch (id) {
      case 'pharmacy':
        return 'Prescriptions, stock, and fast checkout.';
      case 'retail':
        return 'Inventory, POS, and customer flow.';
      case 'bakery':
        return 'Bread, pastries, POS, and daily stock.';
      case 'wholesale':
        return 'Bulk stock, pricing, and dispatch.';
      case 'agri':
        return 'Farm stock, supplies, and field sales.';
      case 'auto':
        return 'Repairs, bookings, and service tracking.';
      case 'salon':
      case 'barbershop':
        return 'Appointments, services, and staff activity.';
      case 'hotel':
      case 'apartment':
        return 'Bookings, rooms, guests, and billing.';
      case 'restaurant':
      case 'drink':
        return 'Tables, orders, kitchen, and bar sales.';
      case 'gas':
        return 'Pump sales, stock, and station records.';
      case 'petroleum':
        return 'Petrol, diesel, pump sales, and station stock.';
      case 'realestate':
        return 'Properties, clients, and payment records.';
      case 'gym':
        return 'Memberships, sessions, and attendance.';
      default:
        return 'Tools tailored to your business flow.';
    }
  }
}

class _BusinessTypeCard extends StatefulWidget {
  final BusinessTypeOption business;
  final int index;

  const _BusinessTypeCard({
    required this.business,
    required this.index,
  });

  @override
  State<_BusinessTypeCard> createState() => _BusinessTypeCardState();
}

class _BusinessTypeCardState extends State<_BusinessTypeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          Routes.businessDetails,
          arguments: {'businessType': widget.business.id},
        );
      },
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.95),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.business.color
                      .withOpacity(_isHovered ? 0.22 : 0.12),
                  blurRadius: _isHovered ? 24 : 16,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isHovered ? 74 : 66,
                    height: _isHovered ? 74 : 66,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.business.color.withOpacity(0.20),
                          widget.business.color.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      widget.business.icon,
                      color: widget.business.color,
                      size: _isHovered ? 36 : 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.business.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark ? Colors.white : const Color(0xFF10223F),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      widget.business.tagline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.white.withOpacity(0.68)
                            : const Color(0xFF61708A),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Set up business',
                        style: TextStyle(
                          color: widget.business.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.business.color.withOpacity(
                            _isHovered ? 0.18 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: widget.business.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

