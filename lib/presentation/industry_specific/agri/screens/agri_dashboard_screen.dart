import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/whatsapp_utils.dart';

import '../../../../providers/agri_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/agri/livestock_group.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/notification_service.dart';
import 'farm_detail_screen.dart';
import 'farm_inventory_screen.dart';
import 'weather_screen.dart';
import 'farm_management_screen.dart';
import 'harvest_tracker_screen.dart';
import 'market_prices_screen.dart';
import 'suppliers_screen.dart';
import 'input_inventory_screen.dart';
import 'animal_group_detail_screen.dart';

class AgriDashboardScreen extends StatefulWidget {
  const AgriDashboardScreen({super.key});

  @override
  State<AgriDashboardScreen> createState() => _AgriDashboardScreenState();
}

class _AgriDashboardScreenState extends State<AgriDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isRefreshing = false;
  late TextEditingController _searchController;
  String _groupSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AnimalGroup> get _filteredGroups {
    final agri = context.read<AgriProvider>();
    return agri.searchGroups(_groupSearchQuery);
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    // regenerate hint
    try {
      await context.read<AgriProvider>().generateDailyHint(businessId: 'agri');
    } catch (_) {}
    setState(() => _isRefreshing = false);
  }

  void _showAddFarmDialog() {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Farm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final farm = {
                'id': id,
                'name': nameCtrl.text.trim(),
                'location': locationCtrl.text.trim()
              };
              context.read<AgriProvider>().addFarm(farm);
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _openScheduleScreen() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ScheduleSheet(),
    );
  }

  void _openReportsScreen() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const _ReportsScreen()));
  }

  void _openAddRecordModal() {
    showDialog(
      context: context,
      builder: (ctx) => _AddRecordDialog(onAddFarm: (farm) {
        context.read<AgriProvider>().addFarm(farm);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agri = context.watch<AgriProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _contentForIndex(agri)),

          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF66BB6A), Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi, Farmer',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400)),
              const SizedBox(height: 4),
              const Text('Farm Manager',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ]),
            Row(children: [
              _buildHeaderIcon(Icons.wb_sunny_outlined),
              const SizedBox(width: 12),
              _buildHeaderIcon(Icons.notifications_outlined),
            ])
          ]),
          const SizedBox(height: 24),
          _buildSearchBar(),
        ]),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 22));
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.search, color: Colors.white.withOpacity(0.9), size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
                decoration: const InputDecoration.collapsed(
                    hintText: 'Search farms, crops, tasks...')))
      ]),
    );
  }

  Widget _buildStatsRow(AgriProvider agri) {
    return Row(children: [
      _buildStatCard(
          icon: Icons.agriculture_outlined,
          label: 'Total\nFarms',
          value: '${agri.farms.length}',
          color: const Color(0xFF66BB6A)),
      const SizedBox(width: 12),
      _buildStatCard(
          icon: Icons.grass_outlined,
          label: 'Active\nCrops',
          value: '${agri.crops.length}',
          color: const Color(0xFF26A69A)),
      const SizedBox(width: 12),
      _buildStatCard(
          icon: Icons.pets_outlined,
          label: 'Livestock',
          value: '${agri.livestockGroups.length}',
          color: const Color(0xFF66BB6A)),
    ]);
  }

  Widget _buildStatCard(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748))),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3))
        ]),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    // Define actions in a list so we can render in a Grid
    final actions = [
      {'icon': Icons.add_circle_outline, 'label': 'Add Farm', 'color': const Color(0xFF66BB6A), 'onTap': _showAddFarmDialog},
      {'icon': Icons.calendar_today_outlined, 'label': 'Schedule', 'color': const Color(0xFF42A5F5), 'onTap': _openScheduleScreen},
      {'icon': Icons.analytics_outlined, 'label': 'Reports', 'color': const Color(0xFFFF7043), 'onTap': _openReportsScreen},
      {'icon': Icons.wb_sunny, 'label': 'Weather', 'color': const Color(0xFF42A5F5), 'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeatherScreen()))},
      {'icon': Icons.grass, 'label': 'Farms', 'color': const Color(0xFF84CC16), 'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FarmManagementScreen()))},
      {'icon': Icons.track_changes, 'label': 'Harvest', 'color': const Color(0xFF8B5CF6), 'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HarvestTrackerScreen()))},
      {'icon': Icons.price_change, 'label': 'Market', 'color': const Color(0xFFFFC107), 'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketPricesScreen()))},
      {'icon': Icons.storefront, 'label': 'Suppliers', 'color': const Color(0xFF00ACC1), 'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersScreen()))},
      {'icon': Icons.inventory, 'label': 'Inputs', 'color': const Color(0xFF26A69A), 'onTap': () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InputInventoryScreen()))},
      {'icon': Icons.print, 'label': 'Printer Settings', 'color': const Color(0xFF009688), 'onTap': () => Navigator.pushNamed(context, Routes.printerSettings)},
      {'icon': Icons.support_agent_rounded, 'label': 'Customer Care', 'color': Colors.green, 'onTap': () => WhatsAppUtils.openCustomerSupport(context)},
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final crossAxisCount = maxWidth > 900 ? 4 : (maxWidth > 600 ? 3 : 2);
      final rows = (actions.length / crossAxisCount).ceil();
      const itemHeight = 96.0;
      final gridHeight = rows * (itemHeight + 12) + 16; // padding

      return SizedBox(
        height: gridHeight,
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: (constraints.maxWidth / crossAxisCount) / itemHeight,
          children: actions.map((a) {
            return _buildQuickActionButton(
              icon: a['icon'] as IconData,
              label: a['label'] as String,
              color: a['color'] as Color,
              onTap: a['onTap'] as VoidCallback,
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildQuickActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    final agri = context.watch<AgriProvider>();
    final tasks = agri.tasks;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Today's Tasks",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748))),
        TextButton.icon(
          onPressed: _handleRefresh,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF66BB6A)),
        )
      ]),
      const SizedBox(height: 12),
      ...tasks.map((t) => _buildTaskCard(t))
    ]);
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final color = (task['color'] as Color?) ?? const Color(0xFF66BB6A);
    final icon = (task['icon'] as String?) ?? '🛠';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.8), color],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task['title'],
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(task['subtitle'],
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              const Text(' ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600))
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(
                              () => task['done'] = !(task['done'] as bool));
                        },
                        icon: Icon(
                            task['done']
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8))
                ]),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      const Text('Sunny',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white))
                    ]),
                    const SizedBox(height: 12),
                    Text('28°C • Humidity: 65%',
                        style: TextStyle(
                            fontSize: 14, color: Colors.white.withOpacity(0.9)))
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 24),
                    const SizedBox(height: 4),
                    const Text('Good for\nHarvesting',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.2))
                  ]))
            ])));
  }

  Widget _buildFloatingActionButton() {
    // Different actions per selected tab
    switch (_selectedIndex) {
      case 2:
        // Poultry: add livestock group
        return FloatingActionButton.extended(
            onPressed: _openAddLivestockDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Group'));
      default:
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
                onPressed: _openAddRecordModal,
                icon: const Icon(Icons.add, size: 24),
                label: const Text('Add Record',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66BB6A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    shadowColor: Colors.green.withOpacity(0.4))));
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ]),
        child: SafeArea(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.home_outlined, 'Home', 0),
                      _buildNavItem(Icons.lightbulb_outline, 'Hints', 1),
                      _buildNavItem(Icons.pets_outlined, 'Livestock', 2),
                      _buildNavItem(Icons.storefront, 'Inventory', 3),
                      _buildNavItem(Icons.settings, 'Settings', 4),
                    ]))));
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF66BB6A).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  color:
                      isSelected ? const Color(0xFF66BB6A) : Colors.grey[400],
                  size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF66BB6A)
                          : Colors.grey[400]))
            ])));
  }

  Widget _contentForIndex(AgriProvider agri) {
    switch (_selectedIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildStatsRow(agri),
                      const SizedBox(height: 24),
                      _buildQuickActionsGrid(),
                      const SizedBox(height: 24),
                      _buildTasksSection(),
                      const SizedBox(height: 24),
                      _buildWeatherCard(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case 1:
        return _buildSuggestionsTab(agri);

      case 2:
        return _buildAnimalGroupsTab(agri);

      case 3:
        return _buildInventoryTab();

      case 4:
        return _buildSettingsTab();

      default:
        return _buildSuggestionsTab(agri);
    }
  }

  Widget _buildSuggestionsTab(AgriProvider agri) {
    final businessId = Provider.of<BusinessProvider>(context, listen: false)
        .currentBusiness
        ?.id;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Hint',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF66BB6A).withOpacity(0.8), const Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text('Today\'s Tip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    agri.dailyHint ?? 'No hint available. Tap "Generate" to get a new tip!',
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildHintAction(
                        icon: Icons.refresh,
                        label: 'Generate',
                        onTap: () async {
                          await agri.generateDailyHint(businessId: businessId);
                        },
                      ),
                      _buildHintAction(
                        icon: Icons.notifications,
                        label: 'Notify Now',
                        onTap: () async {
                          final svc = NotificationService.instance;
                          final scheduled = DateTime.now().add(const Duration(seconds: 5));
                          await svc.scheduleNotificationAt(id: DateTime.now().millisecondsSinceEpoch ~/ 1000, title: 'Daily Agri Tip', body: agri.dailyHint ?? 'Tip', at: scheduled);
                        },
                      ),
                      _buildHintAction(
                        icon: Icons.access_time,
                        label: 'Schedule',
                        onTap: _openScheduleScreen,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recent Hints by Farm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
          const SizedBox(height: 12),
          if (agri.farms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(Icons.agriculture_outlined, size: 48, color: Colors.grey[300]),
                    SizedBox(height: 12),
                    Text('No farms added yet.', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            ...agri.farms.map((f) {
              final hints = agri.getHintsForFarm(f['id'] ?? '');
              return Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF66BB6A).withOpacity(0.1),
                    child: Icon(Icons.agriculture, color: const Color(0xFF388E3C)),
                  ),
                  title: Text(f['name'] ?? 'Farm', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${hints.length} hints available'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                  onTap: () async {
                    await agri.loadHintsForFarm(businessId ?? '', f['id'] ?? '');
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FarmDetailScreen(farm: f)));
                  },
                )
              );
            })
        ]),
      ),
    );
  }

  Widget _buildHintAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalGroupsTab(AgriProvider agri) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search and add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Animal Groups',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              FloatingActionButton.small(
                backgroundColor: AppColors.agri,
                onPressed: _openAddLivestockDialog,
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search groups...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _groupSearchQuery = v),
          ),
          const SizedBox(height: 16),

          // Groups list
          if (agri.livestockGroups.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No animal groups yet',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filteredGroups.length,
                itemBuilder: (ctx, i) {
                  final g = _filteredGroups[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnimalGroupDetailScreen(
                            group: g,
                            businessId: Provider.of<BusinessProvider>(
                              context,
                              listen: false,
                            ).currentBusiness?.id ?? '',
                          ),
                        ),
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.agri.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(g.emoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                      title: Text(g.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${g.type} • ${g.count} animals • Age: ${g.ageWeeks}w'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'feed') {
                            await _openRecordFeedDialog(g);
                          } else if (v == 'eggs' &&
                              g.type.toLowerCase().contains('poultry')) {
                            await _openRecordEggsDialog(g);
                          } else if (v == 'edit') {
                            _editGroupCount(g);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'feed', child: Text('Record Feed')),
                          if (g.type.toLowerCase().contains('poultry'))
                            const PopupMenuItem(
                                value: 'eggs', child: Text('Record Eggs')),
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit Count')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAddLivestockDialog() async {
    final nameCtrl = TextEditingController();
    final countCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'poultry');

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Animal Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Count'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: typeCtrl.text,
                decoration: const InputDecoration(labelText: 'Animal Type'),
                items: const [
                  DropdownMenuItem(value: 'poultry', child: Text('Poultry')),
                  DropdownMenuItem(value: 'cattle', child: Text('Cattle')),
                  DropdownMenuItem(value: 'sheep', child: Text('Sheep')),
                  DropdownMenuItem(value: 'goats', child: Text('Goats')),
                  DropdownMenuItem(value: 'pigs', child: Text('Pigs')),
                  DropdownMenuItem(value: 'rabbits', child: Text('Rabbits')),
                  DropdownMenuItem(value: 'fish', child: Text('Fish')),
                  DropdownMenuItem(value: 'bees', child: Text('Bees')),
                  DropdownMenuItem(value: 'horses', child: Text('Horses')),
                ],
                onChanged: (v) => typeCtrl.text = v ?? 'poultry',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (res == true) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final emoji = AnimalGroup.getEmojiForType(typeCtrl.text);
      final group = AnimalGroup(
        id: id,
        name: nameCtrl.text.trim(),
        count: int.tryParse(countCtrl.text) ?? 0,
        type: typeCtrl.text.trim(),
        emoji: emoji,
      );
      final businessId =
          Provider.of<BusinessProvider>(context, listen: false)
              .currentBusiness
              ?.id;
      await context.read<AgriProvider>().addLivestockGroup(
            group,
            businessId: businessId,
          );
    }
  }

  void _editGroupCount(AnimalGroup g) async {
    final ctrl = TextEditingController(text: g.count.toString());
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Count'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (res != null) {
      setState(() {
        g.count = res;
      });
      final businessId =
          Provider.of<BusinessProvider>(context, listen: false)
              .currentBusiness
              ?.id;
      if (businessId != null) {
        await context
            .read<AgriProvider>()
            .updateGroupInFirestore(businessId, g, source: 'edit_count');
      }
    }
  }

  Future<void> _openRecordEggsDialog(AnimalGroup g) async {
    final eggsCtrl = TextEditingController();
    bool toInventory = true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) => AlertDialog(
          title: Text('Record Eggs for ${g.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eggsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Egg Count'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: toInventory,
                onChanged: (v) => setState2(() => toInventory = v ?? true),
                title: const Text('Add to Inventory'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );

    if (res == true) {
      final eggs = int.tryParse(eggsCtrl.text) ?? 0;
      final businessId =
          Provider.of<BusinessProvider>(context, listen: false)
              .currentBusiness
              ?.id;
      if (toInventory) {
        await context.read<AgriProvider>().recordEggsAndAddToInventory(
              g.id,
              eggs,
              businessId: businessId,
            );
      } else {
        await context.read<AgriProvider>().recordEggs(
              g.id,
              eggs,
              businessId: businessId,
            );
      }
    }
  }

  Future<void> _openRecordFeedDialog(AnimalGroup g) async {
    final kgCtrl = TextEditingController();
    final feedTypeCtrl = TextEditingController(text: 'grower');
    final businessId =
        Provider.of<BusinessProvider>(context, listen: false)
            .currentBusiness
            ?.id;

    List<Map<String, dynamic>> products = [];
    if (businessId != null) {
      final snap = await FirebaseFirestore.instance
          .collection('businesses/$businessId/inventory')
          .where('category', isEqualTo: 'feed')
          .get();
      products = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    }

    String? selectedProductId;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) => AlertDialog(
          title: Text('Record Feed for ${g.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: kgCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Kg'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: feedTypeCtrl.text,
                  decoration: const InputDecoration(labelText: 'Feed Type'),
                  items: const [
                    DropdownMenuItem(value: 'starter', child: Text('Starter')),
                    DropdownMenuItem(value: 'grower', child: Text('Grower')),
                    DropdownMenuItem(value: 'layer', child: Text('Layer')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => feedTypeCtrl.text = v ?? 'grower',
                ),
                if (products.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    items: products
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as String?,
                              child: Text(p['name'] ?? 'Feed'),
                            ))
                        .toList(),
                    onChanged: (v) => setState2(() => selectedProductId = v),
                    decoration: const InputDecoration(labelText: 'Feed Product'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );

    if (res == true) {
      final kg = double.tryParse(kgCtrl.text) ?? 0.0;
      if (businessId != null) {
        await context.read<AgriProvider>().recordFeedUsage(
              g.id,
              kg: kg,
              productInventoryId: selectedProductId,
              businessId: businessId,
            );
      }
    }
  }

  Widget _buildInventoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        ElevatedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FarmInventoryScreen())), icon: const Icon(Icons.store), label: const Text('Open Farm Inventory')),
        const SizedBox(height: 12),
        const Text('Inventory is centralized under the business inventory collection and used for reports.'),
      ]),
    );
  }

  Widget _buildSettingsTab() {
    final themeProv = Provider.of<ThemeProvider>(context);
    final settingsProv = Provider.of<SettingsProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Dark Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Switch(value: themeProv.isDarkMode, onChanged: (v) => themeProv.setDarkMode(v))
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Switch(value: settingsProv.pushNotificationsEnabled, onChanged: (v) async {
            final businessId = Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id;
            await settingsProv.updateNotificationSettings(businessId ?? '', 'ME', pushEnabled: v);
          })
        ])
      ]),
    );
  }
}

