'use strict';
const d = require('../domain/domain');
const { createHash } = require('node:crypto');

function createNotificationHandlers({ db, getMessaging, FieldValue, Timestamp, Filter }) {
  const pushAdminAlert = async (event) => {
    if (
      process.env.FUNCTIONS_EMULATOR === 'true' &&
      process.env.GCLOUD_PROJECT?.startsWith('demo-')
    )
      return;
    const alert = event.data?.data();
    if (!alert) return;
    const marker = db.doc('admin_notification_events/' + event.params.id);
    const acquired = await db.runTransaction(async (tx) => {
      const old = await tx.get(marker);
      if (old.data()?.state === 'sent') return false;
      if (old.data()?.leaseUntil?.toMillis() > Date.now())
        d.fail('Alert delivery is in progress.', 'unavailable');
      tx.set(marker, { state: 'sending', leaseUntil: Timestamp.fromMillis(Date.now() + 60000) });
      return true;
    });
    if (!acquired) return;
    try {
      const administrators = await db
        .collection('users')
        .where(
          Filter.or(
            Filter.where('role', '==', 'admin'),
            Filter.where('roles', 'array-contains', 'admin'),
          ),
        )
        .get();
      for (const admin of administrators.docs) {
        const p = admin.data();
        if (p.accountSuspended || p.deletionPending || p.notificationsEnabled !== true) continue;
        const preference = await db.doc('admin_preferences/' + admin.id).get();
        if (preference.data()?.[alert.kind] === false) continue;
        const devices = await db
          .collection('notification_devices')
          .where('uid', '==', admin.id)
          .limit(20)
          .get();
        if (devices.empty) continue;
        const result = await getMessaging().sendEachForMulticast({
          tokens: devices.docs.map((d) => d.data().token),
          notification: { title: 'Bloom & Bunch admin', body: alert.title },
          data: { adminAlertId: event.params.id, adminUid: admin.id },
          webpush: { notification: { tag: event.params.id } },
        });
        for (let i = 0; i < result.responses.length; i++) {
          const code = result.responses[i].error?.code;
          if (
            [
              'messaging/registration-token-not-registered',
              'messaging/invalid-registration-token',
            ].includes(code)
          )
            await devices.docs[i].ref.delete();
          else if (code) throw new Error('Admin alert delivery needs retry.');
        }
      }
      await marker.set({ state: 'sent', sentAt: FieldValue.serverTimestamp() });
    } catch (e) {
      await marker.set({ state: 'pending' });
      throw e;
    }
  };

  const updateNotificationSettings = async (req) => {
    const enabled = req.data?.enabled,
      token = req.data?.token;
    if (typeof enabled !== 'boolean') d.fail('Invalid notification preference.');
    if (enabled && (typeof token !== 'string' || token.length < 10 || token.length > 4096))
      d.fail('Allow notifications on this device first.');
    if (token != null && (typeof token !== 'string' || token.length > 4096))
      d.fail('Invalid device token.');
    const ref = db.doc(`users/${req.auth.uid}`);
    await db.runTransaction(async (tx) => {
      const profile = await tx.get(ref);
      if (!profile.exists || profile.data().deletionPending)
        d.fail('Your profile is unavailable.', 'failed-precondition');
      const devices = await tx.get(
        db.collection('notification_devices').where('uid', '==', req.auth.uid),
      );
      const device = token
        ? db.doc(`notification_devices/${createHash('sha256').update(token).digest('hex')}`)
        : null;
      const existing = device ? await tx.get(device) : null;
      if (
        enabled &&
        devices.size >= 20 &&
        !devices.docs.some((doc) => doc.ref.path === device.path)
      ) {
        const oldest = devices.docs.sort(
          (a, b) => (a.data().updatedAt?.toMillis() ?? 0) - (b.data().updatedAt?.toMillis() ?? 0),
        )[0];
        tx.delete(oldest.ref);
      }
      if (device) {
        if (enabled)
          tx.set(device, { uid: req.auth.uid, token, updatedAt: FieldValue.serverTimestamp() });
        else if (existing.data()?.uid === req.auth.uid) tx.delete(device);
      }
      tx.update(ref, { notificationsEnabled: enabled, updatedAt: FieldValue.serverTimestamp() });
    });
    return { enabled };
  };

  const unregisterNotificationDevice = async (req) => {
    const token = d.text(req.data?.token, 'device token', 4096),
      ref = db.doc(`notification_devices/${createHash('sha256').update(token).digest('hex')}`);
    await db.runTransaction(async (tx) => {
      const device = await tx.get(ref);
      if (device.data()?.uid === req.auth.uid) tx.delete(ref);
    });
    return { removed: true };
  };

  const notifyOrderStatus = async (event) => {
    if (
      process.env.FUNCTIONS_EMULATOR === 'true' &&
      process.env.GCLOUD_PROJECT?.startsWith('demo-')
    )
      return;
    const before = event.data?.before.data(),
      order = event.data?.after.data();
    if (
      !order ||
      before?.orderStatus === order.orderStatus ||
      !order.customerId ||
      order.customerId.startsWith('deleted_')
    )
      return;
    const profile = await db.doc(`users/${order.customerId}`).get();
    if (profile.data()?.notificationsEnabled !== true || profile.data()?.deletionPending) return;
    const devices = await db
      .collection('notification_devices')
      .where('uid', '==', order.customerId)
      .get();
    if (devices.empty) return;
    const marker = db.doc(
      `notification_events/${createHash('sha256').update(event.id).digest('hex')}`,
    );
    const acquired = await db.runTransaction(async (tx) => {
      const current = await tx.get(marker),
        state = current.data();
      if (state?.status === 'sent') return false;
      if (state?.leaseUntil?.toMillis() > Date.now())
        d.fail('Notification delivery is already in progress.', 'unavailable');
      tx.set(marker, { status: 'sending', leaseUntil: Timestamp.fromMillis(Date.now() + 60000) });
      return true;
    });
    if (!acquired) return;
    try {
      const result = await getMessaging().sendEachForMulticast({
        tokens: devices.docs.map((doc) => doc.data().token),
        notification: {
          title: 'Bloom & Bunch order update',
          body: `Your order is now ${order.orderStatus}.`,
        },
        data: { orderId: event.params.orderId, customerId: order.customerId },
        android: { collapseKey: event.params.orderId },
        webpush: { notification: { tag: event.params.orderId } },
        apns: { headers: { 'apns-collapse-id': event.params.orderId } },
      });
      let retry = false;
      for (let i = 0; i < result.responses.length; i++) {
        const code = result.responses[i].error?.code;
        if (
          [
            'messaging/registration-token-not-registered',
            'messaging/invalid-registration-token',
          ].includes(code)
        )
          await devices.docs[i].ref.delete();
        else if (code) retry = true;
      }
      if (retry) throw new Error('Some notifications need retry.');
      await marker.set({ status: 'sent', sentAt: FieldValue.serverTimestamp() });
    } catch (error) {
      await marker.set({ status: 'pending' });
      throw error;
    }
  };

  return {
    pushAdminAlert,
    updateNotificationSettings,
    unregisterNotificationDevice,
    notifyOrderStatus,
  };
}

module.exports = { createNotificationHandlers };
