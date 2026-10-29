# Address saving and review-pin label — 6 October 2026

The confirmed-pin control now says **Review delivery pin**, without the required star. The unconfirmed control remains **Confirm delivery pin ***; the other required field labels and optional delivery note are unchanged.

The three address-form tests passed, including saving retries with the same document ID and preserving the typed full address when a pin changes. The browser journey expectation was updated to the new label. The unchanged backend was previously verified by 53 strict emulator tests and four authenticated browser journeys, including real callable address creation.

## Live service blocker

The read-only Functions inventory on 6 October still contains only placeOrder, reviewRiderApplication, saveRecipe, syncDeliveryJobs and transitionOrder. The address service callables are absent from bloom-and-bunch-kl in asia-southeast1. This matches the screenshot's service-unavailable message.

The prepared limited release creates only saveAddress, setDefaultAddress and deleteAddress from the existing tested orders codebase. These authenticate the caller, use the caller's UID for the address path, validate address data, and coordinate default changes transactionally. Direct client writes are not substituted for these transactions.

```powershell
firebase deploy --only functions:orders:saveAddress,functions:orders:setDefaultAddress,functions:orders:deleteAddress --project bloom-and-bunch-kl
```

Deployment authorization is pending because production release was previously deferred. No changes to other Functions, Hosting, security rules, indexes or business/payment policy are included in this limited release. The installed app can use newly deployed callables without a rebuild; seeing the updated pin button requires rebuilding/installing the updated client.

After release, verify the three functions are active in asia-southeast1 and reject unauthenticated calls. An authenticated save should then be retried using the user's existing app and account. Do not create fabricated production users or addresses to claim end-to-end live success.

The previously missing quoteCheckout and other callables remain a separate coordinated backend release requirement; publishing these three address functions alone does not claim the entire live checkout is ready.
