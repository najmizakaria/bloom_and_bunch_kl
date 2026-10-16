'use strict';
const {createHash} = require('node:crypto');
const d = require('./domain');
const configured = {...require('./store-policy.json')};
// Deployment-specific activation belongs in the backend environment. Keep the
// checked-in policy usable by isolated demo tests and fresh installations.
if (process.env.STORE_ORDER_MODE) configured.mode = process.env.STORE_ORDER_MODE;
const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');

function validate(policy) {
  if (!['demo', 'manual', 'toyyibpay_sandbox'].includes(policy.mode)) throw Error('Store mode must be demo, manual or toyyibpay_sandbox.');
  if (!Number.isSafeInteger(policy.deliveryFeeSen) || policy.deliveryFeeSen < 0 || policy.deliveryFeeSen > 100000) throw Error('Invalid delivery fee in sen.');
  if (typeof policy.paymentInstructions !== 'string' || !policy.paymentInstructions.trim() || policy.paymentInstructions.length > 1000) throw Error('Payment instructions required.');
  if (!Array.isArray(policy.operatingWeekdays) || !policy.operatingWeekdays.length || policy.operatingWeekdays.some(n => !Number.isInteger(n) || n < 0 || n > 6)) throw Error('Invalid operating weekdays.');
  if (!Number.isInteger(policy.openingHour) || !Number.isInteger(policy.cutoffHour) || policy.openingHour < 0 || policy.cutoffHour > 24 || policy.openingHour >= policy.cutoffHour) throw Error('Invalid opening/cutoff hours.');
  if (!Array.isArray(policy.holidays) || policy.holidays.length > 366 || policy.holidays.some(s => typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s) || Number.isNaN(Date.parse(s)) || new Date(s).toISOString().slice(0, 10) !== s)) throw Error('Invalid holiday dates.');
  if (!Number.isSafeInteger(policy.dailyDeliveryCapacity) || policy.dailyDeliveryCapacity < 0 || policy.dailyDeliveryCapacity > 10000) throw Error('Invalid delivery capacity.');
  const a = policy.serviceArea;
  if (a != null && (!Number.isFinite(a.latitude) || Math.abs(a.latitude) > 90 || !Number.isFinite(a.longitude) || Math.abs(a.longitude) > 180 || !Number.isFinite(a.radiusKm) || a.radiusKm <= 0 || a.radiusKm > 200 || typeof a.label !== 'string' || !a.label.trim() || a.label.length > 120)) throw Error('Invalid delivery service area.');
  if (policy.mode === 'manual' && (!a || policy.dailyDeliveryCapacity < 1)) throw Error('Live manual orders require a service area and daily capacity.');
  return policy;
}
function distanceKm(a, b) {
  const rad = n => n * Math.PI / 180;
  const x = Math.sin(rad(b.latitude - a.latitude) / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(rad(b.longitude - a.longitude) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(Math.max(0, 1 - x)));
}
function dateFor(now, lead, policy) {
  const local = new Date(now.getTime() + 8 * 3600000);
  const cutoffPassed = local.getUTCHours() >= policy.cutoffHour;
  local.setUTCHours(0, 0, 0, 0);
  const open = () => policy.operatingWeekdays.includes(local.getUTCDay()) && !policy.holidays.includes(local.toISOString().slice(0, 10));
  if (cutoffPassed) local.setUTCDate(local.getUTCDate() + 1);
  while (!open()) local.setUTCDate(local.getUTCDate() + 1);
  while (lead > 0) { local.setUTCDate(local.getUTCDate() + 1); if (open()) lead--; }
  return local.toISOString().slice(0, 10);
}
function quote(plan, address, now = new Date(), policy = configured) {
  validate(policy);
  if (!Number.isFinite(address.latitude) || !Number.isFinite(address.longitude)) d.fail('Confirm your delivery pin before continuing.', 'failed-precondition');
  if (policy.serviceArea && distanceKm(policy.serviceArea, address) > policy.serviceArea.radiusKm) d.fail('This address is outside our delivery area. Choose another address or contact the store.', 'failed-precondition');
  const groups = [];
  for (const [kind, items, lead] of [['ready_now', plan.ready, 0], ['planned', plan.planned, plan.lead]]) {
    if (!items.length) continue;
    const subtotalSen = items.reduce((sum, i) => sum + d.money(i.unitPrice) * i.quantity, 0);
    groups.push({kind, items: items.map(i => ({name:i.name, quantity:i.quantity, unitPrice:i.unitPrice})), date: dateFor(now, lead, policy), subtotalSen, deliveryFeeSen: 0, totalSen: subtotalSen});
  }
  const result = {mode: policy.mode, paymentInstructions: policy.mode === 'toyyibpay_sandbox'
    ? 'Test payments only. Complete ToyyibPay sandbox payment before preparation or delivery. Unpaid reservations expire after 30 minutes.'
    : policy.paymentInstructions, areaLabel: policy.serviceArea?.label ?? 'Store delivery area',
    openingHour: policy.openingHour, cutoffHour: policy.cutoffHour, groups,
    subtotalSen: groups.reduce((n, g) => n + g.subtotalSen, 0), deliveryFeeSen: groups.reduce((n, g) => n + g.deliveryFeeSen, 0), totalSen: groups.reduce((n, g) => n + g.totalSen, 0),
    timingNotice: 'Estimated dispatch dates, not guaranteed arrival times. Delivery depends on preparation and rider availability.'};
  return {...result, quoteId: digest({result, address, items: [...plan.ready, ...plan.planned], policy})};
}
module.exports = {configured, validate, distanceKm, dateFor, quote};
