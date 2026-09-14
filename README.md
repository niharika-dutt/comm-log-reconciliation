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

What Surprised Me:

The biggest surprise was that campaign 9004 had communication_log rows at all despite being approval_awaiting — the send pipeline can apparently outrun the approval bookkeeping, which is exactly the kind of quiet double-counting risk you wouldn't catch without cross-checking campaign and communication_log together. The second surprise was more subtle: a single global COUNT(DISTINCT customer_id) looks like the "obviously correct" fix for retries, but it's actually wrong — it silently merges C20's two legitimate, independent standalone sends into one and undercounts to 21. The correct rule depends on why a customer appears twice (retry chain vs. independent re-target), which isn't visible from customer_id alone — you have to route through the campaign's retry structure first.

A couple of things worth flagging since you'll need to defend this live: I built the retry-chain logic generically (via a recursive CTE walking parent_id) rather than hardcoding campaign IDs, so it'd hold up on a bigger dataset — make sure you can trace through why each CTE step exists. Also worth deciding for yourself (the given data doesn't force an answer either way): should a customer who's retried multiple times and never delivered still count as "reached"? Every retried customer in this dataset eventually succeeds, so it doesn't affect the number 22, but it's a real judgment call you should be ready to explain.
