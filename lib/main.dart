import 'package:flutter/material.dart';
import 'services/local_business_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/business_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/retail_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/apartment_provider.dart';
import 'providers/payment_config_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/enhanced_subscription_provider.dart';
import 'providers/loyalty_provider.dart';
import 'providers/batch_operations_provider.dart';
import 'presentation/industry_specific/restaurant/providers/restaurant_provider.dart';
import 'providers/pharmacy_provider.dart';
import 'data/repositories/industry_specific/pharmacy_repository_impl.dart';
import 'providers/receipt_settings_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/backup_provider.dart';
import 'services/email_service.dart';
import 'providers/agri_provider.dart';
import 'data/repositories/industry_specific/agri_repository_impl.dart';
import 'providers/auto_provider.dart';
import 'presentation/industry_specific/barber_shop/providers/barber_shop_provider.dart';
import 'presentation/industry_specific/salon/providers/salon_provider.dart';
import 'presentation/industry_specific/wholesale/providers/wholesale_provider.dart';
import 'providers/hotel_provider.dart';
import 'data/repositories/industry_specific/hotel_repository_impl.dart';
import 'data/repositories/industry_specific/drink_repository_impl.dart';
import 'providers/drink_provider.dart';
import 'presentation/industry_specific/realestate/providers/real_estate_provider.dart';
import 'providers/realestate_provider.dart'; // wrapper (kept for registration)
import 'providers/gym_provider.dart';
import 'providers/workers_provider.dart';
import 'providers/inventory_alerts_provider.dart';
import 'providers/customer_provider.dart';
import 'data/repositories/industry_specific/gym_repository_impl.dart';
import 'services/notification_service.dart';
import 'data/local/database_helper.dart';
import 'providers/admin_provider.dart';
import 'providers/marketer_provider.dart';
import 'services/services_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite database factory for FFI support (for web and desktop)
  if (!kIsWeb) {
    sqfliteFfiInit();
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (with duplicate check)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    // App already initialized, continue
  }

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize local database (skip on web)
  if (!kIsWeb) {
    try {
      await DatabaseHelper.instance.database;
    } catch (e) {
      print('Database initialization warning: $e');
    }
  }

  // Initialize app services (analytics, barcode, cloud storage, etc.)
  try {
    await ServicesInitializer().initializeAll();
  } catch (e) {
    print('Services initialization warning: $e');
  }

  // Initialize notification service (only on mobile platforms)
  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      // If notifications fail to initialize on the device, log and continue
    }
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BusinessProvider>(
          create: (_) => BusinessProvider(),
          update: (_, auth, previous) {
            // Ensure the BusinessProvider is in a clean state when auth changes
            previous ??= BusinessProvider();

            // If user is not authenticated, clear any cached business data immediately
            if (!auth.isAuthenticated || auth.currentUser == null) {
              try {
                previous.clearCachedBusinessData();
                print('[Main] Cleared BusinessProvider due to unauthenticated auth state');
              } catch (e) {
                print('[Main] Error clearing BusinessProvider on logout: $e');
              }
              return previous;
            }

            // When a user is authenticated, but it's a different user to the one
            // that previously loaded businesses, clear the previous cached data
            // to avoid showing stale businesses from another account.
            final userId = auth.currentUser!.id;
            if (previous.loadedForUserId != null && previous.loadedForUserId != userId) {
              try {
                previous.clearCachedBusinessData();
                print('[Main] Cleared BusinessProvider cache because authenticated user changed (old: ${previous.loadedForUserId}, new: $userId)');
              } catch (e) {
                print('[Main] Error clearing BusinessProvider during user switch: $e');
              }
            }

            try {
              final preferredId = auth.currentUser!.businessId;
              final isWorker = auth.isWorkerUser;

              print('[Main] ProxyProvider update:');
              print('[Main]   User ID: $userId');
              print('[Main]   User role: ${auth.currentUser?.role}');
              print('[Main]   Is worker: $isWorker');
              print('[Main]   Preferred/Business ID: $preferredId');

              if (isWorker && preferredId.isNotEmpty) {
                // Workers (staff) will have a businessId pointing to the owner's business.
                // Load that business by id so the app is scoped correctly for worker users.
                print(
                    '[Main]   Loading as WORKER with business: $preferredId');
                previous.loadBusinessById(preferredId);
              } else {
                // Owners: Load all businesses for the authenticated user (owner flow).
                // This ensures businesses are loaded even if businessId is empty
                print('[Main]   Loading as OWNER');
                previous.loadUserBusinesses(
                  userId,
                  preferredBusinessId: auth.currentUser?.currentBusinessId ?? (preferredId.isNotEmpty ? preferredId : null),
                  userBusinessIds: auth.currentUser?.businessIds,
                );
              }
            } catch (e) {
              print('[Main] ProxyProvider error: $e');
            }

            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ReceiptSettingsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
            create: (_) => NotificationProvider()..initialize()),
        ChangeNotifierProxyProvider<BusinessProvider, CurrencyProvider>(
          create: (_) => CurrencyProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final cp = CurrencyProvider();
              if (bid.isNotEmpty) {
                cp.initialize(bid);
              }
              return cp;
            }
            if (bid.isNotEmpty) {
              previous.initialize(bid);
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, BackupProvider>(
          create: (_) => BackupProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final bp = BackupProvider();
              if (bid.isNotEmpty) {
                bp.initialize(bid);
              }
              return bp;
            }
            if (bid.isNotEmpty) {
              previous.initialize(bid);
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider2<AuthProvider, BusinessProvider,
            ReportsProvider>(
          create: (_) => ReportsProvider(),
          update: (_, auth, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            // Ensure the reports provider can access auth context
            previous ??= ReportsProvider();
            previous.setAuthProvider(auth);
            if (bid.isNotEmpty) {
              // Defer subscriptions with a small delay to ensure window is fully initialized on web
              Future.delayed(const Duration(milliseconds: 100), () {
                if (previous != null) {
                  previous.subscribeToSalesReports(businessId: bid);
                  previous.subscribeToFinancialReports(businessId: bid);
                  previous.subscribeToInventoryReports(businessId: bid);
                  previous.subscribeToExpensesReports(businessId: bid);
                }
              });
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, AnalyticsProvider>(
          create: (_) => AnalyticsProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final ap = AnalyticsProvider();
              if (bid.isNotEmpty) ap.setBusinessId(bid);
              return ap;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, InventoryAlertsProvider>(
          create: (_) => InventoryAlertsProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final iap = InventoryAlertsProvider();
              if (bid.isNotEmpty) {
                iap.setBusinessId(bid);
                iap.loadAlerts();
              }
              return iap;
            }
            if (bid.isNotEmpty) {
              previous.setBusinessId(bid);
              previous.loadAlerts();
            }
            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => LoyaltyProvider()),
        ChangeNotifierProxyProvider<BusinessProvider, BatchOperationsProvider>(
          create: (_) => BatchOperationsProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final bop = BatchOperationsProvider();
              if (bid.isNotEmpty) {
                bop.initialize(bid);
              }
              return bop;
            }
            if (bid.isNotEmpty) {
              previous.initialize(bid);
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, RestaurantProvider>(
          create: (_) => RestaurantProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final p = RestaurantProvider();
              if (bid.isNotEmpty) p.setBusinessId(bid);
              return p;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, RetailProvider>(
          create: (_) => RetailProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final rp = RetailProvider();
              if (bid.isNotEmpty) {
                rp.initialize(bid);
              }
              return rp;
            }
            // Reinitialize for new business
            if (bid.isNotEmpty) {
              previous.initialize(bid);
            }
            return previous;
          },
        ),
        ChangeNotifierProvider(create: (_) => PaymentConfigProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProxyProvider<BusinessProvider,
            EnhancedSubscriptionProvider>(
          create: (_) => EnhancedSubscriptionProvider(),
          update: (_, businessProvider, previous) {
            if (previous == null) return EnhancedSubscriptionProvider();
            // Attempt to initialize with LocalBusinessStorage when available.
            // This avoids blocking app startup while the async LocalBusinessStorage is created.
            LocalBusinessStorage.create().then((localStorage) {
              previous.initialize(localStorage);
            }).catchError((e) {
              // ignore - initialization will be retried later
            });
            return previous;
          },
        ),
        Provider<EmailService>(create: (_) => EmailService()),
        // Industry providers (stubs)
        ChangeNotifierProvider(
          create: (_) => PharmacyProvider(repository: PharmacyRepositoryImpl()),
        ),
        ChangeNotifierProxyProvider<BusinessProvider, AgriProvider>(
          create: (_) =>
              AgriProvider(notificationService: NotificationService.instance),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? 'demo';
            return AgriProvider(
                repository: AgriRepositoryImpl(businessId: bid),
                notificationService: NotificationService.instance,
                initialBusinessId: bid);
          },
        ),
        // Workers provider: caches workers for the current business and refreshes when business changes
        ChangeNotifierProxyProvider<BusinessProvider, WorkersProvider>(
          create: (_) => WorkersProvider(businessId: ''),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              return WorkersProvider(businessId: bid);
            }
            if (bid.isNotEmpty) {
              // refresh existing provider for the new business id
              previous.refreshForBusiness(bid);
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, AutoProvider>(
          create: (_) => AutoProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final ap = AutoProvider();
              if (bid.isNotEmpty) ap.setBusinessId(bid);
              return ap;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, BarberShopProvider>(
          create: (_) => BarberShopProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final p = BarberShopProvider();
              if (bid.isNotEmpty) p.setBusinessId(bid);
              return p;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, SalonProvider>(
          create: (_) => SalonProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final p = SalonProvider();
              if (bid.isNotEmpty) p.setBusinessId(bid);
              return p;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, HotelProvider>(
          create: (_) => HotelProvider(repository: HotelRepositoryImpl()),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final hp = HotelProvider(repository: HotelRepositoryImpl());
              if (bid.isNotEmpty) hp.setBusinessId(bid);
              return hp;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, WholesaleProvider>(
          create: (_) => WholesaleProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final wp = WholesaleProvider();
              if (bid.isNotEmpty) wp.initializeWithBusinessId(bid);
              return wp;
            }
            if (bid.isNotEmpty) previous.initializeWithBusinessId(bid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, DrinkProvider>(
          create: (_) => DrinkProvider(
            repository: DrinkRepositoryImpl(businessId: 'demo'),
          ),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? 'demo';
            final repo = DrinkRepositoryImpl(businessId: bid);
            if (previous == null) {
              final p = DrinkProvider(repository: repo);
              // initialize in background
              p.initialize(repository: repo);
              return p;
            }
            // trigger background re-initialization for existing provider
            previous.initialize(repository: repo);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<BusinessProvider, GymProvider>(
          create: (_) => GymProvider(
              repository: GymRepositoryImpl(businessId: 'demo'),
              businessId: 'demo'),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? 'demo';
            // Create a provider with repository and business id wired to current business
            return GymProvider(
                repository: GymRepositoryImpl(businessId: bid),
                businessId: bid);
          },
        ),
        // Removed duplicate RestaurantProvider instantiation
        ChangeNotifierProxyProvider<BusinessProvider, RealEstateProvider>(
          create: (_) => RealestateProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            if (previous == null) {
              final p = RealestateProvider();
              if (bid.isNotEmpty) p.setBusinessId(bid);
              return p;
            }
            if (bid.isNotEmpty) previous.setBusinessId(bid);
            return previous;
          },
        ),
        // Customer provider: caches customers for the current business
        ChangeNotifierProxyProvider<BusinessProvider, CustomerProvider>(
          create: (_) => CustomerProvider(),
          update: (_, businessProvider, previous) {
            final bid = businessProvider.currentBusiness?.id ?? '';
            final cp = previous ?? CustomerProvider();
            if (bid.isNotEmpty) {
              cp.setBusinessId(bid);
            }
            return cp;
          },
        ),
        // Apartment management provider
        ChangeNotifierProvider(create: (_) => ApartmentProvider()),
        // Marketer provider for admin/marketer login functionality
        ChangeNotifierProvider(create: (_) => MarketerProvider()),
      ],
      child: const App(),
    );
  }
}

