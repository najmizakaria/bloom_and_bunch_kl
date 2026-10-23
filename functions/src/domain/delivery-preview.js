'use strict';

// These are public store details, matching the customer store-information page.
const pickupName = 'Bloom & Bunch KL';
const pickupAddress = 'Unit G2, StreetMall Cyberjaya, Cyberjaya, 63000 Cyberjaya, Selangor';
const states = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Penang',
  'Perak',
  'Perlis',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
  'Kuala Lumpur',
  'Putrajaya',
  'Labuan',
];
function stateName(value) {
  const text =
    typeof value === 'string'
      ? value.trim().replace(/^(?:w\.?p\.?|wilayah persekutuan)\s*/i, '')
      : '';
  return (
    states.find((state) => state.toLowerCase() === text.toLowerCase()) ??
    { kl: 'Kuala Lumpur', 'pulau pinang': 'Penang', malacca: 'Melaka' }[text.toLowerCase()] ??
    ''
  );
}
function safeLocality(value) {
  return (
    typeof value === 'string' &&
    value.length <= 80 &&
    /^[\p{L}][\p{L}\s.'’-]*$/u.test(value.trim()) &&
    !/\b(jalan|jln|street|road|lorong|persiaran|unit|apartment|apt|condominium|condo|residensi|residence|villa|building|block|blok|floor|level)\b/i.test(
      value,
    )
  );
}
function addressArea(raw = {}) {
  const source = typeof raw.address === 'string' ? raw.address : (raw.deliveryAddress ?? '');
  const parts =
    typeof source === 'string'
      ? source
          .split(',')
          .map((p) => p.trim())
          .filter(Boolean)
      : [];
  const explicitLocality = raw.locality ?? raw.deliveryLocality;
  const explicitPostcode = raw.postcode ?? raw.deliveryPostcode;
  const explicitState = raw.state ?? raw.deliveryState;
  let locality = safeLocality(explicitLocality) ? explicitLocality.trim() : '';
  let postcode =
    typeof explicitPostcode === 'string' && /^\d{5}$/.test(explicitPostcode)
      ? explicitPostcode
      : '';
  let state = stateName(explicitState);
  // Only a postcode paired with a place name is a reliable legacy locality.
  // Street/building/unit components do not become inferred locality names.
  for (const part of parts) {
    state ||= stateName(part);
    const match = /^(\d{5})(?:\s+(.+))?$/.exec(part);
    if (!match) continue;
    postcode ||= match[1];
    if (!locality && safeLocality(match[2]) && !stateName(match[2])) locality = match[2].trim();
    if (!locality && ['Kuala Lumpur', 'Putrajaya', 'Labuan'].includes(stateName(match[2])))
      locality = stateName(match[2]);
  }
  if (!locality && ['Kuala Lumpur', 'Putrajaya', 'Labuan'].includes(state)) locality = state;
  return { locality, postcode, state };
}
function preview(order) {
  const area = addressArea(order);
  const itemCount = (Array.isArray(order.items) ? order.items : []).reduce(
    (total, item) =>
      total + (Number.isSafeInteger(item?.quantity) && item.quantity > 0 ? item.quantity : 0),
    0,
  );
  return {
    deliveryAddress: typeof order.deliveryAddress === 'string' ? order.deliveryAddress.trim() : '',
    deliveryArea: area.locality
      ? [area.locality, area.postcode].filter(Boolean).join(' · ')
      : 'Area needs confirmation',
    deliveryLocality: area.locality,
    deliveryPostcode: area.postcode,
    deliveryState: area.state,
    pickupName,
    pickupAddress,
    itemCount,
    estimatedDispatchDate:
      typeof order.estimatedDispatchDate === 'string' ? order.estimatedDispatchDate : null,
    scheduledDeliveryDate:
      typeof order.scheduledDeliveryDate === 'string' ? order.scheduledDeliveryDate : null,
  };
}
module.exports = { addressArea, preview, safeLocality, stateName };
