/**
 * Test script to verify Firebase Cloud Functions for push notifications
 * Run with: node test_notifications.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, 'functions', 'serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
  databaseURL: 'https://manage-care-1e96b.firebaseio.com'
});

const db = admin.firestore();

async function createTestData() {
  try {
    console.log('🔄 Creating test data for push notifications...\n');

    // Test 1: Create a test business
    console.log('📝 Test 1: Creating test business...');
    const businessId = 'test-business-' + Date.now();
    const testOwnerId = 'test-owner-' + Date.now();
    
    await db.collection('businesses').doc(businessId).set({
      name: 'Test Business',
      ownerId: testOwnerId,
      address: '123 Test St',
      phone: '+234123456789',
      email: 'test@business.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ Business created: ${businessId}\n`);

    // Test 2: Create a test user (business owner)
    console.log('📝 Test 2: Creating test user (business owner)...');
    await db.collection('users').doc(testOwnerId).set({
      fullName: 'Test Owner',
      email: 'owner@test.com',
      businessId: businessId,
      pushEnabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ Test user created: ${testOwnerId}\n`);

    // Test 3: Add test FCM token for the owner
    console.log('📝 Test 3: Adding test FCM token...');
    const testToken = 'test-fcm-token-' + Date.now();
    await db.collection('users')
      .doc(testOwnerId)
      .collection('fcmTokens')
      .doc(testToken)
      .set({
        token: testToken,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    console.log(`✅ FCM token added: ${testToken}\n`);

    // Test 4: Create a test payment transaction (triggers onPaymentTransactionCreate)
    console.log('📝 Test 4: Creating test payment transaction...');
    const transactionId = 'txn-' + Date.now();
    await db.collection('payment_transactions').doc(transactionId).set({
      transactionId: transactionId,
      businessId: businessId,
      amount: 5000,
      status: 'success',
      method: 'card',
      currency: 'NGN',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      description: 'Test payment for notification verification'
    });
    console.log(`✅ Payment transaction created: ${transactionId}`);
    console.log(`   This should trigger onPaymentTransactionCreate function\n`);

    // Test 5: Create a test notification (triggers onNotificationCreate)
    console.log('📝 Test 5: Creating test notification...');
    const notificationId = 'notif-' + Date.now();
    await db.collection('notifications').doc(notificationId).set({
      title: 'Test Notification',
      body: 'This is a test notification to verify Firebase Cloud Functions',
      targetUsers: [testOwnerId],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ Notification created: ${notificationId}`);
    console.log(`   This should trigger onNotificationCreate function\n`);

    console.log('✨ Test data created successfully!\n');
    console.log('📊 Summary:');
    console.log(`   Business ID: ${businessId}`);
    console.log(`   Owner ID: ${testOwnerId}`);
    console.log(`   Payment Transaction ID: ${transactionId}`);
    console.log(`   Notification ID: ${notificationId}`);
    console.log(`   FCM Token: ${testToken}\n`);

    console.log('🔍 Next steps:');
    console.log('   1. Go to Firebase Console → Cloud Functions');
    console.log('   2. Click "onPaymentTransactionCreate" and check logs');
    console.log('   3. Click "onNotificationCreate" and check logs');
    console.log('   4. Verify no errors in the function logs\n');

    console.log('💾 Check Cloud Firestore entries:');
    console.log(`   - businesses/${businessId}`);
    console.log(`   - users/${testOwnerId}`);
    console.log(`   - payment_transactions/${transactionId}`);
    console.log(`   - notifications/${notificationId}\n`);

  } catch (error) {
    console.error('❌ Error creating test data:', error);
    process.exit(1);
  }

  // Clean up
  process.exit(0);
}

// Run the script
createTestData().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
