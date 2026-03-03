const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.onPaymentTransactionCreate = functions.firestore
  .document('payment_transactions/{txId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      if (!data) return null;

      const status = (data.status || '').toString().toLowerCase();
      if (status !== 'success' && status !== 'completed') {
        return null; // only notify on successful payments
      }

      const amount = data.amount || 0;
      const businessId = data.businessId;
      const transactionId = data.transactionId || snap.id;
      const method = data.method || '';

      // Load business to find owner(s)
      const businessDoc = await db.collection('businesses').doc(businessId).get();
      const business = businessDoc.exists ? businessDoc.data() : null;
      let ownerIds = [];
      if (business) {
        if (business.ownerId) ownerIds.push(business.ownerId);
        if (Array.isArray(business.ownerIds)) ownerIds = ownerIds.concat(business.ownerIds);
      }

      // If no owners found, nothing to notify
      if (ownerIds.length === 0) return null;

      // Collect tokens for owners respecting their push preference
      const tokens = [];
      for (const ownerId of ownerIds) {
        try {
          const userDoc = await db.collection('users').doc(ownerId).get();
          const userData = userDoc.exists ? userDoc.data() : {};
          if (userData && userData.pushEnabled === false) {
            console.log('Skipping owner', ownerId, 'because pushEnabled=false');
            continue;
          }

          const tokenSnap = await db
            .collection('users')
            .doc(ownerId)
            .collection('fcmTokens')
            .get();
          tokenSnap.forEach((t) => {
            const tok = (t.data() && t.data().token) ? t.data().token : null;
            if (tok) tokens.push(tok);
          });
        } catch (e) {
          // ignore per-owner errors
        }
      }

      if (tokens.length === 0) {
        console.log('[onPaymentTransactionCreate] No FCM tokens for owners of business', businessId);
        return null;
      }

      const title = 'New Transfer Received';
      const body = `₦${Number(amount).toFixed(2)} received (${method})`;

      const payload = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'payment_received',
          transactionId: String(transactionId),
          businessId: String(businessId),
        },
      };

      const response = await admin.messaging().sendToDevice(tokens, payload);

      // Clean up invalid tokens
      const toRemove = [];
      if (response && response.results) {
        response.results.forEach((res, idx) => {
          const error = res.error;
          if (error) {
            const badTok = tokens[idx];
            console.log('Removing invalid token', badTok, error.code);
            toRemove.push(badTok);
          }
        });
      }

      // Remove invalid tokens from owners' collections
      for (const bad of toRemove) {
        for (const ownerId of ownerIds) {
          try {
            await db.collection('users').doc(ownerId).collection('fcmTokens').doc(bad).delete();
          } catch (e) {
            // ignore
          }
        }
      }

      return null;
    } catch (err) {
      console.error('onPaymentTransactionCreate error:', err);
      return null;
    }
  });

// Send push notifications when a notification doc is created (e.g., from Admin UI)
exports.onNotificationCreate = functions.firestore
  .document('notifications/{nid}')
  .onCreate(async (snap, ctx) => {
    try {
      const doc = snap.data();
      if (!doc) return null;
      const title = doc.title || 'Notification';
      const body = doc.body || '';
      const targetUsers = Array.isArray(doc.targetUsers) ? doc.targetUsers : [];
      if (targetUsers.length === 0) return null;

      const tokens = [];
      for (const uid of targetUsers) {
        try {
          const userDoc = await db.collection('users').doc(uid).get();
          const udata = userDoc.exists ? userDoc.data() : {};
          if (udata && udata.pushEnabled === false) continue;
          const tSnap = await db.collection('users').doc(uid).collection('fcmTokens').get();
          tSnap.forEach((t) => {
            const tok = (t.data() && t.data().token) ? t.data().token : null;
            if (tok) tokens.push(tok);
          });
        } catch (e) {
          // ignore per-user failures
        }
      }

      if (tokens.length === 0) return null;

      const payload = {
        notification: { title: title, body: body },
        data: { type: 'admin_notification', nid: snap.id }
      };

      const response = await admin.messaging().sendToDevice(tokens, payload);
      // Optionally remove invalid tokens similar to above
      return null;
    } catch (err) {
      console.error('onNotificationCreate error:', err);
      return null;
    }
  });