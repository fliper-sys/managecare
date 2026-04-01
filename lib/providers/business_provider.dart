import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/business_model.dart';
import '../data/models/apartment_model.dart';
import '../data/models/unit_model.dart';
import '../data/repositories/business_repository_impl.dart';
import '../data/repositories/apartment_repository_impl.dart';
import '../data/repositories/worker_repository_impl.dart';
import '../services/local_business_storage.dart';
import '../services/local_user_storage.dart';
import '../services/subscription_service.dart';

class BusinessProvider with ChangeNotifier {
  final BusinessRepository _repository;
  LocalBusinessStorage? _localStorage;
  LocalUserStorage? _localUserStorage;

  BusinessModel? _currentBusiness;
  List<BusinessModel> _userBusinesses = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUsingCachedData = false;
  bool _verboseLogging = false;

  // Throttling: Prevent redundant Firebase calls
  DateTime? _lastLoadTime;
  static const Duration _minRefreshInterval = Duration(minutes: 5);
  bool _isLoadingInProgress = false;

  BusinessModel? get currentBusiness => _currentBusiness;
  List<BusinessModel> get userBusinesses => _userBusinesses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUsingCachedData => _isUsingCachedData;
  bool get verboseLogging => _verboseLogging;

  BusinessProvider({BusinessRepository? repository}) : _repository = repository ?? BusinessRepository() {
    _initializeLocalStorage();
  }

  /// Initialize local storage
  Future<void> _initializeLocalStorage() async {
    try {
      _localStorage = await LocalBusinessStorage.create();
      print('[BusinessProvider] Local storage initialized');
      try {
        _localUserStorage = await LocalUserStorage.create();
        print('[BusinessProvider] Local user storage initialized');
      } catch (e) {
        print('[BusinessProvider] Error initializing local user storage: $e');
      }
    } catch (e) {
      print('[BusinessProvider] Error initializing local storage: $e');
    }
  }

  String? _loadedForUserId;

  /// Check if we should refresh data (throttled)
  bool _shouldRefreshData() {
    if (_lastLoadTime == null) return true;
    final elapsed = DateTime.now().difference(_lastLoadTime!);
    return elapsed >= _minRefreshInterval;
  }

