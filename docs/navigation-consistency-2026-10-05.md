# Rider navigation and page headers — 5 October 2026

Implemented in the main2 working checkout.

- Rider workspace uses the same Material NavigationBar as the customer workspace, with Available jobs, Deliveries, History and More at the bottom. The previous top tab strip is removed.
- Rider pages initialize when first visited and retain state. Cached queries preserve pagination while changing destinations. Cached profile subscription avoids reconnecting whenever a destination changes.
- Accepting a job automatically selects Deliveries. More retains logout and authorized switching to the customer workspace.
- All 31 existing AppBar headers use the shared left-side PageBackButton and explicitly left-aligned titles. Authentication forms also use the shared back control.
- A detail page's Back arrow pops that route. On customer/florist/admin/rider workspace tabs, Back returns to the first/Home destination. On Home with no earlier route, the arrow is visible but disabled, with an explanatory tooltip. It does not exit the app or sign the user out.

Validation: all 72 Flutter tests passed, all 4 connected Chrome journeys passed together with every journey enabled, static analysis found no issues, and Git whitespace validation passed. Three new tests verify disabled root Back, tab-to-Home navigation and detail route priority. Browser assertions verify rider bottom selection after accepting a delivery, the removal of the top tab bar, and Back from More/History to Available jobs; existing role switching and purchase/delivery journeys still pass.

No backend/rule changes or deployment were needed for this navigation update. Backend tests were not rerun because backend code is unchanged. The existing Java rules-tool shutdown message occurs after the successful browser script exit. Verified test processes were cleaned up.
