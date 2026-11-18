'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');

// Public names and deployment options are part of the existing client contract.
function registerFunctions({ callable, options, paymentEnabled, paymentSecret, stripeSecret, stripeWebhookSecret,
  stripeLiveEnabled, stripeLiveSecret, stripeLiveWebhookSecret, handlers }) {
  const api = {};
  const {
    checkout,
    fulfillment,
    catalog,
    addresses,
    support,
    riders,
    accounts,
    notifications,
    adminEvents,
    admin,
    commerce,
    payments,
    getAssignedRiderContact,
  } = handlers;

  for (const [name, handler] of Object.entries({
    ...checkout,
    ...catalog,
    ...addresses,
    ...support,
    ...riders,
    listAvailableDeliveries: fulfillment.listAvailableDeliveries,
    listAssignableRiders: fulfillment.listAssignableRiders,
    transitionOrder: fulfillment.transitionOrder,
    syncDeliveryJobs: fulfillment.syncDeliveryJobs,
    deleteAccount: accounts.deleteAccount,
    updateNotificationSettings: notifications.updateNotificationSettings,
    unregisterNotificationDevice: notifications.unregisterNotificationDevice,
    ...commerce,
    getAssignedRiderContact,
  }))
    api[name] = callable(handler);

  for (const [name, handler] of Object.entries({
    adminSummary: 'summary',
    adminInventoryAlerts: 'inventoryAlerts',
    adminOrders: 'orders',
    adminPeople: 'people',
    adminCreateStaff: 'createStaff',
    adminUpdateStaff: 'updateStaff',
    adminRiders: 'riders',
    adminSaveRiderContact: 'saveRiderContact',
    publishRiderLocation: 'location',
    saveAdminPreferences: 'preferences',
    adminStorePolicy: 'policy',
    saveAdminStorePolicy: 'savePolicy',
  }))
    api[name] = callable((req) => admin[handler](req));

  const paymentOptions = { secrets: [paymentSecret] };
  const checkoutPaymentOptions = { secrets: [paymentSecret, stripeSecret, ...(stripeLiveEnabled ? [stripeLiveSecret] : [])] };
  api.createToyyibpayPayment = callable((req) => payments.create(req), paymentOptions);
  api.checkToyyibpayPayment = callable((req) => payments.status(req), paymentOptions);
  api.createCheckoutPayment = callable((req) => payments.create(req), checkoutPaymentOptions);
  api.checkCheckoutPayment = callable((req) => payments.status(req), checkoutPaymentOptions);
  api.adminCheckPayment = callable((req) => payments.adminStatus(req), checkoutPaymentOptions);
  function stripeWebhook(secrets, live) {
    return onRequest({ ...options, secrets }, async (req, res) => {
      res.set('Cache-Control', 'no-store');
      if (req.method !== 'POST') {
        res.status(405).send('POST required');
        return;
      }
      try {
        await payments.stripeWebhook(req.rawBody, req.get('stripe-signature'), live);
        res.status(200).send('OK');
      } catch (error) {
        res.status(error.code === 'permission-denied' ? 400 : 503).send('Stripe event not applied');
      }
    });
  }
  api.stripeSandboxWebhook = stripeWebhook([stripeSecret, stripeWebhookSecret], false);
  if (stripeLiveEnabled) api.stripeLiveWebhook = stripeWebhook([stripeLiveSecret, stripeLiveWebhookSecret], true);
  api.toyyibpayCallback = onRequest({ ...options, ...paymentOptions }, async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (req.method !== 'POST') {
      res.status(405).send('POST required');
      return;
    }
    try {
      await payments.callback(req.body);
      res.status(200).send('OK');
    } catch (error) {
      const status =
        error.code === 'permission-denied' ? 403 : error.code === 'invalid-argument' ? 400 : 503;
      res.status(status).send('Payment verification pending or rejected');
    }
  });

  api.expireToyyibpayPayments = onSchedule(
    {
      region: options.region,
      maxInstances: 1,
      ...checkoutPaymentOptions,
      schedule: '* * * * *',
    },
    async () => {
      await payments.sweep({ includeToyyibpay: paymentEnabled.value() });
    },
  );
  api.releaseScheduledDeliveries = onSchedule(
    { region: options.region, maxInstances: 1, schedule: 'every 15 minutes' },
    fulfillment.releaseScheduledDeliveries,
  );

  const created = {
    alertAdminOrderCreated: ['orders/{orderId}', adminEvents.alertAdminOrderCreated],
    alertAdminApplication: ['rider_applications/{uid}', adminEvents.alertAdminApplication],
    finishAccountDeletion: ['account_deletions/{uid}', accounts.finishAccountDeletion],
    pushAdminAlert: ['admin_alerts/{id}', notifications.pushAdminAlert],
  };
  const updated = {
    alertAdminOrderChanged: ['orders/{orderId}', adminEvents.alertAdminOrderChanged],
    alertAdminStock: ['flowers/{id}', adminEvents.alertAdminStock],
    auditAdminOrder: ['orders/{orderId}', adminEvents.auditAdminOrder],
    notifyOrderStatus: ['orders/{orderId}', notifications.notifyOrderStatus],
  };
  for (const [name, [document, handler]] of Object.entries(created))
    api[name] = onDocumentCreated({ document, region: 'asia-southeast1', retry: true }, handler);
  for (const [name, [document, handler]] of Object.entries(updated))
    api[name] = onDocumentUpdated({ document, region: 'asia-southeast1', retry: true }, handler);
  return api;
}

module.exports = { registerFunctions };
