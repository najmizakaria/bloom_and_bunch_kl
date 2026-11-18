const stripeSandboxMode = 'stripe_sandbox';

bool isOnlinePaymentMode(Object? mode) =>
    mode == stripeSandboxMode || mode == 'toyyibpay_sandbox';
