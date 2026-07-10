import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:business_manager/providers/retail_provider.dart';
import 'package:business_manager/services/notification_and_email_service.dart';
import 'package:business_manager/services/notification_interface.dart';
import 'package:business_manager/services/email_service.dart';

class FakeEmailService extends EmailService {
  @override
  Future<bool> sendOrderSuccessAlert(String recipient, Map<String, dynamic> data,
      {List? attachments, bool isPro = false}) async {
    return true;
  }

  @override
  Future<bool> sendReceiptEmail({
    required String recipient,
    required String businessName,
    required String receiptText,
    String? orderId,
    String? businessId,
    String? businessEmail,
    String? businessPhone,
    String? customerName,
    String? logoUrl,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? tax,
    double? total,
    String? paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    bool isPro = false,
    bool generatePDF = false,
    bool sendCopyToSender = false,
    String theme = 'professional',
    String receiptType = 'detailed',
  }) async {
    return true;
  }
} 

class FakeNotificationService implements INotificationService {
  @override
  Future<void> requestPermissions() async {}

  @override
  Future<List<int>> getDaysBeforeThresholds() async => [1, 7];

  @override
  Future<void> scheduleExpiryAlert({required String businessId, required String memberId, required String memberName, required DateTime expiry, int daysBefore = 1}) async {}

  @override
  Future<List<Map<String, dynamic>>> getScheduledAlertMetadata({String? businessId}) async => [];

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> sendNotification(String title, String body, {int id = 0}) async {}

  @override
  Future<void> scheduleNotificationAt({required int id, required String title, required String body, required DateTime at}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('fuelSale sells by amount and updates inventory and creates sale', () async {
    final fs = FakeFirebaseFirestore();

    // Create business
    await fs.collection('businesses').doc('b1').set({'name': 'Test Fuel', 'email': 'owner@test.com'});

    // Add inventory product (fuel)
    await fs.collection('businesses').doc('b1').collection('inventory').doc('fuel1').set({
      'name': 'Petrol',
      'price': 2.0,
      'quantity': 1000,
      'category': 'Fuel',
    });

    final notifService = NotificationAndEmailService(
      firestore: fs,
      emailService: FakeEmailService(),
      notificationService: FakeNotificationService(),
    );

    final provider = RetailProvider(firestore: fs, notificationEmailService: notifService);

    await provider.setBusinessId('b1');

    final res = await provider.fuelSale(
      productId: 'fuel1',
      amountPaid: 10.0,
      paymentMethod: 'Cash',
    );

    expect(res['quantity'], 5.0);
    expect(res['total'], 10.0);

    // Check sale stored
    final sales = await fs.collection('businesses').doc('b1').collection('sales').get();
    expect(sales.docs.length, 1);
    final saleDoc = sales.docs.first.data();
    expect((saleDoc['total'] as num).toDouble(), 10.0);
    final items = saleDoc['items'] as List<dynamic>;
    expect(items.length, 1);
    expect(items.first['productId'], 'fuel1');
    expect((items.first['quantity'] as num).toDouble(), 5.0);

    // Check inventory updated
    final inv = await fs.collection('businesses').doc('b1').collection('inventory').doc('fuel1').get();
    expect((inv.data()!['quantity'] as num).toDouble(), 995.0);

    // Check notification log
    final notifLogs = await fs.collection('businesses').doc('b1').collection('notificationLogs').get();
    expect(notifLogs.docs.isNotEmpty, true);
  });

  test('fuelSale uses a minimum quantity for tiny amount-based sales', () async {
    final fs = FakeFirebaseFirestore();
    await fs.collection('businesses').doc('b1').set({'name': 'Test Fuel', 'email': 'owner@test.com'});
    await fs.collection('businesses').doc('b1').collection('inventory').doc('fuel1').set({
      'name': 'Petrol',
      'price': 1000.0,
      'quantity': 1000,
      'category': 'Fuel',
    });

    final notifService = NotificationAndEmailService(
      firestore: fs,
      emailService: FakeEmailService(),
      notificationService: FakeNotificationService(),
    );

    final provider = RetailProvider(firestore: fs, notificationEmailService: notifService);
    await provider.setBusinessId('b1');

    final res = await provider.fuelSale(
      productId: 'fuel1',
      amountPaid: 1.0,
      paymentMethod: 'Cash',
    );

    expect(res['quantity'], 0.001);
    expect(res['total'], 1.0);
  });
}
