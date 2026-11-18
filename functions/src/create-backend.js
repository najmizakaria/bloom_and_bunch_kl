'use strict';

const {
  FieldValue,
  Timestamp,
  FieldPath,
  Filter,
  AggregateField,
} = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');
const { defineBoolean, defineString, defineSecret } = require('firebase-functions/params');
const { hasRole } = require('./domain/authorization');
const { deliveryEligible } = require('./domain/delivery');
const d = require('./domain/domain');
const storePolicy = require('../store-policy');
const toyyibpay = require('./infrastructure/payments/toyyibpay');
const { createStripeGateway } = require('./infrastructure/payments/stripe');
const { MODE, STRIPE_MODE, STRIPE_LIVE_MODE } = require('./domain/payments');
const { createCheckoutReader } = require('./infrastructure/firebase/checkout-reader');
const { createDeliveryJobWriter } = require('./infrastructure/firebase/delivery-jobs');
const { createCallable } = require('./presentation/callable');
const { registerFunctions } = require('./presentation/register-functions');
const { createCheckoutHandlers } = require('./application/checkout');
const { createFulfillmentHandlers } = require('./application/fulfillment');
const { createCatalogHandlers } = require('./application/catalog');
const { createAddressHandlers } = require('./application/addresses');
const { createSupportHandlers } = require('./application/support');
const { createRiderHandlers } = require('./application/riders');
const { createContactHandler } = require('./application/rider-contact');
const { createAccountHandlers } = require('./application/accounts');
const { createNotificationHandlers } = require('./application/notifications');
const { createAdminEventHandlers } = require('./application/admin-events');
const { createAdminHandlers } = require('./application/admin');
const { createHandlers: createCommerceHandlers } = require('./application/commerce');
const { createPaymentHandlers } = require('./application/payments');