  Future<void> loadUserBusinesses(String userId,
      {String? preferredBusinessId, List<String>? userBusinessIds}) async {
    // Prevent duplicate simultaneous requests
    if (_isLoadingInProgress) {
      print('[BusinessProvider] ⏭️ Load already in progress, skipping duplicate request');
      return;
    }

    // Throttle: Don't reload if we loaded recently
    if (_loadedForUserId == userId && !_shouldRefreshData()) {
      print('[BusinessProvider] ⏭️ Skipping reload - data refreshed ${DateTime.now().difference(_lastLoadTime!).inSeconds}s ago');
      // Still restore current business from cache if needed
      if (_currentBusiness == null && _localStorage != null) {
        final cachedId = _localStorage!.getCurrentBusinessId();
        if (cachedId != null) {
          _currentBusiness = _userBusinesses.firstWhere((b) => b.id == cachedId, orElse: () => _userBusinesses.first);
          notifyListeners();
        }
      }
      return;
    }

    try {
      _isLoadingInProgress = true;
      _errorMessage = null;
      _isUsingCachedData = false;
      // DON'T notify yet - wait until data is loaded

      print('[BusinessProvider] 🔄 Loading businesses for user: $userId');
      print('[BusinessProvider] Preferred business ID: $preferredBusinessId');

      // Check if user has enabled per-user edge logging for diagnostics
      try {
        if (_localUserStorage != null) {
          final flag = _localUserStorage!.getEdgeLoggingForUser(userId);
          _verboseLogging = flag;
          if (_verboseLogging) print('[BusinessProvider] Edge logging ENABLED for user: $userId');
        }
      } catch (e) {
        // ignore local storage issues for diagnostic flags
        print('[BusinessProvider] Error reading edge logging flag: $e');
      }

      // Try to load from Firebase first
      try {
        _userBusinesses = await _repository.getUserBusinesses(userId);
        _lastLoadTime = DateTime.now();
        print(
            '[BusinessProvider] ✅ Loaded ${_userBusinesses.length} businesses from Firebase');
        if (_verboseLogging) {
          print('[BusinessProvider] Verbose: loaded business ids: ${_userBusinesses.map((b) => b.id).join(', ')}');
        }

        // Save to local storage for offline use
        if (_localStorage != null && _userBusinesses.isNotEmpty) {
          await _localStorage!.saveBusinessList(_userBusinesses);
          print('[BusinessProvider] 💾 Cached businesses to local storage');
        }
      } catch (e) {
        print('[BusinessProvider] ❌ Error loading from Firebase: $e');

        // Fallback to cached data if Firebase fails
        if (_localStorage != null) {
          print(
              '[BusinessProvider] Attempting to load cached businesses (offline mode)');
          _userBusinesses = _localStorage!.getCachedBusinesses();
          _isUsingCachedData = true;

          if (_userBusinesses.isNotEmpty) {
            print(
                '[BusinessProvider] Successfully loaded ${_userBusinesses.length} cached businesses');
          } else {
            print('[BusinessProvider] No cached businesses available');
            _errorMessage =
                'Unable to load businesses. Please check your connection.';
          }
        } else {
          _errorMessage = 'Error loading businesses: ${e.toString()}';
          rethrow;
        }
      }

      if (_userBusinesses.isEmpty) {
        print(
            '[BusinessProvider] WARNING: No businesses found for user $userId');
        print(
            '[BusinessProvider] User should create their first business or have been invited to one');
      }

      // If the user document explicitly lists business IDs, ensure we load those
      if (userBusinessIds != null && userBusinessIds.isNotEmpty) {
        print('[BusinessProvider] Ensuring businesses listed on user doc are loaded: ${userBusinessIds.join(', ')}');
        for (final bid in userBusinessIds) {
          try {
            if (!_userBusinesses.any((b) => b.id == bid)) {
              final b = await _repository.getBusinessById(bid);
              if (b != null) {
                _userBusinesses.add(b);
                // Save to local cache
                if (_localStorage != null) {
                  await _localStorage!.saveBusiness(b);
                }
                print('[BusinessProvider] Loaded business by id: ${b.id}');
              } else {
                // If the business doc can't be fetched (permissions, eventual consistency or deletion),
                // still include a placeholder so the user can see all businessIds from their user doc
                print('[BusinessProvider] Business id listed on user doc not found: $bid - adding placeholder');
                try {
                  final placeholder = BusinessModel(
                    id: bid,
                    name: 'Unknown Business ($bid)',
                    businessType: '',
                    ownerId: '',
                    createdAt: DateTime.now(),
                  );
                  _userBusinesses.add(placeholder);
                } catch (e) {
                  print('[BusinessProvider] Failed to create placeholder for business id $bid: $e');
                }
              }
            }
          } catch (e) {
            print('[BusinessProvider] Error loading business by id ($bid): $e');
          }
        }
      }

      // Deduplicate and normalize businesses list to avoid duplicate UI entries
      final beforeDedupe = _userBusinesses.length;
      _dedupeUserBusinesses();
      if (_verboseLogging) {
        print('[BusinessProvider] Verbose: dedupe reduced $beforeDedupe -> ${_userBusinesses.length}');
      }

      for (final b in _userBusinesses) {
        print('[BusinessProvider]   - ${b.id} (${b.businessType}) - ${b.name}');
      }

      // Set the first business as current if available
      // Normalize loaded businesses: do not allow 'free' tier. Convert to 'basic'
      // and mark inactive so users are prompted to pay.
      for (var i = 0; i < _userBusinesses.length; i++) {
        final b = _userBusinesses[i];
        if (b.subscriptionTier.toLowerCase() == 'free') {
          final updated = b.copyWith(
              subscriptionTier: 'basic', isSubscriptionActive: false);
          _userBusinesses[i] = updated;
          // Persist change so backend reflects new requirement. Best-effort.
          try {
            await _repository.updateBusiness(updated);
          } catch (_) {
            // ignore persistence errors here; UI will still prompt
          }
        }
      }

      // If a preferred business id was provided (from the user document),
      // try to select that business as the current one. Otherwise fall back
      // to the first business if none is currently selected.
      if (preferredBusinessId != null && preferredBusinessId.isNotEmpty) {
        print(
            '[BusinessProvider] Looking for preferred business: $preferredBusinessId');
        final idx =
            _userBusinesses.indexWhere((b) => b.id == preferredBusinessId);
        if (idx != -1) {
          // Respect an explicit, already-selected current business; only
          // force the preferred business when no current selection exists
          // or when the IDs differ.
          if (_currentBusiness == null || _currentBusiness!.id != preferredBusinessId) {
            // If we've previously set an explicit selection for this user (e.g. via switch)
            // avoid overwriting it during background loads
            if (_loadedForUserId == userId && _currentBusiness != null) {
              print('[BusinessProvider] Preserving explicit current business (${_currentBusiness!.id}) for user $userId');
            } else {
              _currentBusiness = _userBusinesses[idx];
              print(
                  '[BusinessProvider] Set current business to preferred: ${_currentBusiness?.id}');

              // Cache current business selection
              if (_localStorage != null) {
                await _localStorage!.setCurrentBusiness(_currentBusiness!.id);
              }
            }
          } else {
            // Already set to preferred; ensure cache matches
            if (_localStorage != null && _localStorage!.getCurrentBusinessId() != _currentBusiness!.id) {
              await _localStorage!.setCurrentBusiness(_currentBusiness!.id);
            }
          }
        } else if (_userBusinesses.isNotEmpty && _currentBusiness == null) {
          _currentBusiness = _userBusinesses.first;
          print(
              '[BusinessProvider] Preferred not found, using first: ${_currentBusiness?.id}');

          if (_localStorage != null) {
            await _localStorage!.setCurrentBusiness(_currentBusiness!.id);
          }
        } else if (_userBusinesses.isEmpty) {
          // Preferred business not in results but was specified - might be a worker
          // Try to load it directly by ID
          print(
              '[BusinessProvider] No businesses found, attempting to load preferred ID: $preferredBusinessId');
          await loadBusinessById(preferredBusinessId);
          return;
        }
      } else if (_userBusinesses.isNotEmpty && _currentBusiness == null) {
        // Try to restore previously selected business from cache
        if (_localStorage != null) {
          final cachedBusinessId = _localStorage!.getCurrentBusinessId();
          if (cachedBusinessId != null) {
            final idx =
                _userBusinesses.indexWhere((b) => b.id == cachedBusinessId);
            if (idx != -1) {
              _currentBusiness = _userBusinesses[idx];
              print(
                  '[BusinessProvider] Restored previously selected business: ${_currentBusiness?.id}');
            } else {
              _currentBusiness = _userBusinesses.first;
              await _localStorage!.setCurrentBusiness(_currentBusiness!.id);
            }
          } else {
            _currentBusiness = _userBusinesses.first;
            await _localStorage!.setCurrentBusiness(_currentBusiness!.id);
          }
        } else {
          _currentBusiness = _userBusinesses.first;
        }
        print(
            '[BusinessProvider] No preference, using first: ${_currentBusiness?.id}');
      }

      // Record that these businesses were loaded for this user so we don't
      // mistakenly reuse them after logout/login
      _loadedForUserId = userId;

      print(
          '[BusinessProvider] ✅ Final current business: ${_currentBusiness?.id}');
      _isLoading = false;
      _isLoadingInProgress = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isLoadingInProgress = false;
      _errorMessage = 'Failed to load businesses: ${e.toString()}';
      print('[BusinessProvider] ❌ ERROR: $_errorMessage');
      notifyListeners();
    }
  }

