const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const GRACE_WINDOW_DAYS = 30;

function parseFirestoreDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  if (typeof value.toDate === 'function') {
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
  return null;
}

async function recursiveDeleteSafe(ref) {
  if (!ref) return;

  if (typeof db.recursiveDelete === 'function') {
    await db.recursiveDelete(ref);
    return;
  }

  if (typeof ref.listCollections === 'function') {
    const subcollections = await ref.listCollections();
    for (const subcollection of subcollections) {
      const snap = await subcollection.get();
      for (const doc of snap.docs) {
        await recursiveDeleteSafe(doc.ref);
      }
    }
  }

  await ref.delete().catch(() => null);
}

async function cleanupDeletedBusinessReferences(businessId) {
  const queries = await Promise.all([
    db.collection('users').where('deletedBusinessIds', 'array-contains', businessId).get(),
    db.collection('users').where('lastDeletedBusinessId', '==', businessId).get(),
  ]);

  const refs = new Map();
  for (const snapshot of queries) {
    for (const doc of snapshot.docs) {
      refs.set(doc.id, doc.ref);
    }
  }

  for (const ref of refs.values()) {
    const snap = await ref.get();
    if (!snap.exists) continue;

    const data = snap.data() || {};
    const updates = {
      deletedBusinessIds: FieldValue.arrayRemove(businessId),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if ((data.lastDeletedBusinessId || '').toString() === businessId) {
      updates.lastDeletedBusinessId = FieldValue.delete();
      updates.lastBusinessDeletedAt = FieldValue.delete();
      updates.lastBusinessRecoveryDeadlineAt = FieldValue.delete();
      updates.lastBusinessRecoveryAccess = FieldValue.delete();
      updates.lastBusinessDeletedByType = FieldValue.delete();
    }

    await ref.set(updates, { merge: true });
  }
}

async function purgeBusinessCompletely(businessId) {
  const businessRef = db.collection('businesses').doc(businessId);
  const businessSnap = await businessRef.get();
  if (!businessSnap.exists) return;

  const subcollections = [
    'sales',
    'inventory',
    'orders',
    'bookings',
    'invoices',
    'payments',
    'payment_transactions',
    'serviceOrders',
    'restaurant_orders',
    'services',
    'products',
    'workers',
    'staff',
    'tables',
    'customers',
    'notifications',
  ];

  for (const subcollection of subcollections) {
    try {
      const snap = await businessRef.collection(subcollection).get();
      for (const doc of snap.docs) {
        await recursiveDeleteSafe(doc.ref);
      }
    } catch (error) {
      console.error('[purgeBusinessCompletely] subcollection cleanup failed', businessId, subcollection, error);
    }
  }

  const rootCollections = [
    'subscriptions',
    'payments',
    'transactions',
    'activities',
    'serviceOrders',
    'payment_transactions',
    'notifications',
    'subscription_requests',
    'subscription_approvals',
  ];

  for (const collection of rootCollections) {
    try {
      const snap = await db.collection(collection).where('businessId', '==', businessId).get();
      for (const doc of snap.docs) {
        await recursiveDeleteSafe(doc.ref);
      }
    } catch (error) {
      console.error('[purgeBusinessCompletely] root collection cleanup failed', businessId, collection, error);
    }
  }

  await cleanupDeletedBusinessReferences(businessId);
  await recursiveDeleteSafe(businessRef);
}

async function purgeUserCompletely(userId) {
  const userRef = db.collection('users').doc(userId);
  const workerRef = db.collection('workers').doc(userId);

  await recursiveDeleteSafe(userRef).catch((error) => {
    console.error('[purgeUserCompletely] failed to delete user doc', userId, error);
  });
  await recursiveDeleteSafe(workerRef).catch((error) => {
    console.error('[purgeUserCompletely] failed to delete worker doc', userId, error);
  });

  try {
    await admin.auth().deleteUser(userId);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      console.error('[purgeUserCompletely] failed to delete auth user', userId, error);
    }
  }
}

