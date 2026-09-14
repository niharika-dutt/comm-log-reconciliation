# comm-log-reconciliation
Reconciles raw campaign send data (retries, approval gating, standalone sends) into Finance's target_base metric — bridges a naive row count of 30 down to the correct 22.
| Step | Description | Result | Reason |
|---|---|---|---|
| 0 | Naive count — just `COUNT(*)` on `communication_log` for merchant 501 | 30 | Starting point, counting every row as if it were a valid send |
| 1 | Dropped failed sends (`delivery_status = 1100`) | 26 (−4) | A failed send never actually reached the customer, so it shouldn't count on its own |
| 2 | Dropped all rows under campaign 9004, since it's still `approval_awaiting` | 22 (−4) | The sends went out but the campaign was never approved — turns out the send pipeline can run before approval catches up, so these shouldn't be reported |
| 3 | Checked whether retry chains (9001→9002→9003 and 9201→9202) needed deduping to distinct customers | 22 (no change) | Compared raw row count vs `COUNT(DISTINCT customer_id)` per chain — both came out to 15, since no one in this dataset gets delivered twice in the same chain. Still a real rule to have in there, just didn't move the number this time |
| 4 | Checked customer C20 in campaign 9101, who shows up twice | 22 (no change) | C20 was sent to twice independently, not retried — so both sends count. Almost made the mistake of deduping this globally, which would've wrongly dropped the total to 21 |
| **Final** | | **22** | Matches what Finance reported |
