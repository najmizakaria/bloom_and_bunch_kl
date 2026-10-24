'use strict';
const { createHash } = require('node:crypto');
const d = require('./domain');

// Configuration is supplied by the composition layer, not read by the domain.
function createStorePolicy(configured) {
  const digest = (value) =>
    createHash('sha256').update(require('./commerce').stableStringify(value)).digest('hex');

  function validate(policy) {
    if (!['demo', 'manual', 'toyyibpay_sandbox'].includes(policy.mode))
      throw Error('Store mode must be demo, manual or toyyibpay_sandbox.');
    if (
      !Number.isSafeInteger(policy.deliveryFeeSen) ||
      policy.deliveryFeeSen < 0 ||
      policy.deliveryFeeSen > 100000
    )
      throw Error('Invalid delivery fee in sen.');
    if (
      typeof policy.paymentInstructions !== 'string' ||
      !policy.paymentInstructions.trim() ||
      policy.paymentInstructions.length > 1000
    )
      throw Error('Payment instructions required.');
    if (
      !Array.isArray(policy.operatingWeekdays) ||
      !policy.operatingWeekdays.length ||
      policy.operatingWeekdays.some((n) => !Number.isInteger(n) || n < 0 || n > 6)
    )
      throw Error('Invalid operating weekdays.');
    if (
      !Number.isInteger(policy.openingHour) ||
      !Number.isInteger(policy.cutoffHour) ||
      policy.openingHour < 0 ||
      policy.cutoffHour > 24 ||
      policy.openingHour >= policy.cutoffHour
    )
      throw Error('Invalid opening/cutoff hours.');
    if (
      !Array.isArray(policy.holidays) ||
      policy.holidays.length > 366 ||
      policy.holidays.some(
        (s) =>
          typeof s !== 'string' ||
          !/^\d{4}-\d{2}-\d{2}$/.test(s) ||
          Number.isNaN(Date.parse(s)) ||
          new Date(s).toISOString().slice(0, 10) !== s,
      )
    )
      throw Error('Invalid holiday dates.');
    if (
      !Number.isSafeInteger(policy.dailyDeliveryCapacity) ||
      policy.dailyDeliveryCapacity < 0 ||
      policy.dailyDeliveryCapacity > 10000
    )
      throw Error('Invalid delivery capacity.');
    if (
      !Number.isInteger(policy.bookingWindowDays ?? 90) ||
      (policy.bookingWindowDays ?? 90) < 7 ||
      (policy.bookingWindowDays ?? 90) > 365
    )
      throw Error('Booking window must be 7–365 days.');
    const a = policy.serviceArea;
    if (
      a != null &&
      (!Number.isFinite(a.latitude) ||
        Math.abs(a.latitude) > 90 ||
        !Number.isFinite(a.longitude) ||
        Math.abs(a.longitude) > 180 ||
        !Number.isFinite(a.radiusKm) ||
        a.radiusKm <= 0 ||
        a.radiusKm > 200 ||
        typeof a.label !== 'string' ||
        !a.label.trim() ||
        a.label.length > 120)
    )
      throw Error('Invalid delivery service area.');
    if (policy.mode === 'manual' && (!a || policy.dailyDeliveryCapacity < 1))
      throw Error('Live manual orders require a service area and daily capacity.');
    return policy;
  }
  function distanceKm(a, b) {
    const rad = (n) => (n * Math.PI) / 180;
    const x =
      Math.sin(rad(b.latitude - a.latitude) / 2) ** 2 +
      Math.cos(rad(a.latitude)) *
        Math.cos(rad(b.latitude)) *
        Math.sin(rad(b.longitude - a.longitude) / 2) ** 2;
    return 6371 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(Math.max(0, 1 - x)));
  }
  function dateFor(now, lead, policy) {
    const local = new Date(now.getTime() + 8 * 3600000);
    const cutoffPassed = local.getUTCHours() >= policy.cutoffHour;
    local.setUTCHours(0, 0, 0, 0);
    const open = () =>
      policy.operatingWeekdays.includes(local.getUTCDay()) &&
      !policy.holidays.includes(local.toISOString().slice(0, 10));
    if (cutoffPassed) local.setUTCDate(local.getUTCDate() + 1);
    while (!open()) local.setUTCDate(local.getUTCDate() + 1);
    while (lead > 0) {
      local.setUTCDate(local.getUTCDate() + 1);
      if (open()) lead--;
    }
    return local.toISOString().slice(0, 10);
  }
  function availableDates(now, lead, policy = configured) {
    validate(policy);
    const first = dateFor(now, lead, policy);
    const last = new Date(now.getTime() + 8 * 3600000 + (policy.bookingWindowDays ?? 90) * 86400000)
      .toISOString()
      .slice(0, 10);
    const dates = [];
    for (
      let day = new Date(first);
      day.toISOString().slice(0, 10) <= last;
      day.setUTCDate(day.getUTCDate() + 1)
    ) {
      const iso = day.toISOString().slice(0, 10);
      if (policy.operatingWeekdays.includes(day.getUTCDay()) && !policy.holidays.includes(iso))
        dates.push(iso);
    }
    return dates;
  }
  function quote(plan, address, now = new Date(), policy = configured, options = {}) {
    validate(policy);
    if (!Number.isFinite(address.latitude) || !Number.isFinite(address.longitude))
      d.fail('Confirm your delivery pin before continuing.', 'failed-precondition');
    if (policy.serviceArea && distanceKm(policy.serviceArea, address) > policy.serviceArea.radiusKm)
      d.fail(
        'This address is outside our delivery area. Choose another address or contact the store.',
        'failed-precondition',
      );
    const commerce = require('./commerce'),
      buckets = new Map(),
      groups = [];
    const selectedCards = options.messageCards ?? {};
    for (const item of [
      ...plan.ready.map((i) => ({ fulfillmentType: 'ready_now', ...i })),
      ...plan.planned.map((i) => ({
        fulfillmentType: 'pre_order',
        leadTimeBusinessDays: plan.lead,
        ...i,
      })),
      ...(plan.addons ?? []),
    ]) {
      const planned = item.type !== 'addon' && item.fulfillmentType !== 'ready_now';
      if (planned && options.requireDates && !item.requestedDeliveryDate)
        d.fail(
          'Choose a delivery date for every pre-order and custom bouquet.',
          'failed-precondition',
        );
      const key = commerce.groupKey(item);
      if (
        item.requestedDeliveryDate &&
        !availableDates(now, planned ? Math.max(2, item.leadTimeBusinessDays) : 0, policy).includes(
          item.requestedDeliveryDate,
        )
      )
        d.fail(
          'A selected delivery date is no longer available. Choose another date.',
          'failed-precondition',
        );
      const bucket = buckets.get(key) ?? [];
      bucket.push(item);
      buckets.set(key, bucket);
    }
    for (const [key, items] of buckets) {
      if (items.every((i) => i.type === 'addon'))
        d.fail('Add-ons must accompany a bouquet in the same delivery.', 'failed-precondition');
      const prepared = items.filter((i) => i.type !== 'addon' && i.fulfillmentType !== 'ready_now');
      const kind = prepared.length ? 'planned' : 'ready_now';
      const lead = prepared.reduce((n, i) => Math.max(n, i.leadTimeBusinessDays ?? plan.lead), 0);
      const selectedDate = /^\d{4}/.test(key) ? key : dateFor(now, lead, policy);
      const subtotalSen = items.reduce((sum, i) => sum + d.money(i.unitPrice) * i.quantity, 0);
      const messageCard = selectedCards[key] ?? null,
        cardFeeSen = messageCard ? d.money(messageCard.price) : 0;
      groups.push({
        key,
        kind,
        items,
        date: selectedDate,
        scheduled: /^\d{4}/.test(key),
        messageCard,
        cardFeeSen,
        subtotalSen,
        deliveryFeeSen: 0,
        totalSen: subtotalSen + cardFeeSen,
      });
    }
    if (Object.keys(selectedCards).some((key) => !buckets.has(key)))
      d.fail('A message card belongs to a removed delivery. Review your cart.');
    const result = {
      mode: policy.mode,
      paymentInstructions:
        policy.mode === 'toyyibpay_sandbox'
          ? 'Test payments only. Complete ToyyibPay sandbox payment before preparation or delivery. Unpaid reservations expire after 30 minutes.'
          : policy.paymentInstructions,
      areaLabel: policy.serviceArea?.label ?? 'Store delivery area',
      openingHour: policy.openingHour,
      cutoffHour: policy.cutoffHour,
      groups,
      subtotalSen: groups.reduce((n, g) => n + g.subtotalSen, 0),
      deliveryFeeSen: groups.reduce((n, g) => n + g.deliveryFeeSen, 0),
      totalSen: groups.reduce((n, g) => n + g.totalSen, 0),
      cardFeeSen: groups.reduce((n, g) => n + g.cardFeeSen, 0),
      timingNotice:
        'Estimated dispatch dates, not guaranteed arrival times. Delivery depends on preparation and rider availability.',
    };
    return {
      ...result,
      quoteId: digest({ result, address, items: [...plan.ready, ...plan.planned], policy }),
    };
  }
  return { configured, validate, distanceKm, dateFor, availableDates, quote };
}

module.exports = { createStorePolicy };
