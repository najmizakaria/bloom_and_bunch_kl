'use strict';
const { createHash } = require('node:crypto');

function createAdminEventHandlers({ db, FieldValue }) {
  async function adminAlert(event, kind, title, orderId = null) {
    const id = createHash('sha256').update(event.id).digest('hex');
    await db
      .doc('admin_alerts/' + id)
      .set({ kind, title, orderId, createdAt: FieldValue.serverTimestamp() });
  }

  const alertAdminOrderCreated = (e) =>
    adminAlert(e, 'orders', 'New order received', e.params.orderId);

  const alertAdminOrderChanged = async (e) => {
    const before = e.data.before.data(),
      after = e.data.after.data();
    if (
      before.orderStatus !== after.orderStatus ||
      before.paymentStatus !== after.paymentStatus ||
      before.support?.status !== after.support?.status
    )
      await adminAlert(
        e,
        'orders',
        after.support?.status === 'open' ? 'Order needs support' : `Order ${after.orderStatus}`,
        e.params.orderId,
      );
  };

  const alertAdminApplication = (e) => adminAlert(e, 'riders', 'New rider application');

  const alertAdminStock = async (e) => {
    const available = (p) => (p.stockQuantity ?? 0) - (p.reservedQuantity ?? 0);
    if (available(e.data.before.data()) > 5 && available(e.data.after.data()) <= 5)
      await adminAlert(e, 'orders', 'Flower stock is running low');
  };

  const auditAdminOrder = async (e) => {
    const a = e.data.before.data(),
      b = e.data.after.data();
    if (
      a.orderStatus === b.orderStatus &&
      a.paymentStatus === b.paymentStatus &&
      a.support?.status === b.support?.status
    )
      return;
    await db
      .doc('admin_audit/' + createHash('sha256').update(e.id).digest('hex'))
      .set({
        actorId: b.updatedBy ?? 'system',
        action: 'order_updated',
        target: e.params.orderId,
        status: b.orderStatus,
        paymentStatus: b.paymentStatus ?? '',
        createdAt: FieldValue.serverTimestamp(),
      });
  };

  return {
    alertAdminOrderCreated,
    alertAdminOrderChanged,
    alertAdminApplication,
    alertAdminStock,
    auditAdminOrder,
  };
}

module.exports = { createAdminEventHandlers };