// -------------------- Supporting Widgets --------------------

class _ScheduleSheet extends StatefulWidget {
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  TimeOfDay? _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<AgriProvider>().scheduledTime;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Schedule Daily Hint',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.access_time),
          title: Text(_selected?.format(context) ?? 'Not set'),
          trailing:
              TextButton(onPressed: _pickTime, child: const Text('Change')),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'))
        ])
      ]),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context,
        initialTime: _selected ?? const TimeOfDay(hour: 8, minute: 0));
    if (t != null) {
      setState(() => _selected = t);
      await context.read<AgriProvider>().setScheduledTime(t);
    }
  }
}

class _ReportsScreen extends StatelessWidget {
  const _ReportsScreen();

  @override
  Widget build(BuildContext context) {
    final agri = context.watch<AgriProvider>();
    return Scaffold(
      appBar:
          AppBar(title: const Text('Reports'), backgroundColor: AppColors.agri),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
              child: ListTile(
                  leading: const Icon(Icons.agriculture),
                  title: const Text('Total Farms'),
                  trailing: Text('${agri.farms.length}'))),
          const SizedBox(height: 8),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.grass),
                  title: const Text('Active Crops'),
                  trailing: Text('${agri.crops.length}'))),
          const SizedBox(height: 8),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.pets),
                  title: const Text('Livestock Groups'),
                  trailing: Text('${agri.livestockGroups.length}'))),
          const SizedBox(height: 16),
          const Text('Recent Hints',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: agri.farms.length,
              itemBuilder: (ctx, i) {
                final f = agri.farms[i];
                final hints = agri.getHintsForFarm(f['id'] ?? '');
                return ListTile(
                  title: Text(f['name'] ?? 'Farm'),
                  subtitle: Text('${hints.length} hints'),
                  leading: const Icon(Icons.agriculture),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FarmDetailScreen(farm: f))),
                );
              },
            ),
          )
        ]),
      ),
    );
  }
}

