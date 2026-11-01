'use strict';
const payments = require('../../domain/payments');
const commerce = require('../../domain/commerce');
const deliveryPreview = require('../../domain/delivery-preview');
const { deliveryEligible } = require('../../domain/delivery');

function createDeliveryJobWriter({ db, FieldValue }) {
  function writeAvailableJob(tx, orderId, order) {
    const ref = db.collection('delivery_jobs').doc(orderId);
    tx.set(db.doc('delivery_queue/current'), { updatedAt: FieldValue.serverTimestamp(), revision: FieldValue.increment(1) });
    if (order?.orderStatus !== 'Ready for Delivery' || !deliveryEligible(order) || payments.requiresPayment(order) || !commerce.due(order)) {
      tx.delete(ref);
      return;
    }
    tx.set(ref, {
      orderId,
      orderStatus: 'Ready for Delivery',
      riderId: null,
      ...deliveryPreview.preview(order),
      deliveryTimeSlot: order.deliveryTimeSlot ?? '',
      previewVersion: 3,
      requestedDeliveryDate: order.requestedDeliveryDate ?? null,
      hasValidAddress: true,
      hasValidCoordinates: true,
      createdAt: order.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  return writeAvailableJob;
}

module.exports = { createDeliveryJobWriter };
