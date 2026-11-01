'use strict';

function deliveryEligible(order) {
  return (
    order?.support?.status !== 'open' &&
    order?.riderId == null &&
    typeof order?.deliveryAddress === 'string' &&
    order.deliveryAddress.trim().length > 0 &&
    Number.isFinite(order.latitude) &&
    Math.abs(order.latitude) <= 90 &&
    Number.isFinite(order.longitude) &&
    Math.abs(order.longitude) <= 180
  );
}

const riderActiveStatuses = ['Rider assigned', 'Out for Delivery', 'Awaiting Customer Confirmation'];

module.exports = { deliveryEligible, riderActiveStatuses };
