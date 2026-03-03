import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/loyalty_member_model.dart';
import '../data/models/loyalty_tier_model.dart';
import '../data/models/loyalty_transaction_model.dart';
import '../services/loyalty_service.dart';

class LoyaltyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final LoyaltyService _loyaltyService;

  String? _businessId;
  List<LoyaltyMember> _members = [];
  LoyaltyMember? _currentMember;
  List<LoyaltyTier> _tiers = [];
  List<LoyaltyTransaction> _transactions = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LoyaltyMember> get members => _members;
  LoyaltyMember? get currentMember => _currentMember;
  List<LoyaltyTier> get tiers => _tiers;
  List<LoyaltyTransaction> get transactions => _transactions;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get availablePoints => _currentMember?.availablePoints ?? 0;
  int get totalPoints => _currentMember?.totalPoints ?? 0;
  String get currentTier => _currentMember?.currentTier ?? 'bronze';

  LoyaltyProvider() {
    _loyaltyService = LoyaltyService(firestore: _firestore);
  }

  /// Initialize provider with business ID
  Future<void> initialize(String businessId) async {
    try {
      _businessId = businessId;
      print('[LoyaltyProvider] ▶ Initializing with business: $businessId');

      _isLoading = true;
      notifyListeners();

      // Load members from service
      _members = await _loyaltyService.fetchLoyaltyMembers(businessId);

      // Load tiers
      await _loadTiers();

      // Load statistics
      _stats = await _loyaltyService.getLoyaltyStats(businessId);

      _isLoading = false;
      _error = null;
      print('[LoyaltyProvider] ✓ Initialization complete');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      print('[LoyaltyProvider] ✗ Error: $_error');
      notifyListeners();
    }
  }

  /// Stream loyalty members real-time
  Stream<List<LoyaltyMember>> streamMembers() {
    if (_businessId == null) {
      print('[LoyaltyProvider] ✗ Business ID not set');
      return const Stream.empty();
    }

    return _loyaltyService.streamLoyaltyMembers(_businessId!).map((members) {
      _members = members;
      notifyListeners();
      return members;
    });
  }

  /// Load member by ID
  Future<void> loadMember(String memberId) async {
    if (_businessId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final member =
          await _loyaltyService.fetchMemberDetails(_businessId!, memberId);
      _currentMember = member;

      if (member != null) {
        _transactions = await _loyaltyService.fetchMemberTransactions(
            _businessId!, memberId);
      }

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load member: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register new customer
  Future<bool> registerCustomer({
    required String customerId,
    required String customerName,
    required String phoneNumber,
  }) async {
    if (_businessId == null) return false;

    try {
      print('[LoyaltyProvider] ▶ Registering customer: $customerId');

      final success = await _loyaltyService.registerCustomer(
        businessId: _businessId!,
        customerId: customerId,
        customerName: customerName,
        phoneNumber: phoneNumber,
      );

      if (success) {
        // Reload members
        _members = await _loyaltyService.fetchLoyaltyMembers(_businessId!);
        notifyListeners();
      }

      return success;
    } catch (e) {
      print('[LoyaltyProvider] ✗ Error registering customer: $e');
      return false;
    }
  }

  /// Add points to member
  Future<bool> addPoints({
    required String memberId,
    required int points,
    required String description,
    String? relatedSaleId,
  }) async {
    if (_businessId == null) return false;

    try {
      print('[LoyaltyProvider] ▶ Adding $points points to member: $memberId');

      final success = await _loyaltyService.updateMemberPoints(
        businessId: _businessId!,
        memberId: memberId,
        pointsToAdd: points,
        description: description,
        relatedSaleId: relatedSaleId,
      );

      if (success && _currentMember?.id == memberId) {
        // Reload current member
        await loadMember(memberId);
      }

      return success;
    } catch (e) {
      print('[LoyaltyProvider] ✗ Error adding points: $e');
      return false;
    }
  }

  /// Redeem rewards
  Future<bool> redeemRewards({
    required String memberId,
    required int points,
    required String description,
  }) async {
    if (_businessId == null) return false;

    try {
      print(
          '[LoyaltyProvider] ▶ Redeeming $points points from member: $memberId');

      final success = await _loyaltyService.redeemRewards(
        businessId: _businessId!,
        memberId: memberId,
        pointsToRedeem: points,
        rewardDescription: description,
      );

      if (success && _currentMember?.id == memberId) {
        await loadMember(memberId);
      }

      return success;
    } catch (e) {
      print('[LoyaltyProvider] ✗ Error redeeming rewards: $e');
      return false;
    }
  }

  /// Search members
  Future<void> searchMembers(String query) async {
    if (_businessId == null) return;

    try {
      print('[LoyaltyProvider] ▶ Searching members: $query');

      _isLoading = true;
      notifyListeners();

      _members = await _loyaltyService.searchMembers(_businessId!, query);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[LoyaltyProvider] ✗ Error searching: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload all members
  Future<void> reloadMembers() async {
    if (_businessId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      _members = await _loyaltyService.fetchLoyaltyMembers(_businessId!);
      _stats = await _loyaltyService.getLoyaltyStats(_businessId!);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[LoyaltyProvider] ✗ Error reloading: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set business id and initialize loyalty data for that business
  Future<void> setBusinessId(String businessId) async {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    await initialize(businessId);
    notifyListeners();
  }

  /// Load tiers from Firestore (or create defaults)
  Future<void> _loadTiers() async {
    try {
      print('[LoyaltyProvider] ▶ Loading loyalty tiers');

      _tiers = [
        LoyaltyTier(
          id: 'bronze',
          name: 'Bronze',
          pointsRequired: 0,
          discountPercentage: 0.0,
          benefits: ['Access to loyalty program', 'Birthday bonus'],
          color: '#CD7F32',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        LoyaltyTier(
          id: 'silver',
          name: 'Silver',
          pointsRequired: 2500,
          discountPercentage: 5.0,
          benefits: [
            '5% discount',
            '50 bonus points',
            'Free item after 10 purchases'
          ],
          color: '#C0C0C0',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        LoyaltyTier(
          id: 'gold',
          name: 'Gold',
          pointsRequired: 5000,
          discountPercentage: 10.0,
          benefits: [
            '10% discount',
            '100 bonus points',
            'Priority support',
            'Exclusive deals'
          ],
          color: '#FFD700',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      print('[LoyaltyProvider] ✓ Loaded ${_tiers.length} tiers');
    } catch (e) {
      print('[LoyaltyProvider] ✗ Error loading tiers: $e');
    }
  }

  /// Get tier by name
  LoyaltyTier? getTierByName(String tierName) {
    try {
      return _tiers.firstWhere(
          (tier) => tier.name.toLowerCase() == tierName.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Get member count by tier
  Map<String, int> getMembersByTier() {
    return {
      'bronze': _members.where((m) => m.currentTier == 'bronze').length,
      'silver': _members.where((m) => m.currentTier == 'silver').length,
      'gold': _members.where((m) => m.currentTier == 'gold').length,
    };
  }

  /// Get total loyalty members
  int getTotalMembers() => _members.length;

  /// Get total points issued
  int getTotalPointsIssued() {
    return _members.fold(0, (sum, member) => sum + member.totalPoints);
  }

  /// Clear current member
  void clearCurrentMember() {
    _currentMember = null;
    _transactions = [];
    notifyListeners();
  }

  /// Dispose
  @override
  void dispose() {
    _members.clear();
    _tiers.clear();
    _transactions.clear();
    super.dispose();
  }
}

