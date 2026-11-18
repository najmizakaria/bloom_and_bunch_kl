const stripeSandboxMode = 'stripe_sandbox';
const stripeLiveMode = 'stripe_live';

bool isStripePaymentMode(Object? mode) =>
    mode == stripeSandboxMode || mode == stripeLiveMode;

bool isOnlinePaymentMode(Object? mode) =>
    isStripePaymentMode(mode) || mode == 'toyyibpay_sandbox';