// The composition root is the only place that assembles runtime dependencies.
// Factories do not initialize Firebase, register endpoints, or perform network I/O.
function createBackend({ db }) {
  const paymentEnabled = defineBoolean('TOYYIBPAY_ENABLED', { default: false });
  const paymentCategory = defineString('TOYYIBPAY_SANDBOX_CATEGORY_CODE', { default: '' });
  const paymentReturnUrl = defineString('TOYYIBPAY_RETURN_URL', { default: '' });
  const paymentSecret = defineSecret('TOYYIBPAY_SANDBOX_SECRET_KEY');
  const stripeSecret = defineSecret('STRIPE_SANDBOX_SECRET_KEY');
  const stripeWebhookSecret = defineSecret('STRIPE_SANDBOX_WEBHOOK_SECRET');
  const stripeLiveSecret = defineSecret('STRIPE_LIVE_SECRET_KEY');
  const stripeLiveWebhookSecret = defineSecret('STRIPE_LIVE_WEBHOOK_SECRET');
  const stripeLiveEnabled = process.env.STRIPE_LIVE_ENABLED === 'true' && process.env.FUNCTIONS_EMULATOR !== 'true';
  const stripeLiveReturnUrl = 'https://bloomandbunchkl.com/payment-return.html';
  const stripeConfiguration = defineString('STRIPE_SANDBOX_PAYMENT_METHOD_CONFIGURATION', { default: '' });
  const stripeReturnUrl = defineString('STRIPE_SANDBOX_RETURN_URL', {
    default: 'https://bloomandbunchkl.com/payment-return.html',
  });
  const options = {
    region: 'asia-southeast1',
    maxInstances: 10,
    invoker: 'public',
    enforceAppCheck: process.env.ENFORCE_APP_CHECK === 'true',
  };

  function assertPaymentsEnabled(mode = MODE) {
    if (mode === STRIPE_LIVE_MODE) {
      if (!stripeLiveEnabled) d.fail('Live Stripe Checkout is not enabled.', 'failed-precondition');
      return;
    }
    if (mode === STRIPE_MODE) {
      if (!/^pmc_[A-Za-z0-9]+$/.test(stripeConfiguration.value()) ||
          !/^https:\/\//.test(stripeReturnUrl.value()))
        d.fail('Stripe sandbox checkout is not configured.', 'failed-precondition');
      return;
    }
    if (
      !paymentEnabled.value() ||
      !paymentCategory.value() ||
      !/^https:\/\//.test(paymentReturnUrl.value())
    )
      d.fail(
        'Online payment is not available yet. Please contact the store.',
        'failed-precondition',
      );
  }

  const readers = createCheckoutReader({ db, storePolicy });
  const writeAvailableJob = createDeliveryJobWriter({ db, FieldValue });
  const checkout = createCheckoutHandlers({
    db,
    hasRole,
    ...readers,
    deliveryEligible,
    storePolicy,
    assertPaymentsEnabled,
    FieldValue,
    Timestamp,
  });
  const fulfillment = createFulfillmentHandlers({
    db,
    hasRole,
    writeAvailableJob,
    deliveryEligible,
    FieldValue,
    FieldPath,
  });
  const catalog = createCatalogHandlers({ db, hasRole, FieldValue });
  const addresses = createAddressHandlers({ db, FieldValue });
  const support = createSupportHandlers({ db, hasRole, FieldValue, writeAvailableJob });
  const riders = createRiderHandlers({ db, hasRole, FieldValue, FieldPath, Filter });
  const accounts = createAccountHandlers({ db, getAuth, FieldValue });
  const notifications = createNotificationHandlers({
    db,
    getMessaging,
    FieldValue,
    Timestamp,
    Filter,
  });
  const adminEvents = createAdminEventHandlers({ db, FieldValue });
  const admin = createAdminHandlers({
    db,
    auth: getAuth(),
    defaultPolicy: storePolicy.configured,
    FieldValue,
    FieldPath,
    Filter,
    AggregateField,
    Timestamp,
    validatePolicy: storePolicy.validate,
  });
  const commerce = createCommerceHandlers({
    db,
    hasRole,
    readStorePolicy: readers.readStorePolicy,
    FieldValue,
    policyApi: storePolicy,
  });
  const payments = createPaymentHandlers({
    db,
    writeAvailableJob,
    FieldValue,
    Timestamp,
    gatewayApi: toyyibpay,
    notifyReceiptReminder: notifications.notifyReceiptReminder,
    getStripeGateway: (verifyWebhook = false, live = false) => {
      assertPaymentsEnabled(live ? STRIPE_LIVE_MODE : STRIPE_MODE);
      return createStripeGateway({
        live,
        secret: live ? stripeLiveSecret.value() : stripeSecret.value(),
        configuration: stripeConfiguration.value(),
        returnUrl: live ? stripeLiveReturnUrl : stripeReturnUrl.value(),
        ...(verifyWebhook ? { webhookSecret: (live ? stripeLiveWebhookSecret : stripeWebhookSecret).value() } : {}),
      });
    },
    getSecret: () => paymentSecret.value(),
    getGateway: () => {
      assertPaymentsEnabled();
      const secret = paymentSecret.value();
      if (!secret) d.fail('Online payment is not configured yet.', 'failed-precondition');
      const project =
        process.env.GCLOUD_PROJECT ||
        process.env.GOOGLE_CLOUD_PROJECT ||
        JSON.parse(process.env.FIREBASE_CONFIG || '{}').projectId;
      return toyyibpay.createGateway({
        secret,
        categoryCode: paymentCategory.value(),
        returnUrl: paymentReturnUrl.value(),
        callbackUrl: `https://asia-southeast1-${project}.cloudfunctions.net/toyyibpayCallback`,
      });
    },
  });

  return registerFunctions({
    callable: createCallable({ db, options }),
    options,
    paymentEnabled,
    paymentSecret,
    stripeSecret,
    stripeWebhookSecret,
    stripeLiveEnabled,
    stripeLiveSecret,
    stripeLiveWebhookSecret,
    handlers: {
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
      getAssignedRiderContact: createContactHandler({ db, hasRole }),
    },
  });
}

module.exports = { createBackend };
