# Petroleum Fixes Status

Updated: 2026-09-11

## Original Requests and Status

- [x] **1.The sold volume and cash expected isnt correct,  they id a deficit of about 3.95% in sold volume for  every pump upload**
- [x] **2. under bank deposit and admin , there is no need to fill in balance of cash at hand as the system automatically does this by minusing the cash deposited or collected from the totak cash already recored.**
- [x] **3. the receipt cant currently be shared after a bank deposit is made or recorded.**
- [x] **4. if an expense is recorded , users should select if the payment was cash ot transfer , if it is cash it should be minused from tge cash gotten from the pump upload or cash at hand .**
- [x] **5. the time stamp on upload sales history from the export sales tab and the time stamp from the upload on upload history  page dosent correspond, they should be in sync.**
- [x] **6. if an upload is made offline,  the time the uplaod was made should be saved alongside with it and that is the time and date that should show when the uplaod is finally sync online**
- [x] **7. under pump sale , after completing a sale,  the system should automatically redirect users back to the home page or clear the previous input,.**
- [x] **8. the cash breakdown analysis , users should only be able to edit amount of denominations,  but not the kind of denominations or the total of the denominations when the quantity is inputed, example is , If a user edits 1000 from 20 pcs to 30 pcs, the system automatically calculate the worth of 30pcs of 1000 , so they cant edit tge denominations from 1000, to 500 or vice versa or the worth once the quantity is included .**
- [x] **9. details such as pump number , product , product unit, product price cant be edited from the review page**
- [x] **10. under upload review, the system still shows the wrong sold volume,  but when approved, it goes back to the corrected sold volume.**
- [x] **11. under calculated sales, on the upload page, the sold vol show when cash opening and closing is inputed is wrong .**

## VPS Deployment

- [x] Uploaded updated `routes/pumps.js`.
- [x] Uploaded updated `routes/expenses.js`.
- [x] Uploaded `migration_049.sql`.
- [x] Applied `migration_049.sql` on the VPS database.
- [x] Restarted `managecare-backend` with PM2.
- [x] Saved the PM2 process list.
- [x] Confirmed backend health: database connected and MinIO configured.
- [x] Confirmed public HTTPS health endpoint is responding.

## Validation

- [x] Backend Node syntax checks passed for `routes/pumps.js` and `routes/expenses.js`.
- [x] Flutter analysis completed for the edited petroleum and expense files.
- [x] No new Flutter errors were reported; remaining findings are existing warnings.

## Notes

- The Flutter changes are implemented in the workspace and require building/installing the updated app for users to receive them.
- Existing historical uploads are not recalculated automatically by these changes. New reviews and future uploads use the corrected calculation.
- Added `server/managecare-backend/migration_050_petroleum_cash_tracking.sql` to repair missing petroleum cash tables/columns that caused bank-deposit and admin-cash submissions to return HTTP 500. Apply it on the VPS before restarting the backend.
