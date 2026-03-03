import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

/**
 * Callable function to create a booking with server-side overlap check.
 * Expects:
 * {
 *   businessId: string,
 *   booking: { unitId, apartmentId, tenantId, checkInDate, checkOutDate, nights, guests, subtotal, depositAmount, total, policySnapshot }
 * }
 */
export const createBooking = functions.https.onCall(async (data: any, context: functions.https.CallableContext) => {
  const { businessId, booking } = data;
  if (!businessId || !booking) throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');

  const bookingsRef = db.collection('businesses').doc(businessId).collection('bookings');

  return await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    const qSnap = await tx.get(bookingsRef.where('unitId', '==', booking.unitId));

    for (const doc of qSnap.docs) {
      const existing = doc.data();
      const a = existing.checkInDate?.toDate ? existing.checkInDate.toDate() : new Date(existing.checkInDate);
      const b = existing.checkOutDate?.toDate ? existing.checkOutDate.toDate() : new Date(existing.checkOutDate);
      const status = existing.status || 'pending';

      if (['pending', 'confirmed', 'checkedIn'].includes(status) && (new Date(booking.checkInDate) < b && new Date(booking.checkOutDate) > a)) {
        throw new functions.https.HttpsError('failed-precondition', 'Requested dates overlap with an existing booking');
      }
    }

    const newDocRef = bookingsRef.doc();
    const now = admin.firestore.Timestamp.now();

    const payload = {
      unitId: booking.unitId,
      apartmentId: booking.apartmentId,
      tenantId: booking.tenantId,
      checkInDate: admin.firestore.Timestamp.fromDate(new Date(booking.checkInDate)),
      checkOutDate: admin.firestore.Timestamp.fromDate(new Date(booking.checkOutDate)),
      nights: booking.nights || 0,
      guests: booking.guests || 1,
      status: booking.status || 'pending',
      createdAt: now,
      subtotal: booking.subtotal || 0.0,
      depositAmount: booking.depositAmount || 0.0,
      discount: booking.discount || 0.0,
      total: booking.total || 0.0,
      currency: booking.currency || '₦',
      paymentStatus: booking.paymentStatus || 'none',
      policySnapshot: booking.policySnapshot || {},
      nextReminderAt: booking.nextReminderAt ? admin.firestore.Timestamp.fromDate(new Date(booking.nextReminderAt)) : null,
    };

    tx.set(newDocRef, payload);

    return { bookingId: newDocRef.id };
  });
});
