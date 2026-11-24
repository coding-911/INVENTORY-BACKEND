-- C9 거래 품목의 처리된 수량 = 원본 기록 합계 (INV-75)
--   매입·선발주: 입고·공급사 반품·오류 조정(그 취소·정정 포함)의 원장 수량 + 직납 수량
--   매출: 납품 수량 − 반품 수량
--   대차 전환으로 만든 문서: 그 대차 문서의 확정된 전환 정산 기록 수량 합계 (실제 제품별)
WITH lt AS (
    SELECT e.trade_line_id AS line_id, e.quantity_delta,
           CASE WHEN t.transaction_type IN ('REVERSAL', 'CORRECTION') THEN o.transaction_type
                ELSE t.transaction_type END AS eff_type
    FROM inventory.ledger_entries e
    JOIN inventory.stock_transactions t ON t.id = e.transaction_id AND t.status = 'POSTED'
    LEFT JOIN inventory.stock_transactions o ON o.id = t.related_transaction_id
    WHERE e.trade_line_id IS NOT NULL
), conv AS (
    SELECT converted_trade_document_id AS doc_id, id AS loan_id
    FROM loan.loan_documents WHERE converted_trade_document_id IS NOT NULL
), expected AS (
    SELECT l.id AS line_id,
           CASE WHEN d.trade_type IN ('PURCHASE', 'PRE_ORDER') THEN
                COALESCE((SELECT SUM(lt.quantity_delta) FROM lt
                          WHERE lt.line_id = l.id
                            AND lt.eff_type IN ('RECEIPT', 'SUPPLIER_RETURN', 'ADJUSTMENT')), 0)
              + COALESCE((SELECT SUM(dl.quantity) FROM delivery.delivery_lines dl
                          JOIN delivery.deliveries dv ON dv.id = dl.delivery_id AND dv.status = 'POSTED'
                          WHERE dl.purchase_line_id = l.id), 0)
           ELSE
                COALESCE((SELECT SUM(dl.quantity - dl.returned_quantity) FROM delivery.delivery_lines dl
                          JOIN delivery.deliveries dv ON dv.id = dl.delivery_id AND dv.status = 'POSTED'
                          WHERE dl.sales_line_id = l.id), 0)
           END AS qty
    FROM project.trade_lines l
    JOIN project.trade_documents d ON d.id = l.document_id
    WHERE d.id NOT IN (SELECT doc_id FROM conv)
)
SELECT 'trade_line' AS kind, l.id AS ref_id, l.product_id, l.fulfilled_quantity AS stored, x.qty AS expected
FROM project.trade_lines l JOIN expected x ON x.line_id = l.id
WHERE l.fulfilled_quantity <> x.qty
UNION ALL
SELECT 'converted_document', c.doc_id, s.product_id, s.stored, COALESCE(g.qty, 0)
FROM conv c
JOIN (SELECT document_id, product_id, SUM(fulfilled_quantity) AS stored
      FROM project.trade_lines GROUP BY document_id, product_id) s ON s.document_id = c.doc_id
LEFT JOIN (SELECT ll.loan_id, st.settled_product_id AS product_id, SUM(st.quantity) AS qty
           FROM loan.loan_settlements st JOIN loan.loan_lines ll ON ll.id = st.loan_line_id
           WHERE st.method = 'CONVERT' AND st.status = 'POSTED'
           GROUP BY 1, 2) g ON g.loan_id = c.loan_id AND g.product_id = s.product_id
WHERE s.stored <> COALESCE(g.qty, 0);

-- C10 배정 소진 수량 = 소진 이력 합계, 상태와 수량이 맞음 (INV-75)
--   출고 취소로 소진이 되돌아가면 CONSUME 이력을 음수 수량으로 남긴다
SELECT a.id, a.status, a.quantity, a.consumed_quantity,
       COALESCE(SUM(ev.quantity) FILTER (WHERE ev.action = 'CONSUME'), 0) AS consumed_by_events
FROM allocation.allocations a
LEFT JOIN allocation.allocation_events ev ON ev.allocation_id = a.id
GROUP BY a.id, a.status, a.quantity, a.consumed_quantity
HAVING a.consumed_quantity <> COALESCE(SUM(ev.quantity) FILTER (WHERE ev.action = 'CONSUME'), 0)
    OR (a.status = 'CONSUMED' AND a.consumed_quantity <> a.quantity)
    OR (a.status = 'ACTIVE' AND a.consumed_quantity >= a.quantity);

