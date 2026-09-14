WITH RECURSIVE eligible AS (
    SELECT * FROM campaign
    WHERE creation_status IN ('approved','aborted','resumed','stopped')
      AND processing_status = 'processed'
),
ancestry(id, root_id) AS (
    SELECT id, id FROM eligible WHERE parent_id IS NULL
    UNION ALL
    SELECT e.id, a.root_id
    FROM eligible e
    JOIN ancestry a ON e.parent_id = a.id
),
chain_flag AS (
    SELECT a.id, a.root_id,
           CASE WHEN e.parent_id IS NOT NULL
                 OR EXISTS (SELECT 1 FROM eligible e2 WHERE e2.parent_id = a.id)
                THEN 1 ELSE 0 END AS is_chain_member
    FROM ancestry a
    JOIN eligible e ON e.id = a.id
),
chain_part AS (
    SELECT cf.root_id, COUNT(DISTINCT cl.customer_id) AS n
    FROM chain_flag cf
    JOIN communication_log cl ON cl.communication_id = cf.id
    WHERE cf.is_chain_member = 1 AND cl.delivery_status = 900
    GROUP BY cf.root_id
),
standalone_part AS (
    SELECT COUNT(*) AS n
    FROM chain_flag cf
    JOIN communication_log cl ON cl.communication_id = cf.id
    WHERE cf.is_chain_member = 0 AND cl.delivery_status = 900
)
SELECT
  (SELECT COALESCE(SUM(n),0) FROM chain_part)      AS chain_customers_reached,  -- 15
  (SELECT n FROM standalone_part)                   AS standalone_events,        -- 7
  (SELECT COALESCE(SUM(n),0) FROM chain_part)
   + (SELECT n FROM standalone_part)                AS target_base;             -- 22
