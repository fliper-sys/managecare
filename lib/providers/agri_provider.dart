import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repositories/industry_specific/agri_repository.dart';
import '../services/notification_interface.dart';
import '../models/agri/livestock_group.dart';
import '../models/agri/egg_record.dart';
import '../services/notification_service.dart';

class AgriProvider extends ChangeNotifier {
  AgriProvider({this.repository, this.notificationService, String? initialBusinessId}) {
    if (initialBusinessId != null && initialBusinessId.isNotEmpty) {
      _businessId = initialBusinessId;
    }
    _init();
  }

  final INotificationService? notificationService;
  final AgriRepository? repository;

  String? _businessId;
  final List<Map<String, dynamic>> _crops = [];
  String? _dailyHint;
  DateTime? _dailyHintDate;
  bool _disposed = false;
  final Map<String, List<Map<String, dynamic>>> _farmHints = {};
  // Simple domain lists
  final List<Map<String, dynamic>> _farms = [];

  final List<Map<String, dynamic>> _livestock = [];
  // New structured livestock groups
  final List<LivestockGroup> _livestockGroups = [];

  TimeOfDay _scheduledTime = const TimeOfDay(hour: 8, minute: 0);
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Map<String, dynamic>> get farms => List.unmodifiable(_farms);

  List<Map<String, dynamic>> get crops => List.unmodifiable(_crops);

  List<Map<String, dynamic>> get tasks => List.unmodifiable(_tasks);

  List<Map<String, dynamic>> get livestock => List.unmodifiable(_livestock);

  List<LivestockGroup> get livestockGroups =>
      List.unmodifiable(_livestockGroups);

  String? get dailyHint => _dailyHint;

  DateTime? get dailyHintDate => _dailyHintDate;

  TimeOfDay get scheduledTime => _scheduledTime;