-- C11 납품 품목의 반품 수량 = 확정되고 취소되지 않은 반품 기록 합계 (INV-75)
--   반품 취소는 반품 입고 묶음 단위로 한다
SELECT dl.id, dl.returned_quantity, COALESCE(r.qty, 0) AS returned_by_records
FROM delivery.delivery_lines dl
LEFT JOIN (
    SELECT r.delivery_line_id, SUM(r.quantity) AS qty
    FROM delivery.delivery_returns r
    JOIN inventory.stock_transactions t ON t.id = r.transaction_id AND t.status = 'POSTED'
    WHERE r.delivery_line_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM inventory.stock_transactions x
                      WHERE x.related_transaction_id = t.id AND x.status = 'POSTED'
                        AND x.transaction_type IN ('REVERSAL', 'CORRECTION'))
    GROUP BY r.delivery_line_id) r ON r.delivery_line_id = dl.id
WHERE dl.returned_quantity <> COALESCE(r.qty, 0);

-- C12 장비 상태·현재 위치·소유 = 원장 위치 (INV-20)
WITH pos AS (
    SELECT e.equipment_id, e.location_id, e.stock_condition, e.owner_type, e.owner_partner_id,
           SUM(e.quantity_delta) AS qty
    FROM inventory.ledger_entries e
    JOIN inventory.stock_transactions t ON t.id = e.transaction_id AND t.status = 'POSTED'
    WHERE e.equipment_id IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5 HAVING SUM(e.quantity_delta) <> 0
), expect AS (
    SELECT q.id, q.status, q.current_location_id, q.owner_type, q.owner_partner_id,
           CASE q.status WHEN 'IN_STOCK'       THEN 'INTERNAL/AVAILABLE'
                         WHEN 'INSPECTION'     THEN 'INTERNAL/INSPECTION'
                         WHEN 'DEFECTIVE'      THEN 'INTERNAL/DEFECTIVE'
                         WHEN 'IN_REPAIR'      THEN 'REPAIR/IN_REPAIR'
                         WHEN 'LOANED_OUT'     THEN 'LOAN_OUT/*'
                         WHEN 'TEMP_INSTALLED' THEN 'CUSTOMER_SITE/*'
                         ELSE 'NONE' END AS place
    FROM equipment.equipment q
)
SELECT x.id, x.status, x.place, loc.location_type, p.stock_condition, p.qty
FROM expect x
LEFT JOIN pos p ON p.equipment_id = x.id
LEFT JOIN warehouse.locations loc ON loc.id = p.location_id
WHERE (x.place = 'NONE' AND p.equipment_id IS NOT NULL)
   OR (x.place <> 'NONE' AND (p.equipment_id IS NULL OR p.qty <> 1
        OR loc.location_type <> split_part(x.place, '/', 1)
        OR (split_part(x.place, '/', 2) <> '*' AND p.stock_condition <> split_part(x.place, '/', 2))
        OR p.location_id IS DISTINCT FROM x.current_location_id
        OR p.owner_type <> x.owner_type
        OR p.owner_partner_id IS DISTINCT FROM x.owner_partner_id));

-- C13 대차 품목의 정산 수량 = 확정된 정산 기록 합계 (INV-39)
SELECT ll.id, ll.settled_quantity, COALESCE(SUM(st.quantity) FILTER (WHERE st.status = 'POSTED'), 0) AS settled_by_records
FROM loan.loan_lines ll
LEFT JOIN loan.loan_settlements st ON st.loan_line_id = ll.id
GROUP BY ll.id, ll.settled_quantity
HAVING ll.settled_quantity <> COALESCE(SUM(st.quantity) FILTER (WHERE st.status = 'POSTED'), 0);

-- C14 검수 대기 배정 합계 ≤ 자사 창고 검수 대기 재고, 제품별 (INV-81)
WITH r AS (
    SELECT product_id, SUM(quantity - consumed_quantity) AS q
    FROM allocation.allocations
    WHERE status = 'ACTIVE' AND source_type = 'RECEIVED'
    GROUP BY product_id
), i AS (
    SELECT b.product_id, SUM(b.quantity) AS q
    FROM inventory.stock_balances b
    JOIN warehouse.locations l ON l.id = b.location_id
    WHERE l.location_type = 'INTERNAL' AND b.stock_condition = 'INSPECTION'
    GROUP BY b.product_id
)
SELECT r.product_id, r.q AS received_allocated, COALESCE(i.q, 0) AS inspection_stock
FROM r LEFT JOIN i ON i.product_id = r.product_id
WHERE r.q > COALESCE(i.q, 0);

-- C15 대차 품목: 정산 수량 ≤ 받은·내보낸 수량 (#89)
SELECT id, moved_quantity, settled_quantity
FROM loan.loan_lines
WHERE settled_quantity > moved_quantity;
