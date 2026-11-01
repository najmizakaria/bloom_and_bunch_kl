'use strict';
const d = require('../domain/domain');

function createAccountHandlers({ db, getAuth, FieldValue }) {
  const activeStatuses = [
    'Pending',
    'Awaiting Preparation',
    'Processing',
    'Ready for Delivery',
    'Rider assigned',
    'Out for Delivery',
    'Awaiting Customer Confirmation',
  ];
  async function processAccountDeletion(uid) {
    const task = db.doc(`account_deletions/${uid}`);
    if ((await task.get()).data()?.status === 'completed') return;
    // An Auth error must never remove a profile that is still needed for login.
    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    for (const field of ['customerId', 'riderId', 'floristId']) {
      const orders = await db.collection('orders').where(field, '==', uid).get();
      for (let i = 0; i < orders.docs.length; i += 400) {
        const batch = db.batch();
        for (const order of orders.docs.slice(i, i + 400)) {
          const updates = { [field]: `deleted_${field}`, updatedAt: FieldValue.serverTimestamp() };
          if (field === 'customerId')
            Object.assign(updates, {
              recipientName: 'Deleted customer',
              recipientPhone: '',
              deliveryAddress: '',
              deliveryNote: '',
              deliveryLocality: '',
              deliveryPostcode: '',
              deliveryState: '',
              latitude: null,
              longitude: null,
              addressId: null,
              items: (order.data().items ?? []).map((item) => ({ ...item, cardNote: '' })),
              messageCard: FieldValue.delete(),
              feedback: FieldValue.delete(),
              support: FieldValue.delete(),
            });
          if (field === 'riderId') updates.riderName = FieldValue.delete();
          if (field === 'riderId' && order.data().support?.reportedBy === 'rider')
            updates.support = FieldValue.delete();
          batch.update(order.ref, updates);
        }
        // Remove private issue text before anonymizing the lookup field, so a retry
        // can still find the order if recursive deletion fails partway through.
        if (field === 'customerId')
          for (const order of orders.docs.slice(i, i + 400)) {
            await db.recursiveDelete(order.ref.collection('issues'));
            await db.recursiveDelete(order.ref.collection('assignment_events'));
          }
        await batch.commit();
      }
    }
    const paymentRecords = await db.collection('payments').where('customerId', '==', uid).get();
    for (let i = 0; i < paymentRecords.docs.length; i += 400) {
      const batch = db.batch();
      for (const record of paymentRecords.docs.slice(i, i + 400))
        batch.update(record.ref, {
          customerId: 'deleted_customer',
          checkoutId: FieldValue.delete(),
        });
      await batch.commit();
    }
    const devices = await db.collection('notification_devices').where('uid', '==', uid).get();
    for (const device of devices.docs) await device.ref.delete();
    await db.doc('rider_locations/' + uid).delete();
    await db.doc('admin_preferences/' + uid).delete();
    await db.recursiveDelete(db.doc(`users/${uid}`));
    await db.doc(`rider_applications/${uid}`).delete();
    await task.set(
      { status: 'completed', completedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }

  const deleteAccount = async (req) => {
    const authTime = req.auth.token?.auth_time;
    if (
      !Number.isFinite(authTime) ||
      Date.now() / 1000 - authTime > 300 ||
      authTime > Date.now() / 1000 + 60
    )
      d.fail('Sign in again before deleting your account.', 'failed-precondition');
    const uid = req.auth.uid,
      userRef = db.doc(`users/${uid}`),
      task = db.doc(`account_deletions/${uid}`);
    await db.runTransaction(async (tx) => {
      const profile = await tx.get(userRef),
        previous = await tx.get(task);
      if (previous.exists) return;
      if (!profile.exists) d.fail('Profile no longer exists.', 'not-found');
      const customerOrders = await tx.get(
        db
          .collection('orders')
          .where('customerId', '==', uid)
          .where('orderStatus', 'in', activeStatuses)
          .limit(1),
      );
      const riderOrders = await tx.get(
        db
          .collection('orders')
          .where('riderId', '==', uid)
          .where('orderStatus', 'in', ['Rider assigned', 'Out for Delivery', 'Awaiting Customer Confirmation'])
          .limit(1),
      );
      if (!customerOrders.empty || !riderOrders.empty)
        d.fail(
          'Complete your active orders or deliveries before deleting your account.',
          'failed-precondition',
        );
      tx.update(userRef, { deletionPending: true, updatedAt: FieldValue.serverTimestamp() });
      tx.create(task, { status: 'pending', requestedAt: FieldValue.serverTimestamp() });
    });
    await processAccountDeletion(uid);
    return { deleted: true };
  };

  const finishAccountDeletion = (event) => processAccountDeletion(event.params.uid);

  return { deleteAccount, finishAccountDeletion };
}

module.exports = { createAccountHandlers };
