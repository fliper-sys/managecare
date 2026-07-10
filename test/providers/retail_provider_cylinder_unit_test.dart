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

  test('cylinder unit sales: amount-based rounding and insufficient amount', () async {
    final fs = FakeFirebaseFirestore();

    // Create business
    await fs.collection('businesses').doc('b1').set({'name': 'Test Gas', 'email': 'owner@test.com'});

    // Add cylinder product
    await fs.collection('businesses').doc('b1').collection('inventory').doc('cyl1').set({
      'name': 'Cooking Gas Cylinder',
      'price': 12000.0,
      'quantity': 10,
      'category': 'Fuel',
      'unit': 'cyl',
    });

    final notifService = NotificationAndEmailService(
      firestore: fs,
      emailService: FakeEmailService(),
      notificationService: FakeNotificationService(),
    );

    final provider = RetailProvider(firestore: fs, notificationEmailService: notifService);

    await provider.setBusinessId('b1');

    // Insufficient amount should throw
    expect(() async {
      await provider.fuelSale(productId: 'cyl1', amountPaid: 10000.0, paymentMethod: 'Cash');
    }, throwsException);

    // Amount that covers 2 cylinders (25000 -> floor to 2 => 24000)
    final res = await provider.fuelSale(productId: 'cyl1', amountPaid: 25000.0, paymentMethod: 'Cash');
    expect(res['quantity'], 2.0);
    expect(res['total'], 24000.0);

    final sales = await fs.collection('businesses').doc('b1').collection('sales').get();
    expect(sales.docs.length, 1);
    final saleDoc = sales.docs.first.data();
    final items = saleDoc['items'] as List<dynamic>;
    expect(items.first['unit'], 'cyl');

    // Check inventory updated (10 - 2 = 8)
    final inv = await fs.collection('businesses').doc('b1').collection('inventory').doc('cyl1').get();
    expect((inv.data()!['quantity'] as num).toDouble(), 8.0);

    // Now test fractional quantity request (1.7) gets floored to 1
    final res2 = await provider.fuelSale(productId: 'cyl1', quantity: 1.7, paymentMethod: 'Cash');
    expect(res2['quantity'], 1.0);
    expect(res2['total'], 12000.0);

    final inv2 = await fs.collection('businesses').doc('b1').collection('inventory').doc('cyl1').get();
    expect((inv2.data()!['quantity'] as num).toDouble(), 7.0);
  });
}