  /// Reschedule all persisted hints using current thresholds.
  Future<void> rescheduleAllHints({required String businessId}) async {
    try {
      // fetch hints from repository (if implemented)
      if (repository == null) return;
      final hints = await repository!.fetchHints(businessId);
      final svc = notificationService ?? NotificationService.instance;
      final thresholds = await svc.getDaysBeforeThresholds();
      for (final h in hints) {
        final farmId = h['farmId'] as String? ?? 'daily_hint';
        final text = h['text'] as String? ?? 'Agri tip';
        final dateStr =
            h['date'] as String? ?? DateTime.now().toIso8601String();
        // Validate date format by parsing
        DateTime.tryParse(dateStr) ?? DateTime.now();
        final scheduled = _nextOccurrenceForTime(_scheduledTime);
        for (final days in thresholds) {
          try {
            await svc.scheduleExpiryAlert(
                businessId: businessId,
                memberId: farmId,
                memberName: text,
                expiry: scheduled,
                daysBefore: days);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Set business id and reload repository data for that business
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    await _loadFromRepo();
    _safeNotify();
  }

  /// Load hints for a particular farm (from repository if available)
  Future<void> loadHintsForFarm(String businessId, String farmId) async {
    try {
      if (repository == null) return;
      final hints = await repository!.fetchHints(businessId, farmId: farmId);
      _farmHints[farmId] =
          hints.map((h) => {'text': h['text'], 'date': h['date']}).toList();
      _safeNotify();
    } catch (_) {}
  }

  List<Map<String, dynamic>> getHintsForFarm(String farmId) {
    return List.unmodifiable(_farmHints[farmId] ?? []);
  }

  List<Map<String, dynamic>> getCropsForFarm(String farmId) {
    return _crops.where((c) => (c['farmId'] ?? '') == farmId).toList();
  }

  Future<void> addHintForFarm(
      String businessId, String farmId, String text) async {
    final now = DateTime.now();
    final entry = {'text': text, 'date': now.toIso8601String()};
    final list = _farmHints[farmId] ?? [];
    list.insert(0, entry);
    _farmHints[farmId] = list;
    try {
      if (repository != null) {
        await repository!.saveHint(
            businessId, farmId, {'text': text, 'date': now.toIso8601String()});
      }
    } catch (_) {}
    _safeNotify();
  }

  // Simple management methods for tasks and crops
  void addTask(Map<String, dynamic> task) {
    _tasks.insert(0, task);
    _saveTasksToPrefs();
    _safeNotify();
  }

  void toggleTaskDone(String id) {
    final i = _tasks.indexWhere((t) => t['id'] == id);
    if (i == -1) return;
    _tasks[i]['done'] = !(_tasks[i]['done'] as bool);
    _saveTasksToPrefs();
    _safeNotify();
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t['id'] == id);
    _saveTasksToPrefs();
    _safeNotify();
  }

  Future<void> generateDailyHint(
      {String? businessId, String? farmId, String? farmType}) async {
    // Create a simple rule-based hint; replace with smarter logic later
    final now = DateTime.now();
    // Select hint pool based on farm type if provided

    final defaultPool = [
      'Check irrigation: water crops in the morning to avoid evaporation.',
      'Rotate feed batches to avoid spoilage; check storage humidity.',
      'Apply organic pest control on vulnerable plots this week.',
      'Prune damaged branches on fruit trees to promote growth.',
      'Check soil moisture—consider light irrigation in the evening.',
      'Mulch around young plants to conserve moisture and suppress weeds.',
      'Test soil pH and adjust with lime or sulfur as needed.',
      'Use cover crops to improve soil structure and add organic matter.',
      'Scout fields weekly for early signs of pest outbreaks.',
      'Use drip irrigation to save water and reduce leaf wetness diseases.',
      'Stagger planting dates to spread harvest workload and risk.',
      'Keep records of inputs (fertilizer, pesticides) for future planning.',
      'Calibrate sprayers to ensure correct pesticide application rates.',
      'Rotate crops yearly to break pest and disease cycles.',
      'Test seed germination before planting large areas.',
      'Mark and protect beneficial insect habitats like hedgerows.',
      'Install simple bird deterrents near ripening fruit to reduce losses.',
      'Harvest in the cool of the morning to maintain produce quality.',
      'Store harvested produce in shaded, ventilated areas to avoid spoilage.',
      'Use compost tea sparingly to boost microbial activity in soil.',
      'Avoid working wet soils to prevent compaction.',
      'Use row covers to protect seedlings from early pests.',
      'Remove diseased plant material promptly to limit spread.',
      'Consider intercropping to maximize space and reduce pests.',
      'Train workers on safe handling of agrochemicals and PPE use.',
      'Plan irrigation around crop growth stages for efficient water use.',
      'Use high tunnels/greenhouses for high-value tender crops.',
      'Label seed lots and maintain storage records for traceability.',
      'Check irrigation emitters regularly for blockages.',
      'Use shaded nursery areas for young transplants to reduce stress.',
      'Install inexpensive soil moisture sensors for key plots.',
      'Select disease-resistant varieties when available.',
      'Encourage pollinators by planting flowering strips.',
      'Maintain a small first-aid kit and emergency plan on the farm.',
      'Use local extension services for pest/disease identification.',
      'Time fertilizer applications to crop uptake curves to avoid waste.',
      'Keep farm records to monitor yields and identify trends.',
      'Inspect irrigation lines and tanks for algae and clean regularly.',
      'Plan harvest logistics ahead to avoid post-harvest delays.',
      'Use soil organic amendments to improve long-term fertility.',
    ];

    final poultryPool = [
      'Inspect poultry for signs of respiratory illness and isolate sick birds.',
      'Collect eggs early in the morning to improve quality and reduce breakage.',
      'Ensure nesting boxes are clean and provide supplemental calcium.',
      'Provide fresh clean water at least twice daily and check troughs for algae.',
      'Maintain predator-proof housing to reduce losses from nocturnal attacks.',
      'Rotate pasture or movable housing to reduce parasite build-up.',
      'Vaccinate according to local veterinary advice and keep records.',
      'Provide a balanced layer feed to maintain egg quality.',
      'Use grit for improved digestion when birds are not free-ranging.',
      'Inspect feet for bumblefoot and provide dry bedding to prevent it.',
      'Offer ash or diatomaceous earth in dust-baths to help control external parasites.',
      'Cull clearly sick birds humanely to protect the flock.',
      'Introduce new birds slowly and quarantine before mixing flocks.',
      'Ensure ventilation in housing to reduce humidity and respiratory issues.',
      'Supply shade and cool water in hot weather to prevent heat stress.',
      'Collect and process eggs daily to avoid attractants for predators.',
      'Keep feed in sealed containers to deter rodents.',
      'Provide perches to improve bird welfare and reduce floor eggs.',
      'Monitor for mites and lice; treat housing between flocks.',
      'Rotate range areas to allow ground recovery and reduce pathogens.',
      'Provide extra protein during molting to support feather regrowth.',
      'Keep young chicks warm and draft-free during early development.',
      'Avoid overcrowding; maintain recommended space per bird.',
      'Label vaccines and treatments with dates and batch numbers.',
      'Use simple footbaths at entry points to limit disease spread.',
      'Record egg production daily to spot drops that indicate issues.',
      'Supplement with greens and kitchen scraps safely, avoiding salty foods.',
      'Provide calcium supplements for free-range layers (e.g., crushed shells).',
      'Check waterers for leaks and ensure consistent supply.',
      'Provide shade cloth or trees in free-range systems.',
      'Separate different age groups to reduce disease transmission.',
      'Use natural light where possible to stimulate laying cycles.',
      'Harvest forage carefully to avoid ingesting toxic plants.',
      'Inspect wiring and equipment to avoid hazards in housing.',
      'Keep a clean brooder and change bedding frequently for chicks.',
      'Use non-slip surfaces in pens to prevent injuries.',
      'Provide gentle handling training for staff to reduce bird stress.',
      'Monitor feed conversion ratios to detect health or quality problems.',
      'Engage a vet when unexplained mortality occurs for diagnosis.',
    ];

    final piggeryPool = [
      'Monitor piglets for scours; ensure clean water and vaccines are up to date.',
      'Check feed quality and adjust protein during growth phases.',
      'Ensure bedding is dry to reduce respiratory issues.',
      'Keep farrowing pens clean and disinfected between litters.',
      'Provide creep feeders so piglets can access solid feed early.',
      'Ensure sows have comfortable space and adequate nutrition pre-farrow.',
      'Monitor sow body condition and adjust ration accordingly.',
      'Keep drainage away from pens to prevent standing water and pathogens.',
      'Provide enrichment (toys, straw) to reduce tail-biting in pigs.',
      'Implement all-in/all-out flows where possible to reduce disease carryover.',
      'Record weights regularly to track growth performance.',
      'Check vaccinations and parasite control schedules with a vet.',
      'Ensure appropriate flooring to reduce hoof and leg problems.',
      'Use proper biosecurity to limit introduction of new diseases.',
      'Provide clean drinking nipples and check flow rates daily.',
      'Avoid sudden diet changes; transition feed gradually.',
      'Provide shade and cooling for pigs in hot weather.',
      'Keep boar and sow facilities separate unless breeding schedule requires it.',
      'Use simple disinfection stations for staff entering pig houses.',
      'Cull non-performing animals to improve herd productivity.',
      'Ensure good ventilation in barns to reduce ammonia buildup.',
      'Check for limping or lameness frequently and investigate causes.',
      'Practice careful weaning to reduce stress on piglets.',
      'Ensure feed storage is dry to prevent mold growth.',
      'Mark and treat umbilical infections in newborn piglets early.',
      'Maintain farrowing supervision during peak days after birth.',
      'Rotate pastures where pigs are kept to manage parasites.',
      'Use secure fencing to prevent pigs from escaping and damaging crops.',
      'Provide mineral supplements especially phosphorus and calcium.',
      'Test feed batches for aflatoxin if using stored grains.',
      'Keep records of treatments and medications for withdrawal periods.',
      'Check boar fertility periodically for breeding programs.',
      'Reduce stocking density to improve air quality and welfare.',
      'Train staff in humane handling and emergency procedures.',
      'Work with extension or vets to monitor herd health trends.',
      'Plan manure management to reduce odor and environmental impact.',
      'Use simple shade structures in outdoor systems for pig comfort.',
      'Separate sick animals promptly to reduce spread of disease.',
      'Ensure young stock receive colostrum promptly after birth.',
    ];

    final livestockPool = [
      'Rotate grazing areas to prevent overgrazing and parasites.',
      'Inspect hooves regularly and trim if necessary.',
      'Ensure mineral supplements are available during dry seasons.',
      'Check fences daily to prevent escapes and predator access.',
      'Provide shelter from wind and rain to reduce stress.',
      'Implement a parasite control schedule based on fecal tests.',
      'Provide clean, dry bedding to reduce mastitis in dairy animals.',
      'Castrate or separate males where appropriate to prevent injury.',
      'Keep a vaccination calendar and log for the herd.',
      'Monitor body condition scores to adjust feeding programs.',
      'Weigh sample animals regularly to track growth or loss.',
      'Use rotational grazing to improve pasture quality and rest fields.',
      'Provide shade and water points accessible to all animals.',
      'Consider forage testing to balance rations accurately.',
      'Fence off wet or boggy areas to prevent herd injuries.',
      'Practice good record keeping for births, deaths and treatments.',
      'Use footbaths where appropriate to limit hoof diseases.',
      'Plan breeding seasons to use feed resources effectively.',
      'Monitor milk yield and health for early mastitis detection.',
      'Provide creep feed for lambs/kids to aid early growth.',
      'Ensure good ventilation in barns to reduce respiratory issues.',
      'Check for external parasites and treat pasture where necessary.',
      'Use shade trees and shelterbelts to reduce heat stress in pastures.',
      'Implement biosecurity for visitors and new stock introductions.',
      'Use low-stress handling facilities for movement and treatment.',
      'Provide mineral lick blocks where soil is deficient.',
      'Separate age groups to manage nutrition and disease challenges.',
      'Monitor feed bunks to ensure all animals have access to feed.',
      'Trim hooves regularly on hard surfaces to prevent cracking.',
      'Vaccinate pregnant females to provide passive immunity to offspring.',
      'Test for common herd diseases and isolate positives quickly.',
      'Keep water troughs clean and free from algae.',
      'Consider shelter for newborns in colder climates to improve survival.',
      'Work with a nutritionist to formulate cost-effective rations.',
      'Use guardian animals or fencing to reduce predator losses for small stock.',
      'Track seasonal weight changes to adjust supplementary feeding.',
      'Store medicines properly and track expiry dates on treatments.',
      'Assess pasture species mix to improve palatability and nutrition.',
    ];

    // pick a hint from the appropriate pool based on farmType
    final ft = (farmType ?? '').toLowerCase();
    List<String> pool;
    if (ft.contains('poultry')) {
      pool = poultryPool;
    } else if (ft.contains('pig') || ft.contains('piggery')) {
      pool = piggeryPool;
    } else if (ft.contains('livestock') || ft.contains('herd')) {
      pool = livestockPool;
    } else {
      pool = defaultPool;
    }
    final choice = pool.isNotEmpty
        ? pool[Random().nextInt(pool.length)]
        : 'Check your farm today.';
    _dailyHint = choice;
    _dailyHintDate = now;
    // persist locally and optionally server-side per farm
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('agri_daily_hint', _dailyHint ?? '');
      await prefs.setString(
          'agri_daily_hint_date', _dailyHintDate!.toIso8601String());
      if (farmId != null && repository != null) {
        await repository!.saveHint(businessId ?? '', farmId, {
          'text': _dailyHint,
          'date': _dailyHintDate!.toIso8601String(),
        });
        // also update in-memory hints cache
        final list = _farmHints[farmId] ?? [];
        list.insert(
            0, {'text': _dailyHint, 'date': _dailyHintDate!.toIso8601String()});
        _farmHints[farmId] = list;
      }
    } catch (_) {}

    // schedule notification for today/tomorrow at configured time
    try {
      final svc = notificationService ?? NotificationService.instance;
      final scheduled = _nextOccurrenceForTime(_scheduledTime);
      // ID computation for future extensibility
      _computeDailyHintNotificationId(businessId ?? 'agri');
      // Use scheduleExpiryAlert as a lightweight scheduling hook; memberId encodes farm or 'daily_hint'
      final memberId = farmId ?? 'daily_hint';
      await svc.scheduleExpiryAlert(
          businessId: businessId ?? 'agri',
          memberId: memberId,
          memberName: 'Daily Agri Tip',
          expiry: scheduled,
          daysBefore: 0);
    } catch (_) {}

    _safeNotify();
  }

  Future<void> setScheduledTime(TimeOfDay t) async {
    _scheduledTime = t;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('agri_daily_hint_time', '${t.hour}:${t.minute}');
    } catch (_) {}
    // regenerate and reschedule
    await generateDailyHint(businessId: 'agri');
  }

  // Simple management methods
  void addFarm(Map<String, dynamic> farm) {
    _farms.add(farm);
    // persist locally
    _saveFarmsToPrefs();
    // persist to repository in background if available
    try {
      if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
        repository!.saveFarm(_businessId!, farm).catchError((_) {});
      }
    } catch (_) {}
    _safeNotify();
  }

