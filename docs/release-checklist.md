# Bloom & Bunch release checklist

Run these commands from the VS Code terminal in the project root:

```powershell
flutter pub get
flutter analyze
flutter test
firebase emulators:exec --project demo-bloom --only firestore,storage "npm --prefix functions test"
flutter build apk --debug
```

Before a live release, verify the Firebase `users` collection contains only the
intended `admin`, `florist`, and `rider` accounts. The client cannot grant these
roles after the new rules are deployed.

Deploy the backend and rules together so checkout is never left with only half
of the required system:

```powershell
firebase deploy --project bloom-and-bunch-kl --only functions,firestore,storage
```

After deployment, use separate customer, florist, and approved rider accounts.

1. Customer: place a Ready-to-Send order. Confirm it starts at **Ready for Delivery** and assembled stock decreases once.
2. Rider: accept that order. Confirm it becomes **Out for Delivery** and disappears from another rider's Available list.
3. Rider: mark it delivered. Confirm the customer sees **Delivered**.
4. Customer: place a Pre-Order. Confirm it starts at **Awaiting Preparation** and ready stock is unchanged.
5. Florist: start preparation, restock any shortage, then mark it ready.
6. Customer: build a custom bouquet using a zero-stock flower. Confirm checkout succeeds and the florist sees reserved demand and the shortage.
7. Customer: retry checkout after a slow connection. Confirm only one order group and one stock deduction exist.
8. Customer: select a saved address, edit it later, and confirm the existing order keeps its original delivery snapshot.
9. Customer: submit a rider application. Confirm only the admin dashboard can approve it and approval routes that account to the rider dashboard.

The generated debug APK is at:

`build\app\outputs\flutter-apk\app-debug.apk`