class _AddRecordDialog extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onAddFarm;
  const _AddRecordDialog({this.onAddFarm});

  @override
  State<_AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends State<_AddRecordDialog> {
  int _tab = 0;
  final _farmName = TextEditingController();
  final _farmLocation = TextEditingController();
  final _cropName = TextEditingController();
  String? _selectedFarmId;

  @override
  void dispose() {
    _farmName.dispose();
    _farmLocation.dispose();
    _cropName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Record'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ToggleButtons(
              isSelected: [_tab == 0, _tab == 1],
              onPressed: (i) => setState(() => _tab = i),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Farm')),
                Padding(padding: EdgeInsets.all(8), child: Text('Crop'))
              ]),
          const SizedBox(height: 12),
          if (_tab == 0) ...[
            TextField(
                controller: _farmName,
                decoration: const InputDecoration(labelText: 'Farm name')),
            TextField(
                controller: _farmLocation,
                decoration: const InputDecoration(labelText: 'Location')),
          ] else ...[
            TextField(
                controller: _cropName,
                decoration: const InputDecoration(labelText: 'Crop name')),
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final agri = ctx.watch<AgriProvider>();
              if (agri.farms.isEmpty) {
                return Text('No farms available. Add a farm first.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12));
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedFarmId,
                items: agri.farms
                    .map((f) => DropdownMenuItem(
                        value: f['id'] as String?,
                        child: Text(f['name'] ?? 'Farm')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedFarmId = v),
                decoration: const InputDecoration(labelText: 'Assign to farm'),
              );
            })
          ]
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_tab == 0) {
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final farm = {
                'id': id,
                'name': _farmName.text.trim(),
                'location': _farmLocation.text.trim()
              };
              if (widget.onAddFarm != null) {
                widget.onAddFarm!(farm);
              } else {
                context.read<AgriProvider>().addFarm(farm);
              }
              Navigator.of(context).pop();
              return;
            }
            // adding a crop
            final agri = context.read<AgriProvider>();
            if (agri.farms.isNotEmpty && _selectedFarmId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please select a farm for the crop.')));
              return;
            }
            final crop = {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'name': _cropName.text.trim(),
              'status': 'Active',
              'farmId': _selectedFarmId,
            };
            agri.addCrop(crop);
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        )
      ],
    );
  }
}