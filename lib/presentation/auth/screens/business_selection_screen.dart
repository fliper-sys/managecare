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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Select Your Business',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.95,
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
                        duration: Duration(milliseconds: 300 + (index * 50)),
                      )
                      .slideX(
                        begin: -0.2,
                        end: 0,
                        duration: Duration(milliseconds: 400 + (index * 50)),
                        curve: Curves.easeOut,
                      );
                },
                childCount: businessTypes.length,
              ),
            ),
          ),
        ],
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
          child: Card(
            elevation: _isHovered ? 12 : 4,
            shadowColor: widget.business.color.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.business.color.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isHovered ? 72 : 64,
                    height: _isHovered ? 72 : 64,
                    decoration: BoxDecoration(
                      color: widget.business.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: widget.business.color
                                    .withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      widget.business.icon,
                      color: widget.business.color,
                      size: _isHovered ? 36 : 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.business.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isHovered)
                    Text(
                      'Tap to set up',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.business.color,
                        fontWeight: FontWeight.w500,
                      ),
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