  void removeFarmById(String id) {
    _farms.removeWhere((f) => f['id'] == id);
    // also remove crops associated with this farm
    _crops.removeWhere((c) => c['farmId'] == id);
    // persist changes
    _saveFarmsToPrefs();
    _saveCropsToPrefs();
    // try to delete from repository in background
    try {
      if (repository != null && _businessId != null && _businessId!.isNotEmpty) {
        repository!.deleteFarm(_businessId!, id).catchError((_) {});
      }
    } catch (_) {}
    notifyListeners();
  }

  // Crops
  // add a crop and persist
  void addCrop(Map<String, dynamic> crop) {
    // ensure crop has id
    crop['id'] ??= DateTime.now().millisecondsSinceEpoch.toString();
    _crops.add(crop);
    _saveCropsToPrefs();
    notifyListeners();
  }

  void removeCropById(String id) {
    _crops.removeWhere((c) => c['id'] == id);
    _saveCropsToPrefs();
    notifyListeners();
  }

  // Livestock management (grouped by type)
  Future<void> addLivestockGroup(LivestockGroup group,
      {String? businessId}) async {
    _livestockGroups.add(group);
    // Persist if repository is available
    try {
      if (repository != null && businessId != null && businessId.isNotEmpty) {
        await repository!.saveLivestockGroup(businessId, group.toMap());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeLivestockGroupById(String id, {String? businessId}) async {
    _livestockGroups.removeWhere((g) => g.id == id);
    try {
      if (repository != null && businessId != null && businessId.isNotEmpty) {
        await repository!.deleteLivestockGroup(businessId, id);
      }
    } catch (_) {}
    notifyListeners();
  }

  LivestockGroup? getGroupById(String id) {
    try {
      return _livestockGroups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateGroupCount(String id, int newCount) {
    final g = getGroupById(id);
    if (g == null) return;
    g.count = newCount;
    notifyListeners();
  }

  Future<void> recordEggs(String groupId, int count,
      {DateTime? date, String? note, String? businessId}) async {
    final g = getGroupById(groupId);
    if (g == null) return;
    final rec =
        EggRecord(date: date ?? DateTime.now(), count: count, note: note);
    g.eggRecords.insert(0, rec);
    // Persist updated group if repository available
    try {
      if (repository != null && businessId != null && businessId.isNotEmpty) {
        await repository!.saveLivestockGroup(businessId, g.toMap());
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Record feed usage for a livestock group and optionally deduct from inventory
  Future<void> recordFeedUsage(String groupId,
      {required double kg, String? productInventoryId, String? businessId}) async {
    final bid = businessId ?? _businessId;
    // create a feed usage record in Firestore for reporting
    try {
      if (bid != null && bid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('businesses/$bid/feed_usage')
            .add({
          'groupId': groupId,
          'kg': kg,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Try to deduct from inventory if product ID provided or a feed product exists
        if (productInventoryId != null && productInventoryId.isNotEmpty) {
          final ref = FirebaseFirestore.instance
              .collection('businesses/$bid/inventory')
              .doc(productInventoryId);
          await FirebaseFirestore.instance.runTransaction((tx) async {
            final snap = await tx.get(ref);
            if (snap.exists) {
              final data = snap.data() as Map<String, dynamic>;
              final q = (data['quantity'] as num?)?.toDouble() ?? 0;
              final newQ = q - kg;
              tx.update(ref, {'quantity': newQ, 'updatedAt': FieldValue.serverTimestamp()});
            }
          });
        } else {
          // Look for a feed product in inventory
          final qSnap = await FirebaseFirestore.instance
              .collection('businesses/$bid/inventory')
              .where('category', isEqualTo: 'feed')
              .limit(1)
              .get();
          if (qSnap.docs.isNotEmpty) {
            final ref = qSnap.docs.first.reference;
            await FirebaseFirestore.instance.runTransaction((tx) async {
              final s = await tx.get(ref);
              if (s.exists) {
                final data = s.data() as Map<String, dynamic>;
                final q = (data['quantity'] as num?)?.toDouble() ?? 0;
                final newQ = q - kg;
                tx.update(ref, {'quantity': newQ, 'updatedAt': FieldValue.serverTimestamp()});
              }
            });
          }
        }
      }
    } catch (e) {
      // ignore errors but log in future
    }
    notifyListeners();
  }

  /// Record eggs and optionally add crates to inventory
  Future<void> recordEggsAndAddToInventory(String groupId, int eggs,
      {int eggsPerCrate = 30, String? businessId}) async {
    final bid = businessId ?? _businessId;
    await recordEggs(groupId, eggs, businessId: bid);
    if (bid == null || bid.isEmpty) return;

    final crates = eggs ~/ eggsPerCrate;
    final remainder = eggs % eggsPerCrate;

    try {
      // Find an existing egg-related inventory item
      final snap = await FirebaseFirestore.instance
          .collection('businesses/$bid/inventory')
          .get();
      DocumentReference? eggRef;
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] as String?)?.toLowerCase() ?? '';
        final sku = (data['sku'] as String?)?.toLowerCase() ?? '';
        if (name.contains('egg') || sku == 'eggs') {
          eggRef = doc.reference;
          break;
        }
      }

      if (crates > 0) {
        if (eggRef != null) {
          await FirebaseFirestore.instance.runTransaction((tx) async {
            final s = await tx.get(eggRef!);
            final data = s.data() as Map<String, dynamic>?;
            final q = (data?['quantity'] as num?)?.toInt() ?? 0;
            tx.update(eggRef, {'quantity': q + crates, 'updatedAt': FieldValue.serverTimestamp()});
          });
        } else {
          await FirebaseFirestore.instance
              .collection('businesses/$bid/inventory')
              .add({
            'name': 'Egg Crates',
            'quantity': crates,
            'unit': 'crate',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Record an egg transaction for reporting
      await FirebaseFirestore.instance
          .collection('businesses/$bid/egg_records')
          .add({
        'groupId': groupId,
        'eggs': eggs,
        'crates': crates,
        'remainder': remainder,
        'date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore errors
    }

    notifyListeners();
  }

  double calculateDailyFeedKg(String groupId) {
    final g = getGroupById(groupId);
    if (g == null) return 0;
    return g.dailyFeedKg();
  }

  int weeksToMaturity(String groupId) {
    final g = getGroupById(groupId);
    if (g == null) return 0;
    return g.weeksToMaturity();
  }

  /// Update group in Firestore and local cache
  Future<void> updateGroupInFirestore(String businessId, AnimalGroup group,
      {String source = 'edit'}) async {
    try {
      await FirebaseFirestore.instance
          .collection('businesses/$businessId/animal_groups')
          .doc(group.id)
          .set(group.toMap(), SetOptions(merge: true));

      // Update local cache
      final idx = _livestockGroups.indexWhere((g) => g.id == group.id);
      if (idx >= 0) {
        _livestockGroups[idx] = group;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating group: $e');
    }
  }

  /// Search groups by name or type
  List<AnimalGroup> searchGroups(String query) {
    if (query.trim().isEmpty) return _livestockGroups;
    final lower = query.toLowerCase();
    return _livestockGroups
        .where((g) =>
            g.name.toLowerCase().contains(lower) ||
            g.type.toLowerCase().contains(lower))
        .toList();
  }

  /// Filter groups by type (e.g., 'poultry', 'cattle')
  List<AnimalGroup> filterGroupsByType(String type) {
    if (type.isEmpty) return _livestockGroups;
    return _livestockGroups
        .where((g) => g.type.toLowerCase() == type.toLowerCase())
        .toList();
  }

  /// Get all group types for current business
  List<String> getAvailableGroupTypes() {
    final types = _livestockGroups.map((g) => g.type).toSet().toList();
    return types;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _init() async {
    await _loadFromRepo();
    await _loadFarmsFromPrefs();
    await _loadCropsFromPrefs();
    await _loadTasksFromPrefs();
    await _loadHintFromPrefs();
  }

  Future<void> _loadFarmsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('agri_farms');
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s) as List<dynamic>;
        _farms.clear();
        _farms.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    _safeNotify();
  }

  Future<void> _loadFromRepo() async {
    if (repository == null) return;
    try {
      final fetched = await repository!.fetchFarms(_businessId ?? '');
      _farms.clear();
      _farms.addAll(fetched);

      // Load persisted livestock groups if available
      try {
        final groups = await repository!.fetchLivestockGroups(_businessId ?? '');
        _livestockGroups.clear();
        _livestockGroups.addAll(groups.map((m) => LivestockGroup.fromMap(m)));
      } catch (_) {}
    } catch (_) {}
    _safeNotify();
  }

  Future<void> _saveTasksToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('agri_tasks', jsonEncode(_tasks));
    } catch (_) {}
  }

  Future<void> _saveFarmsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('agri_farms', jsonEncode(_farms));
    } catch (_) {}
  }

  Future<void> _saveCropsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('agri_crops', jsonEncode(_crops));
    } catch (_) {}
  }

  Future<void> _loadHintFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyHint = prefs.getString('agri_daily_hint');
      final s = prefs.getString('agri_daily_hint_date');
      if (s != null) _dailyHintDate = DateTime.tryParse(s);
      final time = prefs.getString('agri_daily_hint_time');
      if (time != null) {
        final parts = time.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 8;
          final m = int.tryParse(parts[1]) ?? 0;
          _scheduledTime = TimeOfDay(hour: h, minute: m);
        }
      }
    } catch (_) {}
    _safeNotify();
  }

  Future<void> _loadCropsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('agri_crops');
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s) as List<dynamic>;
        _crops.clear();
        _crops.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    _safeNotify();
  }

  Future<void> _loadTasksFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('agri_tasks');
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    _safeNotify();
  }

  DateTime _nextOccurrenceForTime(TimeOfDay t) {
    final now = DateTime.now();
    final candidate = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (candidate.isAfter(now)) return candidate;
    return candidate.add(const Duration(days: 1));
  }

  int _computeDailyHintNotificationId(String businessId) =>
      businessId.hashCode ^ 'daily_hint'.hashCode;
}