  Future<bool> createBusiness(BusinessModel business) async {
    const timeoutDuration = Duration(seconds: 15);
    try {
      _errorMessage = null;
      // DON'T notify yet - wait until business is created

      // Create business document (with a timeout so UI doesn't hang indefinitely)
      try {
        await _repository.createBusiness(business).timeout(timeoutDuration);
      } catch (e) {
        _isLoading = false;
        _errorMessage = 'Failed to create business (network timeout or error): $e';
        print('[BusinessProvider] ERROR: $_errorMessage');
        notifyListeners();
        return false;
      }

      _userBusinesses.add(business);
      _currentBusiness = business;

      // Persist the new business selection locally so the UI reflects it immediately
      if (_localStorage != null) {
        try {
          await _localStorage!.setCurrentBusiness(business.id);
          await _localStorage!.saveBusiness(business);
          print('[BusinessProvider] Persisted newly created business to local storage: ${business.id}');
        } catch (e) {
          print('[BusinessProvider] Warning: failed to persist new business to local storage: $e');
        }
      }

      // If this is a Gas business and default fuel products aren't configured yet,
      // create common fuel SKUs (Petrol, Diesel, Kerosene) and mark the business as configured.
      if (business.businessType.toLowerCase() == 'gas') {
        final configured = (business.industrySpecificSettings ?? {})['defaultFuelProductsConfigured'] ?? false;
        if (configured != true) {
          try {
            final fuelUnit = (business.industrySpecificSettings ?? {})['fuelUnit'] ?? 'L';
            print('[BusinessProvider] Detected Gas business - creating default fuel products (unit: $fuelUnit)');
            // Guard default product creation with a timeout as well
            try {
              await _repository.createDefaultFuelProducts(business.id, fuelUnit: fuelUnit).timeout(timeoutDuration);
            } catch (e) {
              print('[BusinessProvider] Warning: default fuel products creation timed out or failed: $e');
            }

            // Update the business doc to mark default products configured
            final updatedSettings = Map<String, dynamic>.from(business.industrySpecificSettings ?? {});
            updatedSettings['defaultFuelProductsConfigured'] = true;
            final updated = business.copyWith(industrySpecificSettings: updatedSettings);

            try {
              await _repository.updateBusiness(updated).timeout(timeoutDuration);
            } catch (e) {
              print('[BusinessProvider] Warning: update business to mark default products configured timed out or failed: $e');
            }

            // Update local caches
            final idx = _userBusinesses.indexWhere((b) => b.id == updated.id);
            if (idx != -1) _userBusinesses[idx] = updated;
            if (_currentBusiness?.id == updated.id) _currentBusiness = updated;

            if (_localStorage != null) {
              try {
                await _localStorage!.saveBusiness(updated);
                print('[BusinessProvider] Updated local cache to mark default fuel products configured for ${updated.id}');
              } catch (e) {
                print('[BusinessProvider] Warning: failed to update local business cache: $e');
              }
            }
          } catch (e) {
            print('[BusinessProvider] Warning: failed to create default fuel products: $e');
            // Do not fail business creation if the onboarding step fails
          }
        }
      }

      // If this is an Apartment business, create a default apartment so the
      // user immediately sees an apartment listed after registration.
      if (business.businessType.toLowerCase() == 'apartment') {
        try {
          print('[BusinessProvider] Detected Apartment business - creating default apartment');
          final aptRepo = ApartmentRepositoryImpl();
          final apt = Apartment(
            id: '',
            title: '${business.name} Apartments',
            description: 'Main apartment for ${business.name}',
            ownerId: business.ownerId,
            address: business.address ?? '',
            createdAt: Timestamp.now(),
          );
          final aptId = await aptRepo.createApartment(businessId: business.id, apartment: apt);
          print('[BusinessProvider] Default apartment created: $aptId');

          // Optionally create a default unit for the newly created apartment
          try {
            final settings = business.industrySpecificSettings ?? {};
            final nightly = (settings['defaultNightlyRate'] is num) ? (settings['defaultNightlyRate'] as num).toDouble() : 0.0;
            final unit = Unit(id: '', name: 'Unit 1', capacity: 1, pricePerNight: nightly);
            final unitId = await aptRepo.createUnit(businessId: business.id, apartmentId: aptId, unit: unit);
            print('[BusinessProvider] Default unit created: $unitId');
          } catch (e) {
            print('[BusinessProvider] Warning: failed to create default unit: $e');
          }
        } catch (e) {
          print('[BusinessProvider] Warning: failed to create default apartment: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to create business: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBusiness(BusinessModel business) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Prevent updating a business to the 'free' tier. Default to 'basic' and
      // mark subscription inactive so the user is prompted to complete payment.
      var toSave = business;
      if (toSave.subscriptionTier.toLowerCase() == 'free') {
        toSave = toSave.copyWith(
          subscriptionTier: 'basic',
          isSubscriptionActive: false,
        );
      }

      await _repository.updateBusiness(toSave);

      // Update the business in the list
      final index = _userBusinesses.indexWhere((b) => b.id == toSave.id);
      if (index != -1) {
        _userBusinesses[index] = toSave;
      }

      // Update current if it's the same business
      if (_currentBusiness?.id == toSave.id) {
        _currentBusiness = toSave;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update business: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Mark a business as deleted (soft-delete by setting isActive=false)
  Future<bool> deleteBusiness(String businessId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.deleteBusiness(businessId);

      // Remove from cached list
      _userBusinesses.removeWhere((b) => b.id == businessId);

      // If it was the current business, select another
      if (_currentBusiness?.id == businessId) {
        _currentBusiness =
            _userBusinesses.isNotEmpty ? _userBusinesses.first : null;
        if (_currentBusiness != null && _localStorage != null) {
          await _localStorage!.setCurrentBusiness(_currentBusiness!.id);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete business: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> setCurrentBusiness(BusinessModel business) async {
    _currentBusiness = business;
    print('[BusinessProvider] Set current business: ${business.id}');

    // Save to local storage and cache the business for faster startup
    if (_localStorage != null) {
      try {
        await _localStorage!.setCurrentBusiness(business.id);
        await _localStorage!.saveBusiness(business);
        print('[BusinessProvider] Persisted current business to local storage');
      } catch (e) {
        print('[BusinessProvider] Warning: failed to persist current business locally: $e');
      }
    }

    notifyListeners();

    // Refresh aggregated business stats (products, workers, customers)
    _refreshBusinessStats(business.id);
  }

  /// Mark that an explicit user selection was made so background loads
  /// do not overwrite the explicit current business. Call this immediately
  /// after a user-initiated switch.
  void markUserSelection(String userId) {
    try {
      _loadedForUserId = userId;
      print('[BusinessProvider] markUserSelection: $userId (protecting explicit selection)');
    } catch (e) {
      print('[BusinessProvider] markUserSelection error: $e');
    }
  }

  /// Set current business and save preference to Firebase and local storage
  Future<void> setCurrentBusinessAndSave(
      String userId, BusinessModel business) async {
    try {
      _currentBusiness = business;
      print(
          '[BusinessProvider] Setting current business and saving: ${business.id}');

      // Save to local storage immediately
      if (_localStorage != null) {
        await _localStorage!.setCurrentBusiness(business.id);
        await _localStorage!.saveBusiness(business);
        print('[BusinessProvider] Saved business to local storage');
      }

      // Save preferred business ID, ensure currentBusinessId and businessIds are persisted to user document
      final firestore = FirebaseFirestore.instance;
      try {
        try {
          await firestore.collection('users').doc(userId).update({
            'preferredBusinessId': business.id,
            'currentBusinessId': business.id,
            // Ensure businessIds contains this business id
            'businessIds': FieldValue.arrayUnion([business.id]),
          }).timeout(const Duration(seconds: 10));
        } catch (e) {
          // If the update times out or fails, record and continue. This should not block UI indefinitely.
          print('[BusinessProvider] Error saving user preference to Firestore (timeout or error): $e');
          _errorMessage = 'Failed to save business preference: $e';
          notifyListeners();
        }

        // Also update local cached user if available
        try {
          final localUserStorage = await LocalUserStorage.create();
          await localUserStorage.updateCachedUser(
            businessId: business.id,
            businessIds: [business.id],
            currentBusinessId: business.id,
          );
        } catch (e) {
          print('[BusinessProvider] Warning: failed to update local cached user: $e');
        }

        // Mark that businesses were explicitly set for this user so subsequent
        // background loads do not unintentionally override this choice
        _loadedForUserId = userId;

        print('[BusinessProvider] Saved business preference to Firebase and local cache');
        notifyListeners();

        // Refresh aggregated stats for the business in background
        _refreshBusinessStats(business.id);
      } catch (e) {
        _errorMessage = 'Failed to save business preference: $e';
        print('[BusinessProvider] Error saving business preference: $e');
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Unexpected error setting current business: $e';
      print('[BusinessProvider] Unexpected error setting current business: $e');
      notifyListeners();
    }
  }

  Future<void> loadBusinessById(String businessId) async {
    try {
      print(
          '[BusinessProvider.loadBusinessById] Starting load for ID: $businessId');
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final b = await _repository.getBusinessById(businessId);
      print(
          '[BusinessProvider.loadBusinessById] Retrieved business: ${b?.name ?? 'NULL'}');

      if (b != null) {
        _currentBusiness = b;
        print(
            '[BusinessProvider.loadBusinessById] Set currentBusiness to: ${b.name} (${b.businessType})');
        if (_verboseLogging) {
          print('[BusinessProvider.loadBusinessById] Verbose: business details: id=${b.id}, name=${b.name}, owner=${b.ownerId}, tier=${b.subscriptionTier}');
        }

        // If a placeholder for this business exists in the list, replace it so UI reflects real data.
        final existingIdx = _userBusinesses.indexWhere((x) => x.id == b.id);
        if (existingIdx != -1) {
          _userBusinesses[existingIdx] = b;
          print('[BusinessProvider.loadBusinessById] Replaced placeholder/entry for business id: ${b.id}');
        } else {
          _userBusinesses.insert(0, b);
        }

        // Deduplicate to avoid duplicates caused by concurrent loads
        _dedupeUserBusinesses();

        // Cache current business selection
        if (_localStorage != null) {
          await _localStorage!.setCurrentBusiness(b.id);
          await _localStorage!.saveBusiness(b);
        }

        // Refresh stats for this business asynchronously
        _refreshBusinessStats(b.id);
      } else {
        _errorMessage = 'Business not found';
        print(
            '[BusinessProvider.loadBusinessById] ERROR: Business returned NULL from repository');
      }

      _isLoading = false;
      print(
          '[BusinessProvider.loadBusinessById] Final currentBusiness: ${_currentBusiness?.name ?? 'NULL'}');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load business: ${e.toString()}';
      print('[BusinessProvider.loadBusinessById] EXCEPTION: $e');
      notifyListeners();
    }
  }

  /// Attempt to locate and load the business associated with a worker.
  ///
  /// This will try multiple strategies in order:
  ///   1. Inspect an existing user->businessId mapping (AuthProvider should have set it)
  ///   2. Query the `workers` collection by document id
  ///   3. Query the `workers` collection by email (if provided)
  /// If a business is found it will be loaded and cached. This method never throws.
  Future<bool> ensureBusinessForWorker(String workerId,
      {String? workerEmail}) async {
    if (_currentBusiness != null) return true;

    try {


      // First, try to find a worker doc by id via repository
      final workerRepo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
      dynamic workerDoc;
      try {
        workerDoc = await workerRepo.getWorkerById(workerId);
        if (workerDoc != null) print('[BusinessProvider] WorkerRepo returned: $workerDoc');
      } catch (e) {
        print('[BusinessProvider] Worker repo lookup by id failed: $e');
      }

      // If still not found, try querying the workers collection for multiple possible fields
      if (workerDoc == null) {
        try {
          // Try userId/uid/workerId fields
          final byIdQuery = await FirebaseFirestore.instance
              .collection('workers')
              .where('userId', isEqualTo: workerId)
              .limit(1)
              .get();
          if (byIdQuery.docs.isNotEmpty) {
            workerDoc = {'id': byIdQuery.docs.first.id, ...byIdQuery.docs.first.data()};
            print('[BusinessProvider] Found worker by userId: ${byIdQuery.docs.first.id}');
          }
        } catch (e) {
          print('[BusinessProvider] Worker lookup by userId failed: $e');
        }
      }

      if (workerDoc == null) {
        try {
          final byUidQuery = await FirebaseFirestore.instance
              .collection('workers')
              .where('uid', isEqualTo: workerId)
              .limit(1)
              .get();
          if (byUidQuery.docs.isNotEmpty) {
            workerDoc = {'id': byUidQuery.docs.first.id, ...byUidQuery.docs.first.data()};
            print('[BusinessProvider] Found worker by uid: ${byUidQuery.docs.first.id}');
          }
        } catch (e) {
          print('[BusinessProvider] Worker lookup by uid failed: $e');
        }
      }

      if (workerDoc == null && workerEmail != null && workerEmail.contains('@')) {
        try {
          // Try email and emailAddress fields
          final byEmailQuery = await FirebaseFirestore.instance
              .collection('workers')
              .where('email', isEqualTo: workerEmail)
              .limit(1)
              .get();
          if (byEmailQuery.docs.isNotEmpty) {
            workerDoc = {'id': byEmailQuery.docs.first.id, ...byEmailQuery.docs.first.data()};
            print('[BusinessProvider] Found worker by email: ${byEmailQuery.docs.first.id}');
          } else {
            final byAltEmailQuery = await FirebaseFirestore.instance
                .collection('workers')
                .where('emailAddress', isEqualTo: workerEmail)
                .limit(1)
                .get();
            if (byAltEmailQuery.docs.isNotEmpty) {
              workerDoc = {'id': byAltEmailQuery.docs.first.id, ...byAltEmailQuery.docs.first.data()};
              print('[BusinessProvider] Found worker by emailAddress: ${byAltEmailQuery.docs.first.id}');
            }
          }
        } catch (e) {
          print('[BusinessProvider] Worker lookup by email failed: $e');
        }
      }

      // As a final fallback, check the users collection for a businessId entry
      if (workerDoc == null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(workerId).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            if (data.containsKey('businessId') && (data['businessId'] as String).isNotEmpty) {
              final found = data['businessId'] as String;
              print('[BusinessProvider] Found businessId on users doc: $found');
              await loadBusinessById(found);
              return _currentBusiness != null;
            }
          }
        } catch (e) {
          print('[BusinessProvider] User doc lookup failed: $e');
        }
      }

      final foundBusinessId = (workerDoc != null && workerDoc is Map<String, dynamic>)
          ? (workerDoc['businessId'] as String?) ?? ''
          : '';

      if (foundBusinessId.isNotEmpty) {
        print('[BusinessProvider] Found businessId for worker: $foundBusinessId');
        await loadBusinessById(foundBusinessId);
        return _currentBusiness != null;
      } else {
        print('[BusinessProvider] No businessId found for worker $workerId');
        return false;
      }
    } catch (e) {
      print('[BusinessProvider] ensureBusinessForWorker error: $e');
      // Do not rethrow; this is a best-effort helper
      return false;
    }
  }

  /// Refresh computed statistics for a business (products, workers, customers)
  Future<void> _refreshBusinessStats(String businessId) async {
    try {
      print('[BusinessProvider] Refreshing business stats for $businessId');
      final fs = FirebaseFirestore.instance;

      // Products and customers still use subcollection counts (fast count aggregation)
      final prodSnap = await fs
          .collection('businesses')
          .doc(businessId)
          .collection('inventory')
          .count()
          .get();
      final products = prodSnap.count ?? 0;

      final custSnap = await fs
          .collection('businesses')
          .doc(businessId)
          .collection('customers')
          .count()
          .get();
      final customers = custSnap.count ?? 0;

      int workers = 0;

      // Prefer authoritative worker list from WorkerRepository (merges global "workers" and "users" collections)
      try {
        final workerRepo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
        final list = await workerRepo.getWorkers(businessId);
        workers = list.length;
        print('[BusinessProvider] WorkerRepo returned ${workers} workers for business');
      } catch (e) {
        // Fallback to business subcollection count if repository lookup fails
        try {
          final workersSnap = await fs
              .collection('businesses')
              .doc(businessId)
              .collection('workers')
              .count()
              .get();
          workers = workersSnap.count ?? 0;
        } catch (e2) {
          print('[BusinessProvider] Failed to compute workers count: $e2');
        }
      }

      print('[BusinessProvider] Counts: products=$products, workers=$workers, customers=$customers');

      // Persist computed stats to primary business document
      try {
        await _repository.updateBusinessStats(
            businessId: businessId, totalWorkers: workers, totalProducts: products, totalCustomers: customers);
      } catch (e) {
        print('[BusinessProvider] Failed to update business stats: $e');
      }

      // Update cached currentBusiness if it matches
      if (_currentBusiness != null && _currentBusiness!.id == businessId) {
        _currentBusiness = _currentBusiness!.copyWith(
          totalWorkers: workers,
          totalProducts: products,
          totalCustomers: customers,
        );
        try {
          if (_localStorage != null) await _localStorage!.saveBusiness(_currentBusiness!);
        } catch (e) {
          print('[BusinessProvider] Warning: failed to cache updated business: $e');
        }
        notifyListeners();
      }
    } catch (e) {
      print('[BusinessProvider] Error refreshing business stats: $e');
    }
  }

  /// Helper: Get authoritative list of workers for a business using WorkerRepository
  Future<List<Map<String, dynamic>>> getWorkersForBusiness(String businessId) async {
    try {
      final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
      final list = await repo.getWorkers(businessId);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print('[BusinessProvider] getWorkersForBusiness failed: $e');
      return [];
    }
  }

  Future<void> switchBusiness(String businessId) async {
    try {
      final business = _userBusinesses.firstWhere((b) => b.id == businessId);
      _currentBusiness = business;

      // Persist selection locally for faster restoration
      if (_localStorage != null) {
        try {
          await _localStorage!.setCurrentBusiness(businessId);
          await _localStorage!.saveBusiness(business);
        } catch (e) {
          print('[BusinessProvider] Warning: failed to persist switched business: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Business not found';
      notifyListeners();
    }
  }

  /// Public wrapper to refresh computed business statistics (products, workers, customers)
  Future<void> refreshBusinessStats(String businessId) async {
    await _refreshBusinessStats(businessId);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Subscription management

  String get normalizedSubscriptionTier {
    return _normalizeSubscriptionTier(_currentBusiness);
  }

  String get normalizedBusinessClass {
    return _normalizeBusinessClass(_currentBusiness);
  }

  String _normalizeSubscriptionTier(BusinessModel? business) {
    if (business == null) return 'basic';
    return SubscriptionService.normalizeStoredPlanLevel(
      subscriptionTier: business.subscriptionTier,
      subscriptionPlan: business.subscriptionPlan,
    );
  }

  String _normalizeBusinessClass(BusinessModel? business) {
    if (business == null) return 'tier1';
    return SubscriptionService.normalizeStoredBusinessClass(
      businessClass: business.businessClass,
      subscriptionPlan: business.subscriptionPlan,
    );
  }

  int? getLimitFor(String limitType) {
    if (_currentBusiness == null) return null;

    final tier = normalizedSubscriptionTier;
    final businessClass = normalizedBusinessClass;

    switch (limitType) {
      case 'workers':
        if (tier == 'pro') {
          if (businessClass == 'tier2') return 50;
          if (businessClass == 'tier3') return null;
          return 5;
        }
        switch (businessClass) {
          case 'tier2':
            return 10;
          case 'tier3':
            return 100;
          case 'tier1':
          default:
            return 5;
        }

      case 'products':
        switch (businessClass) {
          case 'tier2':
            return 1000;
          case 'tier3':
            return null;
          case 'tier1':
          default:
            return 400;
        }

      case 'monthly_transactions':
        switch (businessClass) {
          case 'tier2':
            return 5000;
          case 'tier3':
            return null;
          case 'tier1':
          default:
            return 1000;
        }

      default:
        return null;
    }
  }

  String getLimitReachedMessage(String limitType) {
    final limit = getLimitFor(limitType);
    String noun;
    switch (limitType) {
      case 'workers':
        noun = 'workers';
        break;
      case 'products':
        noun = 'products';
        break;
      case 'monthly_transactions':
        noun = 'monthly transactions';
        break;
      default:
        noun = limitType;
    }
    final tier = normalizedSubscriptionTier.toUpperCase();
    final businessClassLabel = normalizedBusinessClass.toUpperCase();

    if (limit == null) {
      return 'Your $businessClassLabel $tier plan has no fixed $noun limit.';
    }

    return 'Your $businessClassLabel $tier plan allows up to $limit $noun. Upgrade before adding more.';
  }

  /// Check if feature is available in current subscription tier
  /// NOTE: For enhanced checking including expiration validation,
  /// use EnhancedSubscriptionProvider.canAccessFeature() instead
  ///
  /// This method only checks tier-based access, not subscription validity
  /// For production, migrate to EnhancedSubscriptionProvider
  @Deprecated('Use EnhancedSubscriptionProvider.canAccessFeature() instead. '
      'This method does not check expiration dates.')
  bool hasFeatureAccess(String feature, {String? userRole}) {
    // Worker accounts are always allowed regardless of subscription
    if (userRole != null && userRole.toLowerCase() == 'worker') return true;

    if (_currentBusiness == null) return false;

    final tier = normalizedSubscriptionTier;
    final businessClass = normalizedBusinessClass;

    // Define feature access based on subscription tier
    switch (feature) {
      case 'unlimited_workers':
        return tier == 'basic' || tier == 'pro';
      case 'advanced_analytics':
        return tier == 'basic' || tier == 'pro';
      case 'multi_location':
        return tier == 'pro' || businessClass == 'tier3';
      case 'api_access':
        return tier == 'pro';
      case 'priority_support':
        return tier == 'pro';
      default:
        return true; // Basic features available to all
    }
  }

  /// Enhanced feature access check with subscription validation
  /// Validates: tier + active status + expiration date
  ///
  /// Usage:
  /// ```dart
  /// final canAccess = await businessProvider.canAccessFeatureEnhanced(
  ///   feature: 'email_receipts',
  ///   context: 'email_screen_init',
  /// );
  /// ```
  /// Enhanced feature access check returning a map {ok: bool, message: String?}
  Future<Map<String, dynamic>> canAccessFeatureEnhanced(
    String feature, {
    String context = 'business_provider',
    String? userRole,
  }) async {
    // Workers are exempt from subscription restrictions
    if (userRole != null && userRole.toLowerCase() == 'worker') {
      return {'ok': true, 'message': null};
    }

    if (_currentBusiness == null) {
      return {'ok': false, 'message': 'No active business'};
    }

    // Check subscription is valid (active + not expired)
    if (isSubscriptionExpired()) {
      return {'ok': false, 'message': 'Subscription expired'};
    }

    if (!_currentBusiness!.isSubscriptionActive) {
      return {'ok': false, 'message': 'Subscription inactive'};
    }

    // Check tier-based access
    final tier = normalizedSubscriptionTier;
    final businessClass = normalizedBusinessClass;
    switch (feature) {
      case 'unlimited_workers':
      case 'advanced_analytics':
      case 'email_receipts':
      case 'sms_notifications':
        if (!(tier == 'basic' || tier == 'pro')) {
          return {
            'ok': false,
            'message': 'Feature available in Basic tier and above'
          };
        }
        return {'ok': true, 'message': null};

      case 'multi_location':
        if (tier == 'pro' || businessClass == 'tier3') {
          return {'ok': true, 'message': null};
        }
        return {
          'ok': false,
          'message': 'Feature available in Tier 3 Basic or Pro plans'
        };

      case 'api_access':
      case 'payment_processing':
      case 'custom_reports':
      case 'priority_support':
        if (tier != 'pro') {
          return {
            'ok': false,
            'message': 'Feature available in Pro plans'
          };
        }
        return {'ok': true, 'message': null};

      case 'white_label':
      case 'sso_login':
      case 'dedicated_support':
        if (!(tier == 'pro' && businessClass == 'tier3')) {
          return {
            'ok': false,
            'message': 'Feature available in Tier 3 Pro plans only'
          };
        }
        return {'ok': true, 'message': null};

      default:
        return {'ok': true, 'message': null}; // Basic features available to all
    }
  }

  bool isWithinLimit(String limitType, int currentCount) {
    if (_currentBusiness == null) return false;

    final limit = getLimitFor(limitType);
    if (limit == null) return true;
    return currentCount < limit;
  }

  String getBusinessTypeName() {
    if (_currentBusiness == null) return '';

    switch (_currentBusiness!.businessType) {
      case 'pharmacy':
        return 'Pharmacy';
      case 'retail':
        return 'Retail Store';
      case 'wholesale':
        return 'Wholesale';
      case 'agri':
        return 'Agriculture';
      case 'auto':
        return 'Auto Service';
      case 'salon':
        return 'Salon';
      case 'hotel':
        return 'Hotel';
      case 'drink':
        return 'Bar/Lounge';
      case 'restaurant':
        return 'Restaurant';
      case 'realestate':
        return 'Real Estate';
      default:
        return 'Business';
    }
  }

  /// Returns a route name that matches the current business's industry so
  /// callers (e.g. login flows) can navigate directly to the correct
  /// industry-specific dashboard for worker users.
  String? getIndustryRouteForCurrentBusiness() {
    if (_currentBusiness == null) return null;
    return getIndustryRouteForType(_currentBusiness!.businessType);
  }

  /// Static helper that maps a business type string to an industry route.
  /// Useful for callers that don't want to instantiate the provider (e.g. tests).
  static String? industryRouteForType(String? businessType) {
    if (businessType == null || businessType.isEmpty) return null;
    final bt = businessType.toLowerCase();
    final primary = bt.contains('/') ? bt.split('/').last : bt;

    switch (primary) {
      case 'pharmacy':
        return '/pharmacy';
      case 'retail':
        return '/retail';
      case 'wholesale':
        return '/wholesale';
      case 'agri':
      case 'agriculture':
        return '/agri';
      case 'auto':
      case 'auto repair':
        return '/auto';
      case 'salon':
        return '/salon';
      case 'hotel':
        return '/hotel';
      case 'drink':
      case 'bar':
        return '/drink';
      case 'restaurant':
        return '/restaurant';
      case 'gas':
        return '/gas';
      case 'realestate':
      case 'real estate':
        return '/realestate';
      case 'barber':
      case 'barbershop':
        return '/barbershop';
      case 'gym':
        return '/gym';
      default:
        return null;
    }
  }

  /// Backwards-compatible instance wrapper
  String? getIndustryRouteForType(String? businessType) => BusinessProvider.industryRouteForType(businessType);

  /// Subscription helpers
  DateTime? get subscriptionEndDate => _currentBusiness?.subscriptionEndDate;

  /// Returns true when the subscription is expired or not active
  bool isSubscriptionExpired() {
    final b = _currentBusiness;
    if (b == null) return true;
    if (!b.isSubscriptionActive) return true;
    final end = b.subscriptionEndDate;
    if (end == null) return false; // no end => treated as active
    return DateTime.now().isAfter(end);
  }

  /// Returns true when the business has a valid paid subscription (professional or enterprise)
  bool isSubscriptionValid() {
    final b = _currentBusiness;
    if (b == null) return false;
    final tier = _normalizeSubscriptionTier(b);

    if (!(tier == 'basic' || tier == 'pro')) return false;
    if (!b.isSubscriptionActive) return false;
    final end = b.subscriptionEndDate;
    if (end != null && DateTime.now().isAfter(end)) return false;
    return true;
  }

  /// Get cached business for offline support
  /// Returns the current business from local cache if available
  BusinessModel? getCachedCurrentBusiness() {
    if (_localStorage == null) return _currentBusiness;

    try {
      final cached = _localStorage!.getCurrentBusiness();
      if (cached != null) {
        print('[BusinessProvider] Using cached business: ${cached.id}');
        return cached;
      }
      return _currentBusiness;
    } catch (e) {
      print('[BusinessProvider] Error getting cached business: $e');
      return _currentBusiness;
    }
  }

  /// Get all cached businesses for offline support
  List<BusinessModel> getCachedBusinesses() {
    if (_localStorage == null) return _userBusinesses;

    try {
      final cached = _localStorage!.getCachedBusinesses();
      if (cached.isNotEmpty) {
        print('[BusinessProvider] Using ${cached.length} cached businesses');
        return cached;
      }
      return _userBusinesses;
    } catch (e) {
      print('[BusinessProvider] Error getting cached businesses: $e');
      return _userBusinesses;
    }
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    if (_localStorage == null)
      return {'error': 'Local storage not initialized'};
    return _localStorage!.getCacheStats();
  }

  /// Enable / disable edge diagnostic logging for a given user and persist preference
  Future<void> setEdgeLoggingForUser(String userId, bool enabled) async {
    try {
      if (_localUserStorage != null) {
        await _localUserStorage!.setEdgeLoggingForUser(userId, enabled);
      }
      if (_loadedForUserId == userId) _verboseLogging = enabled;
      print('[BusinessProvider] Edge logging ${enabled ? 'ENABLED' : 'DISABLED'} for user $userId');
      notifyListeners();
    } catch (e) {
      print('[BusinessProvider] Failed to set edge logging for $userId: $e');
    }
  }

  String? get loadedForUserId => _loadedForUserId;

  /// Deduplicate businesses list preferring full documents over placeholders
  void _dedupeUserBusinesses() {
    final Map<String, BusinessModel> map = {};
    for (final b in _userBusinesses) {
      if (!map.containsKey(b.id)) {
        map[b.id] = b;
      } else {
        final existing = map[b.id]!;
        // Prefer a business that appears to be a full record (has ownerId or non-placeholder name)
        final existingIsPlaceholder = existing.ownerId.isEmpty || existing.name.startsWith('Unknown Business');
        final candidateIsPlaceholder = b.ownerId.isEmpty || b.name.startsWith('Unknown Business');
        if (existingIsPlaceholder && !candidateIsPlaceholder) {
          map[b.id] = b;
        }
      }
    }
    _userBusinesses = map.values.toList();
  }

  /// Clear all cached business data on logout
  Future<void> clearCachedBusinessData() async {
    if (_localStorage != null) {
      await _localStorage!.clearAllBusinessData();
      print('[BusinessProvider] Cleared all cached business data');
    }

    _currentBusiness = null;
    _userBusinesses = [];
    _isUsingCachedData = false;
    _loadedForUserId = null;
    notifyListeners();
  }
}