async function deleteWorkerCompletely(workerId, actorId) {
  console.log('[deleteWorkerCompletely] Starting deletion of worker', workerId, 'by', actorId);

  const workerRef = db.collection('workers').doc(workerId);
  const userRef = db.collection('users').doc(workerId);

  const workerSnap = await workerRef.get();
  const userSnap = await userRef.get();
  if (!workerSnap.exists && !userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Worker not found');
  }

  const workerData = workerSnap.data() || {};
  const userData = userSnap.data() || {};
  const mergedWorkerData = { ...workerData, ...userData };
  const businessId = mergedWorkerData.businessId;

  // Verify the actor has permission (is owner of the business)
  if (businessId) {
    const businessRef = db.collection('businesses').doc(businessId);
    const businessSnap = await businessRef.get();
    if (businessSnap.exists) {
      const businessData = businessSnap.data() || {};
      const ownerId = businessData.ownerId;
      const ownerIds = Array.isArray(businessData.ownerIds) ? businessData.ownerIds : [];

      console.log('[deleteWorkerCompletely] permission check', {
        workerId,
        actorId,
        businessId,
        ownerId,
        ownerIdsCount: ownerIds.length,
      });

      if (ownerId !== actorId && !ownerIds.includes(actorId)) {
        throw new functions.https.HttpsError('permission-denied', 'Only business owners can delete workers');
      }
    }
  }

  const authUid = (mergedWorkerData.authUid || mergedWorkerData.uid || workerId || '').toString().trim();
  const workerEmail = (mergedWorkerData.email || userData.email || workerData.email || '').toString().trim();

  // Delete Firestore documents
  await recursiveDeleteSafe(userRef).catch((error) => {
    console.error('[deleteWorkerCompletely] failed to delete user doc', workerId, error);
  });
  await recursiveDeleteSafe(workerRef).catch((error) => {
    console.error('[deleteWorkerCompletely] failed to delete worker doc', workerId, error);
  });

  // Delete Firebase Auth user. Some legacy worker documents use a synthetic
  // Firestore id instead of the Firebase Auth uid, so fall back to email.
  try {
    if (!authUid) {
      console.log('[deleteWorkerCompletely] No auth uid available, skipping direct auth deletion', workerId);
      return { success: true };
    }

    await admin.auth().deleteUser(authUid);
    console.log('[deleteWorkerCompletely] Successfully deleted auth user', authUid);
  } catch (error) {
    if (error.code === 'auth/user-not-found' || error.code === 'auth/invalid-uid') {
      if (workerEmail) {
        try {
          const userRecord = await admin.auth().getUserByEmail(workerEmail);
          await admin.auth().deleteUser(userRecord.uid);
          console.log('[deleteWorkerCompletely] Successfully deleted auth user by email', workerEmail, userRecord.uid);
          await recursiveDeleteSafe(db.collection('users').doc(userRecord.uid)).catch((err) => {
            console.error('[deleteWorkerCompletely] failed to delete fallback user doc', userRecord.uid, err);
          });
          await recursiveDeleteSafe(db.collection('workers').doc(userRecord.uid)).catch((err) => {
            console.error('[deleteWorkerCompletely] failed to delete fallback worker doc', userRecord.uid, err);
          });
          return { success: true };
        } catch (emailError) {
          if (
            emailError.code !== 'auth/user-not-found' &&
            emailError.code !== 'auth/invalid-email'
          ) {
            console.error('[deleteWorkerCompletely] failed to lookup auth user by email', workerEmail, emailError);
            throw new functions.https.HttpsError('internal', 'Failed to delete user authentication');
          }
        }
      }
      console.log('[deleteWorkerCompletely] Auth user not found for workerId or email, skipping auth deletion', {
        workerId,
        authUid,
        workerEmail,
      });
      return { success: true };
    }

    console.error('[deleteWorkerCompletely] failed to delete auth user', workerId, error);
    throw new functions.https.HttpsError('internal', 'Failed to delete user authentication');
  }

  return { success: true };
}

exports.deleteWorkerCompletely = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const workerId = data.workerId;
  if (!workerId || typeof workerId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'workerId is required');
  }

  const actorId = context.auth.uid;

  try {
    return await deleteWorkerCompletely(workerId, actorId);
  } catch (error) {
    console.error('[deleteWorkerCompletely] Error:', error);
    const knownCodes = [
      'invalid-argument',
      'failed-precondition',
      'out-of-range',
      'unauthenticated',
      'permission-denied',
      'not-found',
      'aborted',
      'already-exists',
      'resource-exhausted',
      'cancelled',
      'data-loss',
      'unknown',
      'internal',
      'unavailable',
      'deadline-exceeded',
    ];
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    if (typeof error?.code === 'string' && knownCodes.includes(error.code)) {
      throw new functions.https.HttpsError(
        error.code,
        error.message || 'Delete worker failed',
        error.details || null
      );
    }
    throw new functions.https.HttpsError('internal', 'Failed to delete worker');
  }
});

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

exports.syncDeletedUserAuthState = functions.firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const shouldDisable =
      after.isDeleted === true &&
      (after.deletedByType || '').toString() === 'admin';
    const wasDisabled =
      before.isDeleted === true &&
      (before.deletedByType || '').toString() === 'admin';

    if (shouldDisable === wasDisabled) {
      return null;
    }

    try {
      await admin.auth().updateUser(context.params.userId, {
        disabled: shouldDisable,
      });
    } catch (error) {
      if (error.code !== 'auth/user-not-found') {
        console.error('[syncDeletedUserAuthState] failed for', context.params.userId, error);
      }
    }

    return null;
  });

exports.purgeExpiredDeletedRecords = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Africa/Lagos')
  .onRun(async () => {
    const now = new Date();
    const cutoff = new Date(now.getTime() - GRACE_WINDOW_DAYS * 24 * 60 * 60 * 1000);

    const expiredBusinesses = await db
      .collection('businesses')
      .where('isDeleted', '==', true)
      .get();

    for (const doc of expiredBusinesses.docs) {
      const data = doc.data() || {};
      const recoveryDeadline = parseFirestoreDate(data.recoveryDeadlineAt);
      const deletedAt = parseFirestoreDate(data.deletedAt);
      const effectiveDeadline =
        recoveryDeadline ||
        (deletedAt ? new Date(deletedAt.getTime() + GRACE_WINDOW_DAYS * 24 * 60 * 60 * 1000) : null);

      if (!effectiveDeadline || effectiveDeadline > now) {
        continue;
      }

      await purgeBusinessCompletely(doc.id);
    }

    const expiredUsers = await db
      .collection('users')
      .where('isDeleted', '==', true)
      .get();

    for (const doc of expiredUsers.docs) {
      const data = doc.data() || {};
      const recoveryDeadline = parseFirestoreDate(data.recoveryDeadlineAt);
      const deletedAt = parseFirestoreDate(data.deletedAt);
      const effectiveDeadline =
        recoveryDeadline ||
        (deletedAt ? new Date(deletedAt.getTime() + GRACE_WINDOW_DAYS * 24 * 60 * 60 * 1000) : null);

      if (!effectiveDeadline || effectiveDeadline > now) {
        continue;
      }

      if (!deletedAt && effectiveDeadline > cutoff) {
        continue;
      }

      await purgeUserCompletely(doc.id);
    }

    return null;
  });
